class ValidationReport {
  final String id;
  final String readingId;
  final String? reporterId;
  final ReportCategory category;
  final String description;
  final String? suggestedCorrection;
  final bool isVerified;
  final String? adminNotes;
  final ValidationStatus status;
  final String? resolvedByAdminId;
  final DateTime? resolvedAt;
  final DateTime createdAt;

  const ValidationReport({
    required this.id,
    required this.readingId,
    this.reporterId,
    required this.category,
    required this.description,
    this.suggestedCorrection,
    this.isVerified = false,
    this.adminNotes,
    this.status = ValidationStatus.pending,
    this.resolvedByAdminId,
    this.resolvedAt,
    required this.createdAt,
  });

  factory ValidationReport.fromJson(Map<String, dynamic> json) {
    return ValidationReport(
      id: json['id'] as String,
      readingId: json['reading_id'] as String,
      reporterId: json['reporter_id'] as String?,
      category: ReportCategory.values.firstWhere(
        (e) => e.name == json['report_category'],
        orElse: () => ReportCategory.other,
      ),
      description: json['report_description'] as String,
      suggestedCorrection: json['suggested_correction'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
      adminNotes: json['admin_notes'] as String?,
      status: ValidationStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ValidationStatus.pending,
      ),
      resolvedByAdminId: json['resolved_by_admin_id'] as String?,
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reading_id': readingId,
      'reporter_id': reporterId,
      'report_category': category.name,
      'report_description': description,
      'suggested_correction': suggestedCorrection,
      'is_verified': isVerified,
      'admin_notes': adminNotes,
      'status': status.name,
      'resolved_by_admin_id': resolvedByAdminId,
      'resolved_at': resolvedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  ValidationReport copyWith({
    String? id,
    String? readingId,
    String? reporterId,
    ReportCategory? category,
    String? description,
    String? suggestedCorrection,
    bool? isVerified,
    String? adminNotes,
    ValidationStatus? status,
    String? resolvedByAdminId,
    DateTime? resolvedAt,
    DateTime? createdAt,
  }) {
    return ValidationReport(
      id: id ?? this.id,
      readingId: readingId ?? this.readingId,
      reporterId: reporterId ?? this.reporterId,
      category: category ?? this.category,
      description: description ?? this.description,
      suggestedCorrection: suggestedCorrection ?? this.suggestedCorrection,
      isVerified: isVerified ?? this.isVerified,
      adminNotes: adminNotes ?? this.adminNotes,
      status: status ?? this.status,
      resolvedByAdminId: resolvedByAdminId ?? this.resolvedByAdminId,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get categoryDisplayName {
    switch (category) {
      case ReportCategory.contentError:
        return 'Content Error';
      case ReportCategory.citationError:
        return 'Citation Error';
      case ReportCategory.translationIssue:
        return 'Translation Issue';
      case ReportCategory.formattingIssue:
        return 'Formatting Issue';
      case ReportCategory.missingContent:
        return 'Missing Content';
      case ReportCategory.other:
        return 'Other';
    }
  }

  String get statusDisplayName {
    switch (status) {
      case ValidationStatus.pending:
        return 'Pending Review';
      case ValidationStatus.approved:
        return 'Approved';
      case ValidationStatus.flagged:
        return 'Flagged';
      case ValidationStatus.rejected:
        return 'Rejected';
      case ValidationStatus.underReview:
        return 'Under Review';
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ValidationReport &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'ValidationReport(id: $id, category: ${category.name}, status: ${status.name})';
  }
}

class QualityScore {
  final String id;
  final String readingId;
  final double overallQualityScore;
  final double contentQualityScore;
  final double citationAccuracyScore;
  final double sourceAgreementScore;
  final double languageQualityScore;
  final double userReportImpactScore;
  final Map<String, dynamic> validationDetails;
  final DateTime lastCalculatedAt;
  final DateTime createdAt;

  const QualityScore({
    required this.id,
    required this.readingId,
    required this.overallQualityScore,
    required this.contentQualityScore,
    required this.citationAccuracyScore,
    required this.sourceAgreementScore,
    required this.languageQualityScore,
    required this.userReportImpactScore,
    required this.validationDetails,
    required this.lastCalculatedAt,
    required this.createdAt,
  });

  factory QualityScore.fromJson(Map<String, dynamic> json) {
    return QualityScore(
      id: json['id'] as String,
      readingId: json['reading_id'] as String,
      overallQualityScore: (json['overall_quality_score'] as num).toDouble(),
      contentQualityScore: (json['content_quality_score'] as num).toDouble(),
      citationAccuracyScore:
          (json['citation_accuracy_score'] as num).toDouble(),
      sourceAgreementScore: (json['source_agreement_score'] as num).toDouble(),
      languageQualityScore: (json['language_quality_score'] as num).toDouble(),
      userReportImpactScore:
          (json['user_report_impact_score'] as num).toDouble(),
      validationDetails:
          Map<String, dynamic>.from(json['validation_details'] as Map? ?? {}),
      lastCalculatedAt: DateTime.parse(json['last_calculated_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  String get qualityGrade {
    if (overallQualityScore >= 0.95) return 'A+';
    if (overallQualityScore >= 0.90) return 'A';
    if (overallQualityScore >= 0.85) return 'B+';
    if (overallQualityScore >= 0.80) return 'B';
    if (overallQualityScore >= 0.75) return 'C+';
    if (overallQualityScore >= 0.70) return 'C';
    return 'Needs Review';
  }

  List<String> get validationIssues {
    final issues = <String>[];
    if (contentQualityScore < 0.70)
      issues.add('Content quality needs improvement');
    if (citationAccuracyScore < 0.80)
      issues.add('Citation format issues detected');
    if (sourceAgreementScore < 0.75)
      issues.add('Discrepancies with other sources');
    if (languageQualityScore < 0.80) issues.add('Language quality concerns');
    if (userReportImpactScore < 0.90)
      issues.add('User reports indicate issues');
    return issues;
  }
}

class AdminReviewItem {
  final String id;
  final String contentId;
  final String contentType;
  final int priorityLevel;
  final String reviewReason;
  final String? assignedAdminId;
  final ValidationStatus status;
  final String? reviewNotes;
  final String? resolutionAction;
  final DateTime createdAt;
  final DateTime? assignedAt;
  final DateTime? resolvedAt;

  const AdminReviewItem({
    required this.id,
    required this.contentId,
    required this.contentType,
    required this.priorityLevel,
    required this.reviewReason,
    this.assignedAdminId,
    this.status = ValidationStatus.pending,
    this.reviewNotes,
    this.resolutionAction,
    required this.createdAt,
    this.assignedAt,
    this.resolvedAt,
  });

  factory AdminReviewItem.fromJson(Map<String, dynamic> json) {
    return AdminReviewItem(
      id: json['id'] as String,
      contentId: json['content_id'] as String,
      contentType: json['content_type'] as String,
      priorityLevel: json['priority_level'] as int,
      reviewReason: json['review_reason'] as String,
      assignedAdminId: json['assigned_admin_id'] as String?,
      status: ValidationStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ValidationStatus.pending,
      ),
      reviewNotes: json['review_notes'] as String?,
      resolutionAction: json['resolution_action'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      assignedAt: json['assigned_at'] != null
          ? DateTime.parse(json['assigned_at'] as String)
          : null,
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'] as String)
          : null,
    );
  }

  String get priorityDisplayName {
    switch (priorityLevel) {
      case 1:
        return 'Low';
      case 2:
        return 'Medium';
      case 3:
        return 'High';
      case 4:
        return 'Urgent';
      default:
        return 'Unknown';
    }
  }

  bool get isOverdue {
    final daysSinceCreated = DateTime.now().difference(createdAt).inDays;
    switch (priorityLevel) {
      case 4: // Urgent
        return daysSinceCreated > 1;
      case 3: // High
        return daysSinceCreated > 3;
      case 2: // Medium
        return daysSinceCreated > 7;
      case 1: // Low
        return daysSinceCreated > 14;
      default:
        return false;
    }
  }
}

enum ReportCategory {
  contentError('content_error'),
  citationError('citation_error'),
  translationIssue('translation_issue'),
  formattingIssue('formatting_issue'),
  missingContent('missing_content'),
  other('other');

  const ReportCategory(this.value);
  final String value;

  String get name => value;
}

enum ValidationStatus {
  pending('pending'),
  approved('approved'),
  flagged('flagged'),
  rejected('rejected'),
  underReview('under_review');

  const ValidationStatus(this.value);
  final String value;

  String get name => value;
}

enum ValidationSource {
  usccb('usccb'),
  universalis('universalis'),
  vatican('vatican'),
  cna('cna'),
  internal('internal');

  const ValidationSource(this.value);
  final String value;

  String get name => value;
}
