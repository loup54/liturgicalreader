import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../core/app_export.dart';
import '../routes/app_routes.dart';
import '../services/supabase_service.dart';

class CustomErrorWidget extends StatelessWidget {
  final FlutterErrorDetails errorDetails;

  const CustomErrorWidget({
    Key? key,
    required this.errorDetails,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // In debug mode, show detailed error for developers
    if (kDebugMode) {
      return _buildDebugErrorWidget(context);
    }

    // In release mode, show user-friendly error
    return _buildUserFriendlyErrorWidget(context);
  }

  Widget _buildDebugErrorWidget(BuildContext context) {
    return MaterialApp(
        home: Scaffold(
            backgroundColor: Colors.red[50],
            appBar: AppBar(
                title: const Text('Debug Error'),
                backgroundColor: Colors.red,
                foregroundColor: Colors.white),
            body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Service status
                      Card(
                          color: Colors.blue[50],
                          child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Service Status',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16)),
                                    const SizedBox(height: 8),
                                    Text(
                                        'Supabase Available: ${SupabaseService.isAvailable}'),
                                    Text(
                                        'Supabase Initialized: ${SupabaseService.isInitialized}'),
                                    if (SupabaseService.initializationError !=
                                        null)
                                      Text(
                                          'Error: ${SupabaseService.initializationError}'),
                                  ]))),
                      const SizedBox(height: 16),

                      // Error details
                      const Text('Error Details:',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: Colors.red[100],
                              borderRadius: BorderRadius.circular(8)),
                          child: Text(errorDetails.exception.toString(),
                              style: const TextStyle(fontFamily: 'monospace'))),
                      const SizedBox(height: 16),

                      const Text('Stack Trace:',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8)),
                          child: Text(
                              errorDetails.stack?.toString() ??
                                  'No stack trace available',
                              style: const TextStyle(
                                  fontFamily: 'monospace', fontSize: 12))),
                    ]))));
  }

  Widget _buildUserFriendlyErrorWidget(BuildContext context) {
    return MaterialApp(
        home: Scaffold(
            backgroundColor: Colors.grey[100],
            body: SafeArea(
                child: Center(
                    child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Error icon
                              Icon(Icons.error_outline,
                                  size: 80, color: Colors.red[400]),
                              const SizedBox(height: 24),

                              // Title
                              Text('Something went wrong',
                                  style: TextStyle(
                                      fontSize: 24.sp,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[800]),
                                  textAlign: TextAlign.center),
                              const SizedBox(height: 16),

                              // Description
                              Text(
                                  'We encountered an unexpected error. The app will continue to work in offline mode with sample content.',
                                  style: TextStyle(
                                      fontSize: 16.sp,
                                      color: Colors.grey[600],
                                      height: 1.5),
                                  textAlign: TextAlign.center),
                              const SizedBox(height: 32),

                              // Service status
                              if (!SupabaseService.isAvailable)
                                Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                        color: Colors.orange[50],
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: Colors.orange[200]!)),
                                    child: Row(children: [
                                      Icon(Icons.wifi_off,
                                          color: Colors.orange[600]),
                                      const SizedBox(width: 12),
                                      Expanded(
                                          child: Text(
                                              'Running in offline mode with sample content',
                                              style: TextStyle(
                                                  fontSize: 14.sp,
                                                  color: Colors.orange[800]))),
                                    ])),
                              const SizedBox(height: 32),

                              // Continue button
                              SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: ElevatedButton(
                                      onPressed: () {
                                        // Try to navigate to main app
                                        try {
                                          Navigator.of(context)
                                              .pushReplacementNamed(
                                                  AppRoutes.initial);
                                        } catch (e) {
                                          // If navigation fails, create a new MaterialApp
                                          Navigator.of(context).pushAndRemoveUntil(
                                              MaterialPageRoute(
                                                  builder: (context) => MaterialApp(
                                                      home: Scaffold(
                                                          appBar: AppBar(
                                                              title: const Text(
                                                                  'Liturgical Reader')),
                                                          body: const Center(
                                                              child: Text(
                                                                  'App is running in safe mode'))))),
                                              (route) => false);
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8))),
                                      child: Text('Continue to App',
                                          style: TextStyle(
                                              fontSize: 16.sp,
                                              fontWeight: FontWeight.w600)))),

                              const SizedBox(height: 16),

                              // Restart button
                              TextButton(
                                  onPressed: () {
                                    // Try to restart the app initialization
                                    _restartApp(context);
                                  },
                                  child: Text('Try Again',
                                      style: TextStyle(fontSize: 14.sp))),
                            ]))))));
  }

  void _restartApp(BuildContext context) {
    // Attempt to reinitialize services and restart
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
            child: Card(
                child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Restarting app...'),
                    ])))));

    Future.delayed(const Duration(seconds: 2), () async {
      try {
        await SupabaseService.initialize();
        if (context.mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
              AppRoutes.splashScreen, (route) => false);
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.of(context).pop(); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Restart failed. Continuing in offline mode.')));
        }
      }
    });
  }
}
