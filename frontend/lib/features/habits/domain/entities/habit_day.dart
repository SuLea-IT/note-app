class HabitDay {
  const HabitDay({
    required this.date,
    required this.isToday,
    required this.completedCount,
    required this.totalCount,
    this.completionRate,
  });

  factory HabitDay.fromJson(Map<String, dynamic> json) {
    final rawDate = json['date'];
    final date = rawDate is String
        ? DateTime.tryParse(rawDate) ?? DateTime.now()
        : DateTime.now();
    return HabitDay(
      date: date,
      isToday: json['is_today'] as bool? ?? false,
      completedCount: json['completed_count'] as int? ?? 0,
      totalCount: json['total_count'] as int? ?? 0,
      completionRate: (json['completion_rate'] as num?)?.toDouble(),
    );
  }

  final DateTime date;
  final bool isToday;
  final int completedCount;
  final int totalCount;
  final double? completionRate;
}
