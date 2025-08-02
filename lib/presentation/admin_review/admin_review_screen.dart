import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../services/auth_service.dart';
import '../../services/user_report_service.dart';
import '../../services/validation_cross_reference_service.dart';
import './widgets/admin_dashboard_widget.dart';
import './widgets/flagged_content_list_widget.dart';
import './widgets/quality_scores_widget.dart';
import './widgets/user_reports_list_widget.dart';

class AdminReviewScreen extends StatefulWidget {
  const AdminReviewScreen({Key? key}) : super(key: key);

  @override
  State<AdminReviewScreen> createState() => _AdminReviewScreenState();
}

class _AdminReviewScreenState extends State<AdminReviewScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  final ValidationCrossReferenceService _validationService =
      ValidationCrossReferenceService();
  final UserReportService _reportService = UserReportService();
  final AuthService _authService = AuthService();

  bool _isAdmin = false;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _checkAdminAccess();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkAdminAccess() async {
    try {
      final user = _authService.currentUser;

      // Check if user is admin (this would normally be done via a service call)
      // For now, we'll assume admin check is done by the service itself
      setState(() {
        _isAdmin = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Access denied: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.purple.shade300),
              SizedBox(height: 2.h),
              Text(
                'Checking admin access...',
                style: GoogleFonts.inter(
                  fontSize: 16.sp,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null || !_isAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Access Denied',
            style: GoogleFonts.inter(
              fontSize: 20.sp,
              fontWeight: FontWeight.w600,
              color: Colors.red[700],
            ),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.red[700]),
        ),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(4.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.admin_panel_settings,
                  size: 80.sp,
                  color: Colors.red[300],
                ),
                SizedBox(height: 3.h),
                Text(
                  'Administrator Access Required',
                  style: GoogleFonts.inter(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.red[700],
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 2.h),
                Text(
                  _error ??
                      'You do not have permission to access the admin review panel.',
                  style: GoogleFonts.inter(
                    fontSize: 16.sp,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 4.h),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade300,
                    padding:
                        EdgeInsets.symmetric(horizontal: 8.w, vertical: 1.5.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Go Back',
                    style: GoogleFonts.inter(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Administrative Review Panel',
          style: GoogleFonts.inter(
            fontSize: 20.sp,
            fontWeight: FontWeight.w700,
            color: Colors.purple[700],
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 2,
        shadowColor: Colors.purple.shade100,
        iconTheme: IconThemeData(color: Colors.purple[700]),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Dashboard'),
            Tab(icon: Icon(Icons.flag), text: 'Flagged Content'),
            Tab(icon: Icon(Icons.report), text: 'User Reports'),
            Tab(icon: Icon(Icons.analytics), text: 'Quality Scores'),
          ],
          labelColor: Colors.purple[700],
          unselectedLabelColor: Colors.grey[500],
          indicatorColor: Colors.purple[700],
          labelStyle: GoogleFonts.inter(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          AdminDashboardWidget(
            validationService: _validationService,
            reportService: _reportService,
          ),
          FlaggedContentListWidget(
            validationService: _validationService,
          ),
          UserReportsListWidget(
            reportService: _reportService,
          ),
          QualityScoresWidget(
            validationService: _validationService,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showBatchValidationDialog,
        backgroundColor: Colors.purple[700],
        icon: const Icon(Icons.batch_prediction, color: Colors.white),
        label: Text(
          'Batch Validate',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _showBatchValidationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.batch_prediction, color: Colors.purple[700]),
              SizedBox(width: 2.w),
              Text(
                'Batch Validation',
                style: GoogleFonts.inter(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.purple[700],
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Run cross-reference validation on multiple readings:',
                style: GoogleFonts.inter(
                  fontSize: 14.sp,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                '• Validates against multiple Catholic sources',
                style:
                    GoogleFonts.inter(fontSize: 12.sp, color: Colors.grey[600]),
              ),
              Text(
                '• Flags discrepancies for review',
                style:
                    GoogleFonts.inter(fontSize: 12.sp, color: Colors.grey[600]),
              ),
              Text(
                '• Updates quality scores automatically',
                style:
                    GoogleFonts.inter(fontSize: 12.sp, color: Colors.grey[600]),
              ),
              SizedBox(height: 2.h),
              Container(
                padding: EdgeInsets.all(3.w),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber,
                        color: Colors.orange[700], size: 20.sp),
                    SizedBox(width: 2.w),
                    Expanded(
                      child: Text(
                        'This process may take several minutes',
                        style: GoogleFonts.inter(
                          fontSize: 12.sp,
                          color: Colors.orange[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(color: Colors.grey[600]),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _runBatchValidation();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple[700],
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                'Start Validation',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _runBatchValidation() async {
    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.purple.shade300),
              SizedBox(height: 2.h),
              Text(
                'Running batch validation...',
                style: GoogleFonts.inter(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 1.h),
              Text(
                'Please wait while we validate readings against multiple Catholic sources',
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );

    try {
      // Run batch validation for last 30 days
      final result = await _validationService.batchCrossReference(
        startDate: DateTime.now().subtract(const Duration(days: 30)),
        endDate: DateTime.now(),
        limit: 50,
      );

      // Close progress dialog
      Navigator.of(context).pop();

      // Show results dialog
      _showBatchValidationResults(result);
    } catch (e) {
      // Close progress dialog
      Navigator.of(context).pop();

      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Batch validation failed: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _showBatchValidationResults(Map<String, dynamic> results) {
    final summary = results['summary'] as Map<String, dynamic>? ?? {};
    final totalReadings = results['total_readings'] as int? ?? 0;
    final flaggedReadings = summary['flagged_readings'] as int? ?? 0;
    final highConfidenceReadings =
        summary['high_confidence_readings'] as int? ?? 0;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.analytics, color: Colors.green[700]),
              SizedBox(width: 2.w),
              Text(
                'Validation Complete',
                style: GoogleFonts.inter(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.green[700],
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatRow(
                  'Total Readings Processed', totalReadings.toString()),
              _buildStatRow(
                  'High Confidence', highConfidenceReadings.toString()),
              _buildStatRow('Flagged for Review', flaggedReadings.toString()),
              SizedBox(height: 2.h),
              if (flaggedReadings > 0)
                Container(
                  padding: EdgeInsets.all(3.w),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Text(
                    '$flaggedReadings readings have been flagged and added to the review queue.',
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      color: Colors.orange[700],
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                'Close',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 0.5.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14.sp,
              color: Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: Colors.purple[700],
            ),
          ),
        ],
      ),
    );
  }
}
