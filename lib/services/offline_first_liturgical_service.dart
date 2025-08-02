import 'package:flutter/foundation.dart';
import '../models/liturgical_reading.dart';
import '../models/liturgical_day.dart';
import '../models/user_bookmark.dart';
import './offline_storage_service.dart';
import './connectivity_service.dart';
import './sync_manager_service.dart';
import './liturgical_service.dart';

class OfflineFirstLiturgicalService {
  static final OfflineFirstLiturgicalService _instance =
      OfflineFirstLiturgicalService._internal();
  factory OfflineFirstLiturgicalService() => _instance;
  OfflineFirstLiturgicalService._internal();

  final OfflineStorageService _offlineStorage = OfflineStorageService();
  final ConnectivityService _connectivity = ConnectivityService();
  final SyncManagerService _syncManager = SyncManagerService();
  final LiturgicalService _fallbackService = LiturgicalService();

  bool _isInitialized = false;

  // Initialize offline-first service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _offlineStorage.initialize();
      await _connectivity.initialize();
      await _syncManager.initialize();

      _isInitialized = true;
      debugPrint('OfflineFirstLiturgicalService: Initialized successfully');
    } catch (e) {
      debugPrint('OfflineFirstLiturgicalService: Failed to initialize: $e');
      throw Exception('Failed to initialize offline-first service: $e');
    }
  }

  // Get today's liturgical readings with offline-first approach
  Future<List<LiturgicalReading>> getTodaysReadings() async {
    final today = DateTime.now();
    return await getReadingsForDate(today);
  }

  // Get liturgical day with offline-first approach
  Future<LiturgicalDay> getLiturgicalDay({DateTime? date}) async {
    final targetDate = date ?? DateTime.now();

    try {
      // Step 1: Try cache first (fastest)
      final cachedDay =
          await _offlineStorage.getCachedLiturgicalDay(targetDate);
      if (cachedDay != null) {
        debugPrint(
            'OfflineFirstLiturgicalService: Got liturgical day from cache for $targetDate');

        // Trigger background sync if online and not already syncing
        if (_connectivity.isOnline && !_syncManager.isSyncing) {
          // Don't await - let it happen in background
          _syncManager.performSmartSync().catchError((e) {
            debugPrint(
                'OfflineFirstLiturgicalService: Background sync failed: $e');
          });
        }

        return cachedDay;
      }

      // Step 2: If not in cache and online, fetch and cache
      if (_connectivity.isOnline) {
        debugPrint(
            'OfflineFirstLiturgicalService: Fetching liturgical day from network for $targetDate');

        final liturgicalDay =
            await _fallbackService.getLiturgicalDay(date: targetDate);

        // Cache the result for future use
        await _offlineStorage.cacheLiturgicalDay(liturgicalDay);

        return liturgicalDay;
      }

      // Step 3: Offline and not cached - use fallback service (local calculation)
      debugPrint(
          'OfflineFirstLiturgicalService: Using fallback calculation for $targetDate');
      final liturgicalDay =
          await _fallbackService.getLiturgicalDay(date: targetDate);

      // Cache the calculated result
      await _offlineStorage.cacheLiturgicalDay(liturgicalDay);

      return liturgicalDay;
    } catch (e) {
      debugPrint(
          'OfflineFirstLiturgicalService: Error getting liturgical day for $targetDate: $e');

      // Final fallback - use the original service
      return await _fallbackService.getLiturgicalDay(date: targetDate);
    }
  }

  // Get readings for a specific date with offline-first approach
  Future<List<LiturgicalReading>> getReadingsForDate(DateTime date) async {
    try {
      // Step 1: Try cache first (fastest)
      final cachedReadings = await _offlineStorage.getCachedReadings(date);
      if (cachedReadings.isNotEmpty) {
        debugPrint(
            'OfflineFirstLiturgicalService: Got ${cachedReadings.length} readings from cache for $date');

        // Trigger background sync if online and not already syncing
        if (_connectivity.isOnline && !_syncManager.isSyncing) {
          // Don't await - let it happen in background
          _syncManager.performSmartSync().catchError((e) {
            debugPrint(
                'OfflineFirstLiturgicalService: Background sync failed: $e');
          });
        }

        return cachedReadings;
      }

      // Step 2: If not in cache and online, fetch and cache
      if (_connectivity.isOnline) {
        debugPrint(
            'OfflineFirstLiturgicalService: Fetching readings from network for $date');

        final readings = await _fallbackService.getReadingsForDate(date);

        if (readings.isNotEmpty) {
          // Cache the readings for future use
          await _offlineStorage.cacheLiturgicalReadings(readings);

          // Also ensure we have the liturgical day cached
          final liturgicalDay = await getLiturgicalDay(date: date);
          await _offlineStorage.cacheLiturgicalDay(liturgicalDay);
        }

        return readings;
      }

      // Step 3: Offline and not cached - use fallback service
      debugPrint(
          'OfflineFirstLiturgicalService: Using fallback readings for $date');
      final readings = await _fallbackService.getReadingsForDate(date);

      // Cache the fallback results
      if (readings.isNotEmpty) {
        await _offlineStorage.cacheLiturgicalReadings(readings);
      }

      return readings;
    } catch (e) {
      debugPrint(
          'OfflineFirstLiturgicalService: Error getting readings for $date: $e');

      // Final fallback - use the original service
      return await _fallbackService.getReadingsForDate(date);
    }
  }

  // Get readings for a date range with offline-first approach
  Future<Map<DateTime, List<LiturgicalReading>>> getReadingsForDateRange({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final start = startDate ?? DateTime.now();
    final end = endDate ?? DateTime.now().add(const Duration(days: 7));

    final readings = <DateTime, List<LiturgicalReading>>{};

    try {
      // Generate all dates in the range
      DateTime current = start;
      while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
        final dateReadings = await getReadingsForDate(current);
        if (dateReadings.isNotEmpty) {
          readings[current] = dateReadings;
        }
        current = current.add(const Duration(days: 1));
      }

      debugPrint(
          'OfflineFirstLiturgicalService: Got readings for ${readings.length} days in range');
      return readings;
    } catch (e) {
      debugPrint(
          'OfflineFirstLiturgicalService: Error getting readings for date range: $e');

      // Fallback to original service
      return await _fallbackService.getReadingsForDateRange(
        startDate: startDate,
        endDate: endDate,
      );
    }
  }

  // Get moveable feasts with offline-first consideration
  Future<List<Map<String, dynamic>>> getMoveableFeasts({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    // For moveable feasts, we delegate to the fallback service since this data
    // is less frequently accessed and calculation-based
    return await _fallbackService.getMoveableFeasts(
      startDate: startDate,
      endDate: endDate,
    );
  }

  // Get liturgical year information
  Future<Map<String, dynamic>?> getLiturgicalYearInfo(
      int liturgicalYear) async {
    return await _fallbackService.getLiturgicalYearInfo(liturgicalYear);
  }

  // Get user bookmarks (delegates to original service for now)
  Future<List<UserBookmark>> getUserBookmarks(String userId) async {
    return await _fallbackService.getUserBookmarks(userId);
  }

  // Create bookmark (delegates to original service)
  Future<UserBookmark?> createBookmark({
    required String userId,
    required String readingId,
    required String readingType,
    required DateTime date,
    String? note,
    bool isPrivate = true,
  }) async {
    return await _fallbackService.createBookmark(
      userId: userId,
      readingId: readingId,
      readingType: readingType,
      date: date,
      note: note,
      isPrivate: isPrivate,
    );
  }

  // Delete bookmark (delegates to original service)
  Future<bool> deleteBookmark(String bookmarkId) async {
    return await _fallbackService.deleteBookmark(bookmarkId);
  }

  // Initialize liturgical calendar
  Future<void> initializeLiturgicalCalendar() async {
    await _fallbackService.initializeLiturgicalCalendar();
  }

  // Force sync trigger
  Future<bool> forceSync() async {
    return await _syncManager.triggerManualSync();
  }

  // Get cache statistics
  Future<Map<String, dynamic>> getCacheStats() async {
    return await _syncManager.getSyncStats();
  }

  // Check if specific date is cached
  Future<bool> isDateCached(DateTime date) async {
    return await _offlineStorage.hasDataForDate(date);
  }

  // Clear cache
  Future<void> clearCache() async {
    // This would be implemented if needed for maintenance
    debugPrint(
        'OfflineFirstLiturgicalService: Cache clearing not implemented yet');
  }

  // Check service availability
  bool get isAvailable => _isInitialized && _offlineStorage.isInitialized;

  // Enhanced status message with offline-first context
  String get statusMessage {
    if (!_isInitialized) {
      return 'Offline-first service initializing...';
    }

    if (_connectivity.isOnline) {
      if (_syncManager.isSyncing) {
        final progress = (_syncManager.syncProgress * 100).toStringAsFixed(0);
        return 'Online - Syncing liturgical data ($progress% complete)';
      } else {
        return 'Online - 90-day cache ready, background sync active';
      }
    } else {
      return 'Offline - Using cached readings (90-day offline capability)';
    }
  }

  // Get detailed service status
  Future<Map<String, dynamic>> getServiceStatus() async {
    final syncStats = await _syncManager.getSyncStats();
    final connectivityInfo = await _connectivity.getConnectivityInfo();
    final cacheSize = await _offlineStorage.getCacheSizeInMB();

    return {
      'service_initialized': _isInitialized,
      'cache_size_mb': cacheSize.toStringAsFixed(2),
      'connectivity': connectivityInfo,
      'sync': syncStats,
      'offline_first_ready': isAvailable && syncStats['cached_days'] > 60,
    };
  }

  // Check if service is initialized
  bool get isInitialized => _isInitialized;

  // Get sync manager for direct access if needed
  SyncManagerService get syncManager => _syncManager;

  // Get connectivity service for direct access if needed
  ConnectivityService get connectivityService => _connectivity;
}
