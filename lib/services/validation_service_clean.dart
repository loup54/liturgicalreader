import 'package:flutter/foundation.dart';
import './supabase_service.dart';

/// Clean, simplified validation service with corrected Supabase query patterns
/// Replaces the problematic validation_cross_reference_service.dart
class ValidationService {
  static final ValidationService _instance = ValidationService._internal();
  factory ValidationService() => _instance;
  ValidationService._internal();

  /// Get reading reports using safe query pattern
  Future<List<Map<String, dynamic>>> getReadingReports(String readingId) async {
    try {
      final client = await SupabaseService.getClient();
      if (client == null) return [];

      // Use simple select with eq filter - no complex joins
      final response = await client
          .from('user_content_reports')
          .select('id, report_category, report_description, status, created_at')
          .eq('reading_id', readingId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('ValidationService: Error getting reading reports: $e');
      return [];
    }
  }

  /// Get validation results using safe query pattern
  Future<List<Map<String, dynamic>>> getValidationResults(
      String readingId) async {
    try {
      final client = await SupabaseService.getClient();
      if (client == null) return [];

      // Simple query pattern - no complex chaining
      final response = await client
          .from('reading_source_validations')
          .select(
              'id, source_name, content_similarity_score, overall_confidence_score, validation_date')
          .eq('reading_id', readingId)
          .order('validation_date', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('ValidationService: Error getting validation results: $e');
      return [];
    }
  }

  /// Get quality score using safe query pattern
  Future<Map<String, dynamic>?> getQualityScore(String readingId) async {
    try {
      final client = await SupabaseService.getClient();
      if (client == null) return null;

      // Simple single row query
      final response = await client
          .from('reading_quality_scores')
          .select(
              'id, overall_quality_score, content_quality_score, citation_accuracy_score')
          .eq('reading_id', readingId)
          .maybeSingle();

      return response;
    } catch (e) {
      debugPrint('ValidationService: Error getting quality score: $e');
      return null;
    }
  }

  /// Submit user report using safe insert pattern
  Future<bool> submitUserReport({
    required String readingId,
    required String reportCategory,
    required String description,
    String? userId,
  }) async {
    try {
      final client = await SupabaseService.getClient();
      if (client == null) return false;

      // Simple insert without complex validation
      await client.from('user_content_reports').insert({
        'reading_id': readingId,
        'reporter_id': userId,
        'report_category': reportCategory,
        'report_description': description,
        'status': 'pending',
      });

      return true;
    } catch (e) {
      debugPrint('ValidationService: Error submitting report: $e');
      return false;
    }
  }

  /// Get flagged content using safe query pattern
  Future<List<Map<String, dynamic>>> getFlaggedContent({int? limit}) async {
    try {
      final client = await SupabaseService.getClient();
      if (client == null) return [];

      // Build query step by step
      var query = client
          .from('admin_review_queue')
          .select(
              'id, content_id, content_type, priority_level, review_reason, status')
          .eq('status', 'flagged')
          .order('priority_level', ascending: false);

      // Apply limit if provided
      if (limit != null) {
        query = query.limit(limit);
      }

      final response = await query;
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('ValidationService: Error getting flagged content: $e');
      return [];
    }
  }

  /// Get validation summary for readings
  Future<List<Map<String, dynamic>>> getValidationSummary({int? limit}) async {
    try {
      final client = await SupabaseService.getClient();
      if (client == null) return [];

      // Use the simplified view created in migration
      var query = client
          .from('reading_validation_summary')
          .select('*')
          .order('created_at', ascending: false);

      if (limit != null) {
        query = query.limit(limit);
      }

      final response = await query;
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('ValidationService: Error getting validation summary: $e');
      return [];
    }
  }

  /// Update report status using safe update pattern
  Future<bool> updateReportStatus(String reportId, String newStatus) async {
    try {
      final client = await SupabaseService.getClient();
      if (client == null) return false;

      await client.from('user_content_reports').update({
        'status': newStatus,
        'resolved_at': DateTime.now().toIso8601String(),
      }).eq('id', reportId);

      return true;
    } catch (e) {
      debugPrint('ValidationService: Error updating report status: $e');
      return false;
    }
  }

  /// Get service statistics using safe aggregation
  Future<Map<String, dynamic>> getServiceStats() async {
    try {
      final client = await SupabaseService.getClient();
      if (client == null) {
        return _createEmptyStats();
      }

      // Get counts using simple queries
      final reportsResponse = await client
          .from('user_content_reports')
          .select('id')
          .gte(
              'created_at',
              DateTime.now()
                  .subtract(const Duration(days: 30))
                  .toIso8601String());

      final pendingResponse = await client
          .from('user_content_reports')
          .select('id')
          .eq('status', 'pending');

      final flaggedResponse = await client
          .from('admin_review_queue')
          .select('id')
          .eq('status', 'flagged');

      return {
        'total_reports': reportsResponse.length,
        'pending_reports': pendingResponse.length,
        'flagged_items': flaggedResponse.length,
        'last_updated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      debugPrint('ValidationService: Error getting stats: $e');
      return _createEmptyStats();
    }
  }

  /// Create empty stats structure
  Map<String, dynamic> _createEmptyStats() {
    return {
      'total_reports': 0,
      'pending_reports': 0,
      'flagged_items': 0,
      'last_updated': DateTime.now().toIso8601String(),
    };
  }

  /// Check if reading has reports
  Future<bool> hasReports(String readingId) async {
    try {
      final client = await SupabaseService.getClient();
      if (client == null) return false;

      final response = await client
          .from('user_content_reports')
          .select('id')
          .eq('reading_id', readingId)
          .limit(1);

      return response.isNotEmpty;
    } catch (e) {
      debugPrint('ValidationService: Error checking reports: $e');
      return false;
    }
  }

  /// Get service status
  Map<String, dynamic> getServiceStatus() {
    return {
      'service': 'ValidationService',
      'version': 'clean_rebuild',
      'status': 'active',
      'features': [
        'Safe query patterns',
        'Error-resistant operations',
        'Simplified data access',
        'Admin review support',
      ],
    };
  }
}
