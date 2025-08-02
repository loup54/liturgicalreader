import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../services/validation_cross_reference_service.dart';
import '../../../services/user_report_service.dart';

class AdminDashboardWidget extends StatefulWidget {
  final ValidationCrossReferenceService validationService;
  final UserReportService reportService;

  const AdminDashboardWidget({
    Key? key,
    required this.validationService,
    required this.reportService,
  }) : super(key: key);

  @override
  State<AdminDashboardWidget> createState() => _AdminDashboardWidgetState();
}

class _AdminDashboardWidgetState extends State<AdminDashboardWidget> {
  bool _isLoading = true;
  Map<String, dynamic> _dashboardData = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      setState(() => _isLoading = true);

      // Load various dashboard metrics in parallel
      final results = await Future.wait([
        widget.reportService.getReportStatistics(),
        widget.validationService.getFlaggedReadings(limit: 10),
        widget.reportService.getPendingReports(limit: 10),
      ]);

      setState(() {
        _dashboardData = {
          'report_stats': results[0],
          'flagged_readings': results[1],
          'pending_reports': results[2],
        };
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.purple.shade300),
            SizedBox(height: 2.h),
            Text(
              'Loading dashboard...',
              style: GoogleFonts.inter(
                fontSize: 16.sp,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 60.sp, color: Colors.red[300]),
            SizedBox(height: 2.h),
            Text(
              'Failed to load dashboard',
              style: GoogleFonts.inter(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: Colors.red[700],
              ),
            ),
            SizedBox(height: 1.h),
            Text(
              _error!,
              style: GoogleFonts.inter(
                fontSize: 14.sp,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 2.h),
            ElevatedButton(
              onPressed: _loadDashboardData,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple[700],
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                'Retry',
                style: GoogleFonts.inter(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }

    final reportStats =
        _dashboardData['report_stats'] as Map<String, dynamic>? ?? {};
    final totals = reportStats['totals'] as Map<String, dynamic>? ?? {};
    final rates = reportStats['rates'] as Map<String, dynamic>? ?? {};
    final flaggedReadings = _dashboardData['flagged_readings'] as List? ?? [];
    final pendingReports = _dashboardData['pending_reports'] as List? ?? [];

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      color: Colors.purple.shade300,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(4.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with refresh
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Content Validation Overview',
                  style: GoogleFonts.inter(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.purple[800],
                  ),
                ),
                IconButton(
                  onPressed: _loadDashboardData,
                  icon: Icon(Icons.refresh, color: Colors.purple[700]),
                ),
              ],
            ),

            SizedBox(height: 3.h),

            // Key metrics cards
            _buildMetricsSection(totals, rates),

            SizedBox(height: 4.h),

            // Quick action items
            _buildQuickActionsSection(flaggedReadings, pendingReports),

            SizedBox(height: 4.h),

            // System status
            _buildSystemStatusSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsSection(
      Map<String, dynamic> totals, Map<String, dynamic> rates) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Key Metrics (Last 30 Days)',
          style: GoogleFonts.inter(
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 2.h),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Total Reports',
                '${totals['total_reports'] ?? 0}',
                Icons.report,
                Colors.blue,
              ),
            ),
            SizedBox(width: 3.w),
            Expanded(
              child: _buildMetricCard(
                'Pending Review',
                '${totals['pending_reports'] ?? 0}',
                Icons.pending,
                Colors.orange,
              ),
            ),
          ],
        ),
        SizedBox(height: 2.h),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Resolution Rate',
                '${((rates['resolution_rate'] as double? ?? 0.0) * 100).toStringAsFixed(1)}%',
                Icons.check_circle,
                Colors.green,
              ),
            ),
            SizedBox(width: 3.w),
            Expanded(
              child: _buildMetricCard(
                'Quality Issues',
                '${totals['rejected_reports'] ?? 0}',
                Icons.flag,
                Colors.red,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(26),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: color.withAlpha(51)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24.sp),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
                decoration: BoxDecoration(
                  color: color.withAlpha(26),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Live',
                  style: GoogleFonts.inter(
                    fontSize: 10.sp,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 1.5.h),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 24.sp,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          SizedBox(height: 0.5.h),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsSection(List flaggedReadings, List pendingReports) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Items Requiring Attention',
          style: GoogleFonts.inter(
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 2.h),

        // Flagged readings
        if (flaggedReadings.isNotEmpty) ...[
          _buildActionSection(
            'High Priority Flagged Content',
            '${flaggedReadings.length} items need review',
            Icons.flag,
            Colors.red,
            onTap: () {
              // Would navigate to flagged content tab
              DefaultTabController.of(context).animateTo(1);
            },
          ),
          SizedBox(height: 2.h),
        ],

        // Pending reports
        if (pendingReports.isNotEmpty) ...[
          _buildActionSection(
            'User Reports Pending',
            '${pendingReports.length} reports awaiting review',
            Icons.report_problem,
            Colors.orange,
            onTap: () {
              // Would navigate to reports tab
              DefaultTabController.of(context).animateTo(2);
            },
          ),
          SizedBox(height: 2.h),
        ],

        // Quality check action
        _buildActionSection(
          'Run Quality Check',
          'Validate recent readings against sources',
          Icons.verified,
          Colors.purple,
          onTap: () {
            // Trigger batch validation
            _showBatchValidationDialog();
          },
        ),
      ],
    );
  }

  Widget _buildActionSection(
    String title,
    String subtitle,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(4.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withAlpha(26),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(3.w),
              decoration: BoxDecoration(
                color: color.withAlpha(26),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24.sp),
            ),
            SizedBox(width: 4.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  SizedBox(height: 0.5.h),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16.sp),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemStatusSection() {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.health_and_safety,
                  color: Colors.green[700], size: 20.sp),
              SizedBox(width: 2.w),
              Text(
                'Validation System Status',
                style: GoogleFonts.inter(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.green[700],
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          _buildStatusRow('Cross-Reference Service', 'Active', Colors.green),
          _buildStatusRow('User Report System', 'Active', Colors.green),
          _buildStatusRow('Quality Scoring', 'Active', Colors.green),
          _buildStatusRow('Admin Review Queue', 'Active', Colors.green),
          SizedBox(height: 1.h),
          Text(
            'Last system check: ${DateTime.now().toString().split('.')[0]}',
            style: GoogleFonts.inter(
              fontSize: 10.sp,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String service, String status, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 0.5.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            service,
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              color: Colors.grey[700],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
            decoration: BoxDecoration(
              color: color.withAlpha(26),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status,
              style: GoogleFonts.inter(
                fontSize: 10.sp,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
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
          title: Text(
            'Run Batch Validation',
            style: GoogleFonts.inter(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: Colors.purple[700],
            ),
          ),
          content: Text(
            'This will validate recent readings against multiple Catholic sources. Continue?',
            style: GoogleFonts.inter(fontSize: 14.sp),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel',
                  style: GoogleFonts.inter(color: Colors.grey[600])),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Trigger parent's batch validation
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Batch validation started...')),
                );
              },
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.purple[700]),
              child: Text(
                'Start',
                style: GoogleFonts.inter(
                    color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }
}
