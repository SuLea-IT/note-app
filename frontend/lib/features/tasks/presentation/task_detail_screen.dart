import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/locale_utils.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../application/task_detail_controller.dart';
import '../domain/entities/task.dart';
import 'task_editor_sheet.dart';

class TaskDetailScreen extends StatelessWidget {
  const TaskDetailScreen({
    super.key,
    required this.taskId,
    this.onTaskUpdated,
    this.onTaskDeleted,
  });

  final String taskId;
  final ValueChanged<Task>? onTaskUpdated;
  final VoidCallback? onTaskDeleted;

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskDetailController>(
      builder: (context, controller, _) {
        final state = controller.state;
        return Scaffold(
          appBar: AppBar(
            title: Text(context.tr('任务详情')),
            actions: [
              IconButton(
                tooltip: '刷新',
                onPressed: controller.refresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: _buildBody(context, state, controller),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    TaskDetailState state,
    TaskDetailController controller,
  ) {
    switch (state.status) {
      case TaskDetailStatus.initial:
      case TaskDetailStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case TaskDetailStatus.failure:
        return _ErrorView(
          message: state.error ?? '加载失败，请稍后重试',
          onRetry: controller.refresh,
        );
      case TaskDetailStatus.ready:
        final task = state.task!;
        return _TaskDetailContent(
          task: task,
          controller: controller,
          onTaskUpdated: onTaskUpdated,
          onTaskDeleted: onTaskDeleted,
        );
    }
  }
}

class _TaskDetailContent extends StatelessWidget {
  const _TaskDetailContent({
    required this.task,
    required this.controller,
    this.onTaskUpdated,
    this.onTaskDeleted,
  });

  final Task task;
  final TaskDetailController controller;
  final ValueChanged<Task>? onTaskUpdated;
  final VoidCallback? onTaskDeleted;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy年MM月dd日 HH:mm', 'zh_CN');
    final dueLabel = task.dueAt != null ? dateFormat.format(task.dueAt!) : '未设置';
    final createdLabel = task.createdAt != null
        ? dateFormat.format(task.createdAt!)
        : '--';
    final updatedLabel = task.updatedAt != null
        ? dateFormat.format(task.updatedAt!)
        : '--';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  task.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      _openEditor(context, task);
                      break;
                    case 'complete':
                      controller.updateStatus(TaskStatus.completed);
                      break;
                    case 'delete':
                      _confirmDelete(context, controller);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'edit', child: Text(context.tr('编辑任务'))),
                  PopupMenuItem(value: 'complete', child: Text(context.tr('标记完成'))),
                  PopupMenuItem(value: 'delete', child: Text(context.tr('删除任务'))),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Chip(
                label: Text(task.status.label),
                avatar: Icon(task.status.icon, size: 18),
              ),
              const SizedBox(width: AppSpacing.sm),
              Chip(
                label: Text('${task.priority.label}优先'),
                avatar: Icon(Icons.flag, size: 18, color: task.priority.color),
                backgroundColor: task.priority.color.withAlpha(31),
              ),
              const Spacer(),
              SwitchListTile.adaptive(
                value: task.status == TaskStatus.completed,
                onChanged: (value) async {
                  final status = value ? TaskStatus.completed : TaskStatus.pending;
                  final success = await controller.updateStatus(status);
                  if (success && onTaskUpdated != null) {
                    final updated = controller.state.task;
                    if (updated != null) {
                      onTaskUpdated!(updated);
                    }
                  }
                },
                title: Text(context.tr('完成')),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionCard(
            title: '计划时间',
            children: [
              _InfoRow(label: '截止时间', value: dueLabel),
              _InfoRow(label: '全天任务', value: task.allDay ? '是' : '否'),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if ((task.description ?? '').trim().isNotEmpty)
            _SectionCard(
              title: '任务备注',
              children: [
                Text(
                  task.description!,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          if (task.tags.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            _SectionCard(
              title: '标签',
              children: [
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: task.tags
                      .map((tag) => Chip(label: Text('#$tag')))
                      .toList(),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          _SectionCard(
            title: '提醒',
            children: [
              if (task.reminders.isEmpty)
                Text(context.tr('暂无提醒，可在编辑任务时添加'),
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.textSecondary),
                )
              else
                Column(
                  children: task.reminders
                      .map(
                        (reminder) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.alarm_outlined),
                          title: Text(dateFormat.format(reminder.remindAt)),
                          subtitle: Text(context.tr('到期前提醒')),
                        ),
                      )
                      .toList(),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionCard(
            title: '元信息',
            children: [
              _InfoRow(label: '创建时间', value: createdLabel),
              _InfoRow(label: '最近更新', value: updatedLabel),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _confirmDelete(context, controller),
                  icon: const Icon(Icons.delete_outline),
                  label: Text(context.tr('删除任务')),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _openEditor(context, task),
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(context.tr('编辑任务')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openEditor(BuildContext context, Task task) async {
    final result = await TaskEditorSheet.show(context, task: task);
    if (result != null) {
      await controller.refresh();
      if (onTaskUpdated != null) {
        onTaskUpdated!(result);
      }
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    TaskDetailController controller,
  ) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.tr('删除任务')),
            content: Text(context.tr('确定要删除该任务吗？此操作无法撤销。')),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(context.tr('取消')),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(context.tr('删除')),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) {
      return;
    }
    final success = await controller.delete();
    if (!success || !context.mounted) {
      return;
    }
    onTaskDeleted?.call();
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(context.tr('任务已删除'))));
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: AppSpacing.md),
          Text(message),
          const SizedBox(height: AppSpacing.md),
          FilledButton(onPressed: onRetry, child: Text(context.tr('重试'))),
        ],
      ),
    );
  }
}
