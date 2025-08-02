import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';

import './supabase_service.dart';
import '../models/liturgical_reading.dart';

/// Service for managing data integrity, checksum validation, and quality assurance
/// of liturgical readings from multiple sources
class LiturgicalDataIntegrityService {
  static final LiturgicalDataIntegrityService _instance =
      LiturgicalDataIntegrityService._internal();
  factory LiturgicalDataIntegrityService() => _instance;
  LiturgicalDataIntegrityService._internal();

  /// Validate a single reading's data integrity
  Future<Map<String, dynamic>> validateReading(String readingId) async {
    try {
      final client = await SupabaseService.getClient();
      if (client == null) {
        return _createErrorResult('Database connection unavailable');
      }

      final response = await client.rpc('check_reading_data_integrity',
          params: {'reading_id': readingId});

      if (response.isNotEmpty) {
        final result = Map<String, dynamic>.from(response[0]);

        // Add additional validation checks
        final reading = await _getReadingById(readingId);
        if (reading != null) {
          result['content_quality_score'] =
              _calculateContentQualityScore(reading);
          result['citation_format_valid'] =
              _validateCitationFormat(reading.citation);
          result['content_language_score'] =
              _analyzeContentLanguage(reading.content);
        }

        return result;
      }

      return _createErrorResult('No validation results found');
    } catch (e) {
      debugPrint('DataIntegrity: Error validating reading: $e');
      return _createErrorResult('Validation failed: $e');
    }
  }

  /// Validate all readings for a specific date
  Future<Map<String, dynamic>> validateDailyReadings(DateTime date) async {
    try {
      final client = await SupabaseService.getClient();
      if (client == null) {
        return _createErrorResult('Database connection unavailable');
      }

      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      final readings = await client
          .from('liturgical_readings')
          .select('*, liturgical_days!inner(*)')
          .eq('liturgical_days.date', dateStr);

      if (readings.isEmpty) {
        return {
          'date': dateStr,
          'total_readings': 0,
          'validation_score': 0.0,
          'issues': ['No readings found for this date'],
          'recommendations': ['Schedule data scraping for this date'],
        };
      }

      final validationResults = <Map<String, dynamic>>[];
      final issues = <String>[];
      final recommendations = <String>[];

      for (final reading in readings) {
        final readingValidation = await validateReading(reading['id']);
        validationResults.add(readingValidation);

        if (readingValidation['is_valid'] == false) {
          issues.addAll(List<String>.from(readingValidation['issues'] ?? []));
        }
      }

      // Calculate overall validation score
      final validCount =
          validationResults.where((r) => r['is_valid'] == true).length;
      final validationScore =
          readings.isNotEmpty ? (validCount / readings.length) : 0.0;

      // Check for missing reading types
      final expectedTypes = {'first_reading', 'responsorial_psalm', 'gospel'};
      final foundTypes =
          readings.map((r) => r['reading_type'] as String).toSet();
      final missingTypes = expectedTypes.difference(foundTypes);

      if (missingTypes.isNotEmpty) {
        issues.add('Missing reading types: ${missingTypes.join(', ')}');
        recommendations
            .add('Scrape missing reading types from additional sources');
      }

      // Check for duplicate readings
      final duplicates = _findDuplicateReadings(readings);
      if (duplicates.isNotEmpty) {
        issues.add('Found ${duplicates.length} duplicate readings');
        recommendations.add('Remove or merge duplicate readings');
      }

      return {
        'date': dateStr,
        'total_readings': readings.length,
        'valid_readings': validCount,
        'validation_score': validationScore,
        'issues': issues,
        'recommendations': recommendations,
        'reading_validations': validationResults,
        'has_complete_set': missingTypes.isEmpty,
        'integrity_status': _determineIntegrityStatus(validationScore, issues),
      };
    } catch (e) {
      debugPrint('DataIntegrity: Error validating daily readings: $e');
      return _createErrorResult('Daily validation failed: $e');
    }
  }

  /// Perform comprehensive integrity audit for date range
  Future<Map<String, dynamic>> performIntegrityAudit({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final start = startDate ?? DateTime.now().subtract(const Duration(days: 7));
    final end = endDate ?? DateTime.now().add(const Duration(days: 1));

    try {
      final client = await SupabaseService.getClient();
      if (client == null) {
        return _createErrorResult('Database connection unavailable');
      }

      final auditResults = <String, dynamic>{
        'audit_period': {
          'start_date': start.toIso8601String(),
          'end_date': end.toIso8601String(),
          'total_days': end.difference(start).inDays + 1,
        },
        'daily_results': <Map<String, dynamic>>[],
        'overall_metrics': <String, dynamic>{},
        'critical_issues': <String>[],
        'recommendations': <String>[],
      };

      final dailyValidations = <Map<String, dynamic>>[];
      DateTime currentDate = start;

      while (currentDate.isBefore(end.add(const Duration(days: 1)))) {
        final dailyResult = await validateDailyReadings(currentDate);
        dailyValidations.add(dailyResult);
        currentDate = currentDate.add(const Duration(days: 1));
      }

      auditResults['daily_results'] = dailyValidations;

      // Calculate overall metrics
      final totalReadings = dailyValidations.fold<int>(
          0, (sum, day) => sum + (day['total_readings'] as int));

      final validReadings = dailyValidations.fold<int>(
          0, (sum, day) => sum + (day['valid_readings'] as int));

      final overallScore =
          totalReadings > 0 ? (validReadings / totalReadings) : 0.0;

      final daysWithCompleteSet = dailyValidations
          .where((day) => day['has_complete_set'] == true)
          .length;

      auditResults['overall_metrics'] = {
        'total_readings': totalReadings,
        'valid_readings': validReadings,
        'overall_validation_score': overallScore,
        'days_with_complete_readings': daysWithCompleteSet,
        'completion_rate': dailyValidations.length > 0
            ? (daysWithCompleteSet / dailyValidations.length)
            : 0.0,
      };

      // Identify critical issues
      final criticalIssues = <String>[];
      final recommendations = <String>[];

      if (overallScore < 0.8) {
        criticalIssues.add('Overall validation score below 80%');
        recommendations.add('Review and improve data scraping sources');
      }

      final daysWithIssues = dailyValidations
          .where((day) => (day['issues'] as List).isNotEmpty)
          .length;

      if (daysWithIssues > dailyValidations.length * 0.3) {
        criticalIssues.add('More than 30% of days have data issues');
        recommendations.add('Implement additional data source validation');
      }

      auditResults['critical_issues'] = criticalIssues;
      auditResults['recommendations'] = recommendations;

      // Store audit results for tracking
      await _storeAuditResults(auditResults);

      return auditResults;
    } catch (e) {
      debugPrint('DataIntegrity: Error performing integrity audit: $e');
      return _createErrorResult('Integrity audit failed: $e');
    }
  }

  /// Calculate checksum for reading content
  String calculateContentChecksum(
      String content, String citation, String readingType) {
    final combined = '$content|$citation|$readingType';
    final bytes = utf8.encode(combined);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Detect potential duplicate readings
  Future<List<Map<String, dynamic>>> detectDuplicateReadings({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final client = await SupabaseService.getClient();
      if (client == null) return [];

      final start =
          startDate ?? DateTime.now().subtract(const Duration(days: 30));
      final end = endDate ?? DateTime.now();

      final startStr =
          '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
      final endStr =
          '${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}';

      final readings = await client
          .from('liturgical_readings')
          .select('*, liturgical_days!inner(date)')
          .gte('liturgical_days.date', startStr)
          .lte('liturgical_days.date', endStr);

      return _findDuplicateReadings(readings);
    } catch (e) {
      debugPrint('DataIntegrity: Error detecting duplicates: $e');
      return [];
    }
  }

  /// Fix data integrity issues automatically where possible
  Future<Map<String, dynamic>> autoFixIntegrityIssues(String readingId) async {
    try {
      final client = await SupabaseService.getClient();
      if (client == null) {
        return _createErrorResult('Database connection unavailable');
      }

      final reading = await _getReadingById(readingId);
      if (reading == null) {
        return _createErrorResult('Reading not found');
      }

      final fixes = <String>[];
      final warnings = <String>[];

      // Fix 1: Recalculate and update checksum
      final newChecksum = calculateContentChecksum(
          reading.content, reading.citation, reading.readingType.name);

      await client
          .from('liturgical_readings')
          .update({'data_hash': newChecksum}).eq('id', readingId);

      fixes.add('Recalculated and updated data checksum');

      // Fix 2: Clean up content formatting
      final cleanedContent = _cleanupReadingContent(reading.content);
      if (cleanedContent != reading.content) {
        await client.from('liturgical_readings').update({
          'content': cleanedContent,
          'data_hash': calculateContentChecksum(
              cleanedContent, reading.citation, reading.readingType.name)
        }).eq('id', readingId);

        fixes.add('Cleaned up content formatting');
      }

      // Fix 3: Validate and fix citation format
      final fixedCitation = _fixCitationFormat(reading.citation);
      if (fixedCitation != reading.citation) {
        await client
            .from('liturgical_readings')
            .update({'citation': fixedCitation}).eq('id', readingId);

        fixes.add('Fixed citation format');
      }

      // Update validation status
      await client.from('liturgical_readings').update({
        'validation_status': 'corrected',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', readingId);

      return {
        'reading_id': readingId,
        'fixes_applied': fixes,
        'warnings': warnings,
        'success': true,
      };
    } catch (e) {
      debugPrint('DataIntegrity: Error auto-fixing issues: $e');
      return _createErrorResult('Auto-fix failed: $e');
    }
  }

  /// Get reading by ID
  Future<LiturgicalReading?> _getReadingById(String readingId) async {
    try {
      final client = await SupabaseService.getClient();
      if (client == null) return null;

      final response = await client
          .from('liturgical_readings')
          .select()
          .eq('id', readingId)
          .single();

      return LiturgicalReading.fromJson(response);
    } catch (e) {
      debugPrint('DataIntegrity: Error getting reading by ID: $e');
      return null;
    }
  }

  /// Calculate content quality score based on various factors
  double _calculateContentQualityScore(LiturgicalReading reading) {
    double score = 1.0;

    // Length check
    if (reading.content.length < 50) score -= 0.3;
    if (reading.content.length > 10000) score -= 0.1;

    // Citation quality
    if (reading.citation.isEmpty) score -= 0.2;
    if (!_validateCitationFormat(reading.citation)) score -= 0.1;

    // Content quality indicators
    if (reading.content.contains('Error') || reading.content.contains('404')) {
      score -= 0.5;
    }

    // Check for common formatting issues
    if (reading.content.contains('  ')) score -= 0.05; // Double spaces
    if (reading.content.startsWith(' ') || reading.content.endsWith(' ')) {
      score -= 0.05; // Leading/trailing spaces
    }

    return score.clamp(0.0, 1.0);
  }

  /// Validate citation format
  bool _validateCitationFormat(String citation) {
    if (citation.isEmpty) return false;

    // Basic pattern matching for biblical citations
    final patterns = [
      RegExp(r'^[A-Za-z\s]+\d+:\d+'), // Book Chapter:Verse
      RegExp(r'^[A-Za-z\s]+\d+:\d+-\d+'), // Book Chapter:Verse-Verse
      RegExp(r'^[A-Za-z\s]+\d+'), // Book Chapter (for Psalms)
    ];

    return patterns.any((pattern) => pattern.hasMatch(citation));
  }

  /// Analyze content language quality
  double _analyzeContentLanguage(String content) {
    // Simple language quality scoring
    double score = 1.0;

    // Check for common issues
    final issues = [
      content.contains('???'), // Encoding issues
      content.contains('&amp;'), // HTML entities not decoded
      content.contains('<'), // HTML tags
      content.toLowerCase().contains('lorem ipsum'), // Placeholder text
    ];

    final issueCount = issues.where((issue) => issue).length;
    score -= (issueCount * 0.2);

    return score.clamp(0.0, 1.0);
  }

  /// Find duplicate readings
  List<Map<String, dynamic>> _findDuplicateReadings(List<dynamic> readings) {
    final duplicates = <Map<String, dynamic>>[];
    final seen = <String, dynamic>{};

    for (final reading in readings) {
      final key = '${reading['citation']}_${reading['reading_type']}';

      if (seen.containsKey(key)) {
        duplicates.add({
          'original_id': seen[key]['id'],
          'duplicate_id': reading['id'],
          'citation': reading['citation'],
          'reading_type': reading['reading_type'],
          'content_similarity': _calculateContentSimilarity(
              seen[key]['content'], reading['content']),
        });
      } else {
        seen[key] = reading;
      }
    }

    return duplicates;
  }

  /// Calculate content similarity between two strings
  double _calculateContentSimilarity(String content1, String content2) {
    if (content1 == content2) return 1.0;
    if (content1.isEmpty || content2.isEmpty) return 0.0;

    // Simple similarity based on common words
    final words1 = content1.toLowerCase().split(RegExp(r'\s+'));
    final words2 = content2.toLowerCase().split(RegExp(r'\s+'));

    final commonWords = words1.where((word) => words2.contains(word)).length;
    final totalWords = (words1.length + words2.length) / 2;

    return totalWords > 0 ? (commonWords / totalWords) : 0.0;
  }

  /// Cleanup reading content
  String _cleanupReadingContent(String content) {
    return content
        .replaceAll(RegExp(r'\s+'), ' ') // Multiple spaces to single
        .replaceAll(RegExp(r'^\s+|\s+$'), '') // Trim leading/trailing spaces
        .replaceAll('&amp;', '&') // Fix HTML entities
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"');
  }

  /// Fix citation format
  String _fixCitationFormat(String citation) {
    return citation
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ') // Multiple spaces to single
        .replaceAll(':', ':') // Normalize colons
        .replaceAll('–', '-') // Normalize dashes
        .replaceAll('—', '-');
  }

  /// Determine integrity status
  String _determineIntegrityStatus(double score, List<String> issues) {
    if (score >= 0.95 && issues.isEmpty) return 'excellent';
    if (score >= 0.85 && issues.length <= 1) return 'good';
    if (score >= 0.7) return 'fair';
    return 'poor';
  }

  /// Store audit results for tracking
  Future<void> _storeAuditResults(Map<String, dynamic> auditResults) async {
    try {
      final client = await SupabaseService.getClient();
      if (client == null) return;

      await client.from('content_sync_status').insert({
        'content_type': 'integrity_audit',
        'last_sync_at': DateTime.now().toIso8601String(),
        'sync_status':
            auditResults['overall_metrics']['overall_validation_score'] >= 0.8
                ? 'success'
                : 'needs_attention',
        'error_message': auditResults['critical_issues'].isNotEmpty
            ? auditResults['critical_issues'].join('; ')
            : null,
        'records_synced': auditResults['overall_metrics']['total_readings'],
      });
    } catch (e) {
      debugPrint('DataIntegrity: Error storing audit results: $e');
    }
  }

  /// Create error result
  Map<String, dynamic> _createErrorResult(String error) {
    return {
      'error': error,
      'is_valid': false,
      'validation_score': 0.0,
      'issues': [error],
    };
  }

  /// Get integrity service status
  Map<String, dynamic> getServiceStatus() {
    return {
      'service': 'LiturgicalDataIntegrityService',
      'status': 'active',
      'features': [
        'Checksum validation',
        'Content quality scoring',
        'Duplicate detection',
        'Auto-fix capabilities',
        'Comprehensive auditing'
      ],
      'supported_validations': [
        'Data integrity',
        'Citation format',
        'Content quality',
        'Language analysis',
        'Duplicate detection'
      ],
    };
  }
}
