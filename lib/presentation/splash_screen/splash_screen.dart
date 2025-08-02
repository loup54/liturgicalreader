import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import '../../routes/app_routes.dart';
import '../../services/liturgical_service.dart';
import '../../services/supabase_service.dart';
import './widgets/liturgical_logo_widget.dart';
import './widgets/liturgical_season_background_widget.dart';
import './widgets/loading_indicator_widget.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _statusMessage = 'Initializing...';
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Step 1: Initialize Supabase
      setState(() {
        _statusMessage = 'Connecting to services...';
      });

      await SupabaseService.initialize();

      // Step 2: Check service status
      setState(() {
        if (SupabaseService.isAvailable) {
          _statusMessage = 'Connected successfully';
        } else {
          _statusMessage = 'Running in offline mode';
        }
      });

      // Step 3: Initialize liturgical service
      final liturgicalService = LiturgicalService();
      setState(() {
        _statusMessage = liturgicalService.statusMessage;
      });

      // Step 4: Brief delay for user experience
      await Future.delayed(const Duration(seconds: 2));

      // Step 5: Navigate to main app
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.todaySReadings);
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _statusMessage =
            'Initialization failed. Check your connection or continue offline.';
      });
    }
  }

  // Retry initialization
  void _retryInitialization() {
    setState(() {
      _hasError = false;
      _statusMessage = 'Retrying...';
    });
    _initializeApp();
  }

  // Continue offline without initialization
  void _continueOffline() {
    if (mounted) {
      Navigator.pushReplacementNamed(context, AppRoutes.todaySReadings);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background
          const LiturgicalSeasonBackgroundWidget(),

          // Main content
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                const Expanded(
                  flex: 3,
                  child: Center(
                    child: LiturgicalLogoWidget(),
                  ),
                ),

                // Loading and status
                Expanded(
                  flex: 2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const LoadingIndicatorWidget(),
                      const SizedBox(height: 24),

                      // Retry / Offline actions
                      if (_hasError) ...[
                        SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton(
                              onPressed: _retryInitialization,
                              child: const Text('Retry'),
                            ),
                            SizedBox(width: 16),
                            OutlinedButton(
                              onPressed: _continueOffline,
                              child: const Text('Continue Offline'),
                            ),
                          ],
                        ),
                      ],

                      // Status message
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          _statusMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16.sp,
                            color: _hasError ? Colors.orange : Colors.white70,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // App info
                Padding(
                  padding: const EdgeInsets.only(bottom: 32),
                  child: Column(
                    children: [
                      Text(
                        'Liturgical Reader',
                        style: TextStyle(
                          fontSize: 24.sp,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Daily Scripture & Prayer',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: Colors.white60,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
