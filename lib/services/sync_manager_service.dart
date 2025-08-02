import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import './offline_storage_service.dart';
import './connectivity_service.dart';
import './liturgical_service.dart';

enum SyncStatus {
  idle,
  syncing,
  success,
  error,
  paused,
}

class SyncManagerService {
  static final SyncManagerService _instance = SyncManagerService._internal();
  factory SyncManagerService() => _instance;
  SyncManagerService._internal();

  final OfflineStorageService _offlineStorage = OfflineStorageService();
  final ConnectivityService _connectivity = ConnectivityService();
  final LiturgicalService _liturgicalService = LiturgicalService();

  SyncStatus _syncStatus = SyncStatus.idle;
  final StreamController<SyncStatus> _statusController =
      StreamController<SyncStatus>.broadcast();
  final StreamController<String> _messageController =
      StreamController<String>.broadcast();

  Timer? _backgroundSyncTimer;
  Timer? _preloadTimer;
  StreamSubscription<ConnectivityStatus>? _connectivitySubscription;

  bool _isInitialized = false;
  DateTime? _lastSyncTime;
  int _syncProgress = 0;
  int _totalSyncItems = 0;
  String _lastSyncError = '';

  // Retry configuration
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 5);
  static const Duration _backgroundSyncInterval = Duration(hours: 6);
  static const Duration _preloadCheckInterval = Duration(hours: 12);

  // Initialize sync manager
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _offlineStorage.initialize();
      await _connectivity.initialize();

      // Listen for connectivity changes
      _connectivitySubscription = _connectivity.statusStream.listen(
        _onConnectivityChanged,
        onError: (error) {
          debugPrint(
              'SyncManagerService: Error monitoring connectivity: $error');
        },
      );

      // Start background sync timer
      _startBackgroundSyncTimer();

      // Start preload check timer
      _startPreloadCheckTimer();

      // Initial sync if online
      if (_connectivity.isOnline) {
        unawaited(_performInitialSync());
      }

      _isInitialized = true;
      debugPrint('SyncManagerService: Initialized successfully');
    } catch (e) {
      debugPrint('SyncManagerService: Failed to initialize: $e');
      _updateSyncStatus(SyncStatus.error);
      _updateMessage('Sync initialization failed');
    }
  }

  // Handle connectivity changes
  void _onConnectivityChanged(ConnectivityStatus status) {
    debugPrint('SyncManagerService: Connectivity changed to $status');

    if (status == ConnectivityStatus.online &&
        _syncStatus != SyncStatus.syncing) {
      // Reconnected - attempt sync after brief delay
      Timer(const Duration(seconds: 2), () {
        if (_connectivity.isOnline) {
          unawaited(performSmartSync());
        }
      });
    } else if (status == ConnectivityStatus.offline) {
      _updateMessage('Offline - Using cached content');
    }
  }

  // Perform initial sync on app start
  Future<void> _performInitialSync() async {
    try {
      debugPrint('SyncManagerService: Starting initial sync');
      await performFullPreload();
    } catch (e) {
      debugPrint('SyncManagerService: Initial sync failed: $e');
    }
  }

  // Smart sync - only sync what's needed
  Future<bool> performSmartSync() async {
    if (!_connectivity.isOnline || _syncStatus == SyncStatus.syncing) {
      return false;
    }

    try {
      _updateSyncStatus(SyncStatus.syncing);
      _updateMessage('Syncing liturgical data...');

      // Check what dates are missing in our 90-day range
      final missingDates = await _offlineStorage.getMissingDatesInRange();

      if (missingDates.isEmpty) {
        _updateSyncStatus(SyncStatus.success);
        _updateMessage('All data is up to date');
        _lastSyncTime = DateTime.now();
        return true;
      }

      _totalSyncItems = missingDates.length;
      _syncProgress = 0;

      // Prioritize dates closer to today
      missingDates.sort((a, b) {
        final now = DateTime.now();
        final diffA = (a.difference(now).inDays).abs();
        final diffB = (b.difference(now).inDays).abs();
        return diffA.compareTo(diffB);
      });

      // Sync in batches to avoid overwhelming the API
      const batchSize = 5;
      for (int i = 0; i < missingDates.length; i += batchSize) {
        if (!_connectivity.isOnline) break;

        final batch = missingDates.sublist(
          i,
          math.min(i + batchSize, missingDates.length),
        );

        await _syncDateBatch(batch);
        _syncProgress += batch.length;
        _updateMessage('Synced ${_syncProgress}/${_totalSyncItems} days');

        // Brief pause between batches
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Clean old cache data
      await _offlineStorage.cleanOldCacheData();

      _updateSyncStatus(SyncStatus.success);
      _updateMessage('Sync completed successfully');
      _lastSyncTime = DateTime.now();

      // Update cache metadata
      await _offlineStorage.setCacheMetadata(
          'last_sync_time', DateTime.now().toIso8601String());

      return true;
    } catch (e) {
      debugPrint('SyncManagerService: Smart sync failed: $e');
      _lastSyncError = e.toString();
      _updateSyncStatus(SyncStatus.error);
      _updateMessage('Sync failed: ${e.toString()}');
      return false;
    }
  }

  // Full preload - ensure we have 90 days of data
  Future<bool> performFullPreload() async {
    if (!_connectivity.isOnline) {
      debugPrint('SyncManagerService: Cannot preload - offline');
      return false;
    }

    try {
      _updateSyncStatus(SyncStatus.syncing);
      _updateMessage('Pre-loading 90 days of readings...');

      // Generate all dates in 90-day range (30 past, 60 future)
      final now = DateTime.now();
      final startDate = now.subtract(const Duration(days: 30));
      final endDate = now.add(const Duration(days: 60));

      final allDates = <DateTime>[];
      DateTime current = startDate;

      while (current.isBefore(endDate) || current.isAtSameMomentAs(endDate)) {
        allDates.add(current);
        current = current.add(const Duration(days: 1));
      }

      _totalSyncItems = allDates.length;
      _syncProgress = 0;

      // Sync in smaller batches for preload
      const batchSize = 3;
      for (int i = 0; i < allDates.length; i += batchSize) {
        if (!_connectivity.isOnline) break;

        final batch = allDates.sublist(
          i,
          math.min(i + batchSize, allDates.length),
        );

        await _syncDateBatch(batch,
            forceSync: false); // Don't force if already cached
        _syncProgress += batch.length;
        _updateMessage('Pre-loaded ${_syncProgress}/${_totalSyncItems} days');

        // Longer pause during preload to be gentle on API
        await Future.delayed(const Duration(seconds: 1));
      }

      _updateSyncStatus(SyncStatus.success);
      _updateMessage('Pre-load completed - 90 days ready');
      _lastSyncTime = DateTime.now();

      return true;
    } catch (e) {
      debugPrint('SyncManagerService: Full preload failed: $e');
      _lastSyncError = e.toString();
      _updateSyncStatus(SyncStatus.error);
      _updateMessage('Pre-load failed: ${e.toString()}');
      return false;
    }
  }

  // Sync a batch of dates
  Future<void> _syncDateBatch(List<DateTime> dates,
      {bool forceSync = true}) async {
    for (final date in dates) {
      if (!_connectivity.isOnline) break;

      try {
        // Skip if already cached and not forcing sync
        if (!forceSync && await _offlineStorage.hasDataForDate(date)) {
          continue;
        }

        // Get liturgical day
        final liturgicalDay =
            await _liturgicalService.getLiturgicalDay(date: date);
        await _offlineStorage.cacheLiturgicalDay(liturgicalDay);

        // Get readings for the day
        final readings = await _liturgicalService.getReadingsForDate(date);
        if (readings.isNotEmpty) {
          await _offlineStorage.cacheLiturgicalReadings(readings);
        }

        debugPrint('SyncManagerService: Synced data for $date');
      } catch (e) {
        debugPrint('SyncManagerService: Failed to sync date $date: $e');
        // Continue with other dates even if one fails
      }
    }
  }

  // Start background sync timer
  void _startBackgroundSyncTimer() {
    _backgroundSyncTimer?.cancel();
    _backgroundSyncTimer = Timer.periodic(_backgroundSyncInterval, (timer) {
      if (_connectivity.isOnline && _syncStatus != SyncStatus.syncing) {
        debugPrint('SyncManagerService: Starting background sync');
        unawaited(performSmartSync());
      }
    });
  }

  // Start preload check timer
  void _startPreloadCheckTimer() {
    _preloadTimer?.cancel();
    _preloadTimer = Timer.periodic(_preloadCheckInterval, (timer) {
      if (_connectivity.isOnline && _syncStatus != SyncStatus.syncing) {
        debugPrint('SyncManagerService: Checking preload status');
        unawaited(_checkPreloadStatus());
      }
    });
  }

  // Check if preload needs updating
  Future<void> _checkPreloadStatus() async {
    try {
      final missingDates = await _offlineStorage.getMissingDatesInRange();

      // If we're missing more than 10 days, trigger a smart sync
      if (missingDates.length > 10) {
        debugPrint(
            'SyncManagerService: Missing ${missingDates.length} days, triggering sync');
        await performSmartSync();
      }
    } catch (e) {
      debugPrint('SyncManagerService: Preload check failed: $e');
    }
  }

  // Update sync status
  void _updateSyncStatus(SyncStatus status) {
    if (_syncStatus == status) return;
    _syncStatus = status;
    _statusController.add(status);
  }

  // Update message
  void _updateMessage(String message) {
    debugPrint('SyncManagerService: $message');
    _messageController.add(message);
  }

  // Manual sync trigger
  Future<bool> triggerManualSync() async {
    if (_syncStatus == SyncStatus.syncing) {
      debugPrint('SyncManagerService: Sync already in progress');
      return false;
    }

    if (!_connectivity.isOnline) {
      _updateMessage('Cannot sync - device is offline');
      return false;
    }

    debugPrint('SyncManagerService: Manual sync triggered');
    return await performSmartSync();
  }

  // Pause sync operations
  void pauseSync() {
    if (_syncStatus == SyncStatus.syncing) {
      _updateSyncStatus(SyncStatus.paused);
      _updateMessage('Sync paused');
    }
    _backgroundSyncTimer?.cancel();
    _preloadTimer?.cancel();
  }

  // Resume sync operations
  void resumeSync() {
    if (_syncStatus == SyncStatus.paused) {
      _updateSyncStatus(SyncStatus.idle);
      _updateMessage('Sync resumed');
    }
    _startBackgroundSyncTimer();
    _startPreloadCheckTimer();
  }

  // Get sync statistics
  Future<Map<String, dynamic>> getSyncStats() async {
    final cacheStats = await _offlineStorage.getCacheStats();
    final cacheSize = await _offlineStorage.getCacheSizeInMB();

    return {
      'sync_status': _syncStatus.name,
      'last_sync_time': _lastSyncTime?.toIso8601String(),
      'sync_progress': _syncProgress,
      'total_sync_items': _totalSyncItems,
      'cached_days': cacheStats['cached_days'] ?? 0,
      'cached_readings': cacheStats['cached_readings'] ?? 0,
      'cache_size_mb': cacheSize.toStringAsFixed(2),
      'last_error': _lastSyncError,
      'connectivity_status': _connectivity.currentStatus.name,
      'is_initialized': _isInitialized,
    };
  }

  // Get current sync status
  SyncStatus get syncStatus => _syncStatus;

  // Sync status stream
  Stream<SyncStatus> get statusStream => _statusController.stream;

  // Message stream
  Stream<String> get messageStream => _messageController.stream;

  // Check if sync is in progress
  bool get isSyncing => _syncStatus == SyncStatus.syncing;

  // Get last sync time
  DateTime? get lastSyncTime => _lastSyncTime;

  // Get sync progress
  double get syncProgress =>
      _totalSyncItems > 0 ? _syncProgress / _totalSyncItems : 0.0;

  // Dispose resources
  void dispose() {
    _backgroundSyncTimer?.cancel();
    _preloadTimer?.cancel();
    _connectivitySubscription?.cancel();
    _statusController.close();
    _messageController.close();
    _isInitialized = false;
  }

  // Check if service is initialized
  bool get isInitialized => _isInitialized;
}
