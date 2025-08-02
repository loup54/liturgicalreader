import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import './widgets/calendar_grid_widget.dart';
import './widgets/liturgical_bottom_sheet_widget.dart';
import './widgets/month_navigation_widget.dart';
import './widgets/upcoming_feasts_widget.dart';

class LiturgicalCalendar extends StatefulWidget {
  const LiturgicalCalendar({super.key});

  @override
  State<LiturgicalCalendar> createState() => _LiturgicalCalendarState();
}

class _LiturgicalCalendarState extends State<LiturgicalCalendar> {
  DateTime _currentMonth = DateTime.now();
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  // Mock liturgical data
  final List<Map<String, dynamic>> _liturgicalData = [
    {
      "date": "2025-01-01",
      "celebration": "Solemnity of Mary, Mother of God",
      "season": "Christmas",
      "rank": "Solemnity",
      "isFeastDay": true,
      "description":
          "Holy Day of Obligation celebrating Mary as the Mother of God"
    },
    {
      "date": "2025-01-06",
      "celebration": "Epiphany of the Lord",
      "season": "Christmas",
      "rank": "Solemnity",
      "isFeastDay": true,
      "description":
          "Celebration of the manifestation of Christ to the Gentiles"
    },
    {
      "date": "2025-01-12",
      "celebration": "Baptism of the Lord",
      "season": "Christmas",
      "rank": "Feast",
      "isFeastDay": true,
      "description": "End of the Christmas season"
    },
    {
      "date": "2025-02-02",
      "celebration": "Presentation of the Lord",
      "season": "Ordinary Time",
      "rank": "Feast",
      "isFeastDay": true,
      "description": "Candlemas - Presentation of Jesus in the Temple"
    },
    {
      "date": "2025-02-14",
      "celebration": "Saints Cyril and Methodius",
      "season": "Ordinary Time",
      "rank": "Memorial",
      "isFeastDay": true,
      "description": "Patrons of Europe and evangelizers of the Slavs"
    },
    {
      "date": "2025-03-05",
      "celebration": "Ash Wednesday",
      "season": "Lent",
      "rank": "Special",
      "isFeastDay": true,
      "description": "Beginning of Lent - Day of fasting and abstinence"
    },
    {
      "date": "2025-03-19",
      "celebration": "Saint Joseph",
      "season": "Lent",
      "rank": "Solemnity",
      "isFeastDay": true,
      "description": "Husband of Mary and foster father of Jesus"
    },
    {
      "date": "2025-03-25",
      "celebration": "Annunciation of the Lord",
      "season": "Lent",
      "rank": "Solemnity",
      "isFeastDay": true,
      "description":
          "Angel Gabriel announces to Mary she will bear the Son of God"
    },
    {
      "date": "2025-04-13",
      "celebration": "Palm Sunday",
      "season": "Lent",
      "rank": "Special",
      "isFeastDay": true,
      "description": "Beginning of Holy Week"
    },
    {
      "date": "2025-04-17",
      "celebration": "Holy Thursday",
      "season": "Lent",
      "rank": "Special",
      "isFeastDay": true,
      "description": "Institution of the Eucharist and Priesthood"
    },
    {
      "date": "2025-04-18",
      "celebration": "Good Friday",
      "season": "Lent",
      "rank": "Special",
      "isFeastDay": true,
      "description": "Commemoration of the Crucifixion of Jesus"
    },
    {
      "date": "2025-04-20",
      "celebration": "Easter Sunday",
      "season": "Easter",
      "rank": "Solemnity",
      "isFeastDay": true,
      "description": "Resurrection of Our Lord Jesus Christ"
    },
    {
      "date": "2025-05-29",
      "celebration": "Ascension of the Lord",
      "season": "Easter",
      "rank": "Solemnity",
      "isFeastDay": true,
      "description": "Jesus ascends into heaven"
    },
    {
      "date": "2025-06-08",
      "celebration": "Pentecost Sunday",
      "season": "Easter",
      "rank": "Solemnity",
      "isFeastDay": true,
      "description": "Descent of the Holy Spirit upon the Apostles"
    },
    {
      "date": "2025-06-15",
      "celebration": "Trinity Sunday",
      "season": "Ordinary Time",
      "rank": "Solemnity",
      "isFeastDay": true,
      "description": "Celebration of the Holy Trinity"
    },
    {
      "date": "2025-06-19",
      "celebration": "Corpus Christi",
      "season": "Ordinary Time",
      "rank": "Solemnity",
      "isFeastDay": true,
      "description": "Body and Blood of Christ"
    },
    {
      "date": "2025-06-27",
      "celebration": "Sacred Heart of Jesus",
      "season": "Ordinary Time",
      "rank": "Solemnity",
      "isFeastDay": true,
      "description": "Devotion to the Sacred Heart of Jesus"
    },
    {
      "date": "2025-08-15",
      "celebration": "Assumption of Mary",
      "season": "Ordinary Time",
      "rank": "Solemnity",
      "isFeastDay": true,
      "description": "Mary is assumed body and soul into heaven"
    },
    {
      "date": "2025-11-01",
      "celebration": "All Saints Day",
      "season": "Ordinary Time",
      "rank": "Solemnity",
      "isFeastDay": true,
      "description": "Celebration of all saints, known and unknown"
    },
    {
      "date": "2025-11-30",
      "celebration": "First Sunday of Advent",
      "season": "Advent",
      "rank": "Special",
      "isFeastDay": true,
      "description": "Beginning of the liturgical year"
    },
    {
      "date": "2025-12-08",
      "celebration": "Immaculate Conception",
      "season": "Advent",
      "rank": "Solemnity",
      "isFeastDay": true,
      "description": "Mary conceived without original sin"
    },
    {
      "date": "2025-12-25",
      "celebration": "Christmas Day",
      "season": "Christmas",
      "rank": "Solemnity",
      "isFeastDay": true,
      "description": "Birth of Our Lord Jesus Christ"
    }
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: _refreshLiturgicalData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              MonthNavigationWidget(
                currentMonth: _currentMonth,
                onPreviousMonth: _goToPreviousMonth,
                onNextMonth: _goToNextMonth,
                onTodayTap: _goToToday,
              ),
              CalendarGridWidget(
                currentMonth: _currentMonth,
                selectedDate: _selectedDate,
                onDateTap: _onDateTap,
                onDateLongPress: _onDateLongPress,
                liturgicalData: _liturgicalData,
              ),
              SizedBox(height: 2.h),
              UpcomingFeastsWidget(
                upcomingFeasts: _getUpcomingFeasts(),
              ),
              SizedBox(height: 10.h), // Space for bottom navigation
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showDatePicker,
        child: CustomIconWidget(
          iconName: 'date_range',
          color: AppTheme.lightTheme.floatingActionButtonTheme.foregroundColor!,
          size: 6.w,
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        'Liturgical Calendar',
        style: AppTheme.lightTheme.appBarTheme.titleTextStyle,
      ),
      backgroundColor: AppTheme.lightTheme.appBarTheme.backgroundColor,
      elevation: AppTheme.lightTheme.appBarTheme.elevation,
      actions: [
        IconButton(
          onPressed: _showSearchDialog,
          icon: CustomIconWidget(
            iconName: 'search',
            color: AppTheme.lightTheme.appBarTheme.foregroundColor!,
            size: 6.w,
          ),
        ),
        IconButton(
          onPressed: () {
            // Navigate to settings or preferences
          },
          icon: CustomIconWidget(
            iconName: 'settings',
            color: AppTheme.lightTheme.appBarTheme.foregroundColor!,
            size: 6.w,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      backgroundColor:
          AppTheme.lightTheme.bottomNavigationBarTheme.backgroundColor,
      selectedItemColor:
          AppTheme.lightTheme.bottomNavigationBarTheme.selectedItemColor,
      unselectedItemColor:
          AppTheme.lightTheme.bottomNavigationBarTheme.unselectedItemColor,
      currentIndex: 2, // Calendar tab
      onTap: _onBottomNavTap,
      items: [
        BottomNavigationBarItem(
          icon: CustomIconWidget(
            iconName: 'home',
            color: AppTheme
                .lightTheme.bottomNavigationBarTheme.unselectedItemColor!,
            size: 6.w,
          ),
          activeIcon: CustomIconWidget(
            iconName: 'home',
            color:
                AppTheme.lightTheme.bottomNavigationBarTheme.selectedItemColor!,
            size: 6.w,
          ),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: CustomIconWidget(
            iconName: 'menu_book',
            color: AppTheme
                .lightTheme.bottomNavigationBarTheme.unselectedItemColor!,
            size: 6.w,
          ),
          activeIcon: CustomIconWidget(
            iconName: 'menu_book',
            color:
                AppTheme.lightTheme.bottomNavigationBarTheme.selectedItemColor!,
            size: 6.w,
          ),
          label: 'Readings',
        ),
        BottomNavigationBarItem(
          icon: CustomIconWidget(
            iconName: 'calendar_today',
            color:
                AppTheme.lightTheme.bottomNavigationBarTheme.selectedItemColor!,
            size: 6.w,
          ),
          label: 'Calendar',
        ),
        BottomNavigationBarItem(
          icon: CustomIconWidget(
            iconName: 'article',
            color: AppTheme
                .lightTheme.bottomNavigationBarTheme.unselectedItemColor!,
            size: 6.w,
          ),
          activeIcon: CustomIconWidget(
            iconName: 'article',
            color:
                AppTheme.lightTheme.bottomNavigationBarTheme.selectedItemColor!,
            size: 6.w,
          ),
          label: 'Details',
        ),
      ],
    );
  }

  void _goToPreviousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
  }

  void _goToNextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
  }

  void _goToToday() {
    setState(() {
      _currentMonth = DateTime.now();
      _selectedDate = DateTime.now();
    });
  }

  void _onDateTap(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
    _showLiturgicalBottomSheet(date);
  }

  void _onDateLongPress(DateTime date) {
    _showContextMenu(date);
  }

  void _showLiturgicalBottomSheet(DateTime date) {
    final liturgicalInfo = _getLiturgicalInfoForDate(date);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LiturgicalBottomSheetWidget(
        selectedDate: date,
        liturgicalInfo: liturgicalInfo,
        onReadingsPressed: () {
          Navigator.pop(context);
          Navigator.pushNamed(context, '/reading-detail');
        },
        onBookmarkPressed: () {
          Navigator.pop(context);
          _bookmarkDate(date);
        },
      ),
    );
  }

  void _showContextMenu(DateTime date) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(4.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: CustomIconWidget(
                iconName: 'bookmark',
                color: AppTheme.lightTheme.colorScheme.primary,
                size: 6.w,
              ),
              title: Text('Bookmark this date'),
              onTap: () {
                Navigator.pop(context);
                _bookmarkDate(date);
              },
            ),
            ListTile(
              leading: CustomIconWidget(
                iconName: 'share',
                color: AppTheme.lightTheme.colorScheme.primary,
                size: 6.w,
              ),
              title: Text('Share liturgical info'),
              onTap: () {
                Navigator.pop(context);
                _shareDate(date);
              },
            ),
            ListTile(
              leading: CustomIconWidget(
                iconName: 'notifications',
                color: AppTheme.lightTheme.colorScheme.primary,
                size: 6.w,
              ),
              title: Text('Set reminder'),
              onTap: () {
                Navigator.pop(context);
                _setReminder(date);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDatePicker() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: AppTheme.lightTheme.copyWith(
            datePickerTheme: DatePickerThemeData(
              backgroundColor: AppTheme.lightTheme.colorScheme.surface,
              headerBackgroundColor: AppTheme.lightTheme.colorScheme.primary,
              headerForegroundColor: AppTheme.lightTheme.colorScheme.onPrimary,
              dayForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppTheme.lightTheme.colorScheme.onPrimary;
                }
                return AppTheme.lightTheme.colorScheme.onSurface;
              }),
              dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppTheme.lightTheme.colorScheme.primary;
                }
                return Colors.transparent;
              }),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _currentMonth = DateTime(picked.year, picked.month);
      });
    }
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Search Liturgical Calendar'),
        content: TextField(
          decoration: InputDecoration(
            hintText: 'Search for feast days, saints, or celebrations...',
            prefixIcon: CustomIconWidget(
              iconName: 'search',
              color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
              size: 5.w,
            ),
          ),
          onSubmitted: (query) {
            Navigator.pop(context);
            _performSearch(query);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshLiturgicalData() async {
    setState(() {
      _isLoading = true;
    });

    // Simulate API call
    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      _isLoading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Liturgical data updated'),
        backgroundColor: AppTheme.lightTheme.snackBarTheme.backgroundColor,
      ),
    );
  }

  void _onBottomNavTap(int index) {
    switch (index) {
      case 0:
        Navigator.pushNamed(context, '/splash-screen');
        break;
      case 1:
        Navigator.pushNamed(context, '/today-s-readings');
        break;
      case 2:
        // Already on calendar
        break;
      case 3:
        Navigator.pushNamed(context, '/reading-detail');
        break;
    }
  }

  Map<String, dynamic> _getLiturgicalInfoForDate(DateTime date) {
    final liturgicalEntry = _liturgicalData.firstWhere(
      (entry) => _isSameDay(DateTime.parse(entry['date'] as String), date),
      orElse: () => <String, dynamic>{},
    );

    if (liturgicalEntry.isNotEmpty) {
      return liturgicalEntry;
    }

    return {
      'celebration': null,
      'season': 'Ordinary Time',
      'rank': 'Weekday',
      'isFeastDay': false,
      'description': 'Regular weekday in Ordinary Time',
    };
  }

  List<Map<String, dynamic>> _getUpcomingFeasts() {
    final now = DateTime.now();
    final upcomingFeasts = _liturgicalData
        .where((feast) {
          final feastDate = DateTime.parse(feast['date'] as String);
          return feastDate.isAfter(now) && (feast['isFeastDay'] as bool);
        })
        .take(5)
        .toList();

    upcomingFeasts.sort((a, b) {
      final dateA = DateTime.parse(a['date'] as String);
      final dateB = DateTime.parse(b['date'] as String);
      return dateA.compareTo(dateB);
    });

    return upcomingFeasts;
  }

  void _bookmarkDate(DateTime date) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Date bookmarked successfully'),
        backgroundColor: AppTheme.lightTheme.snackBarTheme.backgroundColor,
      ),
    );
  }

  void _shareDate(DateTime date) {
    final liturgicalInfo = _getLiturgicalInfoForDate(date);
    final celebration = liturgicalInfo['celebration'] as String?;
    final shareText = celebration != null
        ? 'Today is ${celebration} - ${_formatDate(date)}'
        : 'Liturgical Calendar - ${_formatDate(date)}';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sharing: $shareText'),
        backgroundColor: AppTheme.lightTheme.snackBarTheme.backgroundColor,
      ),
    );
  }

  void _setReminder(DateTime date) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Reminder set for ${_formatDate(date)}'),
        backgroundColor: AppTheme.lightTheme.snackBarTheme.backgroundColor,
      ),
    );
  }

  void _performSearch(String query) {
    final results = _liturgicalData
        .where((entry) =>
            (entry['celebration'] as String?)
                ?.toLowerCase()
                .contains(query.toLowerCase()) ??
            false)
        .toList();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Found ${results.length} results for "$query"'),
        backgroundColor: AppTheme.lightTheme.snackBarTheme.backgroundColor,
      ),
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

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }
}
