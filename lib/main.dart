import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import './services/offline_first_liturgical_service.dart';
import 'services/feature_flags_service.dart';
import 'core/app_export.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Sentry for crash/error monitoring
  await SentryFlutter.init(
    (options) {
      options.dsn =
          const String.fromEnvironment('SENTRY_DSN', defaultValue: '');
      options.tracesSampleRate = 1.0; // Adjust in production
    },
  );

  // Initialize Sizer
  SizerUtil.setScreenSize(
    BoxConstraints(maxWidth: 360, maxHeight: 640),
    Orientation.portrait,
  );

  // Initialize feature flags
  final featureFlags = FeatureFlagsService();
  await featureFlags.initialize();

  // Initialize performance monitoring (guarded by flag)
  await PerformanceService().initialize();

  // Initialize offline-first architecture services
  try {
    final offlineFirstService = OfflineFirstLiturgicalService();
    await offlineFirstService.initialize();

    debugPrint('main: Offline-first architecture initialized successfully');
  } catch (e) {
    debugPrint('main: Failed to initialize offline-first services: $e');
    // App can still continue with fallback behavior
  }

  runApp(const LiturgicalReaderApp());
}

class LiturgicalReaderApp extends StatelessWidget {
  const LiturgicalReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Sizer(
      builder: (context, orientation, deviceType) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(1.0),
          ),
          child: MaterialApp(
            title: 'Liturgical Reader',
            theme: AppTheme.lightTheme,
            initialRoute: AppRoutes.splashScreen,
            routes: AppRoutes.routes,
            debugShowCheckedModeBanner: false,
          ),
        );
      },
    );
  }
}
