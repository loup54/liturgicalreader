import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

enum ConnectivityStatus {
  online,
  offline,
  unknown,
}

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  final InternetConnectionChecker _internetChecker =
      InternetConnectionChecker();

  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  StreamSubscription<InternetConnectionStatus>? _internetSubscription;

  ConnectivityStatus _currentStatus = ConnectivityStatus.unknown;
  final StreamController<ConnectivityStatus> _statusController =
      StreamController<ConnectivityStatus>.broadcast();

  bool _isInitialized = false;
  DateTime? _lastOnlineTime;
  Duration _offlineDuration = Duration.zero;

  // Initialize connectivity monitoring
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Check initial connectivity
      await _checkInitialConnectivity();

      // Monitor connectivity changes
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        _onConnectivityChanged,
        onError: (error) {
          debugPrint(
              'ConnectivityService: Error monitoring connectivity: $error');
        },
      );

      // Monitor internet availability
      _internetSubscription = _internetChecker.onStatusChange.listen(
        _onInternetStatusChanged,
        onError: (error) {
          debugPrint('ConnectivityService: Error monitoring internet: $error');
        },
      );

      _isInitialized = true;
      debugPrint('ConnectivityService: Initialized successfully');
    } catch (e) {
      debugPrint('ConnectivityService: Failed to initialize: $e');
    }
  }

  // Check initial connectivity status
  Future<void> _checkInitialConnectivity() async {
    try {
      final connectivityResults = await _connectivity.checkConnectivity();
      final hasInternet = await _internetChecker.hasConnection;

      if (connectivityResults == ConnectivityResult.none) {
        _updateStatus(ConnectivityStatus.offline);
      } else if (hasInternet) {
        _updateStatus(ConnectivityStatus.online);
      } else {
        _updateStatus(ConnectivityStatus.offline);
      }
    } catch (e) {
      debugPrint(
          'ConnectivityService: Failed to check initial connectivity: $e');
      _updateStatus(ConnectivityStatus.unknown);
    }
  }

  // Handle connectivity changes
  void _onConnectivityChanged(ConnectivityResult result) {
    debugPrint('ConnectivityService: Connectivity changed: $result');

    if (result == ConnectivityResult.none) {
      _updateStatus(ConnectivityStatus.offline);
    } else {
      // Have network connection, but need to verify internet access
      _verifyInternetAccess();
    }
  }

  // Handle internet status changes
  void _onInternetStatusChanged(InternetConnectionStatus status) {
    debugPrint('ConnectivityService: Internet status changed: $status');

    switch (status) {
      case InternetConnectionStatus.connected:
        _updateStatus(ConnectivityStatus.online);
        break;
      case InternetConnectionStatus.disconnected:
        _updateStatus(ConnectivityStatus.offline);
        break;
    }
  }

  // Verify internet access with timeout
  Future<void> _verifyInternetAccess() async {
    try {
      final hasInternet = await _internetChecker.hasConnection.timeout(
        const Duration(seconds: 10),
        onTimeout: () => false,
      );

      _updateStatus(
          hasInternet ? ConnectivityStatus.online : ConnectivityStatus.offline);
    } catch (e) {
      debugPrint('ConnectivityService: Failed to verify internet access: $e');
      _updateStatus(ConnectivityStatus.offline);
    }
  }

  // Update connectivity status
  void _updateStatus(ConnectivityStatus newStatus) {
    if (_currentStatus == newStatus) return;

    final previousStatus = _currentStatus;
    _currentStatus = newStatus;

    // Track online/offline times
    if (newStatus == ConnectivityStatus.online) {
      if (previousStatus == ConnectivityStatus.offline &&
          _lastOnlineTime != null) {
        _offlineDuration = DateTime.now().difference(_lastOnlineTime!);
        debugPrint(
            'ConnectivityService: Was offline for ${_offlineDuration.inMinutes} minutes');
      }
      _lastOnlineTime = DateTime.now();
    }

    _statusController.add(newStatus);
    debugPrint('ConnectivityService: Status updated to $newStatus');
  }

  // Get current connectivity status
  ConnectivityStatus get currentStatus => _currentStatus;

  // Stream of connectivity status changes
  Stream<ConnectivityStatus> get statusStream => _statusController.stream;

  // Check if currently online
  bool get isOnline => _currentStatus == ConnectivityStatus.online;

  // Check if currently offline
  bool get isOffline => _currentStatus == ConnectivityStatus.offline;

  // Get offline duration
  Duration get offlineDuration => _offlineDuration;

  // Get time since last online
  Duration? get timeSinceLastOnline {
    if (_lastOnlineTime == null) return null;
    return DateTime.now().difference(_lastOnlineTime!);
  }

  // Force connectivity check
  Future<bool> checkConnectivity() async {
    try {
      await _checkInitialConnectivity();
      return isOnline;
    } catch (e) {
      debugPrint('ConnectivityService: Failed to check connectivity: $e');
      return false;
    }
  }

  // Wait for online status with timeout
  Future<bool> waitForOnline(
      {Duration timeout = const Duration(seconds: 30)}) async {
    if (isOnline) return true;

    try {
      await statusStream
          .where((status) => status == ConnectivityStatus.online)
          .first
          .timeout(timeout);
      return true;
    } catch (e) {
      debugPrint('ConnectivityService: Timeout waiting for online status: $e');
      return false;
    }
  }

  // Get connection quality (rough estimate)
  Future<String> getConnectionQuality() async {
    if (!isOnline) return 'offline';

    try {
      final stopwatch = Stopwatch()..start();
      await _internetChecker.hasConnection;
      stopwatch.stop();

      final latency = stopwatch.elapsedMilliseconds;

      if (latency < 100) return 'excellent';
      if (latency < 300) return 'good';
      if (latency < 1000) return 'fair';
      return 'poor';
    } catch (e) {
      debugPrint(
          'ConnectivityService: Failed to measure connection quality: $e');
      return 'unknown';
    }
  }

  // Get detailed connectivity info
  Future<Map<String, dynamic>> getConnectivityInfo() async {
    try {
      final connectivityResults = await _connectivity.checkConnectivity();
      final hasInternet = await _internetChecker.hasConnection;
      final quality = await getConnectionQuality();

      return {
        'status': _currentStatus.name,
        'connectivity_results': connectivityResults.name,
        'has_internet': hasInternet,
        'quality': quality,
        'is_initialized': _isInitialized,
        'last_online_time': _lastOnlineTime?.toIso8601String(),
        'offline_duration_minutes': _offlineDuration.inMinutes,
      };
    } catch (e) {
      debugPrint('ConnectivityService: Failed to get connectivity info: $e');
      return {
        'status': 'error',
        'error': e.toString(),
      };
    }
  }

  // Configure internet checker settings
  void configureInternetChecker({
    Duration checkTimeout = const Duration(seconds: 10),
    Duration checkInterval = const Duration(seconds: 10),
  }) {
    // Configuration removed as these properties are final
  }

  // Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _internetSubscription?.cancel();
    _statusController.close();
    _isInitialized = false;
  }

  // Check if service is initialized
  bool get isInitialized => _isInitialized;

  // Get status message for UI
  String get statusMessage {
    switch (_currentStatus) {
      case ConnectivityStatus.online:
        return 'Connected - Data syncing enabled';
      case ConnectivityStatus.offline:
        return 'Offline - Using cached content';
      case ConnectivityStatus.unknown:
        return 'Checking connection...';
    }
  }

  // Check if we should attempt sync based on connection
  bool get shouldAttemptSync {
    return isOnline && _isInitialized;
  }
}