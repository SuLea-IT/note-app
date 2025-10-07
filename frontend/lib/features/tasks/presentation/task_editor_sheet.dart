import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/locale_utils.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_spacing.dart';
import '../../auth/application/auth_controller.dart';
import '../application/task_editor_controller.dart';
import '../data/task_repository.dart';
import '../domain/entities/task.dart';

class TaskEditorSheet extends StatelessWidget {
  const TaskEditorSheet({super.key, this.initialTask});

  final Task? initialTask;

  static Future<Task?> show(BuildContext context, {Task? task}) {
    return showModalBottomSheet<Task?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TaskEditorSheet(initialTask: task),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repository = context.read<TaskRepository>();
    final auth = context.read<AuthController>();
    final draft = initialTask != null
        ? TaskDraft.fromTask(initialTask!)
        : TaskDraft(userId: auth.state.user?.id);

    return ChangeNotifierProvider<TaskEditorController>(
      create: (_) => TaskEditorController(
        repository,
        draft,
        isEditing: initialTask != null,
      ),
      child: const _TaskEditorView(),
    );
  }
}

class _TaskEditorView extends StatefulWidget {
  const _TaskEditorView();

  @override
  State<_TaskEditorView> createState() => _TaskEditorViewState();
}

class _TaskEditorViewState extends State<_TaskEditorView> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _tagController;
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  final DateFormat _timeFormat = DateFormat('HH:mm');

  @override
  void initState() {
    super.initState();
    final controller = context.read<TaskEditorController>();
    _titleController = TextEditingController(text: controller.draft.title);
    _descriptionController =
        TextEditingController(text: controller.draft.description ?? '');
    _tagController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(AppRadius.xl),
            topRight: Radius.circular(AppRadius.xl),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.lg,
            ),
            child: Consumer<TaskEditorController>(
              builder: (context, controller, _) {
                final state = controller.state;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 48,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        Text(
                          controller.isEditing ? '编辑任务' : '新建任务',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextField(
                      controller: _titleController,
                      maxLength: 60,
                      decoration: InputDecoration(
                        labelText: '任务标题',
                        hintText: '请输入任务标题',
                      ),
                      onChanged: controller.updateTitle,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: '任务备注',
                        hintText: '补充描述、上下文或链接',
                      ),
                      onChanged: controller.updateDescription,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _buildDateRow(controller),
                    const SizedBox(height: AppSpacing.md),
                    _buildPriorityRow(controller),
                    const SizedBox(height: AppSpacing.md),
                    _buildStatusRow(controller),
                    const SizedBox(height: AppSpacing.lg),
                    _buildTagInput(controller),
                    const SizedBox(height: AppSpacing.md),
                    _buildTagChips(controller),
                    const SizedBox(height: AppSpacing.lg),
                    _buildReminderList(controller),
                    if (state.error != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          state.error!,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.error),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: state.isSubmitting
                            ? null
                            : () async {
                                final result = await controller.submit();
                                if (!mounted) {
                                  return;
                                }
                                if (result != null) {
                                  Navigator.of(context).pop(result);
                                }
                              },
                        child: state.isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(controller.isEditing ? '保存修改' : '创建任务'),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateRow(TaskEditorController controller) {
    final draft = controller.draft;
    final dueAt = draft.dueAt;
    final dueLabel = dueAt != null ? _dateFormat.format(dueAt) : '未设置日期';
    final timeLabel = dueAt != null
        ? _timeFormat.format(dueAt)
        : (draft.allDay ? '全天' : '未设置时间');
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () async {
              final now = DateTime.now();
              final initial = dueAt ?? now;
              final picked = await showDatePicker(
                context: context,
                initialDate: initial,
                firstDate: now.subtract(const Duration(days: 365)),
                lastDate: now.add(const Duration(days: 365 * 5)),
              );
              if (picked != null) {
                if (dueAt != null) {
                  final newDate = DateTime(
                    picked.year,
                    picked.month,
                    picked.day,
                    dueAt.hour,
                    dueAt.minute,
                  );
                  controller.updateDueAt(newDate);
                } else {
                  controller.updateDueAt(picked);
                }
              }
            },
            icon: const Icon(Icons.event_outlined),
            label: Text(dueLabel),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: draft.allDay
                ? null
                : () async {
                    final base = draft.dueAt ?? DateTime.now();
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(base),
                    );
                    if (picked != null) {
                      final newDate = DateTime(
                        base.year,
                        base.month,
                        base.day,
                        picked.hour,
                        picked.minute,
                      );
                      controller.updateDueAt(newDate);
                    }
                  },
            icon: const Icon(Icons.schedule_outlined),
            label: Text(timeLabel),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Switch(
          value: draft.allDay,
          onChanged: (value) {
            controller.updateAllDay(value);
          },
        ),
        const SizedBox(width: 4),
        Text(context.tr('全天')),
      ],
    );
  }

  Widget _buildPriorityRow(TaskEditorController controller) {
    final draft = controller.draft;
    return Row(
      children: [
        Text(context.tr('优先级：')),
        const SizedBox(width: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          children: TaskPriority.values.map((priority) {
            final selected = priority == draft.priority;
            return ChoiceChip(
              label: Text(priority.label),
              selected: selected,
              onSelected: (_) => controller.updatePriority(priority),
              selectedColor: priority.color.withAlpha(38),
              labelStyle: TextStyle(
                color: selected ? priority.color : AppColors.textPrimary,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStatusRow(TaskEditorController controller) {
    final draft = controller.draft;
    return Row(
      children: [
        Text(context.tr('状态：')),
        const SizedBox(width: AppSpacing.sm),
        DropdownButton<TaskStatus>(
          value: draft.status,
          onChanged: (value) {
            if (value != null) {
              controller.updateStatus(value);
            }
          },
          items: TaskStatus.values
              .map(
                (status) => DropdownMenuItem<TaskStatus>(
                  value: status,
                  child: Text(status.label),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildTagInput(TaskEditorController controller) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _tagController,
            decoration: InputDecoration(
              labelText: '添加标签',
              hintText: '输入标签后按回车',
            ),
            onSubmitted: (value) {
              controller.addTag(value);
              _tagController.clear();
            },
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        IconButton(
          tooltip: '添加标签',
          onPressed: () {
            controller.addTag(_tagController.text);
            _tagController.clear();
          },
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }

  Widget _buildTagChips(TaskEditorController controller) {
    final tags = controller.draft.tags;
    if (tags.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(context.tr('可使用标签快速分类，如“工作”“个人”'),
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.textSecondary),
        ),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: tags
            .map(
              (tag) => Chip(
                label: Text(tag),
                onDeleted: () => controller.removeTag(tag),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildReminderList(TaskEditorController controller) {
    final reminders = controller.draft.reminders;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(context.tr('提醒设置')),
            const Spacer(),
            TextButton.icon(
              onPressed: () async {
                final now = DateTime.now().add(const Duration(hours: 1));
                final pickedDate = await showDatePicker(
                  context: context,
                  initialDate: now,
                  firstDate: DateTime.now().subtract(const Duration(days: 1)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (pickedDate == null) {
                  return;
                }
                final pickedTime = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(now),
                );
                if (pickedTime == null) {
                  return;
                }
                final remindAt = DateTime(
                  pickedDate.year,
                  pickedDate.month,
                  pickedDate.day,
                  pickedTime.hour,
                  pickedTime.minute,
                );
                controller.addReminder(remindAt);
              },
              icon: const Icon(Icons.alarm_add_outlined),
              label: Text(context.tr('添加提醒')),
            ),
          ],
        ),
        if (reminders.isEmpty)
          Text(context.tr('设置多个提醒，在关键时间收到通知'),
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          )
        else
          Column(
            children: reminders.asMap().entries.map((entry) {
              final index = entry.key;
              final reminder = entry.value;
              final dateLabel = _dateFormat.format(reminder.remindAt);
              final timeLabel = _timeFormat.format(reminder.remindAt);
              return Card(
                margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: ListTile(
                  leading: const Icon(Icons.alarm_outlined),
                  title: Text('$dateLabel $timeLabel'),
                  subtitle: Text(context.tr('将在设定时间提醒')),
                  trailing: Wrap(
                    spacing: AppSpacing.sm,
                    children: [
                      IconButton(
                        tooltip: '调整时间',
                        onPressed: () async {
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate: reminder.remindAt,
                            firstDate: DateTime.now().subtract(const Duration(days: 1)),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (pickedDate == null) {
                            return;
                          }
                          final pickedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(reminder.remindAt),
                          );
                          if (pickedTime == null) {
                            return;
                          }
                          final remindAt = DateTime(
                            pickedDate.year,
                            pickedDate.month,
                            pickedDate.day,
                            pickedTime.hour,
                            pickedTime.minute,
                          );
                          controller.updateReminder(index, remindAt);
                        },
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: '删除提醒',
                        onPressed: () => controller.removeReminder(index),
                        icon: const Icon(Icons.delete_outline, color: AppColors.error),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}
