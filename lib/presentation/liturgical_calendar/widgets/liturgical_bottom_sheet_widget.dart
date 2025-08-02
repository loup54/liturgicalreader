import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class LiturgicalBottomSheetWidget extends StatelessWidget {
  final DateTime selectedDate;
  final Map<String, dynamic> liturgicalInfo;
  final VoidCallback onReadingsPressed;
  final VoidCallback onBookmarkPressed;

  const LiturgicalBottomSheetWidget({
    super.key,
    required this.selectedDate,
    required this.liturgicalInfo,
    required this.onReadingsPressed,
    required this.onBookmarkPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: AppTheme.lightTheme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHandle(),
          SizedBox(height: 2.h),
          _buildHeader(),
          SizedBox(height: 3.h),
          _buildLiturgicalDetails(),
          SizedBox(height: 3.h),
          _buildActionButtons(context),
          SizedBox(height: 2.h),
        ],
      ),
    );
  }

  Widget _buildHandle() {
    return Center(
      child: Container(
        width: 12.w,
        height: 0.5.h,
        decoration: BoxDecoration(
          color: AppTheme.lightTheme.colorScheme.outline.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatDate(selectedDate),
                style: AppTheme.lightTheme.textTheme.headlineSmall?.copyWith(
                  color: AppTheme.lightTheme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 0.5.h),
              Text(
                _getDayOfWeek(selectedDate),
                style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (liturgicalInfo['isFeastDay'] == true)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
            decoration: BoxDecoration(
              color: AppTheme.accentGold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.accentGold.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomIconWidget(
                  iconName: 'star',
                  color: AppTheme.accentGold,
                  size: 4.w,
                ),
                SizedBox(width: 1.w),
                Text(
                  'Feast Day',
                  style: AppTheme.lightTheme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.accentGold,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildLiturgicalDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (liturgicalInfo['celebration'] != null) ...[
          _buildDetailRow(
            'Celebration',
            liturgicalInfo['celebration'] as String,
            Icons.celebration,
          ),
          SizedBox(height: 2.h),
        ],
        _buildDetailRow(
          'Liturgical Season',
          liturgicalInfo['season'] as String? ?? 'Ordinary Time',
          Icons.calendar_today,
        ),
        SizedBox(height: 2.h),
        _buildDetailRow(
          'Liturgical Color',
          _getSeasonColorName(liturgicalInfo['season'] as String?),
          Icons.palette,
        ),
        if (liturgicalInfo['rank'] != null) ...[
          SizedBox(height: 2.h),
          _buildDetailRow(
            'Rank',
            liturgicalInfo['rank'] as String,
            Icons.military_tech,
          ),
        ],
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(2.w),
          decoration: BoxDecoration(
            color:
                AppTheme.lightTheme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: CustomIconWidget(
            iconName: icon.toString().split('.').last,
            color: AppTheme.lightTheme.colorScheme.primary,
            size: 5.w,
          ),
        ),
        SizedBox(width: 3.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTheme.lightTheme.textTheme.labelMedium?.copyWith(
                  color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.lightTheme.colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onReadingsPressed,
            icon: CustomIconWidget(
              iconName: 'menu_book',
              color: AppTheme.lightTheme.colorScheme.onPrimary,
              size: 5.w,
            ),
            label: Text('View Readings'),
            style: AppTheme.lightTheme.elevatedButtonTheme.style,
          ),
        ),
        SizedBox(width: 3.w),
        OutlinedButton.icon(
          onPressed: onBookmarkPressed,
          icon: CustomIconWidget(
            iconName: 'bookmark_border',
            color: AppTheme.lightTheme.colorScheme.primary,
            size: 5.w,
          ),
          label: Text('Bookmark'),
          style: AppTheme.lightTheme.outlinedButtonTheme.style,
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _getDayOfWeek(DateTime date) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return days[date.weekday - 1];
  }

  String _getSeasonColorName(String? season) {
    switch (season) {
      case 'Advent':
      case 'Lent':
        return 'Purple';
      case 'Christmas':
      case 'Easter':
        return 'White';
      case 'Ordinary Time':
        return 'Green';
      default:
        return 'Green';
    }
  }
}
