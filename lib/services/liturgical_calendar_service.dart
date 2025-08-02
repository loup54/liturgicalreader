import 'package:flutter/foundation.dart';

import './supabase_service.dart';

/// Comprehensive liturgical calendar service for Step 2 implementation
/// Handles date-to-reading mapping with full liturgical year calculations
class LiturgicalCalendarService {
  static final LiturgicalCalendarService _instance =
      LiturgicalCalendarService._internal();
  factory LiturgicalCalendarService() => _instance;
  LiturgicalCalendarService._internal();

  /// Calculate Easter date using Gregorian algorithm
  DateTime calculateEasterDate(int year) {
    final a = year % 19;
    final b = year ~/ 100;
    final c = year % 100;
    final d = b ~/ 4;
    final e = b % 4;
    final f = (b + 8) ~/ 25;
    final g = (b - f + 1) ~/ 3;
    final h = (19 * a + b - d - g + 15) % 30;
    final i = c ~/ 4;
    final k = c % 4;
    final l = (32 + 2 * e + 2 * i - h - k) % 7;
    final m = (a + 11 * h + 22 * l) ~/ 451;

    final month = (h + l - 7 * m + 114) ~/ 31;
    final day = ((h + l - 7 * m + 114) % 31) + 1;

    return DateTime(year, month, day);
  }

  /// Calculate First Sunday of Advent for a given year
  DateTime calculateFirstSundayOfAdvent(int year) {
    final christmas = DateTime(year, 12, 25);
    final christmasWeekday = christmas.weekday;

    // Calculate days back to get to the 4th Sunday before
    int daysBack = (christmasWeekday % 7) + 21;
    if (christmasWeekday == DateTime.sunday) {
      daysBack = 21; // If Christmas is Sunday, go back exactly 3 weeks
    }

    return christmas.subtract(Duration(days: daysBack));
  }

  /// Calculate liturgical year cycle (A, B, C)
  String calculateLiturgicalYearCycle(int liturgicalYear) {
    switch (liturgicalYear % 3) {
      case 0:
        return 'A';
      case 1:
        return 'B';
      default:
        return 'C';
    }
  }

  /// Get liturgical year for a given date
  int getLiturgicalYear(DateTime date) {
    final currentYear = date.year;
    final firstAdvent = calculateFirstSundayOfAdvent(currentYear - 1);

    if (date.isAfter(firstAdvent) || date.isAtSameMomentAs(firstAdvent)) {
      return currentYear - 1;
    } else {
      return currentYear - 2;
    }
  }

  /// Calculate all moveable feasts for a year
  Map<String, DateTime> calculateMoveableFeasts(int year) {
    final easter = calculateEasterDate(year);
    final firstAdvent = calculateFirstSundayOfAdvent(year);

    return {
      'ash_wednesday': easter.subtract(const Duration(days: 46)),
      'palm_sunday': easter.subtract(const Duration(days: 7)),
      'holy_thursday': easter.subtract(const Duration(days: 3)),
      'good_friday': easter.subtract(const Duration(days: 2)),
      'easter_sunday': easter,
      'divine_mercy_sunday': easter.add(const Duration(days: 7)),
      'ascension': easter.add(const Duration(days: 39)),
      'pentecost': easter.add(const Duration(days: 49)),
      'trinity_sunday': easter.add(const Duration(days: 56)),
      'corpus_christi': easter.add(const Duration(days: 63)),
      'sacred_heart': easter.add(const Duration(days: 68)),
      'christ_the_king': firstAdvent.subtract(const Duration(days: 7)),
    };
  }

  /// Get comprehensive liturgical information for any date
  Future<Map<String, dynamic>> getLiturgicalDayInfo(DateTime date) async {
    try {
      final client = await SupabaseService.getClient();
      if (client != null) {
        // Try to get from database first
        final response = await client.rpc('get_liturgical_day_info',
            params: {'input_date': date.toIso8601String().split('T')[0]});

        if (response != null && response.isNotEmpty) {
          final info = response[0];
          return {
            'liturgical_season': info['liturgical_season'],
            'liturgical_year_cycle': info['liturgical_year_cycle'],
            'season_week': info['season_week'],
            'days_from_easter': info['days_from_easter'],
            'is_sunday': info['is_sunday'],
            'is_moveable_feast': info['is_moveable_feast'],
            'moveable_feast_type': info['moveable_feast_type'],
            'liturgical_color': info['liturgical_color'],
          };
        }
      }
    } catch (e) {
      debugPrint('Error getting liturgical info from database: $e');
    }

    // Fallback to local calculation
    return _calculateLiturgicalInfoLocally(date);
  }

  /// Local calculation fallback for liturgical information
  Map<String, dynamic> _calculateLiturgicalInfoLocally(DateTime date) {
    final currentYear = date.year;
    final liturgicalYear = getLiturgicalYear(date);
    final cycle = calculateLiturgicalYearCycle(liturgicalYear);

    // Calculate key dates for the liturgical year
    final firstAdvent = calculateFirstSundayOfAdvent(liturgicalYear);
    final christmas = DateTime(liturgicalYear, 12, 25);
    final easter = calculateEasterDate(liturgicalYear + 1);
    final ashWednesday = easter.subtract(const Duration(days: 46));
    final pentecost = easter.add(const Duration(days: 49));

    final moveableFeasts = calculateMoveableFeasts(liturgicalYear + 1);

    // Determine liturgical season
    String season;
    int weekOfSeason;
    String color;
    bool isSunday = date.weekday == DateTime.sunday;

    // Check for moveable feast
    String? moveableFeastType;
    for (final entry in moveableFeasts.entries) {
      if (_isSameDay(date, entry.value)) {
        moveableFeastType = entry.key;
        break;
      }
    }

    if (date.isAfter(firstAdvent) || _isSameDay(date, firstAdvent)) {
      if (date.isBefore(christmas)) {
        season = 'advent';
        weekOfSeason = ((date.difference(firstAdvent).inDays) ~/ 7) + 1;
        color = 'purple';
      } else if (date.isBefore(ashWednesday)) {
        season = 'christmas';
        weekOfSeason = ((date.difference(christmas).inDays) ~/ 7) + 1;
        color = 'white';
      } else if (date.isBefore(easter)) {
        season = 'lent';
        weekOfSeason = ((date.difference(ashWednesday).inDays) ~/ 7) + 1;
        color = 'purple';
      } else if (date.isBefore(pentecost) || _isSameDay(date, pentecost)) {
        season = 'easter';
        weekOfSeason = ((date.difference(easter).inDays) ~/ 7) + 1;
        color = 'white';
      } else {
        season = 'ordinary_time';
        weekOfSeason = ((date.difference(pentecost).inDays) ~/ 7) + 1;
        color = 'green';
      }
    } else {
      season = 'ordinary_time';
      weekOfSeason =
          ((date.difference(christmas.add(const Duration(days: 7))).inDays) ~/
                  7) +
              1;
      color = 'green';
    }

    // Override colors for special feasts
    if (moveableFeastType != null) {
      switch (moveableFeastType) {
        case 'easter_sunday':
        case 'christmas':
          color = 'white';
          break;
        case 'good_friday':
        case 'palm_sunday':
          color = 'red';
          break;
      }
    }

    final daysFromEaster = date.difference(easter).inDays;

    return {
      'liturgical_season': season,
      'liturgical_year_cycle': cycle,
      'season_week': weekOfSeason,
      'days_from_easter': daysFromEaster,
      'is_sunday': isSunday,
      'is_moveable_feast': moveableFeastType != null,
      'moveable_feast_type': moveableFeastType,
      'liturgical_color': color,
      'liturgical_year': liturgicalYear,
    };
  }

  /// Ensure liturgical day exists in database
  Future<String?> ensureLiturgicalDayExists(DateTime date) async {
    try {
      final client = await SupabaseService.getClient();
      if (client == null) return null;

      final response = await client.rpc('ensure_liturgical_day_exists',
          params: {'input_date': date.toIso8601String().split('T')[0]});

      return response?.toString();
    } catch (e) {
      debugPrint('Error ensuring liturgical day exists: $e');
      return null;
    }
  }

  /// Get moveable feasts for a date range
  Future<List<Map<String, dynamic>>> getMoveableFeasts({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final start =
        startDate ?? DateTime.now().subtract(const Duration(days: 30));
    final end = endDate ?? DateTime.now().add(const Duration(days: 365));

    try {
      final client = await SupabaseService.getClient();
      if (client != null) {
        final response = await client
            .from('moveable_feasts')
            .select()
            .gte('date', start.toIso8601String().split('T')[0])
            .lte('date', end.toIso8601String().split('T')[0])
            .order('date');

        return List<Map<String, dynamic>>.from(response);
      }
    } catch (e) {
      debugPrint('Error fetching moveable feasts: $e');
    }

    // Fallback to local calculation
    final feasts = <Map<String, dynamic>>[];
    final currentYear = start.year;

    for (int year = currentYear - 1; year <= end.year + 1; year++) {
      final yearFeasts = calculateMoveableFeasts(year);
      final liturgicalYear = getLiturgicalYear(DateTime(year, 6, 1));
      final cycle = calculateLiturgicalYearCycle(liturgicalYear);

      for (final entry in yearFeasts.entries) {
        if ((entry.value.isAfter(start) || _isSameDay(entry.value, start)) &&
            (entry.value.isBefore(end) || _isSameDay(entry.value, end))) {
          feasts.add({
            'feast_type': entry.key,
            'date': entry.value.toIso8601String().split('T')[0],
            'liturgical_year_cycle': cycle,
            'year': year,
          });
        }
      }
    }

    feasts.sort((a, b) => a['date'].compareTo(b['date']));
    return feasts;
  }

  /// Get liturgical year boundaries
  Future<Map<String, dynamic>?> getLiturgicalYearBoundaries(
      int liturgicalYear) async {
    try {
      final client = await SupabaseService.getClient();
      if (client != null) {
        final response = await client
            .from('liturgical_year_boundaries')
            .select()
            .eq('liturgical_year', liturgicalYear)
            .maybeSingle();

        if (response != null) {
          return Map<String, dynamic>.from(response);
        }
      }
    } catch (e) {
      debugPrint('Error fetching liturgical year boundaries: $e');
    }

    // Fallback to local calculation
    final firstAdvent = calculateFirstSundayOfAdvent(liturgicalYear);
    final christmas = DateTime(liturgicalYear, 12, 25);
    final easter = calculateEasterDate(liturgicalYear + 1);
    final ashWednesday = easter.subtract(const Duration(days: 46));
    final pentecost = easter.add(const Duration(days: 49));
    final cycle = calculateLiturgicalYearCycle(liturgicalYear);

    return {
      'liturgical_year': liturgicalYear,
      'cycle': cycle,
      'first_sunday_advent': firstAdvent.toIso8601String().split('T')[0],
      'christmas_date': christmas.toIso8601String().split('T')[0],
      'ash_wednesday': ashWednesday.toIso8601String().split('T')[0],
      'easter_date': easter.toIso8601String().split('T')[0],
      'pentecost_date': pentecost.toIso8601String().split('T')[0],
    };
  }

  /// Initialize liturgical years in database
  Future<void> initializeLiturgicalYears({
    int? startYear,
    int? endYear,
  }) async {
    try {
      final client = await SupabaseService.getClient();
      if (client == null) return;

      final currentYear = DateTime.now().year;
      final start = startYear ?? (currentYear - 1);
      final end = endYear ?? (currentYear + 2);

      for (int year = start; year <= end; year++) {
        await client
            .rpc('populate_liturgical_year', params: {'year_val': year});
      }

      debugPrint('Initialized liturgical years from $start to $end');
    } catch (e) {
      debugPrint('Error initializing liturgical years: $e');
    }
  }

  /// Helper method to check if two dates are the same day
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  /// Validate date is within supported range
  bool isDateSupported(DateTime date) {
    final currentYear = DateTime.now().year;
    return date.year >= currentYear - 10 && date.year <= currentYear + 10;
  }

  /// Get liturgical calendar status
  String get statusMessage {
    return 'Liturgical Calendar Service: Ready with comprehensive date-to-reading mapping';
  }
}
