import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../services/user_report_service.dart';
import '../../../models/validation_report.dart';

class UserReportsListWidget extends StatefulWidget {
  final UserReportService reportService;

  const UserReportsListWidget({
    Key? key,
    required this.reportService,
  }) : super(key: key);

  @override
  State<UserReportsListWidget> createState() => _UserReportsListWidgetState();
}

class _UserReportsListWidgetState extends State<UserReportsListWidget> {
  List<ValidationReport> _reports = [];
  bool _isLoading = true;
  String? _error;
  ReportCategory? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    try {
      setState(() => _isLoading = true);

      final reports = await widget.reportService.getPendingReports(
        category: _selectedCategory,
        limit: 100,
      );

      setState(() {
        _reports = reports;
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with filters
        Container(
          padding: EdgeInsets.all(4.w),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'User Reports',
                    style: GoogleFonts.inter(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.orange[700],
                    ),
                  ),
                  IconButton(
                    onPressed: _loadReports,
                    icon: Icon(Icons.refresh, color: Colors.orange[700]),
                  ),
                ],
              ),
              SizedBox(height: 2.h),

              // Category filters
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('All Categories', null),
                    SizedBox(width: 2.w),
                    ...ReportCategory.values.map(
                      (category) => Padding(
                        padding: EdgeInsets.only(right: 2.w),
                        child: _buildFilterChip(
                          category
                              .toString()
                              .split('.')
                              .last
                              .replaceAll('_', ' ')
                              .toUpperCase(),
                          category,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: _buildContent(),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, ReportCategory? category) {
    final isSelected = _selectedCategory == category;

    return FilterChip(
      label: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12.sp,
          color: isSelected ? Colors.white : Colors.orange[700],
          fontWeight: FontWeight.w500,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedCategory = selected ? category : null;
        });
        _loadReports();
      },
      backgroundColor: Colors.white,
      selectedColor: Colors.orange[700],
      checkmarkColor: Colors.white,
      side: BorderSide(color: Colors.orange[300]!),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.orange.shade300),
            SizedBox(height: 2.h),
            Text(
              'Loading user reports...',
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
            Icon(Icons.error_outline, size: 60.sp, color: Colors.orange[300]),
            SizedBox(height: 2.h),
            Text(
              'Failed to load reports',
              style: GoogleFonts.inter(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: Colors.orange[700],
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
              onPressed: _loadReports,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[700],
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

    if (_reports.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 80.sp, color: Colors.green[300]),
            SizedBox(height: 3.h),
            Text(
              'No Pending Reports',
              style: GoogleFonts.inter(
                fontSize: 24.sp,
                fontWeight: FontWeight.w700,
                color: Colors.green[700],
              ),
            ),
            SizedBox(height: 1.h),
            Text(
              'All user reports have been reviewed. Great job!',
              style: GoogleFonts.inter(
                fontSize: 16.sp,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadReports,
      color: Colors.orange.shade300,
      child: ListView.builder(
        padding: EdgeInsets.all(4.w),
        itemCount: _reports.length,
        itemBuilder: (context, index) {
          final report = _reports[index];
          return _buildReportItem(report);
        },
      ),
    );
  }

  Widget _buildReportItem(ValidationReport report) {
    final categoryColor = _getCategoryColor(report.category);
    final timeAgo = _getTimeAgo(report.createdAt);

    return Container(
      margin: EdgeInsets.only(bottom: 3.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: categoryColor.withAlpha(26),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: categoryColor.withAlpha(77)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: categoryColor.withAlpha(26),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
                  decoration: BoxDecoration(
                    color: categoryColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    report.categoryDisplayName.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Text(
                    report.statusDisplayName.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: EdgeInsets.all(4.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User report description
                Container(
                  padding: EdgeInsets.all(3.w),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person,
                              color: Colors.blue[700], size: 16.sp),
                          SizedBox(width: 2.w),
                          Text(
                            'User Report',
                            style: GoogleFonts.inter(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 1.h),
                      Text(
                        report.description,
                        style: GoogleFonts.inter(
                          fontSize: 11.sp,
                          color: Colors.blue[600],
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),

                // Suggested correction if provided
                if (report.suggestedCorrection != null &&
                    report.suggestedCorrection!.isNotEmpty) ...[
                  SizedBox(height: 2.h),
                  Container(
                    padding: EdgeInsets.all(3.w),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.lightbulb,
                                color: Colors.green[700], size: 16.sp),
                            SizedBox(width: 2.w),
                            Text(
                              'Suggested Correction',
                              style: GoogleFonts.inter(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.green[700],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 1.h),
                        Text(
                          report.suggestedCorrection!,
                          style: GoogleFonts.inter(
                            fontSize: 11.sp,
                            color: Colors.green[600],
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                SizedBox(height: 2.h),

                // Reading info
                Row(
                  children: [
                    Icon(Icons.book, color: Colors.purple[600], size: 18.sp),
                    SizedBox(width: 2.w),
                    Expanded(
                      child: Text(
                        'Reading ID: ${report.readingId}',
                        style: GoogleFonts.inter(
                          fontSize: 12.sp,
                          color: Colors.purple[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 2.h),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _viewReadingContent(report),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.purple[700]!),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(
                          'View Reading',
                          style: GoogleFonts.inter(
                            color: Colors.purple[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 2.w),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _approveReport(report),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(
                          'Approve',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 2.w),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _rejectReport(report),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[700],
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(
                          'Reject',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 1.h),

                // Timestamp and reporter info
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Reported $timeAgo',
                      style: GoogleFonts.inter(
                        fontSize: 10.sp,
                        color: Colors.grey[500],
                      ),
                    ),
                    if (report.reporterId != null)
                      Text(
                        'ID: ${report.reporterId!.substring(0, 8)}...',
                        style: GoogleFonts.inter(
                          fontSize: 10.sp,
                          color: Colors.grey[500],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(ReportCategory category) {
    switch (category) {
      case ReportCategory.contentError:
        return Colors.red[600]!;
      case ReportCategory.citationError:
        return Colors.orange[600]!;
      case ReportCategory.translationIssue:
        return Colors.purple[600]!;
      case ReportCategory.formattingIssue:
        return Colors.blue[600]!;
      case ReportCategory.missingContent:
        return Colors.pink[600]!;
      case ReportCategory.other:
        return Colors.grey[600]!;
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    }
  }

  void _viewReadingContent(ValidationReport report) {
    // This would typically fetch and display the actual reading content
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Reading Content',
            style: GoogleFonts.inter(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: Colors.purple[700],
            ),
          ),
          content: Text(
            'This would display the actual reading content that was reported. In a production app, this would fetch the reading data and display it in a formatted manner.',
            style: GoogleFonts.inter(fontSize: 14.sp),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Close',
                style: GoogleFonts.inter(color: Colors.grey[600]),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _approveReport(ValidationReport report) async {
    final result = await _showReviewDialog(
      'Approve Report',
      'Approve this user report and mark the content for correction?',
      Colors.green[700]!,
      'Approve',
    );

    if (result != null && result['confirmed']) {
      try {
        await widget.reportService.updateReportStatus(
          reportId: report.id,
          status: ValidationStatus.approved,
          adminNotes: result['notes'],
          resolutionAction: 'Report approved - content flagged for correction',
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report approved successfully'),
            backgroundColor: Colors.green,
          ),
        );

        _loadReports();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to approve report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectReport(ValidationReport report) async {
    final result = await _showReviewDialog(
      'Reject Report',
      'Reject this user report? This will mark it as invalid.',
      Colors.red[700]!,
      'Reject',
    );

    if (result != null && result['confirmed']) {
      try {
        await widget.reportService.updateReportStatus(
          reportId: report.id,
          status: ValidationStatus.rejected,
          adminNotes: result['notes'],
          resolutionAction: 'Report rejected - no action required',
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report rejected'),
            backgroundColor: Colors.orange,
          ),
        );

        _loadReports();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reject report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<Map<String, dynamic>?> _showReviewDialog(
      String title, String message, Color color, String actionText) async {
    final notesController = TextEditingController();

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: GoogleFonts.inter(fontSize: 14.sp),
              ),
              SizedBox(height: 2.h),
              Text(
                'Admin Notes (Optional):',
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 1.h),
              TextField(
                controller: notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Add any notes about this decision...',
                  hintStyle: GoogleFonts.inter(
                      fontSize: 12.sp, color: Colors.grey[500]),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  contentPadding: EdgeInsets.all(3.w),
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
                Navigator.of(context).pop({
                  'confirmed': true,
                  'notes': notesController.text.trim(),
                });
              },
              style: ElevatedButton.styleFrom(backgroundColor: color),
              child: Text(
                actionText,
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
}
