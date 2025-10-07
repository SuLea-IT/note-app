import 'package:flutter/material.dart';

enum HabitStatus { upcoming, inProgress, completed }

extension HabitStatusColor on HabitStatus {
  Color get color {
    switch (this) {
      case HabitStatus.upcoming:
        return const Color(0xFF7C4DFF);
      case HabitStatus.inProgress:
        return const Color(0xFFFFA726);
      case HabitStatus.completed:
        return const Color(0xFF4CAF50);
    }
  }
}

extension HabitStatusApi on HabitStatus {
  String get apiValue {
    switch (this) {
      case HabitStatus.upcoming:
        return 'upcoming';
      case HabitStatus.inProgress:
        return 'in_progress';
      case HabitStatus.completed:
        return 'completed';
    }
  }

  static HabitStatus fromApi(String raw) {
    switch (raw) {
      case 'completed':
        return HabitStatus.completed;
      case 'in_progress':
        return HabitStatus.inProgress;
      default:
        return HabitStatus.upcoming;
    }
  }

  static TimeOfDay? parseTime(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final parts = raw.split(':');
    if (parts.length < 2) {
      return null;
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return null;
    }
    return TimeOfDay(hour: hour, minute: minute);
  }

  static String formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute:00';
  }
}
