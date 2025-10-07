import 'quick_action.dart';
import 'habit.dart';
import '../../../notes/domain/entities/note.dart';
import '../../../tasks/domain/entities/task.dart';

enum HomeDisplayMode { list, card }

class HomeFeed {
  const HomeFeed({
    required this.sections,
    required this.quickActions,
    required this.habits,
    required this.taskStats,
  });

  factory HomeFeed.fromJson(Map<String, dynamic> json) {
    final sections = (json['sections'] as List<dynamic>)
        .map((e) => NoteSection.fromJson(e as Map<String, dynamic>))
        .toList();
    final quickActions = (json['quick_actions'] as List<dynamic>)
        .map((e) => QuickActionCard.fromJson(e as Map<String, dynamic>))
        .toList();
    final habits = (json['habits'] as List<dynamic>)
        .map((e) => DailyHabit.fromJson(e as Map<String, dynamic>))
        .toList();

    final tasks = TaskStatistics.fromJson(json['tasks'] as Map<String, dynamic>);

    return HomeFeed(
      sections: sections,
      quickActions: quickActions,
      habits: habits,
      taskStats: tasks,
    );
  }

  final List<NoteSection> sections;
  final List<QuickActionCard> quickActions;
  final List<DailyHabit> habits;
  final TaskStatistics taskStats;
}
