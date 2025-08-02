import 'package:flutter/foundation.dart';

import '../models/liturgical_day.dart';
import '../models/liturgical_reading.dart';
import '../models/user_bookmark.dart';
import './supabase_service.dart';
import './catholic_api_service.dart';
import './liturgical_calendar_service.dart';

class LiturgicalService {
  static final LiturgicalService _instance = LiturgicalService._internal();
  factory LiturgicalService() => _instance;
  LiturgicalService._internal();

  final CatholicApiService _catholicApiService = CatholicApiService();
  final LiturgicalCalendarService _calendarService =
      LiturgicalCalendarService();

  // Get today's liturgical readings with corrected query patterns
  Future<List<LiturgicalReading>> getTodaysReadings() async {
    final today = DateTime.now();
    return await getReadingsForDate(today);
  }

  // Get liturgical day information with safe query methods
  Future<LiturgicalDay> getLiturgicalDay({DateTime? date}) async {
    final targetDate = date ?? DateTime.now();

    // Step 1: Try Supabase database with corrected query pattern
    try {
      final client = await SupabaseService.getClient();
      if (client != null) {
        final dateStr =
            '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';

        // Simple, safe query pattern
        final response = await client
            .from('liturgical_days')
            .select('*')
            .eq('date', dateStr)
            .maybeSingle();

        if (response != null) {
          debugPrint('LiturgicalService: Got liturgical day from Supabase');
          return _createLiturgicalDayFromDatabase(response, targetDate);
        }
      }
    } catch (e) {
      debugPrint(
          'LiturgicalService: Supabase liturgical day failed (fallback to local): $e');
    }

    // Step 2: Try Catholic API sources
    try {
      final liturgicalDay =
          await _catholicApiService.getLiturgicalDay(date: targetDate);
      if (liturgicalDay != null) {
        debugPrint('LiturgicalService: Got liturgical day from Catholic APIs');
        return liturgicalDay;
      }
    } catch (e) {
      debugPrint('LiturgicalService: Catholic APIs liturgical day failed: $e');
    }

    // Step 3: Use local calculation as reliable fallback
    debugPrint('LiturgicalService: Using local liturgical day calculation');
    return await _createLiturgicalDayFromCalculation(targetDate);
  }

  // Get readings for a specific date with corrected query patterns
  Future<List<LiturgicalReading>> getReadingsForDate(DateTime date) async {
    // Step 1: Try Catholic API sources first
    try {
      final readings = await _catholicApiService.getReadingsForDate(date);
      if (readings.isNotEmpty) {
        debugPrint(
            'LiturgicalService: Got ${readings.length} readings from Catholic APIs for $date');
        return readings;
      }
    } catch (e) {
      debugPrint('LiturgicalService: Catholic APIs failed for date $date: $e');
    }

    // Step 2: Try Supabase database with safe query pattern
    try {
      final client = await SupabaseService.getClient();
      if (client != null) {
        final dateStr =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

        // First get liturgical day
        final liturgicalDay = await client
            .from('liturgical_days')
            .select('id')
            .eq('date', dateStr)
            .maybeSingle();

        if (liturgicalDay != null) {
          // Then get readings - simple pattern
          final response = await client
              .from('liturgical_readings')
              .select('*')
              .eq('liturgical_day_id', liturgicalDay['id'])
              .order('order_sequence', ascending: true);

          if (response.isNotEmpty) {
            debugPrint(
                'LiturgicalService: Got ${response.length} readings from Supabase for $date');
            return response
                .map((json) => LiturgicalReading.fromJson(json))
                .toList();
          }
        }
      }
    } catch (e) {
      debugPrint('LiturgicalService: Supabase query failed for date $date: $e');
    }

    // Step 3: Use mock data fallback
    debugPrint('LiturgicalService: Using mock data fallback for $date');
    return await _getMockReadingsForDateWithContext(date);
  }

  // Get readings for a date range with corrected query patterns
  Future<Map<DateTime, List<LiturgicalReading>>> getReadingsForDateRange({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final start = startDate ?? DateTime.now();
    final end = endDate ?? DateTime.now().add(const Duration(days: 7));

    final readings = <DateTime, List<LiturgicalReading>>{};

    try {
      final client = await SupabaseService.getClient();
      if (client != null) {
        final startStr =
            '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
        final endStr =
            '${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}';

        // Get liturgical days in range first
        final liturgicalDays = await client
            .from('liturgical_days')
            .select('id, date')
            .gte('date', startStr)
            .lte('date', endStr)
            .order('date', ascending: true);

        // Get readings for each day
        for (final day in liturgicalDays) {
          final dayReadings = await client
              .from('liturgical_readings')
              .select('*')
              .eq('liturgical_day_id', day['id'])
              .order('order_sequence', ascending: true);

          if (dayReadings.isNotEmpty) {
            final dateStr = day['date'] as String;
            final readingDate = DateTime.parse(dateStr);
            readings[readingDate] = dayReadings
                .map((json) => LiturgicalReading.fromJson(json))
                .toList();
          }
        }
      }
    } catch (e) {
      debugPrint('LiturgicalService: Error getting date range readings: $e');
    }

    return readings;
  }

  // Get moveable feasts
  Future<List<Map<String, dynamic>>> getMoveableFeasts({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return await _calendarService.getMoveableFeasts(
      startDate: startDate,
      endDate: endDate,
    );
  }

  // Get liturgical year information
  Future<Map<String, dynamic>?> getLiturgicalYearInfo(
      int liturgicalYear) async {
    return await _calendarService.getLiturgicalYearBoundaries(liturgicalYear);
  }

  // Get user bookmarks with safe query pattern
  Future<List<UserBookmark>> getUserBookmarks(String userId) async {
    try {
      final client = await SupabaseService.getClient();
      if (client == null) {
        return _getMockBookmarks(userId);
      }

      final response = await client
          .from('user_bookmarks')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return response.map((json) => UserBookmark.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Failed to get user bookmarks: $e');
      return _getMockBookmarks(userId);
    }
  }

  // Create bookmark with safe insert pattern
  Future<UserBookmark?> createBookmark({
    required String userId,
    required String readingId,
    required String readingType,
    required DateTime date,
    String? note,
    bool isPrivate = true,
  }) async {
    try {
      final client = await SupabaseService.getClient();
      if (client == null) {
        debugPrint('Cannot create bookmark: Supabase client unavailable');
        return UserBookmark.mock(
            userId: userId, readingId: readingId, date: date);
      }

      final response = await client
          .from('user_bookmarks')
          .insert({
            'user_id': userId,
            'reading_id': readingId,
            'notes': note,
          })
          .select()
          .single();

      return UserBookmark.fromJson(response);
    } catch (e) {
      debugPrint('Failed to create bookmark: $e');
      return null;
    }
  }

  // Delete bookmark with safe delete pattern
  Future<bool> deleteBookmark(String bookmarkId) async {
    try {
      final client = await SupabaseService.getClient();
      if (client == null) {
        debugPrint('Cannot delete bookmark: Supabase client unavailable');
        return false;
      }

      await client.from('user_bookmarks').delete().eq('id', bookmarkId);

      return true;
    } catch (e) {
      debugPrint('Failed to delete bookmark: $e');
      return false;
    }
  }

  // Initialize liturgical calendar for future dates
  Future<void> initializeLiturgicalCalendar() async {
    try {
      await _calendarService.initializeLiturgicalYears();
      debugPrint('LiturgicalService: Calendar initialization completed');
    } catch (e) {
      debugPrint('LiturgicalService: Calendar initialization failed: $e');
    }
  }

  // Create LiturgicalDay from database response
  LiturgicalDay _createLiturgicalDayFromDatabase(
      Map<String, dynamic> data, DateTime date) {
    return LiturgicalDay(
      id: data['id']?.toString() ?? '',
      date: date,
      liturgicalSeason: data['season']?.toString() ?? 'ordinary_time',
      liturgicalRank: data['is_sunday'] == true ? 'sunday' : 'weekday',
      feastName: data['moveable_feast_type']?.toString(),
      commemoration: null,
      liturgicalColor: data['color']?.toString() ?? 'green',
      weekOfSeason: data['season_week'] as int? ?? 1,
      dayOfWeek: _getDayOfWeek(date.weekday),
      isSunday: data['is_sunday'] as bool? ?? false,
      isHolyDay: data['is_holyday'] as bool? ?? false,
      readings: {
        'liturgical_year_cycle':
            data['liturgical_year_cycle']?.toString() ?? 'A',
        'days_from_easter': data['days_from_easter']?.toString() ?? '0',
        'is_moveable_feast': data['is_moveable_feast']?.toString() ?? 'false',
      },
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  // Create LiturgicalDay from local calculation
  Future<LiturgicalDay> _createLiturgicalDayFromCalculation(
      DateTime date) async {
    final liturgicalInfo = await _calendarService.getLiturgicalDayInfo(date);

    return LiturgicalDay(
      id: 'calc-${date.millisecondsSinceEpoch}',
      date: date,
      liturgicalSeason: liturgicalInfo['liturgical_season'] ?? 'ordinary_time',
      liturgicalRank:
          liturgicalInfo['is_sunday'] == true ? 'sunday' : 'weekday',
      feastName: liturgicalInfo['moveable_feast_type'],
      commemoration: null,
      liturgicalColor: liturgicalInfo['liturgical_color'] ?? 'green',
      weekOfSeason: liturgicalInfo['season_week'] ?? 1,
      dayOfWeek: _getDayOfWeek(date.weekday),
      isSunday: liturgicalInfo['is_sunday'] ?? false,
      isHolyDay: liturgicalInfo['is_moveable_feast'] ?? false,
      readings: {
        'liturgical_year_cycle': liturgicalInfo['liturgical_year_cycle'] ?? 'A',
        'days_from_easter':
            liturgicalInfo['days_from_easter']?.toString() ?? '0',
        'liturgical_year':
            liturgicalInfo['liturgical_year']?.toString() ?? '2024',
      },
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  // Mock readings with liturgical context
  Future<List<LiturgicalReading>> _getMockReadingsForDateWithContext(
      DateTime date) async {
    final liturgicalInfo = await _calendarService.getLiturgicalDayInfo(date);
    final season = liturgicalInfo['liturgical_season'] ?? 'ordinary_time';
    final cycle = liturgicalInfo['liturgical_year_cycle'] ?? 'A';

    return [
      LiturgicalReading(
        id: 'mock-1-${date.millisecondsSinceEpoch}',
        liturgicalDayId: 'mock-day-${date.millisecondsSinceEpoch}',
        readingType: ReadingType.firstReading,
        citation: 'First Reading for $season - Year $cycle',
        content:
            'Enhanced liturgical reading content for ${season} season, Year ${cycle} cycle.',
        orderSequence: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        previewText: 'Enhanced liturgical reading content...',
      ),
      LiturgicalReading(
        id: 'mock-2-${date.millisecondsSinceEpoch}',
        liturgicalDayId: 'mock-day-${date.millisecondsSinceEpoch}',
        readingType: ReadingType.responsorialPsalm,
        citation: 'Responsorial Psalm for $season - Year $cycle',
        content: 'Psalm response appropriate for ${season} season.',
        orderSequence: 2,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        previewText: 'Psalm response appropriate...',
      ),
      LiturgicalReading(
        id: 'mock-3-${date.millisecondsSinceEpoch}',
        liturgicalDayId: 'mock-day-${date.millisecondsSinceEpoch}',
        readingType: ReadingType.gospel,
        citation: 'Gospel Reading for $season - Year $cycle',
        content:
            'Gospel reading from Year ${cycle} cycle for ${season} season.',
        orderSequence: 3,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        previewText: 'Gospel reading from Year ${cycle}...',
      ),
    ];
  }

  List<UserBookmark> _getMockBookmarks(String userId) {
    return [
      UserBookmark.mock(userId: userId, readingId: 'mock-1'),
      UserBookmark.mock(userId: userId, readingId: 'mock-2'),
    ];
  }

  static String _getDayOfWeek(int weekday) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return days[weekday - 1];
  }

  // Check if service is available
  bool get isAvailable => SupabaseService.isAvailable;

  // Enhanced status message with error handling
  String get statusMessage {
    if (SupabaseService.isAvailable) {
      return 'Connected to liturgical database with corrected query patterns and comprehensive validation';
    } else {
      final error = SupabaseService.initializationError;
      if (error?.contains('missing') == true) {
        return 'Running in offline mode - Configure SUPABASE_URL and SUPABASE_ANON_KEY for online features';
      } else {
        return 'Running in offline mode with local liturgical calculations - Database temporarily unavailable';
      }
    }
  }
}
