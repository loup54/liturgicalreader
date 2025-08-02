import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../theme/app_theme.dart';

class CalendarGridWidget extends StatelessWidget {
  final DateTime currentMonth;
  final DateTime selectedDate;
  final Function(DateTime) onDateTap;
  final Function(DateTime) onDateLongPress;
  final List<Map<String, dynamic>> liturgicalData;

  const CalendarGridWidget({
    super.key,
    required this.currentMonth,
    required this.selectedDate,
    required this.onDateTap,
    required this.onDateLongPress,
    required this.liturgicalData,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      child: Column(
        children: [
          _buildWeekdayHeaders(),
          SizedBox(height: 1.h),
          _buildCalendarGrid(context),
        ],
      ),
    );
  }

  Widget _buildWeekdayHeaders() {
    final weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return Row(
      children: weekdays
          .map((day) => Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 1.h),
                  child: Text(
                    day,
                    textAlign: TextAlign.center,
                    style: AppTheme.lightTheme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildCalendarGrid(BuildContext context) {
    final firstDayOfMonth = DateTime(currentMonth.year, currentMonth.month, 1);
    final lastDayOfMonth =
        DateTime(currentMonth.year, currentMonth.month + 1, 0);
    final firstDayWeekday = firstDayOfMonth.weekday % 7;
    final daysInMonth = lastDayOfMonth.day;

    final List<Widget> dayWidgets = [];

    // Add empty cells for days before the first day of the month
    for (int i = 0; i < firstDayWeekday; i++) {
      dayWidgets.add(Container());
    }

    // Add day cells
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(currentMonth.year, currentMonth.month, day);
      dayWidgets.add(_buildDayCell(context, date));
    }

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 7,
      children: dayWidgets,
    );
  }

  Widget _buildDayCell(BuildContext context, DateTime date) {
    final isToday = _isSameDay(date, DateTime.now());
    final isSelected = _isSameDay(date, selectedDate);
    final liturgicalInfo = _getLiturgicalInfo(date);
    final isSunday = date.weekday == 7;
    final isFeastDay = liturgicalInfo['isFeastDay'] as bool;

    return GestureDetector(
      onTap: () => onDateTap(date),
      onLongPress: () => onDateLongPress(date),
      child: Container(
        margin: EdgeInsets.all(0.5.w),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.lightTheme.colorScheme.primary
              : isToday
                  ? AppTheme.lightTheme.colorScheme.primary
                      .withValues(alpha: 0.1)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isToday && !isSelected
              ? Border.all(
                  color: AppTheme.lightTheme.colorScheme.primary,
                  width: 1.5,
                )
              : null,
        ),
        child: Stack(
          children: [
            Center(
              child: Text(
                date.day.toString(),
                style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                  color: isSelected
                      ? AppTheme.lightTheme.colorScheme.onPrimary
                      : isSunday
                          ? AppTheme.lightTheme.colorScheme.primary
                          : AppTheme.lightTheme.colorScheme.onSurface,
                  fontWeight: isSunday ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (isFeastDay)
              Positioned(
                top: 1.w,
                right: 1.w,
                child: Container(
                  width: 2.w,
                  height: 2.w,
                  decoration: BoxDecoration(
                    color: AppTheme.accentGold,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            if (liturgicalInfo['seasonColor'] != null)
              Positioned(
                bottom: 1.w,
                left: 1.w,
                right: 1.w,
                child: Container(
                  height: 0.5.w,
                  decoration: BoxDecoration(
                    color: liturgicalInfo['seasonColor'] as Color,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _getLiturgicalInfo(DateTime date) {
    final liturgicalEntry = liturgicalData.firstWhere(
      (entry) => _isSameDay(DateTime.parse(entry['date'] as String), date),
      orElse: () => <String, dynamic>{},
    );

    if (liturgicalEntry.isNotEmpty) {
      return {
        'isFeastDay': liturgicalEntry['isFeastDay'] ?? false,
        'seasonColor': _getSeasonColor(liturgicalEntry['season'] as String?),
        'celebration': liturgicalEntry['celebration'] as String?,
      };
    }

    return {
      'isFeastDay': false,
      'seasonColor': _getSeasonColor('Ordinary Time'),
      'celebration': null,
    };
  }

  Color _getSeasonColor(String? season) {
    switch (season) {
      case 'Advent':
      case 'Lent':
        return const Color(0xFF6A0DAD); // Purple
      case 'Christmas':
      case 'Easter':
        return Colors.white;
      case 'Ordinary Time':
        return const Color(0xFF228B22); // Green
      default:
        return const Color(0xFF228B22);
    }
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }
}
