import '../domain/entities/habit_day.dart';
import '../domain/entities/habit_entry.dart';
import '../domain/entities/habit_history_entry.dart';
import '../domain/entities/habit_overview.dart';

class HabitFeed {
  const HabitFeed({
    required this.days,
    required this.entries,
    required this.overview,
    required this.history,
  });

  HabitFeed copyWith({
    List<HabitDay>? days,
    List<HabitEntry>? entries,
    HabitOverview? overview,
    List<HabitHistoryEntry>? history,
  }) {
    return HabitFeed(
      days: days ?? this.days,
      entries: entries ?? this.entries,
      overview: overview ?? this.overview,
      history: history ?? this.history,
    );
  }

  final List<HabitDay> days;
  final List<HabitEntry> entries;
  final HabitOverview overview;
  final List<HabitHistoryEntry> history;
}

abstract class HabitRepository {
  Future<HabitFeed> fetchFeed();
  Future<HabitEntry> updateEntry(HabitEntry entry);
  Future<void> addHabit(HabitEntry habit);
}
