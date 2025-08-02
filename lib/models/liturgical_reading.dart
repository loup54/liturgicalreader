class LiturgicalReading {
  final String id;
  final String liturgicalDayId;
  final ReadingType readingType;
  final String citation;
  final String? biblicalBookId;
  final String? chapterVerse;
  final String content;
  final String? audioUrl;
  final int orderSequence;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Additional computed properties
  final String previewText;
  final bool isBookmarked;

  const LiturgicalReading({
    required this.id,
    required this.liturgicalDayId,
    required this.readingType,
    required this.citation,
    this.biblicalBookId,
    this.chapterVerse,
    required this.content,
    this.audioUrl,
    required this.orderSequence,
    required this.createdAt,
    required this.updatedAt,
    required this.previewText,
    this.isBookmarked = false,
  });

  factory LiturgicalReading.fromJson(Map<String, dynamic> json) {
    final content = json['content'] as String? ?? '';
    return LiturgicalReading(
      id: json['id'] as String,
      liturgicalDayId: json['liturgical_day_id'] as String,
      readingType: ReadingType.values.firstWhere(
        (e) => e.name == json['reading_type'],
        orElse: () => ReadingType.firstReading,
      ),
      citation: json['citation'] as String? ?? '',
      biblicalBookId: json['biblical_book_id'] as String?,
      chapterVerse: json['chapter_verse'] as String?,
      content: content,
      audioUrl: json['audio_url'] as String?,
      orderSequence: json['order_sequence'] as int? ?? 1,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      previewText: _generatePreviewText(content),
      isBookmarked: json['is_bookmarked'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'liturgical_day_id': liturgicalDayId,
      'reading_type': readingType.name,
      'citation': citation,
      'biblical_book_id': biblicalBookId,
      'chapter_verse': chapterVerse,
      'content': content,
      'audio_url': audioUrl,
      'order_sequence': orderSequence,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  static String _generatePreviewText(String content) {
    if (content.length <= 150) return content;
    return '${content.substring(0, 147)}...';
  }

  String get displayTitle {
    switch (readingType) {
      case ReadingType.firstReading:
        return 'First Reading';
      case ReadingType.responsorialPsalm:
        return 'Responsorial Psalm';
      case ReadingType.secondReading:
        return 'Second Reading';
      case ReadingType.gospel:
        return 'Gospel';
      case ReadingType.alleluia:
        return 'Alleluia';
      case ReadingType.communionAntiphon:
        return 'Communion Antiphon';
    }
  }

  LiturgicalReading copyWith({
    String? id,
    String? liturgicalDayId,
    ReadingType? readingType,
    String? citation,
    String? biblicalBookId,
    String? chapterVerse,
    String? content,
    String? audioUrl,
    int? orderSequence,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isBookmarked,
  }) {
    final newContent = content ?? this.content;
    return LiturgicalReading(
      id: id ?? this.id,
      liturgicalDayId: liturgicalDayId ?? this.liturgicalDayId,
      readingType: readingType ?? this.readingType,
      citation: citation ?? this.citation,
      biblicalBookId: biblicalBookId ?? this.biblicalBookId,
      chapterVerse: chapterVerse ?? this.chapterVerse,
      content: newContent,
      audioUrl: audioUrl ?? this.audioUrl,
      orderSequence: orderSequence ?? this.orderSequence,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      previewText: _generatePreviewText(newContent),
      isBookmarked: isBookmarked ?? this.isBookmarked,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LiturgicalReading &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'LiturgicalReading(id: $id, type: ${readingType.name}, citation: $citation)';
  }
}

enum ReadingType {
  firstReading('first_reading'),
  responsorialPsalm('responsorial_psalm'),
  secondReading('second_reading'),
  gospel('gospel'),
  alleluia('alleluia'),
  communionAntiphon('communion_antiphon');

  const ReadingType(this.value);
  final String value;

  String get name => value;
}
