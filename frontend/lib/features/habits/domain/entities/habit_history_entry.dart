import 'habit_status.dart';

class HabitHistoryEntry {
  const HabitHistoryEntry({
    required this.habitId,
    required this.title,
    required this.date,
    required this.status,
    this.completedAt,
    this.durationMinutes,
  });

  factory HabitHistoryEntry.fromJson(Map<String, dynamic> json) {
    final statusValue = (json['status'] as String? ?? '').toLowerCase();
    return HabitHistoryEntry(
      habitId: json['habit_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      status: HabitStatusApi.fromApi(statusValue),
      completedAt: DateTime.tryParse(json['completed_at'] as String? ?? ''),
      durationMinutes: (json['duration_minutes'] as num?)?.toInt(),
    );
  }

  final String habitId;
  final String title;
  final DateTime date;
  final HabitStatus status;
  final DateTime? completedAt;
  final int? durationMinutes;
}
