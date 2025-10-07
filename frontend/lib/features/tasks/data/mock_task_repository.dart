import 'dart:math';

import '../domain/entities/task.dart';
import 'task_repository.dart';

class MockTaskRepository implements TaskRepository {
  MockTaskRepository()
    : _random = Random(20241006),
      _tasks = List<Task>.generate(12, (index) {
        final now = DateTime.now();
        final due = now.add(Duration(days: index - 4));
        final priority = TaskPriority.values[index % TaskPriority.values.length];
        final status = index % 5 == 0
            ? TaskStatus.completed
            : (index % 4 == 0 ? TaskStatus.inProgress : TaskStatus.pending);
        return Task(
          id: 'task-$index',
          userId: 'mock-user',
          title: '演示任务 #$index',
          description: '这是一个示例任务，用于展示待办列表效果。',
          dueAt: due,
          allDay: index.isEven,
          priority: priority,
          status: status,
          tags: ['示例', if (priority == TaskPriority.urgent) '关注'],
          reminders: [],
          createdAt: now.subtract(Duration(hours: index * 3)),
          completedAt:
              status == TaskStatus.completed ? now.subtract(const Duration(days: 1)) : null,
          updatedAt: now,
        );
      });

  final Random _random;
  final List<Task> _tasks;

  @override
  Future<List<Task>> bulkComplete(List<String> taskIds, {bool completed = true}) async {
    final updated = <Task>[];
    for (var i = 0; i < _tasks.length; i++) {
      final task = _tasks[i];
      if (taskIds.contains(task.id)) {
        final newStatus = completed ? TaskStatus.completed : TaskStatus.pending;
        final updatedTask = task.copyWith(
          status: newStatus,
          completedAt: completed ? DateTime.now() : null,
        );
        _tasks[i] = updatedTask;
        updated.add(updatedTask);
      }
    }
    return Future.delayed(const Duration(milliseconds: 120), () => updated);
  }

  @override
  Future<Task> createTask(TaskDraft draft) async {
    final id = 'task-${_random.nextInt(99999)}';
    final task = Task(
      id: id,
      userId: draft.userId ?? 'mock-user',
      title: draft.title,
      description: draft.description,
      dueAt: draft.dueAt,
      allDay: draft.allDay,
      priority: draft.priority,
      status: draft.status,
      tags: List.of(draft.tags),
      reminders: draft.reminders
          .map(
            (item) => TaskReminder(
              id: _random.nextInt(99999),
              remindAt: item.remindAt,
              timezone: item.timezone,
              channel: item.channel,
              repeatRule: item.repeatRule,
              repeatEvery: item.repeatEvery,
              active: item.active,
              expiresAt: item.expiresAt,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              lastTriggeredAt: null,
            ),
          )
          .toList(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _tasks.add(task);
    return Future.delayed(const Duration(milliseconds: 120), () => task);
  }

  @override
  Future<void> deleteTask(String id) async {
    _tasks.removeWhere((task) => task.id == id);
    await Future<void>.delayed(const Duration(milliseconds: 80));
  }

  @override
  Future<Task> fetchTask(String id) async {
    final task = _tasks.firstWhere((task) => task.id == id);
    return Future.delayed(const Duration(milliseconds: 80), () => task);
  }

  @override
  Future<TaskCollection> fetchTasks({TaskQuery? query}) async {
    Iterable<Task> result = _tasks;
    if (query != null) {
      if (query.statuses != null && query.statuses!.isNotEmpty) {
        result = result.where((task) => query.statuses!.contains(task.status));
      }
      if (query.priorities != null && query.priorities!.isNotEmpty) {
        result = result.where((task) => query.priorities!.contains(task.priority));
      }
      if (query.tags != null && query.tags!.isNotEmpty) {
        result = result.where(
          (task) => task.tags.any((tag) => query.tags!.contains(tag)),
        );
      }
      if (query.dueFrom != null) {
        result = result.where(
          (task) => task.dueAt == null || !task.dueAt!.isBefore(query.dueFrom!),
        );
      }
      if (query.dueTo != null) {
        result = result.where(
          (task) => task.dueAt == null || !task.dueAt!.isAfter(query.dueTo!),
        );
      }
      if (query.search != null && query.search!.isNotEmpty) {
        final keyword = query.search!.toLowerCase();
        result = result.where(
          (task) => task.title.toLowerCase().contains(keyword) ||
              (task.description?.toLowerCase().contains(keyword) ?? false),
        );
      }
    }
    final list = result.toList()
      ..sort((a, b) {
        final dueA = a.dueAt ?? DateTime.now().add(const Duration(days: 365));
        final dueB = b.dueAt ?? DateTime.now().add(const Duration(days: 365));
        final compare = dueA.compareTo(dueB);
        if (compare != 0) {
          return compare;
        }
        return a.priority.index.compareTo(b.priority.index);
      });

    return Future.delayed(
      const Duration(milliseconds: 160),
      () => TaskCollection(total: list.length, items: list),
    );
  }

  @override
  Future<Task> updateTask(String id, TaskDraft draft) async {
    final index = _tasks.indexWhere((task) => task.id == id);
    if (index == -1) {
      throw StateError('Task not found');
    }
    final updated = _tasks[index].copyWith(
      title: draft.title,
      description: draft.description,
      dueAt: draft.dueAt,
      allDay: draft.allDay,
      priority: draft.priority,
      status: draft.status,
      tags: List.of(draft.tags),
      reminders: draft.reminders
          .map(
            (item) => TaskReminder(
              id: _random.nextInt(99999),
              remindAt: item.remindAt,
              timezone: item.timezone,
              channel: item.channel,
              repeatRule: item.repeatRule,
              repeatEvery: item.repeatEvery,
              active: item.active,
              expiresAt: item.expiresAt,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              lastTriggeredAt: null,
            ),
          )
          .toList(),
      completedAt: draft.status == TaskStatus.completed
          ? (draft.dueAt ?? DateTime.now())
          : null,
    );
    _tasks[index] = updated;
    return Future.delayed(const Duration(milliseconds: 120), () => updated);
  }

  @override
  Future<TaskStatistics> fetchStatistics() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    int pendingToday = 0;
    int overdue = 0;
    int upcoming = 0;
    int completedToday = 0;

    for (final task in _tasks) {
      if (task.status == TaskStatus.completed) {
        if (task.completedAt != null &&
            !task.completedAt!.isBefore(todayStart) &&
            task.completedAt!.isBefore(todayEnd)) {
          completedToday++;
        }
        continue;
      }
      if (task.dueAt == null) {
        continue;
      }
      if (task.dueAt!.isBefore(todayStart)) {
        overdue++;
      } else if (task.dueAt!.isBefore(todayEnd)) {
        pendingToday++;
      } else if (task.dueAt!.isBefore(todayStart.add(const Duration(days: 7)))) {
        upcoming++;
      }
    }

    return Future.delayed(
      const Duration(milliseconds: 120),
      () => TaskStatistics(
        pendingToday: pendingToday,
        overdue: overdue,
        upcomingWeek: upcoming,
        completedToday: completedToday,
      ),
    );
  }
}
