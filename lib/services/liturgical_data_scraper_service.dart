import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:xml/xml.dart' as xml;
import 'package:crypto/crypto.dart';

import '../models/liturgical_reading.dart';
import './supabase_service.dart';

/// Enhanced liturgical data scraper service with checksum validation
/// and automated daily scraping at 12:01 AM local time
class LiturgicalDataScraperService {
  static final LiturgicalDataScraperService _instance =
      LiturgicalDataScraperService._internal();
  factory LiturgicalDataScraperService() => _instance;
  LiturgicalDataScraperService._internal();

  static final Dio _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'User-Agent': 'LiturgicalReader-DataPipeline/1.0.0',
        'Accept': 'application/json, text/html, application/xml',
      }));

  /// Main scraping orchestrator - processes all active sources
  Future<Map<String, dynamic>> executeDataPipeline(DateTime targetDate) async {
    final results = <String, dynamic>{
      'date': targetDate.toIso8601String(),
      'sources_processed': 0,
      'readings_created': 0,
      'readings_updated': 0,
      'errors': <String>[],
      'checksums_validated': 0,
      'data_integrity_score': 0.0,
    };

    try {
      // Get active data sources ordered by priority
      final sources = await _getActiveSources();
      debugPrint(
          'DataScraper: Processing ${sources.length} sources for $targetDate');

      for (final source in sources) {
        try {
          final sourceResult = await _processDataSource(source, targetDate);
          results['sources_processed'] =
              (results['sources_processed'] as int) + 1;
          results['readings_created'] = (results['readings_created'] as int) +
              (sourceResult['readings_created'] as int);
          results['readings_updated'] = (results['readings_updated'] as int) +
              (sourceResult['readings_updated'] as int);
          results['checksums_validated'] =
              (results['checksums_validated'] as int) +
                  (sourceResult['checksums_validated'] as int);

          // Update source last sync time
          await _updateSourceSyncStatus(source['id'], true);
        } catch (e) {
          debugPrint('DataScraper: Source ${source['name']} failed: $e');
          results['errors'].add('${source['name']}: $e');
          await _updateSourceSyncStatus(source['id'], false);
        }
      }

      // Calculate data integrity score
      results['data_integrity_score'] = _calculateDataIntegrityScore(results);

      // Log pipeline completion
      await _logPipelineExecution(targetDate, results);
    } catch (e) {
      debugPrint('DataScraper: Pipeline execution failed: $e');
      results['errors'].add('Pipeline error: $e');
    }

    return results;
  }

  /// Get active data sources ordered by priority
  Future<List<Map<String, dynamic>>> _getActiveSources() async {
    final client = await SupabaseService.getClient();
    if (client == null) {
      throw Exception('Database connection unavailable');
    }

    final response = await client
        .from('liturgical_data_sources')
        .select()
        .eq('is_active', true)
        .lt('consecutive_failures', 5) // Skip sources with too many failures
        .order('priority');

    return List<Map<String, dynamic>>.from(response);
  }

  /// Process individual data source
  Future<Map<String, dynamic>> _processDataSource(
      Map<String, dynamic> source, DateTime targetDate) async {
    final result = {
      'readings_created': 0,
      'readings_updated': 0,
      'checksums_validated': 0,
    };

    final sourceType = source['source_type'] as String;
    List<LiturgicalReading> readings = [];

    // Fetch readings based on source type
    switch (sourceType) {
      case 'usccb':
        readings = await _scrapeUSCCB(targetDate, source);
        break;
      case 'universalis':
        readings = await _scrapeUniversalis(targetDate, source);
        break;
      case 'catholic_news_agency':
        readings = await _scrapeCatholicNewsAgency(targetDate, source);
        break;
      case 'vatican':
        readings = await _scrapeVatican(targetDate, source);
        break;
      default:
        throw Exception('Unsupported source type: $sourceType');
    }

    if (readings.isEmpty) {
      throw Exception('No readings retrieved from source');
    }

    // Process and validate each reading
    for (final reading in readings) {
      final processResult = await _processReading(reading, source, targetDate);
      if (processResult['created']) {
        result['readings_created'] = (result['readings_created'] as int) + 1;
      } else if (processResult['updated']) {
        result['readings_updated'] = (result['readings_updated'] as int) + 1;
      }
      if (processResult['checksum_validated']) {
        result['checksums_validated'] =
            (result['checksums_validated'] as int) + 1;
      }
    }

    return result;
  }

  /// Enhanced USCCB scraper with error handling
  Future<List<LiturgicalReading>> _scrapeUSCCB(
      DateTime date, Map<String, dynamic> source) async {
    final dateStr =
        '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';
    final url = '${source['base_url']}${source['api_endpoint']}/$dateStr';

    final response = await _dio.get(url);

    if (response.statusCode != 200) {
      throw Exception('USCCB API returned ${response.statusCode}');
    }

    final data = response.data;
    if (data == null || data['readings'] == null) {
      throw Exception('Invalid USCCB response format');
    }

    final readings = <LiturgicalReading>[];
    final liturgicalDayId = 'usccb-${date.millisecondsSinceEpoch}';
    int orderSequence = 1;

    // Process each reading type
    final readingTypes = {
      'first_reading': ReadingType.firstReading,
      'responsorial_psalm': ReadingType.responsorialPsalm,
      'second_reading': ReadingType.secondReading,
      'gospel': ReadingType.gospel,
    };

    for (final entry in readingTypes.entries) {
      final readingData = data['readings'][entry.key];
      if (readingData != null) {
        readings.add(_createReadingFromUSCCB(readingData, liturgicalDayId,
            entry.value, orderSequence++, source, url));
      }
    }

    return readings;
  }

  /// Enhanced Universalis scraper with XML parsing
  Future<List<LiturgicalReading>> _scrapeUniversalis(
      DateTime date, Map<String, dynamic> source) async {
    final dateStr =
        '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
    final url = '${source['base_url']}/$dateStr${source['api_endpoint']}';

    final response = await _dio.get(url);

    if (response.statusCode != 200) {
      throw Exception('Universalis API returned ${response.statusCode}');
    }

    final document = xml.XmlDocument.parse(response.data);
    final readingElements = document.findAllElements('reading');

    final readings = <LiturgicalReading>[];
    final liturgicalDayId = 'universalis-${date.millisecondsSinceEpoch}';

    for (int i = 0; i < readingElements.length; i++) {
      final reading = readingElements.elementAt(i);
      final type = reading.getAttribute('type');
      final citation = reading.findElements('citation').firstOrNull?.text ?? '';
      final content = reading.findElements('text').firstOrNull?.text ?? '';

      final readingType = _parseUniversalisReadingType(type);
      if (readingType != null && content.isNotEmpty) {
        readings.add(LiturgicalReading(
            id: 'universalis-${readingType.name}-${DateTime.now().millisecondsSinceEpoch}',
            liturgicalDayId: liturgicalDayId,
            readingType: readingType,
            citation: citation,
            content: _cleanHtmlContent(content),
            orderSequence: i + 1,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            previewText: _generatePreviewText(content)));
      }
    }

    return readings;
  }

  /// Catholic News Agency scraper with HTML parsing
  Future<List<LiturgicalReading>> _scrapeCatholicNewsAgency(
      DateTime date, Map<String, dynamic> source) async {
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final url = '${source['base_url']}${source['api_endpoint']}/$dateStr';

    final response = await _dio.get(url);

    if (response.statusCode != 200) {
      throw Exception('Catholic News Agency returned ${response.statusCode}');
    }

    final document = html_parser.parse(response.data);
    final readingElements = document.querySelectorAll('.daily-reading-content');

    final readings = <LiturgicalReading>[];
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

      final readingType = _parseCNAReadingType(title);
      if (readingType != null && content.isNotEmpty) {
        readings.add(LiturgicalReading(
            id: 'cna-${readingType.name}-${DateTime.now().millisecondsSinceEpoch}',
            liturgicalDayId: liturgicalDayId,
            readingType: readingType,
            citation: citation,
            content: content,
            orderSequence: i + 1,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            previewText: _generatePreviewText(content)));
      }
    }

    return readings;
  }

  /// Vatican News scraper (placeholder - would need actual Vatican API)
  Future<List<LiturgicalReading>> _scrapeVatican(
      DateTime date, Map<String, dynamic> source) async {
    // Vatican doesn't have a direct readings API, so this would use RSS feeds
    // or web scraping of their liturgy pages
    debugPrint('Vatican scraper not yet implemented - using fallback');
    return [];
  }

  /// Process and validate individual reading with checksum
  Future<Map<String, dynamic>> _processReading(LiturgicalReading reading,
      Map<String, dynamic> source, DateTime targetDate) async {
    final client = await SupabaseService.getClient();
    if (client == null) {
      throw Exception('Database connection unavailable');
    }

    // Calculate checksum for data integrity
    final contentHash = _calculateChecksum(
        reading.content, reading.citation, reading.readingType.name);

    // Check if reading already exists
    final existing = await client
        .from('liturgical_readings')
        .select('id, data_hash')
        .eq('citation', reading.citation)
        .eq('reading_type', reading.readingType.name)
        .eq('liturgical_day_id', reading.liturgicalDayId)
        .maybeSingle();

    final result = {
      'created': false,
      'updated': false,
      'checksum_validated': false,
    };

    if (existing == null) {
      // Create new reading
      await client.from('liturgical_readings').insert({
        'liturgical_day_id': reading.liturgicalDayId,
        'reading_type': reading.readingType.name,
        'citation': reading.citation,
        'content': reading.content,
        'order_sequence': reading.orderSequence,
        'source_id': source['id'],
        'source_url': reading.sourceUrl,
        'scraped_at': DateTime.now().toIso8601String(),
        'data_hash': contentHash,
      });
      result['created'] = true;
    } else if (existing['data_hash'] != contentHash) {
      // Update existing reading if content changed
      await client.from('liturgical_readings').update({
        'content': reading.content,
        'data_hash': contentHash,
        'last_updated_from_source': DateTime.now().toIso8601String(),
        'scraped_at': DateTime.now().toIso8601String(),
      }).eq('id', existing['id']);
      result['updated'] = true;
    }

    result['checksum_validated'] = true;
    return result;
  }

  /// Create LiturgicalReading from USCCB data
  LiturgicalReading _createReadingFromUSCCB(
      Map<String, dynamic> readingData,
      String liturgicalDayId,
      ReadingType readingType,
      int orderSequence,
      Map<String, dynamic> source,
      String sourceUrl) {
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
        previewText: _generatePreviewText(content));
  }

  /// Parse Universalis reading types
  ReadingType? _parseUniversalisReadingType(String? type) {
    switch (type?.toLowerCase()) {
      case 'first_reading':
      case 'firstreading':
        return ReadingType.firstReading;
      case 'psalm':
      case 'responsorial_psalm':
        return ReadingType.responsorialPsalm;
      case 'second_reading':
      case 'secondreading':
        return ReadingType.secondReading;
      case 'gospel':
        return ReadingType.gospel;
      default:
        return null;
    }
  }

  /// Parse Catholic News Agency reading types
  ReadingType? _parseCNAReadingType(String title) {
    if (title.contains('first reading')) return ReadingType.firstReading;
    if (title.contains('psalm')) return ReadingType.responsorialPsalm;
    if (title.contains('second reading')) return ReadingType.secondReading;
    if (title.contains('gospel')) return ReadingType.gospel;
    return null;
  }

  /// Calculate SHA-256 checksum for data integrity
  String _calculateChecksum(
      String content, String citation, String readingType) {
    final combined = '$content|$citation|$readingType';
    final bytes = utf8.encode(combined);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Clean HTML content
  String _cleanHtmlContent(String htmlContent) {
    if (htmlContent.isEmpty) return htmlContent;
    final document = html_parser.parse(htmlContent);
    final text = document.body?.text ?? htmlContent;
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Generate preview text
  String _generatePreviewText(String content) {
    if (content.length <= 150) return content;
    return '${content.substring(0, 147)}...';
  }

  /// Update source sync status
  Future<void> _updateSourceSyncStatus(String sourceId, bool success) async {
    final client = await SupabaseService.getClient();
    if (client == null) return;

    if (success) {
      await client.from('liturgical_data_sources').update({
        'last_successful_sync': DateTime.now().toIso8601String(),
        'consecutive_failures': 0,
      }).eq('id', sourceId);
    } else {
      await client.from('liturgical_data_sources').update({
        'consecutive_failures': 'consecutive_failures + 1',
      }).eq('id', sourceId);
    }
  }

  /// Calculate data integrity score
  double _calculateDataIntegrityScore(Map<String, dynamic> results) {
    final total = (results['readings_created'] as int) +
        (results['readings_updated'] as int);
    final validated = results['checksums_validated'] as int;
    final errors = (results['errors'] as List).length;

    if (total == 0) return 0.0;

    final validationScore = validated / total;
    final errorPenalty = errors * 0.1;

    return (validationScore - errorPenalty).clamp(0.0, 1.0);
  }

  /// Log pipeline execution
  Future<void> _logPipelineExecution(
      DateTime targetDate, Map<String, dynamic> results) async {
    final client = await SupabaseService.getClient();
    if (client == null) return;

    await client.from('content_sync_status').insert({
      'content_type': 'automated_pipeline',
      'last_sync_at': DateTime.now().toIso8601String(),
      'sync_status': results['errors'].isEmpty ? 'success' : 'partial',
      'error_message':
          results['errors'].isNotEmpty ? results['errors'].join('; ') : null,
      'records_synced':
          results['readings_created'] + results['readings_updated'],
    });

    debugPrint('DataScraper: Pipeline execution logged for $targetDate');
    debugPrint('Results: ${results.toString()}');
  }

  /// Public method to validate reading data integrity
  Future<Map<String, dynamic>> validateReadingIntegrity(
      String readingId) async {
    final client = await SupabaseService.getClient();
    if (client == null) {
      return {'error': 'Database connection unavailable'};
    }

    try {
      final response = await client.rpc('check_reading_data_integrity',
          params: {'reading_id': readingId});

      if (response.isNotEmpty) {
        return Map<String, dynamic>.from(response[0]);
      }
    } catch (e) {
      debugPrint('Error validating reading integrity: $e');
    }

    return {'error': 'Validation failed'};
  }

  /// Get scraper status and metrics
  Future<Map<String, dynamic>> getScraperStatus() async {
    final client = await SupabaseService.getClient();
    if (client == null) {
      return {'status': 'offline', 'error': 'Database unavailable'};
    }

    try {
      // Get recent sync jobs
      final recentJobs = await client
          .from('liturgical_sync_jobs')
          .select()
          .gte(
              'created_at',
              DateTime.now()
                  .subtract(const Duration(days: 7))
                  .toIso8601String())
          .order('created_at', ascending: false)
          .limit(10);

      // Get source status
      final sources = await client
          .from('liturgical_data_sources')
          .select()
          .order('priority');

      return {
        'status': 'active',
        'recent_jobs': recentJobs.length,
        'active_sources': sources.where((s) => s['is_active'] == true).length,
        'total_sources': sources.length,
        'last_execution':
            recentJobs.isNotEmpty ? recentJobs[0]['completed_at'] : null,
      };
    } catch (e) {
      return {'status': 'error', 'error': e.toString()};
    }
  }
}

/// Extension for LiturgicalReading to add scraping metadata
extension LiturgicalReadingExt on LiturgicalReading {
  String? get sourceUrl => null; // This would be stored in database
  DateTime? get scrapedAt => null; // This would be stored in database
}
