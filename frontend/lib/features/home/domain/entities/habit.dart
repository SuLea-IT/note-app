class DailyHabit {
  const DailyHabit({
    required this.id,
    required this.label,
    required this.timeRange,
    required this.notes,
    required this.isCompleted,
  });

  factory DailyHabit.fromJson(Map<String, dynamic> json) {
    return DailyHabit(
      id: json['id'] as String,
      label: json['label'] as String,
      timeRange: json['time_range'] as String,
      notes: json['notes'] as String,
      isCompleted: json['is_completed'] as bool,
    );
  }

  final String id;
  final String label;
  final String timeRange;
  final String notes;
  final bool isCompleted;
}
