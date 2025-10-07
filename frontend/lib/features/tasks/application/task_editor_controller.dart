import 'package:flutter/foundation.dart';

import '../data/task_repository.dart';
import '../domain/entities/task.dart';

class TaskEditorState {
  const TaskEditorState({
    required this.draft,
    this.isSubmitting = false,
    this.error,
    this.result,
  });

  final TaskDraft draft;
  final bool isSubmitting;
  final String? error;
  final Task? result;

  TaskEditorState copyWith({
    TaskDraft? draft,
    bool? isSubmitting,
    String? error,
    bool clearError = false,
    Task? result,
  }) {
    return TaskEditorState(
      draft: draft ?? this.draft,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : (error ?? this.error),
      result: result ?? this.result,
    );
  }
}

class TaskEditorController extends ChangeNotifier {
  TaskEditorController(
    this._repository,
    TaskDraft draft, {
    required this.isEditing,
  }) : _state = TaskEditorState(draft: draft);

  final TaskRepository _repository;
  final bool isEditing;

  TaskEditorState _state;
  TaskEditorState get state => _state;

  TaskDraft get draft => _state.draft;

  void updateTitle(String value) {
    draft.title = value.trimLeft();
    _markDirty();
  }

  void updateDescription(String? value) {
    draft.description = value?.trim();
    _markDirty();
  }

  void updateDueAt(DateTime? value) {
    draft.dueAt = value;
    _markDirty();
  }

  void updateAllDay(bool value) {
    draft.allDay = value;
    _markDirty();
  }

  void updatePriority(TaskPriority priority) {
    draft.priority = priority;
    _markDirty();
  }

  void updateStatus(TaskStatus status) {
    draft.status = status;
    _markDirty();
  }

  void addTag(String tag) {
    final normalized = tag.trim();
    if (normalized.isEmpty) {
      return;
    }
    if (!draft.tags.contains(normalized)) {
      draft.tags.add(normalized);
      _markDirty();
    }
  }

  void removeTag(String tag) {
    draft.tags.remove(tag);
    _markDirty();
  }

  void replaceTags(List<String> tags) {
    draft.tags = tags
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();
    _markDirty();
  }

  void addReminder(DateTime dateTime) {
    draft.reminders.add(TaskReminderDraft(remindAt: dateTime));
    draft.reminders.sort((a, b) => a.remindAt.compareTo(b.remindAt));
    _markDirty();
  }

  void updateReminder(int index, DateTime dateTime) {
    if (index < 0 || index >= draft.reminders.length) {
      return;
    }
    draft.reminders[index].remindAt = dateTime;
    draft.reminders.sort((a, b) => a.remindAt.compareTo(b.remindAt));
    _markDirty();
  }

  void removeReminder(int index) {
    if (index < 0 || index >= draft.reminders.length) {
      return;
    }
    draft.reminders.removeAt(index);
    _markDirty();
  }

  Future<Task?> submit() async {
    if (draft.title.trim().isEmpty) {
      _setState(
        (state) => state.copyWith(error: '请填写任务标题'),
      );
      return null;
    }
    if (_state.isSubmitting) {
      return _state.result;
    }
    _setState((state) => state.copyWith(isSubmitting: true, clearError: true));
    try {
      final result = isEditing && draft.id != null
          ? await _repository.updateTask(draft.id!, draft)
          : await _repository.createTask(draft);
      _setState(
        (state) => state.copyWith(
          isSubmitting: false,
          result: result,
          draft: TaskDraft.fromTask(result),
        ),
      );
      return result;
    } catch (error, stackTrace) {
      debugPrint('TaskEditorController submit error: $error');
      debugPrintStack(stackTrace: stackTrace);
      _setState(
        (state) => state.copyWith(
          isSubmitting: false,
          error: '保存任务失败，请稍后重试',
        ),
      );
      return null;
    }
  }

  void _markDirty() {
    _setState((state) => state.copyWith(draft: draft, clearError: true));
  }

  void _setState(TaskEditorState Function(TaskEditorState) updater) {
    _state = updater(_state);
    notifyListeners();
  }
}