import 'package:flutter/foundation.dart';

import './supabase_service.dart';
import './auth_service.dart';
import '../models/validation_report.dart';

/// Service for handling user reports with corrected Supabase query patterns
class UserReportService {
  static final UserReportService _instance = UserReportService._internal();
  factory UserReportService() => _instance;
  UserReportService._internal();

  final AuthService _authService = AuthService();

  /// Submit a new content report using safe query pattern
  Future<ValidationReport?> submitReport({
    required String readingId,
    required ReportCategory category,
    required String description,
    String? suggestedCorrection,
  }) async {
    try {
      final client = await SupabaseService.getClient();
      if (client == null) {
        throw Exception('Database connection unavailable');
      }

      final currentUser = await _authService.currentUser;

      // Check for existing reports - simple query pattern
      final existingReports = await client
          .from('user_content_reports')
          .select('id')
          .eq('reading_id', readingId)
          .eq('reporter_id', currentUser?.id ?? '');

      if (existingReports.isNotEmpty) {
        throw Exception('You have already reported this reading.');
      }

      // Rate limiting check - simple date comparison
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      final todayReports = await client
          .from('user_content_reports')
          .select('id')
          .eq('reporter_id', currentUser?.id ?? '')
          .gte('created_at', startOfDay.toIso8601String());

      if (todayReports.length >= 10) {
        throw Exception(
            'Daily report limit reached. Please try again tomorrow.');
      }

      // Simple insert operation
      final response = await client
          .from('user_content_reports')
          .insert({
            'reading_id': readingId,
            'reporter_id': currentUser?.id,
            'report_category': category.name,
            'report_description': description,
            'suggested_correction': suggestedCorrection,
            'status': 'pending',
          })
          .select()
          .single();

      final report = ValidationReport.fromJson(response);

      // Update quality score in background - don't await
      _updateReadingQualityScore(readingId, category).catchError((e) {
        debugPrint('UserReportService: Quality score update failed: $e');
      });

      debugPrint(
          'UserReportService: Successfully submitted report ${report.id}');
      return report;
    } catch (e) {
      debugPrint('UserReportService: Error submitting report: $e');
      rethrow;
    }
  }

  /// Get user's reports using safe query pattern
  Future<List<ValidationReport>> getUserReports({
    ValidationStatus? status,
    int? limit,
  }) async {
    try {
      final client = await SupabaseService.getClient();
      if (client == null) return [];

      final currentUser = await _authService.currentUser;

      // Build query step by step
      var query = client
          .from('user_content_reports')
          .select('*')
          .eq('reporter_id', currentUser?.id ?? '');

      if (status != null) {
        query = query.eq('status', status.name);
      }

      // Apply ordering and limit - use final variable for chained operations
      final results = await query
          .order('created_at', ascending: false)
          .limit(limit ?? 1000);

      return results.map((json) => ValidationReport.fromJson(json)).toList();
    } catch (e) {
      debugPrint('UserReportService: Error getting user reports: $e');
      return [];
    }
  }

  /// Get pending reports for admin using safe query pattern
  Future<List<ValidationReport>> getPendingReports({
    ReportCategory? category,
    int? limit,
  }) async {
    try {
      final client = await SupabaseService.getClient();
      if (client == null) return [];

      // Check admin status first
      final currentUser = await _authService.currentUser;

      final userProfile = await client
          .from('user_profiles')
          .select('role')
          .eq('id', currentUser?.id ?? '')
          .maybeSingle();

      if (userProfile == null || userProfile['role'] != 'admin') {
        throw Exception('Admin access required');
      }

      // Build query for pending reports
      var query = client
          .from('user_content_reports')
          .select('*')
          .eq('status', 'pending')
          .order('created_at', ascending: true);

      if (limit != null) {
        query = query.limit(limit);
      }

      final results = await query;
      return results.map((json) => ValidationReport.fromJson(json)).toList();
    } catch (e) {
      debugPrint('UserReportService: Error getting pending reports: $e');
      return [];
    }
  }

  /// Update report status using safe update pattern
  Future<bool> updateReportStatus({
    required String reportId,
    required ValidationStatus status,
    String? adminNotes,
    String? resolutionAction,
  }) async {
    try {
      final client = await SupabaseService.getClient();
      if (client == null) return false;

      final currentUser = await _authService.currentUser;

      // Verify admin access
      final userProfile = await client
          .from('user_profiles')
          .select('role')
          .eq('id', currentUser?.id ?? '')
          .maybeSingle();

      if (userProfile == null || userProfile['role'] != 'admin') {
        throw Exception('Admin access required');
      }

      // Simple update operation
      final updateData = <String, dynamic>{
        'status': status.name,
        'resolved_by_admin_id': currentUser?.id,
        'resolved_at': DateTime.now().toIso8601String(),
      };

      if (adminNotes != null) {
        updateData['admin_notes'] = adminNotes;
      }

      await client
          .from('user_content_reports')
          .update(updateData)
          .eq('id', reportId);

      debugPrint('UserReportService: Successfully updated report status');
      return true;
    } catch (e) {
      debugPrint('UserReportService: Error updating report status: $e');
      return false;
    }
  }

  /// Get report statistics using safe aggregation
  Future<Map<String, dynamic>> getReportStatistics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final client = await SupabaseService.getClient();
      if (client == null) {
        return _createEmptyStats();
      }

      final start =
          startDate ?? DateTime.now().subtract(const Duration(days: 30));
      final end = endDate ?? DateTime.now();

      // Simple query with date filter
      final allReports = await client
          .from('user_content_reports')
          .select('status, report_category, created_at')
          .gte('created_at', start.toIso8601String())
          .lte('created_at', end.toIso8601String());

      // Calculate statistics in Dart (safer than complex SQL)
      final totalReports = allReports.length;
      final pendingReports =
          allReports.where((r) => r['status'] == 'pending').length;
      final resolvedReports =
          allReports.where((r) => r['status'] == 'approved').length;
      final rejectedReports =
          allReports.where((r) => r['status'] == 'rejected').length;

      // Category breakdown
      final categoryStats = <String, int>{};
      for (final category in ReportCategory.values) {
        categoryStats[category.name] = allReports
            .where((r) => r['report_category'] == category.name)
            .length;
      }

      return {
        'period': {
          'start_date': start.toIso8601String(),
          'end_date': end.toIso8601String(),
        },
        'totals': {
          'total_reports': totalReports,
          'pending_reports': pendingReports,
          'resolved_reports': resolvedReports,
          'rejected_reports': rejectedReports,
        },
        'rates': {
          'resolution_rate':
              totalReports > 0 ? (resolvedReports / totalReports) : 0.0,
          'rejection_rate':
              totalReports > 0 ? (rejectedReports / totalReports) : 0.0,
          'pending_rate':
              totalReports > 0 ? (pendingReports / totalReports) : 0.0,
        },
        'category_breakdown': categoryStats,
      };
    } catch (e) {
      debugPrint('UserReportService: Error getting report statistics: $e');
      return _createEmptyStats();
    }
  }

  /// Update reading quality score using safe operations
  Future<void> _updateReadingQualityScore(
      String readingId, ReportCategory category) async {
    try {
      final client = await SupabaseService.getClient();
      if (client == null) return;

      // Check if quality score exists
      final existingScore = await client
          .from('reading_quality_scores')
          .select('id, user_report_impact_score')
          .eq('reading_id', readingId)
          .maybeSingle();

      double impactReduction = _getImpactReduction(category);

      if (existingScore == null) {
        // Create new quality score record
        await client.from('reading_quality_scores').insert({
          'reading_id': readingId,
          'overall_quality_score': 0.8500,
          'content_quality_score': 0.8500,
          'citation_accuracy_score': 0.9000,
          'source_agreement_score': 0.8000,
          'language_quality_score': 0.9000,
          'user_report_impact_score': 1.0 - impactReduction,
        });
      } else {
        // Update existing score
        final currentImpact =
            (existingScore['user_report_impact_score'] as num).toDouble();
        final newImpact = (currentImpact - impactReduction).clamp(0.0, 1.0);

        await client.from('reading_quality_scores').update({
          'user_report_impact_score': newImpact,
          'last_calculated_at': DateTime.now().toIso8601String(),
        }).eq('reading_id', readingId);
      }
    } catch (e) {
      debugPrint('UserReportService: Error updating quality score: $e');
    }
  }

  /// Get impact reduction based on report category
  double _getImpactReduction(ReportCategory category) {
    switch (category) {
      case ReportCategory.contentError:
        return 0.15;
      case ReportCategory.citationError:
        return 0.12;
      case ReportCategory.translationIssue:
        return 0.10;
      case ReportCategory.missingContent:
        return 0.20;
      case ReportCategory.formattingIssue:
        return 0.05;
      case ReportCategory.other:
        return 0.08;
    }
  }

  /// Create empty statistics structure
  Map<String, dynamic> _createEmptyStats() {
    return {
      'totals': {
        'total_reports': 0,
        'pending_reports': 0,
        'resolved_reports': 0,
        'rejected_reports': 0,
      },
      'rates': {
        'resolution_rate': 0.0,
        'rejection_rate': 0.0,
        'pending_rate': 0.0,
      },
      'category_breakdown': {
        for (var cat in ReportCategory.values) cat.name: 0
      },
    };
  }

  /// Check if user has reported reading
  Future<bool> hasUserReportedReading(String readingId) async {
    try {
      final client = await SupabaseService.getClient();
      if (client == null) return false;

      final currentUser = await _authService.currentUser;

      final existingReports = await client
          .from('user_content_reports')
          .select('id')
          .eq('reading_id', readingId)
          .eq('reporter_id', currentUser?.id ?? '')
          .limit(1);

      return existingReports.isNotEmpty;
    } catch (e) {
      debugPrint('UserReportService: Error checking user report status: $e');
      return false;
    }
  }

  /// Get service status
  Map<String, dynamic> getServiceStatus() {
    return {
      'service': 'UserReportService',
      'version': 'clean_rebuild',
      'status': 'active',
      'features': [
        'Safe query patterns',
        'User content reporting',
        'Rate limiting protection',
        'Admin review integration',
        'Statistical analytics',
      ],
      'supported_categories': ReportCategory.values.map((c) => c.name).toList(),
      'rate_limits': {
        'reports_per_day': 10,
        'duplicate_prevention': true,
      },
    };
  }
}