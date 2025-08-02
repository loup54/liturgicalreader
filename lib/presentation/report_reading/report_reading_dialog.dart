import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/user_report_service.dart';
import '../../models/validation_report.dart';

class ReportReadingDialog extends StatefulWidget {
  final String readingId;
  final String readingTitle;

  const ReportReadingDialog({
    Key? key,
    required this.readingId,
    required this.readingTitle,
  }) : super(key: key);

  @override
  State<ReportReadingDialog> createState() => _ReportReadingDialogState();
}

class _ReportReadingDialogState extends State<ReportReadingDialog> {
  final UserReportService _reportService = UserReportService();
  final _descriptionController = TextEditingController();
  final _correctionController = TextEditingController();

  ReportCategory _selectedCategory = ReportCategory.contentError;
  bool _isSubmitting = false;
  String? _error;

  final Map<ReportCategory, Map<String, dynamic>> _categoryInfo = {
    ReportCategory.contentError: {
      'title': 'Content Error',
      'description': 'Incorrect or inaccurate text content',
      'icon': Icons.text_fields,
      'color': Colors.red[600],
    },
    ReportCategory.citationError: {
      'title': 'Citation Error',
      'description': 'Wrong biblical reference or citation format',
      'icon': Icons.format_quote,
      'color': Colors.orange[600],
    },
    ReportCategory.translationIssue: {
      'title': 'Translation Issue',
      'description': 'Problems with translation quality or accuracy',
      'icon': Icons.translate,
      'color': Colors.purple[600],
    },
    ReportCategory.formattingIssue: {
      'title': 'Formatting Issue',
      'description': 'Text formatting, spacing, or display problems',
      'icon': Icons.format_align_left,
      'color': Colors.blue[600],
    },
    ReportCategory.missingContent: {
      'title': 'Missing Content',
      'description': 'Incomplete readings or missing parts',
      'icon': Icons.warning,
      'color': Colors.pink[600],
    },
    ReportCategory.other: {
      'title': 'Other Issue',
      'description': 'Any other quality or accuracy concern',
      'icon': Icons.help,
      'color': Colors.grey[600],
    },
  };

  @override
  void dispose() {
    _descriptionController.dispose();
    _correctionController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (_descriptionController.text.trim().isEmpty) {
      setState(() {
        _error = 'Please describe the issue you found';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      await _reportService.submitReport(
        readingId: widget.readingId,
        category: _selectedCategory,
        description: _descriptionController.text.trim(),
        suggestedCorrection: _correctionController.text.trim().isNotEmpty
            ? _correctionController.text.trim()
            : null,
      );

      if (mounted) {
        Navigator.of(context).pop(true); // Return success
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 2.w),
                Expanded(
                  child: Text(
                    'Thank you for reporting this issue. Our team will review it shortly.',
                    style: GoogleFonts.inter(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green[600],
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: BoxConstraints(maxHeight: 90.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(6.w),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                border: Border(bottom: BorderSide(color: Colors.red[200]!)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(3.w),
                        decoration: BoxDecoration(
                          color: Colors.red[600],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.flag,
                          color: Colors.white,
                          size: 20.sp,
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Report Content Issue',
                              style: GoogleFonts.inter(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.w700,
                                color: Colors.red[700],
                              ),
                            ),
                            SizedBox(height: 0.5.h),
                            Text(
                              'Help improve content quality',
                              style: GoogleFonts.inter(
                                fontSize: 12.sp,
                                color: Colors.red[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.close, color: Colors.red[700]),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 2.h),
                  Container(
                    padding: EdgeInsets.all(3.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.book,
                            color: Colors.purple[600], size: 16.sp),
                        SizedBox(width: 2.w),
                        Expanded(
                          child: Text(
                            widget.readingTitle,
                            style: GoogleFonts.inter(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.purple[700],
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
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(6.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category selection
                    Text(
                      'What type of issue did you find?',
                      style: GoogleFonts.inter(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 2.h),

                    ..._categoryInfo.entries.map((entry) {
                      final category = entry.key;
                      final info = entry.value;
                      final isSelected = _selectedCategory == category;

                      return Column(
                        children: [
                          InkWell(
                            onTap: () {
                              setState(() {
                                _selectedCategory = category;
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: EdgeInsets.all(4.w),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? (info['color'] as Color).withAlpha(26)
                                    : Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? info['color'] as Color
                                      : Colors.grey[300]!,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Radio<ReportCategory>(
                                    value: category,
                                    groupValue: _selectedCategory,
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() {
                                          _selectedCategory = value;
                                        });
                                      }
                                    },
                                    activeColor: info['color'] as Color,
                                  ),
                                  SizedBox(width: 2.w),
                                  Icon(
                                    info['icon'] as IconData,
                                    color: info['color'] as Color,
                                    size: 20.sp,
                                  ),
                                  SizedBox(width: 3.w),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          info['title'] as String,
                                          style: GoogleFonts.inter(
                                            fontSize: 14.sp,
                                            fontWeight: FontWeight.w600,
                                            color: isSelected
                                                ? info['color'] as Color
                                                : Colors.grey[800],
                                          ),
                                        ),
                                        SizedBox(height: 0.5.h),
                                        Text(
                                          info['description'] as String,
                                          style: GoogleFonts.inter(
                                            fontSize: 11.sp,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: 2.h),
                        ],
                      );
                    }),

                    SizedBox(height: 2.h),

                    // Description field
                    Text(
                      'Please describe the issue in detail',
                      style: GoogleFonts.inter(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 1.h),
                    TextField(
                      controller: _descriptionController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText:
                            'Describe what you found wrong and where exactly the issue is located...',
                        hintStyle: GoogleFonts.inter(
                          fontSize: 12.sp,
                          color: Colors.grey[500],
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.red[600]!),
                        ),
                        contentPadding: EdgeInsets.all(4.w),
                      ),
                      style: GoogleFonts.inter(fontSize: 14.sp),
                    ),

                    SizedBox(height: 3.h),

                    // Suggested correction field
                    Text(
                      'Suggested correction (optional)',
                      style: GoogleFonts.inter(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 1.h),
                    TextField(
                      controller: _correctionController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText:
                            'If you know the correct version, please provide it here...',
                        hintStyle: GoogleFonts.inter(
                          fontSize: 12.sp,
                          color: Colors.grey[500],
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.green[600]!),
                        ),
                        contentPadding: EdgeInsets.all(4.w),
                        prefixIcon: Padding(
                          padding: EdgeInsets.all(3.w),
                          child: Icon(
                            Icons.lightbulb,
                            color: Colors.green[600],
                            size: 20.sp,
                          ),
                        ),
                      ),
                      style: GoogleFonts.inter(fontSize: 14.sp),
                    ),

                    // Error message
                    if (_error != null) ...[
                      SizedBox(height: 2.h),
                      Container(
                        padding: EdgeInsets.all(3.w),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error,
                                color: Colors.red[700], size: 16.sp),
                            SizedBox(width: 2.w),
                            Expanded(
                              child: Text(
                                _error!,
                                style: GoogleFonts.inter(
                                  fontSize: 12.sp,
                                  color: Colors.red[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Footer with actions
            Container(
              padding: EdgeInsets.all(6.w),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Column(
                children: [
                  // Privacy notice
                  Container(
                    padding: EdgeInsets.all(3.w),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue[700], size: 16.sp),
                        SizedBox(width: 2.w),
                        Expanded(
                          child: Text(
                            'Your report helps improve content quality for everyone. Reports are reviewed by our moderation team.',
                            style: GoogleFonts.inter(
                              fontSize: 11.sp,
                              color: Colors.blue[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 3.h),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSubmitting
                              ? null
                              : () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.grey[400]!),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 2.h),
                          ),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.inter(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitReport,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[600],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 2.h),
                            elevation: 2,
                          ),
                          child: _isSubmitting
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 16.sp,
                                      height: 16.sp,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    SizedBox(width: 2.w),
                                    Text(
                                      'Submitting...',
                                      style: GoogleFonts.inter(
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                )
                              : Text(
                                  'Submit Report',
                                  style: GoogleFonts.inter(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
