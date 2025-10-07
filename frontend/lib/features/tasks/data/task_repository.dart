import '../../auth/domain/auth_session.dart';
import '../domain/entities/task.dart';

enum TaskListGrouping { byDate, byPriority, byStatus }

class TaskQuery {
  const TaskQuery({
    this.statuses,
    this.priorities,
    this.tags,
    this.dueFrom,
    this.dueTo,
    this.search,
    this.skip = 0,
    this.limit = 100,
  });

  final List<TaskStatus>? statuses;
  final List<TaskPriority>? priorities;
  final List<String>? tags;
  final DateTime? dueFrom;
  final DateTime? dueTo;
  final String? search;
  final int skip;
  final int limit;
}

abstract class TaskRepository {
  Future<TaskCollection> fetchTasks({TaskQuery? query});

  Future<Task> fetchTask(String id);

  Future<Task> createTask(TaskDraft draft);

  Future<Task> updateTask(String id, TaskDraft draft);

  Future<void> deleteTask(String id);

  Future<List<Task>> bulkComplete(List<String> taskIds, {bool completed = true});

  Future<TaskStatistics> fetchStatistics();
}

abstract class TaskSessionRepository extends TaskRepository {
  TaskSessionRepository(this.session);

  final AuthSession session;
}
