import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cron/cron.dart';
import 'package:background_fetch/background_fetch.dart';

import './liturgical_data_scraper_service.dart';
import './supabase_service.dart';

/// Automated scheduler service for daily liturgical data scraping at 12:01 AM
/// Handles both foreground cron jobs and background fetch for mobile platforms
class LiturgicalSchedulerService {
  static final LiturgicalSchedulerService _instance =
      LiturgicalSchedulerService._internal();
  factory LiturgicalSchedulerService() => _instance;
  LiturgicalSchedulerService._internal();

  final Cron _cron = Cron();
  final LiturgicalDataScraperService _scraperService =
      LiturgicalDataScraperService();

  bool _isInitialized = false;
  bool _isSchedulerActive = false;
  Timer? _fallbackTimer;
  StreamController<Map<String, dynamic>>? _statusController;

  /// Initialize the scheduler service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize status broadcast stream
      _statusController = StreamController<Map<String, dynamic>>.broadcast();

      if (kIsWeb) {
        await _initializeWebScheduler();
      } else {
        await _initializeMobileScheduler();
      }

      // Setup daily cron job for 12:01 AM
      await _setupDailyCronJob();

      // Setup fallback timer as backup
      await _setupFallbackTimer();

      _isInitialized = true;
      _isSchedulerActive = true;

      debugPrint('LiturgicalScheduler: Initialized successfully');
      _broadcastStatus('initialized', 'Scheduler service started');
    } catch (e) {
      debugPrint('LiturgicalScheduler: Initialization failed: $e');
      _broadcastStatus('error', 'Failed to initialize: $e');
      rethrow;
    }
  }

  /// Initialize web-specific scheduler
  Future<void> _initializeWebScheduler() async {
    debugPrint('LiturgicalScheduler: Initializing web scheduler');
    // Web browsers don't support true background tasks
    // Use foreground cron jobs only
  }

  /// Initialize mobile-specific scheduler with background fetch
  Future<void> _initializeMobileScheduler() async {
    debugPrint('LiturgicalScheduler: Initializing mobile scheduler');

    try {
      // Configure background fetch
      final status = await BackgroundFetch.configure(
          BackgroundFetchConfig(
            minimumFetchInterval: 15, // 15 minutes minimum
            stopOnTerminate: false,
            enableHeadless: true,
            requiresBatteryNotLow: false,
            requiresCharging: false,
            requiresStorageNotLow: false,
            requiresDeviceIdle: false,
            requiredNetworkType: NetworkType.ANY,
          ),
          _onBackgroundFetch,
          _onBackgroundFetchTimeout);

      debugPrint('LiturgicalScheduler: Background fetch status: $status');

      if (status == BackgroundFetch.STATUS_AVAILABLE) {
        // Start background fetch
        await BackgroundFetch.start();
        debugPrint('LiturgicalScheduler: Background fetch started');
      }
    } catch (e) {
      debugPrint('LiturgicalScheduler: Background fetch setup failed: $e');
      // Continue without background fetch - cron jobs will still work
    }
  }

  /// Setup daily cron job for 12:01 AM local time
  Future<void> _setupDailyCronJob() async {
    try {
      // Schedule for 12:01 AM every day
      _cron.schedule(Schedule.parse('1 0 * * *'), () async {
        debugPrint(
            'LiturgicalScheduler: Daily cron job triggered at ${DateTime.now()}');
        await _executeDailySync();
      });

      // Also schedule a backup job at 12:05 AM in case the first one fails
      _cron.schedule(Schedule.parse('5 0 * * *'), () async {
        debugPrint(
            'LiturgicalScheduler: Backup cron job triggered at ${DateTime.now()}');
        await _executeBackupSync();
      });

      debugPrint('LiturgicalScheduler: Daily cron jobs scheduled');
    } catch (e) {
      debugPrint('LiturgicalScheduler: Failed to setup cron jobs: $e');
      throw Exception('Cron job setup failed: $e');
    }
  }

  /// Setup fallback timer as additional safety net
  Future<void> _setupFallbackTimer() async {
    // Check every hour if daily sync was missed
    _fallbackTimer = Timer.periodic(const Duration(hours: 1), (timer) async {
      await _checkAndExecuteMissedSync();
    });

    debugPrint('LiturgicalScheduler: Fallback timer setup');
  }

  /// Execute daily synchronization
  Future<void> _executeDailySync() async {
    _broadcastStatus('running', 'Executing daily sync');

    try {
      final today = DateTime.now();
      final tomorrow = today.add(const Duration(days: 1));

      debugPrint(
          'LiturgicalScheduler: Starting daily sync for $today and $tomorrow');

      // Sync today's readings (in case of updates)
      final todayResults = await _scraperService.executeDataPipeline(today);

      // Sync tomorrow's readings (prepare ahead)
      final tomorrowResults =
          await _scraperService.executeDataPipeline(tomorrow);

      // Update sync job status in database
      await _updateSyncJobStatus(today, 'success', {
        'today_results': todayResults,
        'tomorrow_results': tomorrowResults,
      });

      final totalCreated = (todayResults['readings_created'] as int) +
          (tomorrowResults['readings_created'] as int);
      final totalUpdated = (todayResults['readings_updated'] as int) +
          (tomorrowResults['readings_updated'] as int);

      _broadcastStatus('completed',
          'Daily sync completed: $totalCreated created, $totalUpdated updated');

      debugPrint('LiturgicalScheduler: Daily sync completed successfully');
    } catch (e) {
      debugPrint('LiturgicalScheduler: Daily sync failed: $e');

      await _updateSyncJobStatus(DateTime.now(), 'failed', {
        'error': e.toString(),
      });

      _broadcastStatus('error', 'Daily sync failed: $e');

      // Schedule retry in 30 minutes
      Timer(const Duration(minutes: 30), () async {
        debugPrint('LiturgicalScheduler: Retrying failed sync');
        await _executeDailySync();
      });
    }
  }

  /// Execute backup sync (more conservative)
  Future<void> _executeBackupSync() async {
    try {
      // Check if primary sync already succeeded today
      final hasRecentSync = await _hasRecentSuccessfulSync();
      if (hasRecentSync) {
        debugPrint(
            'LiturgicalScheduler: Backup sync skipped - primary sync already completed');
        return;
      }

      debugPrint('LiturgicalScheduler: Executing backup sync');
      await _executeDailySync();
    } catch (e) {
      debugPrint('LiturgicalScheduler: Backup sync failed: $e');
    }
  }

  /// Background fetch handler for mobile platforms
  void _onBackgroundFetch(String taskId) async {
    debugPrint('LiturgicalScheduler: Background fetch triggered: $taskId');

    try {
      // Only execute if it's appropriate time (around midnight or if data is stale)
      if (_shouldExecuteBackgroundSync()) {
        await _executeDailySync();
      } else {
        debugPrint(
            'LiturgicalScheduler: Background sync skipped - not appropriate time');
      }

      // Always finish the background task
      BackgroundFetch.finish(taskId);
    } catch (e) {
      debugPrint('LiturgicalScheduler: Background fetch failed: $e');
      BackgroundFetch.finish(taskId);
    }
  }

  /// Background fetch timeout handler
  void _onBackgroundFetchTimeout(String taskId) {
    debugPrint('LiturgicalScheduler: Background fetch timeout: $taskId');
    BackgroundFetch.finish(taskId);
  }

  /// Check if background sync should execute
  bool _shouldExecuteBackgroundSync() {
    final now = DateTime.now();
    final hour = now.hour;

    // Execute between midnight and 2 AM, or if more than 25 hours since last sync
    return (hour >= 0 && hour <= 2) || _isDataStale();
  }

  /// Check if data is stale (more than 25 hours old)
  bool _isDataStale() {
    // This would check the last sync time from database
    // For now, return false as a safe default
    return false;
  }

  /// Check and execute missed sync
  Future<void> _checkAndExecuteMissedSync() async {
    try {
      final hasRecentSync = await _hasRecentSuccessfulSync();
      if (!hasRecentSync) {
        final now = DateTime.now();
        // If it's past 1 AM and no sync today, execute missed sync
        if (now.hour >= 1) {
          debugPrint('LiturgicalScheduler: Executing missed daily sync');
          await _executeDailySync();
        }
      }
    } catch (e) {
      debugPrint('LiturgicalScheduler: Missed sync check failed: $e');
    }
  }

  /// Check if there was a recent successful sync
  Future<bool> _hasRecentSuccessfulSync() async {
    try {
      final client = await SupabaseService.getClient();
      if (client == null) return false;

      final twentyFourHoursAgo =
          DateTime.now().subtract(const Duration(hours: 24));

      final response = await client
          .from('liturgical_sync_jobs')
          .select()
          .eq('status', 'success')
          .gte('completed_at', twentyFourHoursAgo.toIso8601String())
          .limit(1);

      return response.isNotEmpty;
    } catch (e) {
      debugPrint('LiturgicalScheduler: Error checking recent sync: $e');
      return false;
    }
  }

  /// Update sync job status in database
  Future<void> _updateSyncJobStatus(
      DateTime date, String status, Map<String, dynamic> metadata) async {
    try {
      final client = await SupabaseService.getClient();
      if (client == null) return;

      final jobName =
          'automated_daily_sync_${date.year}_${date.month}_${date.day}';

      await client.from('liturgical_sync_jobs').upsert({
        'job_name': jobName,
        'target_date':
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        'status': status,
        'completed_at': DateTime.now().toIso8601String(),
        'error_message': metadata['error'],
        'records_processed':
            (metadata['today_results']?['readings_created'] ?? 0) +
                (metadata['tomorrow_results']?['readings_created'] ?? 0),
      }, onConflict: 'job_name,target_date');
    } catch (e) {
      debugPrint('LiturgicalScheduler: Error updating sync job status: $e');
    }
  }

  /// Broadcast status updates
  void _broadcastStatus(String status, String message) {
    final statusData = {
      'status': status,
      'message': message,
      'timestamp': DateTime.now().toIso8601String(),
    };

    _statusController?.add(statusData);
    debugPrint('LiturgicalScheduler: Status - $status: $message');
  }

  /// Manual trigger for testing or immediate sync
  Future<Map<String, dynamic>> triggerManualSync({DateTime? targetDate}) async {
    final date = targetDate ?? DateTime.now();

    try {
      debugPrint('LiturgicalScheduler: Manual sync triggered for $date');
      _broadcastStatus('manual_running', 'Manual sync started');

      final results = await _scraperService.executeDataPipeline(date);

      await _updateSyncJobStatus(date, 'success', {'manual_results': results});
      _broadcastStatus('manual_completed', 'Manual sync completed');

      return results;
    } catch (e) {
      await _updateSyncJobStatus(date, 'failed', {'error': e.toString()});
      _broadcastStatus('manual_error', 'Manual sync failed: $e');
      rethrow;
    }
  }

  /// Get scheduler status
  Map<String, dynamic> getStatus() {
    return {
      'initialized': _isInitialized,
      'active': _isSchedulerActive,
      'platform': kIsWeb ? 'web' : 'mobile',
      'has_fallback_timer': _fallbackTimer != null,
      'background_fetch_available': !kIsWeb,
    };
  }

  /// Get status stream for real-time updates
  Stream<Map<String, dynamic>>? get statusStream => _statusController?.stream;

  /// Stop the scheduler
  Future<void> stop() async {
    if (!_isInitialized) return;

    try {
      await _cron.close();
      _fallbackTimer?.cancel();

      if (!kIsWeb) {
        await BackgroundFetch.stop();
      }

      await _statusController?.close();

      _isSchedulerActive = false;
      debugPrint('LiturgicalScheduler: Service stopped');
    } catch (e) {
      debugPrint('LiturgicalScheduler: Error stopping service: $e');
    }
  }

  /// Cleanup resources
  void dispose() {
    stop();
  }

  /// Get recent sync jobs for monitoring
  Future<List<Map<String, dynamic>>> getRecentSyncJobs({int limit = 10}) async {
    try {
      final client = await SupabaseService.getClient();
      if (client == null) return [];

      final response = await client
          .from('liturgical_sync_jobs')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('LiturgicalScheduler: Error getting recent sync jobs: $e');
      return [];
    }
  }

  /// Get scheduler performance metrics
  Future<Map<String, dynamic>> getPerformanceMetrics() async {
    try {
      final client = await SupabaseService.getClient();
      if (client == null) return {'error': 'Database unavailable'};

      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));

      final jobs = await client
          .from('liturgical_sync_jobs')
          .select()
          .gte('created_at', sevenDaysAgo.toIso8601String());

      final successCount = jobs.where((j) => j['status'] == 'success').length;
      final failureCount = jobs.where((j) => j['status'] == 'failed').length;
      final totalCount = jobs.length;

      final averageDuration = jobs
              .where((j) => j['duration_seconds'] != null)
              .map((j) => j['duration_seconds'] as int)
              .fold(0, (sum, duration) => sum + duration) /
          (jobs
              .where((j) => j['duration_seconds'] != null)
              .length
              .clamp(1, double.infinity));

      return {
        'total_jobs_7_days': totalCount,
        'success_rate': totalCount > 0 ? (successCount / totalCount) : 0,
        'failure_count': failureCount,
        'average_duration_seconds': averageDuration.isNaN ? 0 : averageDuration,
        'last_successful_sync': jobs
            .where((j) => j['status'] == 'success' && j['completed_at'] != null)
            .map((j) => j['completed_at'])
            .fold<String?>(
                null,
                (latest, current) =>
                    latest == null || current.compareTo(latest) > 0
                        ? current
                        : latest),
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }
}
