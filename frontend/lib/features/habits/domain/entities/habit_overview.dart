class HabitOverview {
  const HabitOverview({
    required this.focusMinutes,
    required this.completedStreak,
    required this.totalHabits,
    required this.completionRate,
    required this.activeDays,
  });

  factory HabitOverview.fromJson(Map<String, dynamic> json) {
    return HabitOverview(
      focusMinutes: json['focus_minutes'] as int? ?? 0,
      completedStreak: json['completed_streak'] as int? ?? 0,
      totalHabits: json['total_habits'] as int? ?? 0,
      completionRate: (json['completion_rate'] as num?)?.toDouble() ?? 0.0,
      activeDays: json['active_days'] as int? ?? 0,
    );
  }

  final int focusMinutes;
  final int completedStreak;
  final int totalHabits;
  final double completionRate;
  final int activeDays;
}
