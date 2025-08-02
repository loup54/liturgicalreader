import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../services/validation_cross_reference_service.dart';
import '../../../models/validation_report.dart';

class FlaggedContentListWidget extends StatefulWidget {
  final ValidationCrossReferenceService validationService;

  const FlaggedContentListWidget({
    Key? key,
    required this.validationService,
  }) : super(key: key);

  @override
  State<FlaggedContentListWidget> createState() =>
      _FlaggedContentListWidgetState();
}

class _FlaggedContentListWidgetState extends State<FlaggedContentListWidget> {
  List<Map<String, dynamic>> _flaggedReadings = [];
  bool _isLoading = true;
  String? _error;
  ValidationStatus? _selectedFilter;

  @override
  void initState() {
    super.initState();
    _loadFlaggedContent();
  }

  Future<void> _loadFlaggedContent() async {
    try {
      setState(() => _isLoading = true);

      final results = await widget.validationService.getFlaggedReadings(
        limit: 100,
        status: _selectedFilter,
      );

      setState(() {
        _flaggedReadings = results;
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
                    'Flagged Content',
                    style: GoogleFonts.inter(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.red[700],
                    ),
                  ),
                  IconButton(
                    onPressed: _loadFlaggedContent,
                    icon: Icon(Icons.refresh, color: Colors.red[700]),
                  ),
                ],
              ),
              SizedBox(height: 2.h),

              // Status filter
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('All', null),
                    SizedBox(width: 2.w),
                    _buildFilterChip('Pending', ValidationStatus.pending),
                    SizedBox(width: 2.w),
                    _buildFilterChip(
                        'Under Review', ValidationStatus.underReview),
                    SizedBox(width: 2.w),
                    _buildFilterChip('Flagged', ValidationStatus.flagged),
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

  Widget _buildFilterChip(String label, ValidationStatus? status) {
    final isSelected = _selectedFilter == status;

    return FilterChip(
      label: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12.sp,
          color: isSelected ? Colors.white : Colors.red[700],
          fontWeight: FontWeight.w500,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = selected ? status : null;
        });
        _loadFlaggedContent();
      },
      backgroundColor: Colors.white,
      selectedColor: Colors.red[700],
      checkmarkColor: Colors.white,
      side: BorderSide(color: Colors.red[300]!),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.red.shade300),
            SizedBox(height: 2.h),
            Text(
              'Loading flagged content...',
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
              'Failed to load flagged content',
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
              onPressed: _loadFlaggedContent,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
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

    if (_flaggedReadings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 80.sp, color: Colors.green[300]),
            SizedBox(height: 3.h),
            Text(
              'No Flagged Content',
              style: GoogleFonts.inter(
                fontSize: 24.sp,
                fontWeight: FontWeight.w700,
                color: Colors.green[700],
              ),
            ),
            SizedBox(height: 1.h),
            Text(
              'Great! All content has been reviewed or no content matches the current filter.',
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
      onRefresh: _loadFlaggedContent,
      color: Colors.red.shade300,
      child: ListView.builder(
        padding: EdgeInsets.all(4.w),
        itemCount: _flaggedReadings.length,
        itemBuilder: (context, index) {
          final item = _flaggedReadings[index];
          return _buildFlaggedContentItem(item);
        },
      ),
    );
  }

  Widget _buildFlaggedContentItem(Map<String, dynamic> item) {
    final reading = item['liturgical_readings'];
    final liturgicalDay = reading?['liturgical_days'];
    final priorityLevel = item['priority_level'] as int? ?? 1;
    final reviewReason = item['review_reason'] as String? ?? 'Unknown reason';
    final status = item['status'] as String? ?? 'pending';
    final createdAt = DateTime.tryParse(item['created_at'] as String? ?? '') ??
        DateTime.now();

    Color priorityColor = _getPriorityColor(priorityLevel);
    String priorityText = _getPriorityText(priorityLevel);

    return Container(
      margin: EdgeInsets.only(bottom: 3.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: priorityColor.withAlpha(26),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: priorityColor.withAlpha(77)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: priorityColor.withAlpha(26),
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
                    color: priorityColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$priorityText Priority',
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
                    status.toUpperCase(),
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
                // Reading info
                Row(
                  children: [
                    Icon(Icons.book, color: Colors.purple[600], size: 18.sp),
                    SizedBox(width: 2.w),
                    Expanded(
                      child: Text(
                        reading?['citation'] ?? 'Unknown Citation',
                        style: GoogleFonts.inter(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.purple[700],
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 1.h),

                Row(
                  children: [
                    Icon(Icons.calendar_today,
                        color: Colors.grey[600], size: 16.sp),
                    SizedBox(width: 2.w),
                    Text(
                      liturgicalDay?['date'] ?? 'Unknown Date',
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(width: 4.w),
                    Icon(Icons.category, color: Colors.grey[600], size: 16.sp),
                    SizedBox(width: 1.w),
                    Text(
                      reading?['reading_type']
                              ?.toString()
                              .replaceAll('_', ' ')
                              .toUpperCase() ??
                          'UNKNOWN',
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 2.h),

                // Issue description
                Container(
                  padding: EdgeInsets.all(3.w),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning,
                              color: Colors.red[700], size: 16.sp),
                          SizedBox(width: 2.w),
                          Text(
                            'Validation Issues Detected',
                            style: GoogleFonts.inter(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.red[700],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 1.h),
                      Text(
                        reviewReason,
                        style: GoogleFonts.inter(
                          fontSize: 11.sp,
                          color: Colors.red[600],
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 2.h),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _reviewContent(item),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.purple[700]!),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(
                          'Review Content',
                          style: GoogleFonts.inter(
                            color: Colors.purple[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 3.w),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _resolveIssue(item),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(
                          'Resolve',
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

                // Timestamp
                Text(
                  'Flagged ${_getTimeAgo(createdAt)}',
                  style: GoogleFonts.inter(
                    fontSize: 10.sp,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getPriorityColor(int priority) {
    switch (priority) {
      case 4:
        return Colors.red[700]!;
      case 3:
        return Colors.orange[700]!;
      case 2:
        return Colors.yellow[700]!;
      case 1:
      default:
        return Colors.blue[700]!;
    }
  }

  String _getPriorityText(int priority) {
    switch (priority) {
      case 4:
        return 'Urgent';
      case 3:
        return 'High';
      case 2:
        return 'Medium';
      case 1:
      default:
        return 'Low';
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

  void _reviewContent(Map<String, dynamic> item) {
    final reading = item['liturgical_readings'];
    final content = reading?['content'] as String? ?? 'No content available';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Content Review',
            style: GoogleFonts.inter(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: Colors.purple[700],
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Citation: ${reading?['citation'] ?? 'Unknown'}',
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.purple[600],
                  ),
                ),
                SizedBox(height: 2.h),
                Container(
                  constraints: BoxConstraints(maxHeight: 40.h),
                  child: SingleChildScrollView(
                    child: Text(
                      content,
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        color: Colors.grey[700],
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
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

  void _resolveIssue(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Resolve Issue',
            style: GoogleFonts.inter(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: Colors.green[700],
            ),
          ),
          content: Text(
            'Mark this content as reviewed and approved?',
            style: GoogleFonts.inter(fontSize: 14.sp),
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
                _markAsResolved(item);
              },
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.green[700]),
              child: Text(
                'Resolve',
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

  Future<void> _markAsResolved(Map<String, dynamic> item) async {
    try {
      // Here you would call a service to mark the item as resolved
      // For now, we'll just show a success message and refresh
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Issue marked as resolved'),
          backgroundColor: Colors.green,
        ),
      );

      // Refresh the list
      _loadFlaggedContent();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to resolve issue: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
