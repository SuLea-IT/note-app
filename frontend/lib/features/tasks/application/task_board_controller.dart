import 'package:flutter/foundation.dart';

import '../../notifications/application/notification_controller.dart';
import '../data/task_repository.dart';
import '../domain/entities/task.dart';

enum TaskBoardStatus { initial, loading, ready, failure }

class TaskSection {
  const TaskSection({
    required this.id,
    required this.label,
    required this.tasks,
    this.caption,
  });

  final String id;
  final String label;
  final String? caption;
  final List<Task> tasks;

  TaskSection copyWith({
    List<Task>? tasks,
  }) {
    return TaskSection(
      id: id,
      label: label,
      caption: caption,
      tasks: tasks ?? this.tasks,
    );
  }
}

class TaskBoardState {
  const TaskBoardState({
    this.status = TaskBoardStatus.initial,
    this.error,
    this.tasks = const [],
    this.sections = const [],
    this.statistics,
    TaskListGrouping? grouping,
    Set<TaskStatus>? statuses,
    Set<TaskPriority>? priorities,
    Set<String>? tags,
    this.query = '',
    this.isBulkCompleting = false,
    Set<String>? selectedTaskIds,
  })  : grouping = grouping ?? TaskListGrouping.byDate,
        statuses = statuses ?? const <TaskStatus>{},
        priorities = priorities ?? const <TaskPriority>{},
        tags = tags ?? const <String>{},
        selectedTaskIds = selectedTaskIds ?? const <String>{};

  final TaskBoardStatus status;
  final String? error;
  final List<Task> tasks;
  final List<TaskSection> sections;
  final TaskStatistics? statistics;
  final TaskListGrouping grouping;
  final Set<TaskStatus> statuses;
  final Set<TaskPriority> priorities;
  final Set<String> tags;
  final String query;
  final bool isBulkCompleting;
  final Set<String> selectedTaskIds;

  TaskBoardState copyWith({
    TaskBoardStatus? status,
    String? error,
    bool clearError = false,
    List<Task>? tasks,
    List<TaskSection>? sections,
    TaskStatistics? statistics,
    TaskListGrouping? grouping,
    Set<TaskStatus>? statuses,
    Set<TaskPriority>? priorities,
    Set<String>? tags,
    String? query,
    bool? isBulkCompleting,
    Set<String>? selectedTaskIds,
  }) {
    return TaskBoardState(
      status: status ?? this.status,
      error: clearError ? null : (error ?? this.error),
      tasks: tasks ?? this.tasks,
      sections: sections ?? this.sections,
      statistics: statistics ?? this.statistics,
      grouping: grouping ?? this.grouping,
      statuses: statuses ?? this.statuses,
      priorities: priorities ?? this.priorities,
      tags: tags ?? this.tags,
      query: query ?? this.query,
      isBulkCompleting: isBulkCompleting ?? this.isBulkCompleting,
      selectedTaskIds: selectedTaskIds ?? this.selectedTaskIds,
    );
  }
}

class TaskBoardController extends ChangeNotifier {
  TaskBoardController(
    this._repository, {
    NotificationController? notifications,
  }) : _notifications = notifications {
    _notifications?.registerSilentUpdateListener(_handleSilentUpdate);
  }

  final TaskRepository _repository;
  final NotificationController? _notifications;

  TaskBoardState _state = const TaskBoardState();
  TaskBoardState get state => _state;

  Future<void> load({bool refresh = false}) async {
    if (_state.status == TaskBoardStatus.loading && !refresh) {
      return;
    }
    _setState(
      (state) => state.copyWith(
        status: TaskBoardStatus.loading,
        clearError: true,
        selectedTaskIds: <String>{},
      ),
    );

    try {
      final query = _buildQuery();
      final collection = await _repository.fetchTasks(query: query);
      final stats = await _repository.fetchStatistics();
      _setState(
        (state) => state.copyWith(
          status: TaskBoardStatus.ready,
          tasks: collection.items,
          sections: _buildSections(collection.items, state.grouping),
          statistics: stats,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('TaskBoardController load error: $error');
      debugPrintStack(stackTrace: stackTrace);
      _setState(
        (state) => state.copyWith(
          status: TaskBoardStatus.failure,
          error: '加载任务失败，请稍后再试',
        ),
      );
    }
  }

  Future<void> refresh() => load(refresh: true);

  Future<void> search(String keyword) async {
    final normalized = keyword.trim();
    if (_state.query == normalized) {
      return;
    }
    _setState((state) => state.copyWith(query: normalized));
    await load(refresh: true);
  }

  void clearSearch() {
    if (_state.query.isEmpty) {
      return;
    }
    _setState((state) => state.copyWith(query: ''));
    load(refresh: true);
  }

  void toggleStatus(TaskStatus status) {
    final updated = Set<TaskStatus>.from(_state.statuses);
    if (!updated.add(status)) {
      updated.remove(status);
    }
    _setState((state) => state.copyWith(statuses: updated));
    load(refresh: true);
  }

  void togglePriority(TaskPriority priority) {
    final updated = Set<TaskPriority>.from(_state.priorities);
    if (!updated.add(priority)) {
      updated.remove(priority);
    }
    _setState((state) => state.copyWith(priorities: updated));
    load(refresh: true);
  }

  void toggleTag(String tag) {
    final normalized = tag.trim();
    if (normalized.isEmpty) {
      return;
    }
    final updated = Set<String>.from(_state.tags);
    if (!updated.add(normalized)) {
      updated.remove(normalized);
    }
    _setState((state) => state.copyWith(tags: updated));
    load(refresh: true);
  }

  void changeGrouping(TaskListGrouping grouping) {
    if (_state.grouping == grouping) {
      return;
    }
    _setState(
      (state) => state.copyWith(
        grouping: grouping,
        sections: _buildSections(state.tasks, grouping),
      ),
    );
  }

  void toggleSelection(String taskId) {
    final updated = Set<String>.from(_state.selectedTaskIds);
    if (!updated.add(taskId)) {
      updated.remove(taskId);
    }
    _setState((state) => state.copyWith(selectedTaskIds: updated));
  }

  void clearSelection() {
    if (_state.selectedTaskIds.isEmpty) {
      return;
    }
    _setState((state) => state.copyWith(selectedTaskIds: <String>{}));
  }

  Future<void> deleteTask(String taskId) async {
    try {
      await _repository.deleteTask(taskId);
      final remaining = _state.tasks.where((task) => task.id != taskId).toList();
      _setState(
        (state) => state.copyWith(
          tasks: remaining,
          sections: _buildSections(remaining, state.grouping),
          selectedTaskIds: Set<String>.from(state.selectedTaskIds)..remove(taskId),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('TaskBoardController delete error: $error');
      debugPrintStack(stackTrace: stackTrace);
      _setState(
        (state) => state.copyWith(error: '删除任务失败，请稍后重试'),
      );
    }
  }

  Future<void> markTaskStatus(String taskId, TaskStatus status) async {
    try {
      final task = _state.tasks.firstWhere((task) => task.id == taskId);
      final draft = TaskDraft.fromTask(task)..status = status;
      if (status == TaskStatus.completed) {
        draft.reminders.clear();
      }
      final updated = await _repository.updateTask(taskId, draft);
      final tasks = _state.tasks.map((task) {
        if (task.id == taskId) {
          return updated;
        }
        return task;
      }).toList();
      _setState(
        (state) => state.copyWith(
          tasks: tasks,
          sections: _buildSections(tasks, state.grouping),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('TaskBoardController mark status error: $error');
      debugPrintStack(stackTrace: stackTrace);
      _setState(
        (state) => state.copyWith(error: '更新任务状态失败，请稍后重试'),
      );
    }
  }

  Future<void> bulkCompleteSelected({bool completed = true}) async {
    final selected = _state.selectedTaskIds.toList(growable: false);
    if (selected.isEmpty) {
      return;
    }
    _setState((state) => state.copyWith(isBulkCompleting: true, clearError: true));
    try {
      final updates = await _repository.bulkComplete(selected, completed: completed);
      final updatedMap = {for (final task in updates) task.id: task};
      final tasks = _state.tasks.map((task) {
        return updatedMap[task.id] ?? (completed
            ? task.copyWith(status: TaskStatus.completed, completedAt: DateTime.now())
            : task.copyWith(status: TaskStatus.pending, completedAt: null));
      }).toList();
      _setState(
        (state) => state.copyWith(
          tasks: tasks,
          sections: _buildSections(tasks, state.grouping),
          selectedTaskIds: <String>{},
          isBulkCompleting: false,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('TaskBoardController bulk complete error: $error');
      debugPrintStack(stackTrace: stackTrace);
      _setState(
        (state) => state.copyWith(
          isBulkCompleting: false,
          error: '批量更新失败，请稍后重试',
        ),
      );
    }
  }

  TaskQuery _buildQuery() {
    return TaskQuery(
      statuses: _state.statuses.isEmpty ? null : _state.statuses.toList(growable: false),
      priorities:
          _state.priorities.isEmpty ? null : _state.priorities.toList(growable: false),
      tags: _state.tags.isEmpty ? null : _state.tags.toList(growable: false),
      search: _state.query.isEmpty ? null : _state.query,
      limit: 200,
    );
  }

  List<TaskSection> _buildSections(List<Task> tasks, TaskListGrouping grouping) {
    switch (grouping) {
      case TaskListGrouping.byPriority:
        return _groupByPriority(tasks);
      case TaskListGrouping.byStatus:
        return _groupByStatus(tasks);
      case TaskListGrouping.byDate:
        return _groupByDate(tasks);
    }
  }

  List<TaskSection> _groupByDate(List<Task> tasks) {
    if (tasks.isEmpty) {
      return [];
    }
    final today = DateTime.now();
    final nowDate = DateTime(today.year, today.month, today.day);
    final endOfWeek = nowDate.add(const Duration(days: 7));

    final Map<String, List<Task>> buckets = {
      'overdue': <Task>[],
      'today': <Task>[],
      'tomorrow': <Task>[],
      'week': <Task>[],
      'later': <Task>[],
      'no_date': <Task>[],
    };

    for (final task in tasks) {
      if (task.dueAt == null) {
        buckets['no_date']!.add(task);
        continue;
      }
      final due = DateTime(task.dueAt!.year, task.dueAt!.month, task.dueAt!.day);
      if (due.isBefore(nowDate)) {
        buckets['overdue']!.add(task);
      } else if (due.isAtSameMomentAs(nowDate)) {
        buckets['today']!.add(task);
      } else if (due.isAtSameMomentAs(nowDate.add(const Duration(days: 1)))) {
        buckets['tomorrow']!.add(task);
      } else if (due.isBefore(endOfWeek)) {
        buckets['week']!.add(task);
      } else {
        buckets['later']!.add(task);
      }
    }

    List<TaskSection> sections = [];
    void addSection(String id, String label, String? caption) {
      final bucket = buckets[id]!;
      if (bucket.isEmpty) {
        return;
      }
      bucket.sort((a, b) {
        final dueA = a.dueAt ?? DateTime.now();
        final dueB = b.dueAt ?? DateTime.now();
        final result = dueA.compareTo(dueB);
        if (result != 0) {
          return result;
        }
        return a.priority.index.compareTo(b.priority.index);
      });
      sections.add(TaskSection(id: id, label: label, caption: caption, tasks: bucket));
    }

    addSection('overdue', '已逾期', '请尽快处理');
    addSection('today', '今日任务', '专注完成当日待办');
    addSection('tomorrow', '明日安排', '提前做好准备');
    addSection('week', '本周计划', '保持节奏');
    addSection('later', '未来任务', '提前规划更安心');
    addSection('no_date', '未设置日期', '为任务补充时间信息');

    return sections;
  }

  List<TaskSection> _groupByPriority(List<Task> tasks) {
    final Map<TaskPriority, List<Task>> buckets = {
      for (final priority in TaskPriority.values) priority: <Task>[],
    };
    for (final task in tasks) {
      buckets[task.priority]!.add(task);
    }
    return TaskPriority.values
        .map((priority) {
          final bucket = buckets[priority]!;
          if (bucket.isEmpty) {
            return null;
          }
          bucket.sort(_compareByDueDate);
          return TaskSection(
            id: 'priority-${priority.name}',
            label: '${priority.label}优先',
            tasks: bucket,
          );
        })
        .whereType<TaskSection>()
        .toList(growable: false);
  }

  List<TaskSection> _groupByStatus(List<Task> tasks) {
    final Map<TaskStatus, List<Task>> buckets = {
      for (final status in TaskStatus.values) status: <Task>[],
    };
    for (final task in tasks) {
      buckets[task.status]!.add(task);
    }
    return TaskStatus.values
        .map((status) {
          final bucket = buckets[status]!;
          if (bucket.isEmpty) {
            return null;
          }
          bucket.sort(_compareByDueDate);
          return TaskSection(
            id: 'status-${status.name}',
            label: status.label,
            tasks: bucket,
          );
        })
        .whereType<TaskSection>()
        .toList(growable: false);
  }

  int _compareByDueDate(Task a, Task b) {
    final dueA = a.dueAt ?? DateTime.now().add(const Duration(days: 365));
    final dueB = b.dueAt ?? DateTime.now().add(const Duration(days: 365));
    final compare = dueA.compareTo(dueB);
    if (compare != 0) {
      return compare;
    }
    return a.priority.index.compareTo(b.priority.index);
  }

  void _setState(TaskBoardState Function(TaskBoardState) updater) {
    _state = updater(_state);
    notifyListeners();
  }

  void _handleSilentUpdate() {
    load(refresh: true);
  }

  @override
  void dispose() {
    _notifications?.registerSilentUpdateListener(null);
    super.dispose();
  }
}
