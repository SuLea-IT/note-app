import 'package:flutter/foundation.dart';

import '../data/task_repository.dart';
import '../domain/entities/task.dart';

enum TaskDetailStatus { initial, loading, ready, failure }

class TaskDetailState {
  const TaskDetailState({
    this.status = TaskDetailStatus.initial,
    this.task,
    this.error,
  });

  final TaskDetailStatus status;
  final Task? task;
  final String? error;

  TaskDetailState copyWith({
    TaskDetailStatus? status,
    Task? task,
    bool clearTask = false,
    String? error,
    bool clearError = false,
  }) {
    return TaskDetailState(
      status: status ?? this.status,
      task: clearTask ? null : (task ?? this.task),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class TaskDetailController extends ChangeNotifier {
  TaskDetailController(this._repository, this.taskId);

  final TaskRepository _repository;
  final String taskId;

  TaskDetailState _state = const TaskDetailState();
  TaskDetailState get state => _state;

  Future<void> load() async {
    _setState((state) => state.copyWith(status: TaskDetailStatus.loading, clearError: true));
    try {
      final task = await _repository.fetchTask(taskId);
      _setState(
        (state) => state.copyWith(
          status: TaskDetailStatus.ready,
          task: task,
          clearError: true,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('TaskDetailController load error: $error');
      debugPrintStack(stackTrace: stackTrace);
      _setState(
        (state) => state.copyWith(
          status: TaskDetailStatus.failure,
          error: '加载任务详情失败，请稍后重试',
        ),
      );
    }
  }

  Future<void> refresh() => load();

  Future<bool> updateStatus(TaskStatus status) async {
    final current = _state.task;
    if (current == null) {
      return false;
    }
    try {
      final draft = TaskDraft.fromTask(current)..status = status;
      final updated = await _repository.updateTask(taskId, draft);
      _setState((state) => state.copyWith(task: updated));
      return true;
    } catch (error, stackTrace) {
      debugPrint('TaskDetailController update status error: $error');
      debugPrintStack(stackTrace: stackTrace);
      _setState((state) => state.copyWith(error: '更新状态失败'));
      return false;
    }
  }

  Future<bool> delete() async {
    try {
      await _repository.deleteTask(taskId);
      _setState((state) => state.copyWith(clearTask: true));
      return true;
    } catch (error, stackTrace) {
      debugPrint('TaskDetailController delete error: $error');
      debugPrintStack(stackTrace: stackTrace);
      _setState((state) => state.copyWith(error: '删除失败，请稍后再试'));
      return false;
    }
  }

  void _setState(TaskDetailState Function(TaskDetailState) updater) {
    _state = updater(_state);
    notifyListeners();
  }
}