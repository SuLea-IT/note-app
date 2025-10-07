import 'package:flutter/material.dart';

import 'habit_history_entry.dart';
import 'habit_status.dart';

class HabitEntry {
  const HabitEntry({
    required this.id,
    required this.title,
    required this.timeLabel,
    required this.description,
    required this.status,
    required this.accentColor,
    this.reminderTime,
    this.repeatRule,
    this.streakDays = 0,
    this.completedToday = false,
    this.latestHistory,
  });

  factory HabitEntry.fromJson(Map<String, dynamic> json) {
    final statusValue = (json['status'] as String? ?? '').toLowerCase();
    final accentValue = (json['accent_color'] as num?)?.toInt() ?? 0xFF7C4DFF;
    final reminderRaw = json['reminder_time'] as String?;
    return HabitEntry(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      timeLabel: json['time_label'] as String? ?? '',
      description: json['description'] as String? ?? '',
      status: HabitStatusApi.fromApi(statusValue),
      accentColor: Color(accentValue),
      reminderTime: HabitStatusApi.parseTime(reminderRaw),
      repeatRule: json['repeat_rule'] as String?,
      streakDays: (json['streak_days'] as num?)?.toInt() ?? 0,
      completedToday: json['completed_today'] as bool? ?? false,
      latestHistory: json['latest_entry'] is Map<String, dynamic>
          ? HabitHistoryEntry.fromJson(
              json['latest_entry'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  HabitEntry copyWith({
    String? id,
    String? title,
    String? timeLabel,
    String? description,
    HabitStatus? status,
    TimeOfDay? reminderTime,
    String? repeatRule,
    Color? accentColor,
    int? streakDays,
    bool? completedToday,
    HabitHistoryEntry? latestHistory,
  }) {
    return HabitEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      timeLabel: timeLabel ?? this.timeLabel,
      description: description ?? this.description,
      status: status ?? this.status,
      reminderTime: reminderTime ?? this.reminderTime,
      repeatRule: repeatRule ?? this.repeatRule,
      accentColor: accentColor ?? this.accentColor,
      streakDays: streakDays ?? this.streakDays,
      completedToday: completedToday ?? this.completedToday,
      latestHistory: latestHistory ?? this.latestHistory,
    );
  }

  Map<String, dynamic> toApiPayload() {
    return {
      'title': title,
      'description': description,
      'time_label': timeLabel,
      'status': status.apiValue,
      if (repeatRule != null && repeatRule!.isNotEmpty) 'repeat_rule': repeatRule,
      'accent_color': accentColor.value,
      if (reminderTime != null) 'reminder_time': HabitStatusApi.formatTime(reminderTime!),
    };
  }

  bool get hasReminder => reminderTime != null;

  final String id;
  final String title;
  final String timeLabel;
  final String description;
  final HabitStatus status;
  final TimeOfDay? reminderTime;
  final String? repeatRule;
  final Color accentColor;
  final int streakDays;
  final bool completedToday;
  final HabitHistoryEntry? latestHistory;
}
