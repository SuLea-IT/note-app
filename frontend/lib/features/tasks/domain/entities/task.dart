import 'package:flutter/material.dart';
import 'package:frontend/core/localization/locale_utils.dart';

enum TaskPriority { low, normal, high, urgent }

extension TaskPriorityX on TaskPriority {
  static TaskPriority fromName(String raw) {
    final normalized = raw.trim().toLowerCase();
    return TaskPriority.values.firstWhere(
      (value) => value.name == normalized,
      orElse: () => TaskPriority.normal,
    );
  }

  Color get color {
    switch (this) {
      case TaskPriority.low:
        return const Color(0xFF81C784);
      case TaskPriority.normal:
        return const Color(0xFF42A5F5);
      case TaskPriority.high:
        return const Color(0xFFFFB74D);
      case TaskPriority.urgent:
        return const Color(0xFFE57373);
    }
  }

  String get label => switch (this) {
        TaskPriority.low => trStatic('低', 'Low'),
        TaskPriority.normal => trStatic('普通', 'Normal'),
        TaskPriority.high => trStatic('较高', 'High'),
        TaskPriority.urgent => trStatic('紧急', 'Urgent'),
      };
}

enum TaskStatus { pending, inProgress, completed, cancelled }

extension TaskStatusX on TaskStatus {
  static TaskStatus fromName(String raw) {
    final normalized = raw.trim().toLowerCase();
    switch (normalized) {
      case 'in_progress':
        return TaskStatus.inProgress;
      case 'completed':
        return TaskStatus.completed;
      case 'cancelled':
        return TaskStatus.cancelled;
      default:
        return TaskStatus.pending;
    }
  }

  String get label => switch (this) {
        TaskStatus.pending => trStatic('待开始', 'Pending'),
        TaskStatus.inProgress => trStatic('进行中', 'In progress'),
        TaskStatus.completed => trStatic('已完成', 'Completed'),
        TaskStatus.cancelled => trStatic('已取消', 'Cancelled'),
      };

  String get apiValue {
    switch (this) {
      case TaskStatus.pending:
        return 'pending';
      case TaskStatus.inProgress:
        return 'in_progress';
      case TaskStatus.completed:
        return 'completed';
      case TaskStatus.cancelled:
        return 'cancelled';
    }
  }

  IconData get icon {
    switch (this) {
      case TaskStatus.pending:
        return Icons.radio_button_unchecked;
      case TaskStatus.inProgress:
        return Icons.timelapse;
      case TaskStatus.completed:
        return Icons.check_circle;
      case TaskStatus.cancelled:
        return Icons.cancel_outlined;
    }
  }
}

enum TaskAssociationType { note, diary }

extension TaskAssociationTypeX on TaskAssociationType {
  static TaskAssociationType? fromName(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final normalized = raw.trim().toLowerCase();
    return TaskAssociationType.values.firstWhere(
      (value) => value.name == normalized,
      orElse: () => TaskAssociationType.note,
    );
  }

  String get label => switch (this) {
        TaskAssociationType.note => trStatic('笔记', 'Note'),
        TaskAssociationType.diary => trStatic('日记', 'Diary'),
      };
}

enum NotificationChannel { push, local, email }

extension NotificationChannelX on NotificationChannel {
  static NotificationChannel fromName(String? raw) {
    final normalized = raw?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) {
      return NotificationChannel.push;
    }
    return NotificationChannel.values.firstWhere(
      (value) => value.name == normalized,
      orElse: () => NotificationChannel.push,
    );
  }
}

enum ReminderRepeatRule { none, daily, weekly, monthly }

extension ReminderRepeatRuleX on ReminderRepeatRule {
  static ReminderRepeatRule fromName(String? raw) {
    final normalized = raw?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) {
      return ReminderRepeatRule.none;
    }
    return ReminderRepeatRule.values.firstWhere(
      (value) => value.name == normalized,
      orElse: () => ReminderRepeatRule.none,
    );
  }
}

class TaskReminder {
  const TaskReminder({
    required this.id,
    required this.remindAt,
    required this.timezone,
    required this.channel,
    required this.repeatRule,
    required this.repeatEvery,
    required this.active,
    this.expiresAt,
    this.createdAt,
    this.updatedAt,
    this.lastTriggeredAt,
  });

  factory TaskReminder.fromJson(Map<String, dynamic> json) {
    final remindAt = _parseDateTime(json['remind_at']) ?? DateTime.now();
    final timezone = (json['timezone'] as String? ?? 'UTC').trim();
    return TaskReminder(
      id: json['id'] as int? ?? 0,
      remindAt: remindAt,
      timezone: timezone.isEmpty ? 'UTC' : timezone,
      channel: NotificationChannelX.fromName(json['channel'] as String? ?? 'push'),
      repeatRule:
          ReminderRepeatRuleX.fromName(json['repeat_rule'] as String? ?? 'none'),
      repeatEvery: (json['repeat_every'] as num?)?.toInt() ?? 1,
      active: json['active'] as bool? ?? true,
      expiresAt: _parseDateTime(json['expires_at']),
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
      lastTriggeredAt: _parseDateTime(json['last_triggered_at']),
    );
  }

  final int id;
  final DateTime remindAt;
  final String timezone;
  final NotificationChannel channel;
  final ReminderRepeatRule repeatRule;
  final int repeatEvery;
  final bool active;
  final DateTime? expiresAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastTriggeredAt;
}

class TaskReminderDraft {
  TaskReminderDraft({
    this.id,
    DateTime? remindAt,
    String? timezone,
    NotificationChannel? channel,
    ReminderRepeatRule? repeatRule,
    int repeatEvery = 1,
    bool active = true,
    this.expiresAt,
  })  : remindAt = (remindAt ?? DateTime.now()).toLocal(),
        timezone = (timezone?.trim().isNotEmpty ?? false)
            ? timezone!.trim()
            : 'UTC',
        channel = channel ?? NotificationChannel.push,
        repeatRule = repeatRule ?? ReminderRepeatRule.none,
        repeatEvery = repeatEvery < 1 ? 1 : repeatEvery,
        active = active;

  factory TaskReminderDraft.fromReminder(TaskReminder reminder) {
    return TaskReminderDraft(
      id: reminder.id,
      remindAt: reminder.remindAt,
      timezone: reminder.timezone,
      channel: reminder.channel,
      repeatRule: reminder.repeatRule,
      repeatEvery: reminder.repeatEvery,
      active: reminder.active,
      expiresAt: reminder.expiresAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'remind_at': remindAt.toUtc().toIso8601String(),
      'timezone': timezone,
      'channel': channel.name,
      'repeat_rule': repeatRule.name,
      'repeat_every': repeatEvery,
      'active': active,
      if (expiresAt != null) 'expires_at': expiresAt!.toUtc().toIso8601String(),
    };
  }

  int? id;
  DateTime remindAt;
  String timezone;
  NotificationChannel channel;
  ReminderRepeatRule repeatRule;
  int repeatEvery;
  bool active;
  DateTime? expiresAt;
}

class Task {
  const Task({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    this.dueAt,
    this.allDay = false,
    this.priority = TaskPriority.normal,
    this.status = TaskStatus.pending,
    this.orderIndex,
    this.relatedEntityId,
    this.relatedEntityType,
    this.tags = const [],
    this.reminders = const [],
    this.createdAt,
    this.updatedAt,
    this.completedAt,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    final tags = (json['tags'] as List<dynamic>? ?? [])
        .whereType<String>()
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList(growable: false);

    final reminders = (json['reminders'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(TaskReminder.fromJson)
        .toList(growable: false);

    return Task(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      dueAt: _parseDateTime(json['due_at']),
      allDay: json['all_day'] as bool? ?? false,
      priority: TaskPriorityX.fromName(json['priority'] as String? ?? ''),
      status: TaskStatusX.fromName(json['status'] as String? ?? ''),
      orderIndex: (json['order_index'] as num?)?.toInt(),
      relatedEntityId: json['related_entity_id'] as String?,
      relatedEntityType:
          TaskAssociationTypeX.fromName(json['related_entity_type'] as String?),
      tags: tags,
      reminders: reminders,
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
      completedAt: _parseDateTime(json['completed_at']),
    );
  }

  Task copyWith({
    TaskStatus? status,
    TaskPriority? priority,
    String? title,
    String? description,
    DateTime? dueAt,
    bool? allDay,
    List<String>? tags,
    List<TaskReminder>? reminders,
    DateTime? completedAt,
  }) {
    return Task(
      id: id,
      userId: userId,
      title: title ?? this.title,
      description: description ?? this.description,
      dueAt: dueAt ?? this.dueAt,
      allDay: allDay ?? this.allDay,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      orderIndex: orderIndex,
      relatedEntityId: relatedEntityId,
      relatedEntityType: relatedEntityType,
      tags: tags ?? this.tags,
      reminders: reminders ?? this.reminders,
      createdAt: createdAt,
      updatedAt: updatedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  final String id;
  final String userId;
  final String title;
  final String? description;
  final DateTime? dueAt;
  final bool allDay;
  final TaskPriority priority;
  final TaskStatus status;
  final int? orderIndex;
  final String? relatedEntityId;
  final TaskAssociationType? relatedEntityType;
  final List<String> tags;
  final List<TaskReminder> reminders;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;

  bool get isOverdue {
    if (status == TaskStatus.completed || status == TaskStatus.cancelled) {
      return false;
    }
    if (dueAt == null) {
      return false;
    }
    return dueAt!.isBefore(DateTime.now());
  }
}

class TaskDraft {
  TaskDraft({
    this.id,
    this.userId,
    this.title = '',
    this.description,
    this.dueAt,
    this.allDay = false,
    this.priority = TaskPriority.normal,
    this.status = TaskStatus.pending,
    List<String>? tags,
    List<TaskReminderDraft>? reminders,
    this.relatedEntityId,
    this.relatedEntityType,
  })  : tags = tags ?? <String>[],
        reminders = reminders ?? <TaskReminderDraft>[];

  factory TaskDraft.fromTask(Task task) {
    return TaskDraft(
      id: task.id,
      userId: task.userId,
      title: task.title,
      description: task.description,
      dueAt: task.dueAt,
      allDay: task.allDay,
      priority: task.priority,
      status: task.status,
      tags: List<String>.from(task.tags),
      reminders: task.reminders
          .map(TaskReminderDraft.fromReminder)
          .toList(),
      relatedEntityId: task.relatedEntityId,
      relatedEntityType: task.relatedEntityType,
    );
  }

  Map<String, dynamic> toCreatePayload() {
    return {
      'user_id': userId,
      'title': title,
      'description': description,
      'due_at': dueAt?.toIso8601String(),
      'all_day': allDay,
      'priority': priority.name,
      'status': status.apiValue,
      if (tags.isNotEmpty) 'tags': tags,
      if (reminders.isNotEmpty)
        'reminders': reminders.map((item) => item.toJson()).toList(),
      if (relatedEntityId != null) 'related_entity_id': relatedEntityId,
      if (relatedEntityType != null)
        'related_entity_type': relatedEntityType!.name,
    };
  }

  Map<String, dynamic> toUpdatePayload() {
    return {
      'title': title,
      'description': description,
      'due_at': dueAt?.toIso8601String(),
      'all_day': allDay,
      'priority': priority.name,
      'status': status.apiValue,
      'tags': tags,
      'reminders': reminders.map((item) => item.toJson()).toList(),
      if (relatedEntityId != null) 'related_entity_id': relatedEntityId,
      'related_entity_type': relatedEntityType?.name,
    };
  }

  String? id;
  String? userId;
  String title;
  String? description;
  DateTime? dueAt;
  bool allDay;
  TaskPriority priority;
  TaskStatus status;
  List<String> tags;
  List<TaskReminderDraft> reminders;
  String? relatedEntityId;
  TaskAssociationType? relatedEntityType;
}

class TaskStatistics {
  const TaskStatistics({
    required this.pendingToday,
    required this.overdue,
    required this.upcomingWeek,
    required this.completedToday,
  });

  factory TaskStatistics.fromJson(Map<String, dynamic> json) {
    return TaskStatistics(
      pendingToday: (json['pending_today'] as num?)?.toInt() ?? 0,
      overdue: (json['overdue'] as num?)?.toInt() ?? 0,
      upcomingWeek: (json['upcoming_week'] as num?)?.toInt() ?? 0,
      completedToday: (json['completed_today'] as num?)?.toInt() ?? 0,
    );
  }

  final int pendingToday;
  final int overdue;
  final int upcomingWeek;
  final int completedToday;
}

class TaskCollection {
  const TaskCollection({
    required this.total,
    required this.items,
  });

  factory TaskCollection.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(Task.fromJson)
        .toList(growable: false);
    return TaskCollection(
      total: (json['total'] as num?)?.toInt() ?? items.length,
      items: items,
    );
  }

  final int total;
  final List<Task> items;
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is DateTime) {
    return value.toLocal();
  }
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value)?.toLocal();
  }
  return null;
}