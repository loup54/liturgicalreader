class UserBookmark {
  final String id;
  final String userId;
  final String readingId;
  final String
      readingType; // 'first_reading', 'psalm', 'second_reading', 'gospel'
  final DateTime date;
  final String? note;
  final bool isPrivate;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserBookmark({
    required this.id,
    required this.userId,
    required this.readingId,
    required this.readingType,
    required this.date,
    this.note,
    required this.isPrivate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserBookmark.fromJson(Map<String, dynamic> json) {
    return UserBookmark(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      readingId: json['reading_id']?.toString() ?? '',
      readingType: json['reading_type']?.toString() ?? 'gospel',
      date: json['date'] != null
          ? DateTime.parse(json['date'].toString())
          : DateTime.now(),
      note: json['note']?.toString(),
      isPrivate: json['is_private'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'].toString())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'reading_id': readingId,
      'reading_type': readingType,
      'date': date.toIso8601String(),
      'note': note,
      'is_private': isPrivate,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Create a copy with updated fields
  UserBookmark copyWith({
    String? id,
    String? userId,
    String? readingId,
    String? readingType,
    DateTime? date,
    String? note,
    bool? isPrivate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserBookmark(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      readingId: readingId ?? this.readingId,
      readingType: readingType ?? this.readingType,
      date: date ?? this.date,
      note: note ?? this.note,
      isPrivate: isPrivate ?? this.isPrivate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Create a mock bookmark for testing
  factory UserBookmark.mock({
    String? userId,
    String? readingId,
    DateTime? date,
  }) {
    final mockDate = date ?? DateTime.now();
    return UserBookmark(
      id: 'mock-${mockDate.millisecondsSinceEpoch}',
      userId: userId ?? 'mock-user',
      readingId: readingId ?? 'mock-reading',
      readingType: 'gospel',
      date: mockDate,
      note: 'Sample bookmark note',
      isPrivate: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  // Get reading type display name
  String get readingTypeDisplayName {
    switch (readingType.toLowerCase()) {
      case 'first_reading':
        return 'First Reading';
      case 'psalm':
        return 'Psalm';
      case 'second_reading':
        return 'Second Reading';
      case 'gospel':
        return 'Gospel';
      default:
        return readingType;
    }
  }

  // Check if bookmark has a note
  bool get hasNote => note != null && note!.isNotEmpty;

  // Get formatted date string
  String get formattedDate {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  String toString() {
    return 'UserBookmark(id: $id, userId: $userId, readingType: $readingType, date: $date)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserBookmark && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
