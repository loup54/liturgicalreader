class LiturgicalDay {
  final String id;
  final DateTime date;
  final String liturgicalSeason;
  final String liturgicalRank;
  final String? feastName;
  final String? commemoration;
  final String liturgicalColor;
  final int weekOfSeason;
  final String dayOfWeek;
  final bool isSunday;
  final bool isHolyDay;
  final Map<String, dynamic> readings;
  final DateTime createdAt;
  final DateTime updatedAt;

  LiturgicalDay({
    required this.id,
    required this.date,
    required this.liturgicalSeason,
    required this.liturgicalRank,
    this.feastName,
    this.commemoration,
    required this.liturgicalColor,
    required this.weekOfSeason,
    required this.dayOfWeek,
    required this.isSunday,
    required this.isHolyDay,
    required this.readings,
    required this.createdAt,
    required this.updatedAt,
  });

  factory LiturgicalDay.fromJson(Map<String, dynamic> json) {
    return LiturgicalDay(
      id: json['id']?.toString() ?? '',
      date: json['date'] != null
          ? DateTime.parse(json['date'].toString())
          : DateTime.now(),
      liturgicalSeason:
          json['liturgical_season']?.toString() ?? 'Ordinary Time',
      liturgicalRank: json['liturgical_rank']?.toString() ?? 'weekday',
      feastName: json['feast_name']?.toString(),
      commemoration: json['commemoration']?.toString(),
      liturgicalColor: json['liturgical_color']?.toString() ?? 'green',
      weekOfSeason: json['week_of_season'] as int? ?? 1,
      dayOfWeek: json['day_of_week']?.toString() ?? 'Monday',
      isSunday: json['is_sunday'] as bool? ?? false,
      isHolyDay: json['is_holy_day'] as bool? ?? false,
      readings: json['readings'] as Map<String, dynamic>? ?? {},
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
      'date': date.toIso8601String(),
      'liturgical_season': liturgicalSeason,
      'liturgical_rank': liturgicalRank,
      'feast_name': feastName,
      'commemoration': commemoration,
      'liturgical_color': liturgicalColor,
      'week_of_season': weekOfSeason,
      'day_of_week': dayOfWeek,
      'is_sunday': isSunday,
      'is_holy_day': isHolyDay,
      'readings': readings,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Create a mock liturgical day for offline mode
  factory LiturgicalDay.mock({DateTime? date}) {
    final mockDate = date ?? DateTime.now();
    return LiturgicalDay(
      id: 'mock-${mockDate.millisecondsSinceEpoch}',
      date: mockDate,
      liturgicalSeason: 'Ordinary Time',
      liturgicalRank: 'weekday',
      feastName: null,
      commemoration: null,
      liturgicalColor: 'green',
      weekOfSeason: 1,
      dayOfWeek: _getDayOfWeek(mockDate.weekday),
      isSunday: mockDate.weekday == 7,
      isHolyDay: false,
      readings: {
        'first_reading': 'Sample First Reading',
        'psalm': 'Sample Psalm',
        'second_reading': 'Sample Second Reading',
        'gospel': 'Sample Gospel Reading',
      },
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
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

  // Check if this is a special liturgical day
  bool get isSpecialDay => isHolyDay || feastName != null;

  // Get display name for the day
  String get displayName {
    if (feastName != null) return feastName!;
    if (isSunday) return '$weekOfSeason Sunday in $liturgicalSeason';
    return '$dayOfWeek of the $weekOfSeason Week in $liturgicalSeason';
  }

  @override
  String toString() {
    return 'LiturgicalDay(id: $id, date: $date, season: $liturgicalSeason, rank: $liturgicalRank)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LiturgicalDay && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
