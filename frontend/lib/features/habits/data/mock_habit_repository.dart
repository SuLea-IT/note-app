import 'dart:async';

import 'package:flutter/material.dart';

import '../domain/entities/habit_day.dart';
import '../domain/entities/habit_entry.dart';
import '../domain/entities/habit_history_entry.dart';
import '../domain/entities/habit_overview.dart';
import '../domain/entities/habit_status.dart';
import 'habit_repository.dart';

class MockHabitRepository implements HabitRepository {
  MockHabitRepository() : _feed = _initialFeed();

  HabitFeed _feed;

  @override
  Future<HabitFeed> fetchFeed() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return _feed;
  }

  @override
  Future<HabitEntry> updateEntry(HabitEntry entry) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final updatedEntries = _feed.entries
        .map((item) => item.id == entry.id ? entry : item)
        .toList(growable: false);
    final history = [
      HabitHistoryEntry(
        habitId: entry.id,
        title: entry.title,
        date: DateTime.now(),
        status: entry.status,
        completedAt: entry.status == HabitStatus.completed ? DateTime.now() : null,
        durationMinutes: entry.status == HabitStatus.completed ? 30 : null,
      ),
      ..._feed.history,
    ];
    _feed = _feed.copyWith(entries: updatedEntries, history: history.take(50).toList());
    return entry;
  }

  @override
  Future<void> addHabit(HabitEntry habit) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final newHabit = habit.copyWith(id: 'habit-new-${DateTime.now().millisecondsSinceEpoch}');
    final updatedEntries = [..._feed.entries, newHabit];
    _feed = _feed.copyWith(entries: updatedEntries);
  }

  static HabitFeed _initialFeed() {
    final today = DateTime.now();
    final days = List<HabitDay>.generate(7, (index) {
      final date = today.subtract(Duration(days: 6 - index));
      final total = 3;
      final completed = (index % (total + 1)).clamp(0, total);
      final isToday =
          date.year == today.year &&
          date.month == today.month &&
          date.day == today.day;
      final completionRate = total == 0 ? 0.0 : completed / total;
      return HabitDay(
        date: date,
        isToday: isToday,
        completedCount: completed,
        totalCount: total,
        completionRate: completionRate,
      );
    });

    final entries = <HabitEntry>[
      HabitEntry(
        id: 'habit-morning-writing',
        title: 'Morning writing',
        timeLabel: '07:30',
        description: 'Outline goals and capture new ideas.',
        status: HabitStatus.inProgress,
        accentColor: const Color(0xFF7C4DFF),
        reminderTime: const TimeOfDay(hour: 7, minute: 0),
        repeatRule: 'daily',
        streakDays: 2,
      ),
      HabitEntry(
        id: 'habit-lunch-reading',
        title: 'Lunch reading',
        timeLabel: '12:30',
        description: 'Read industry articles for 20 minutes.',
        status: HabitStatus.upcoming,
        accentColor: const Color(0xFFFFA726),
        reminderTime: const TimeOfDay(hour: 12, minute: 15),
        repeatRule: 'weekdays',
        streakDays: 0,
      ),
      HabitEntry(
        id: 'habit-evening-retro',
        title: 'Evening retro',
        timeLabel: '21:00',
        description: 'Reflect on achievements and next steps.',
        status: HabitStatus.completed,
        accentColor: const Color(0xFF4CAF50),
        reminderTime: const TimeOfDay(hour: 21, minute: 0),
        repeatRule: 'daily',
        streakDays: 4,
        completedToday: true,
        latestHistory: HabitHistoryEntry(
          habitId: 'habit-evening-retro',
          title: 'Evening retro',
          date: today,
          status: HabitStatus.completed,
          completedAt: today,
          durationMinutes: 30,
        ),
      ),
    ];

    const overview = HabitOverview(
      focusMinutes: 120,
      completedStreak: 3,
      totalHabits: 3,
      completionRate: 0.68,
      activeDays: 5,
    );

    final history = <HabitHistoryEntry>[
      HabitHistoryEntry(
        habitId: 'habit-evening-retro',
        title: 'Evening retro',
        date: today,
        status: HabitStatus.completed,
        completedAt: today,
        durationMinutes: 30,
      ),
      HabitHistoryEntry(
        habitId: 'habit-morning-writing',
        title: 'Morning writing',
        date: today.subtract(const Duration(days: 1)),
        status: HabitStatus.completed,
        completedAt:
            today.subtract(const Duration(days: 1)).add(const Duration(hours: 7)),
        durationMinutes: 25,
      ),
    ];

    return HabitFeed(
      days: days,
      entries: entries,
      overview: overview,
      history: history,
    );
  }
}
