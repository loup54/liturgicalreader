import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:xml/xml.dart' as xml;

import '../models/liturgical_day.dart';
import '../models/liturgical_reading.dart';

/// Service for fetching real liturgical data from official Catholic sources
/// Primary: USCCB Daily Readings API
/// Secondary: Universalis API
/// Tertiary: Catholic News Agency
class CatholicApiService {
  static final CatholicApiService _instance = CatholicApiService._internal();
  factory CatholicApiService() => _instance;
  CatholicApiService._internal();

  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    headers: {
      'User-Agent': 'LiturgicalReader-App/1.0.0',
      'Accept': 'application/json, text/html, application/xml',
    },
  ));

  /// Fetch today's readings from Catholic data sources
  Future<List<LiturgicalReading>> getTodaysReadings() async {
    return getReadingsForDate(DateTime.now());
  }

  /// Fetch readings for a specific date from Catholic data sources
  Future<List<LiturgicalReading>> getReadingsForDate(DateTime date) async {
    // Try primary source: USCCB Daily Readings API
    try {
      final readings = await _fetchFromUSCCB(date);
      if (readings.isNotEmpty) {
        debugPrint(
            'CatholicApiService: Successfully fetched ${readings.length} readings from USCCB');
        return readings;
      }
    } catch (e) {
      debugPrint('CatholicApiService: USCCB failed: $e');
    }

    // Try secondary source: Universalis API
    try {
      final readings = await _fetchFromUniversalis(date);
      if (readings.isNotEmpty) {
        debugPrint(
            'CatholicApiService: Successfully fetched ${readings.length} readings from Universalis');
        return readings;
      }
    } catch (e) {
      debugPrint('CatholicApiService: Universalis failed: $e');
    }

    // Try tertiary source: Catholic News Agency
    try {
      final readings = await _fetchFromCatholicNewsAgency(date);
      if (readings.isNotEmpty) {
        debugPrint(
            'CatholicApiService: Successfully fetched ${readings.length} readings from Catholic News Agency');
        return readings;
      }
    } catch (e) {
      debugPrint('CatholicApiService: Catholic News Agency failed: $e');
    }

    debugPrint(
        'CatholicApiService: All external sources failed, returning empty list');
    return [];
  }

  /// Fetch liturgical day information from Catholic sources
  Future<LiturgicalDay?> getLiturgicalDay({DateTime? date}) async {
    final targetDate = date ?? DateTime.now();

    // Try USCCB for liturgical day info
    try {
      final liturgicalDay = await _fetchLiturgicalDayFromUSCCB(targetDate);
      if (liturgicalDay != null) {
        debugPrint(
            'CatholicApiService: Successfully fetched liturgical day from USCCB');
        return liturgicalDay;
      }
    } catch (e) {
      debugPrint('CatholicApiService: USCCB liturgical day failed: $e');
    }

    // Try Universalis for liturgical day info
    try {
      final liturgicalDay =
          await _fetchLiturgicalDayFromUniversalis(targetDate);
      if (liturgicalDay != null) {
        debugPrint(
            'CatholicApiService: Successfully fetched liturgical day from Universalis');
        return liturgicalDay;
      }
    } catch (e) {
      debugPrint('CatholicApiService: Universalis liturgical day failed: $e');
    }

    return null;
  }

  /// Fetch readings from USCCB Daily Readings API
  Future<List<LiturgicalReading>> _fetchFromUSCCB(DateTime date) async {
    final dateStr =
        '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';
    final url = 'https://bible.usccb.org/api/bible/readings/$dateStr';

    final response = await _dio.get(url);

    if (response.statusCode != 200) {
      throw Exception('USCCB API returned ${response.statusCode}');
    }

    final data = response.data;
    if (data == null || data['readings'] == null) {
      return [];
    }

    final List<LiturgicalReading> readings = [];
    final liturgicalDayId = 'usccb-${date.millisecondsSinceEpoch}';
    int orderSequence = 1;

    // Parse first reading
    if (data['readings']['first_reading'] != null) {
      readings.add(_createReadingFromUSCCB(
        data['readings']['first_reading'],
        liturgicalDayId,
        ReadingType.firstReading,
        orderSequence++,
      ));
    }

    // Parse responsorial psalm
    if (data['readings']['responsorial_psalm'] != null) {
      readings.add(_createReadingFromUSCCB(
        data['readings']['responsorial_psalm'],
        liturgicalDayId,
        ReadingType.responsorialPsalm,
        orderSequence++,
      ));
    }

    // Parse second reading (if available)
    if (data['readings']['second_reading'] != null) {
      readings.add(_createReadingFromUSCCB(
        data['readings']['second_reading'],
        liturgicalDayId,
        ReadingType.secondReading,
        orderSequence++,
      ));
    }

    // Parse gospel reading
    if (data['readings']['gospel'] != null) {
      readings.add(_createReadingFromUSCCB(
        data['readings']['gospel'],
        liturgicalDayId,
        ReadingType.gospel,
        orderSequence++,
      ));
    }

    return readings;
  }

  /// Create LiturgicalReading from USCCB API response
  LiturgicalReading _createReadingFromUSCCB(
    Map<String, dynamic> readingData,
    String liturgicalDayId,
    ReadingType readingType,
    int orderSequence,
  ) {
    final citation = readingData['citation']?.toString() ?? '';
    final content = _cleanHtmlContent(readingData['content']?.toString() ?? '');

    return LiturgicalReading(
      id: 'usccb-${readingType.name}-${DateTime.now().millisecondsSinceEpoch}',
      liturgicalDayId: liturgicalDayId,
      readingType: readingType,
      citation: citation,
      content: content,
      orderSequence: orderSequence,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      previewText:
          content.length > 150 ? '${content.substring(0, 147)}...' : content,
    );
  }

  /// Fetch readings from Universalis API
  Future<List<LiturgicalReading>> _fetchFromUniversalis(DateTime date) async {
    final dateStr =
        '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
    final url = 'http://universalis.com/$dateStr/readings.xml';

    final response = await _dio.get(url);

    if (response.statusCode != 200) {
      throw Exception('Universalis API returned ${response.statusCode}');
    }

    try {
      final document = xml.XmlDocument.parse(response.data);
      final readings = document.findAllElements('reading');

      final List<LiturgicalReading> liturgicalReadings = [];
      final liturgicalDayId = 'universalis-${date.millisecondsSinceEpoch}';

      for (int i = 0; i < readings.length; i++) {
        final reading = readings.elementAt(i);
        final type = reading.getAttribute('type');
        final citation =
            reading.findElements('citation').firstOrNull?.text ?? '';
        final content = reading.findElements('text').firstOrNull?.text ?? '';

        ReadingType readingType;
        switch (type?.toLowerCase()) {
          case 'first_reading':
          case 'firstReading':
            readingType = ReadingType.firstReading;
            break;
          case 'psalm':
          case 'responsorial_psalm':
            readingType = ReadingType.responsorialPsalm;
            break;
          case 'second_reading':
          case 'secondReading':
            readingType = ReadingType.secondReading;
            break;
          case 'gospel':
            readingType = ReadingType.gospel;
            break;
          default:
            continue; // Skip unknown reading types
        }

        liturgicalReadings.add(LiturgicalReading(
          id: 'universalis-${readingType.name}-${DateTime.now().millisecondsSinceEpoch}',
          liturgicalDayId: liturgicalDayId,
          readingType: readingType,
          citation: citation,
          content: content,
          orderSequence: i + 1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          previewText: content.length > 150
              ? '${content.substring(0, 147)}...'
              : content,
        ));
      }

      return liturgicalReadings;
    } catch (e) {
      throw Exception('Failed to parse Universalis XML: $e');
    }
  }

  /// Fetch readings from Catholic News Agency
  Future<List<LiturgicalReading>> _fetchFromCatholicNewsAgency(
      DateTime date) async {
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final url = 'https://www.catholicnewsagency.com/daily-readings/$dateStr';

    final response = await _dio.get(url);

    if (response.statusCode != 200) {
      throw Exception('Catholic News Agency returned ${response.statusCode}');
    }

    try {
      final document = html_parser.parse(response.data);
      final readingElements =
          document.querySelectorAll('.daily-reading-content');

      final List<LiturgicalReading> readings = [];
      final liturgicalDayId = 'cna-${date.millisecondsSinceEpoch}';

      for (int i = 0; i < readingElements.length; i++) {
        final element = readingElements[i];
        final titleElement = element.querySelector('.reading-title');
        final citationElement = element.querySelector('.reading-citation');
        final contentElement = element.querySelector('.reading-text');

        if (titleElement == null || contentElement == null) continue;

        final title = titleElement.text.trim().toLowerCase();
        final citation = citationElement?.text.trim() ?? '';
        final content = _cleanHtmlContent(contentElement.text);

        ReadingType? readingType;
        if (title.contains('first reading')) {
          readingType = ReadingType.firstReading;
        } else if (title.contains('psalm')) {
          readingType = ReadingType.responsorialPsalm;
        } else if (title.contains('second reading')) {
          readingType = ReadingType.secondReading;
        } else if (title.contains('gospel')) {
          readingType = ReadingType.gospel;
        }

        if (readingType != null) {
          readings.add(LiturgicalReading(
            id: 'cna-${readingType.name}-${DateTime.now().millisecondsSinceEpoch}',
            liturgicalDayId: liturgicalDayId,
            readingType: readingType,
            citation: citation,
            content: content,
            orderSequence: i + 1,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            previewText: content.length > 150
                ? '${content.substring(0, 147)}...'
                : content,
          ));
        }
      }

      return readings;
    } catch (e) {
      throw Exception('Failed to parse Catholic News Agency HTML: $e');
    }
  }

  /// Fetch liturgical day information from USCCB
  Future<LiturgicalDay?> _fetchLiturgicalDayFromUSCCB(DateTime date) async {
    final dateStr =
        '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';
    final url = 'https://bible.usccb.org/api/bible/calendar/$dateStr';

    try {
      final response = await _dio.get(url);

      if (response.statusCode != 200) {
        return null;
      }

      final data = response.data;
      if (data == null) return null;

      return LiturgicalDay(
        id: 'usccb-day-${date.millisecondsSinceEpoch}',
        date: date,
        liturgicalSeason: data['season']?.toString() ?? 'Ordinary Time',
        liturgicalRank: data['rank']?.toString() ?? 'weekday',
        feastName: data['celebration']?.toString(),
        commemoration: data['commemoration']?.toString(),
        liturgicalColor: data['color']?.toString() ?? 'green',
        weekOfSeason: data['week_of_season'] as int? ?? 1,
        dayOfWeek: _getDayOfWeek(date.weekday),
        isSunday: date.weekday == 7,
        isHolyDay: data['is_holy_day'] as bool? ?? false,
        readings: data['readings'] as Map<String, dynamic>? ?? {},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } catch (e) {
      return null;
    }
  }

  /// Fetch liturgical day information from Universalis
  Future<LiturgicalDay?> _fetchLiturgicalDayFromUniversalis(
      DateTime date) async {
    final dateStr =
        '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
    final url = 'http://universalis.com/$dateStr/calendar.xml';

    try {
      final response = await _dio.get(url);

      if (response.statusCode != 200) {
        return null;
      }

      final document = xml.XmlDocument.parse(response.data);
      final calendar = document.findElements('calendar').firstOrNull;

      if (calendar == null) return null;

      return LiturgicalDay(
        id: 'universalis-day-${date.millisecondsSinceEpoch}',
        date: date,
        liturgicalSeason: calendar.findElements('season').firstOrNull?.text ??
            'Ordinary Time',
        liturgicalRank:
            calendar.findElements('rank').firstOrNull?.text ?? 'weekday',
        feastName: calendar.findElements('feast').firstOrNull?.text,
        commemoration: calendar.findElements('commemoration').firstOrNull?.text,
        liturgicalColor:
            calendar.findElements('color').firstOrNull?.text ?? 'green',
        weekOfSeason: int.tryParse(
                calendar.findElements('week').firstOrNull?.text ?? '1') ??
            1,
        dayOfWeek: _getDayOfWeek(date.weekday),
        isSunday: date.weekday == 7,
        isHolyDay:
            calendar.findElements('holy_day').firstOrNull?.text.toLowerCase() ==
                'true',
        readings: {},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } catch (e) {
      return null;
    }
  }

  /// Clean HTML content by removing tags and normalizing whitespace
  String _cleanHtmlContent(String htmlContent) {
    if (htmlContent.isEmpty) return htmlContent;

    // Parse HTML and extract text
    final document = html_parser.parse(htmlContent);
    final text = document.body?.text ?? htmlContent;

    // Normalize whitespace
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Get day of week string from weekday number
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

  /// Check if the service has network connectivity
  Future<bool> get hasConnectivity async {
    try {
      final response = await _dio.get('https://www.google.com',
          options: Options(sendTimeout: const Duration(seconds: 5)));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
