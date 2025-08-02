import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import 'feature_flags_service.dart';

/// Initializes Firebase and enables performance monitoring if the feature flag
/// `performance_monitoring` is set to true (either compile-time or remote).
class PerformanceService {
  static final PerformanceService _instance = PerformanceService._internal();
  factory PerformanceService() => _instance;
  PerformanceService._internal();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    final flags = FeatureFlagsService();
    if (!flags.isEnabled('performance_monitoring', defaultValue: false)) {
      debugPrint('PerformanceService: disabled via feature flag');
      _isInitialized = true;
      return;
    }

    try {
      await Firebase.initializeApp(options: defaultFirebaseOptions);
      await FirebasePerformance.instance.setPerformanceCollectionEnabled(true);
      debugPrint('PerformanceService: Firebase Performance enabled');
    } catch (e) {
      debugPrint('PerformanceService: failed to init – $e');
    } finally {
      _isInitialized = true;
    }
  }

  /// Wrapper to run a custom trace.
  Future<T> trace<T>(String name, Future<T> Function() action) async {
    if (!_isInitialized) return action();

    final Trace trace = FirebasePerformance.instance.newTrace(name);
    await trace.start();
    try {
      final result = await action();
      return result;
    } finally {
      await trace.stop();
    }
  }
}