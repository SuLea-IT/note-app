import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/localization/locale_utils.dart';
import '../../notifications/application/notification_controller.dart';
import '../application/task_board_controller.dart';
import '../application/task_detail_controller.dart';
import '../data/task_repository.dart';
import '../domain/entities/task.dart';
import 'task_detail_screen.dart';
import 'task_editor_sheet.dart';

class TaskBoardScreen extends StatelessWidget {
  const TaskBoardScreen({super.key});

  static Route<dynamic> route() {
    return MaterialPageRoute(builder: (_) => const TaskBoardScreen());
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<TaskBoardController>(
      create: (context) => TaskBoardController(
        context.read<TaskRepository>(),
        notifications: context.read<NotificationController?>(),
      )..load(),
      child: const _TaskBoardView(),
    );
  }
}

class _TaskBoardView extends StatefulWidget {
  const _TaskBoardView();

  @override
  State<_TaskBoardView> createState() => _TaskBoardViewState();
}

class _TaskBoardViewState extends State<_TaskBoardView> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final controller = context.read<TaskBoardController>();
    controller.search(_searchController.text);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskBoardController>(
      builder: (context, controller, _) {
        final state = controller.state;
        return Scaffold(
          appBar: AppBar(
            title: Text(context.tr('任务清单', 'Task Board')),
            actions: [
              IconButton(
                tooltip: context.tr('刷新', 'Refresh'),
                onPressed: controller.refresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openEditor(context),
            icon: const Icon(Icons.add_task),
            label: Text(context.tr('新建任务', 'New Task')),
          ),
          body: SafeArea(
            child: Column(
              children: [
                _buildSearchBar(state, controller),
                _buildStatsRow(state),
                _buildFilterBar(state, controller),
                _buildSelectionBar(state, controller),
                const Divider(height: 1),
                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: controller.refresh,
                    child: _buildBody(state, controller),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchBar(TaskBoardState state, TaskBoardController controller) {
    _syncSearchController(state);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.sm,
      ),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search),
          hintText: context.tr('搜索任务', 'Search tasks'),
          suffixIcon: state.query.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: context.tr('清除搜索', 'Clear search'),
                  onPressed: () {
                    _searchController.clear();
                    controller.clearSearch();
                  },
                ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow(TaskBoardState state) {
    final stats = state.statistics;
    if (stats == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              label: context.tr('今日待办', 'Today'),
              value: stats.pendingToday,
              color: const Color(0xFF42A5F5),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _StatCard(
              label: context.tr('逾期任务', 'Overdue'),
              value: stats.overdue,
              color: const Color(0xFFE57373),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _StatCard(
              label: context.tr('本周计划', 'This Week'),
              value: stats.upcomingWeek,
              color: const Color(0xFFFFB74D),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _StatCard(
              label: context.tr('今日完成', 'Completed Today'),
              value: stats.completedToday,
              color: const Color(0xFF66BB6A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(TaskBoardState state, TaskBoardController controller) {
    final allTags = state.tasks
        .expand((task) => task.tags)
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toSet();
    final tagList = allTags.toList()..sort();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: TaskListGrouping.values.map((group) {
              final selected = state.grouping == group;
              return ChoiceChip(
                label: Text(_groupingLabel(group)),
                selected: selected,
                onSelected: (_) => controller.changeGrouping(group),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: TaskStatus.values.map((status) {
              final selected = state.statuses.contains(status);
              return FilterChip(
                label: Text(status.label),
                selected: selected,
                onSelected: (_) => controller.toggleStatus(status),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: TaskPriority.values.map((priority) {
              final selected = state.priorities.contains(priority);
              return FilterChip(
                label: Text(priority.label),
                selected: selected,
                onSelected: (_) => controller.togglePriority(priority),
              );
            }).toList(),
          ),
          if (tagList.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: tagList.map((tag) {
                final selected = state.tags.contains(tag);
                return FilterChip(
                  label: Text('#$tag'),
                  selected: selected,
                  onSelected: (_) => controller.toggleTag(tag),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSelectionBar(TaskBoardState state, TaskBoardController controller) {
    final selectedCount = state.selectedTaskIds.length;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: selectedCount == 0
          ? const SizedBox(height: 0)
          : Container(
              width: double.infinity,
              color: AppColors.surface,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Text(
                    context.tr('已选择$selectedCount项', '$selectedCount selected'),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: controller.clearSelection,
                    child: Text(context.tr('取消', 'Cancel')),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton.icon(
                    onPressed: state.isBulkCompleting
                        ? null
                        : () => controller.bulkCompleteSelected(),
                    icon: state.isBulkCompleting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle),
                    label: Text(context.tr('批量完成', 'Complete selected')),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildBody(TaskBoardState state, TaskBoardController controller) {
    switch (state.status) {
      case TaskBoardStatus.initial:
      case TaskBoardStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case TaskBoardStatus.failure:
        return _ErrorView(
          message:
              state.error ?? context.tr('加载失败，请稍后重试', 'Failed to load, please try again'),
          onRetry: controller.refresh,
        );
      case TaskBoardStatus.ready:
        if (state.sections.isEmpty) {
          return _EmptyView(onCreate: () => _openEditor(context));
        }
        return ListView.builder(
          padding: const EdgeInsets.only(
            left: AppSpacing.xl,
            right: AppSpacing.xl,
            bottom: AppSpacing.xl + 80,
            top: AppSpacing.sm,
          ),
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: state.sections.length,
          itemBuilder: (context, index) {
            final section = state.sections[index];
            return _TaskSectionCard(
              section: section,
              onTaskTap: (task) => _openDetail(context, task.id),
              onToggleComplete: (task, completed) => controller.markTaskStatus(
                task.id,
                completed ? TaskStatus.completed : TaskStatus.pending,
              ),
              onEdit: (task) => _openEditor(context, task: task),
              onDelete: (task) => controller.deleteTask(task.id),
              onToggleSelect: (task) => controller.toggleSelection(task.id),
              isSelected: (task) => state.selectedTaskIds.contains(task.id),
            );
          },
        );
    }
  }

  Future<void> _openEditor(BuildContext context, {Task? task}) async {
    final createdMessage = context.tr('任务创建成功', 'Task created');
    final updatedMessage = context.tr('任务更新成功', 'Task updated');
    final messenger = ScaffoldMessenger.of(context);
    final controller = context.read<TaskBoardController>();

    final result = await TaskEditorSheet.show(context, task: task);
    if (!mounted || result == null) {
      return;
    }

    await controller.refresh();
    if (!mounted) {
      return;
    }

    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(task == null ? createdMessage : updatedMessage),
        ),
      );
  }

  Future<void> _openDetail(BuildContext context, String taskId) async {
    final board = context.read<TaskBoardController>();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider<TaskDetailController>(
          create: (context) => TaskDetailController(
            context.read<TaskRepository>(),
            taskId,
          )..load(),
          child: TaskDetailScreen(
            taskId: taskId,
            onTaskUpdated: (updated) => board.refresh(),
            onTaskDeleted: () => board.refresh(),
          ),
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    await board.refresh();
  }

  void _syncSearchController(TaskBoardState state) {
    if (_searchController.text == state.query) {
      return;
    }
    _searchController.value = TextEditingValue(
      text: state.query,
      selection: TextSelection.fromPosition(
        TextPosition(offset: state.query.length),
      ),
    );
  }

  String _groupingLabel(TaskListGrouping grouping) {
    switch (grouping) {
      case TaskListGrouping.byDate:
        return context.tr('按日期', 'By date');
      case TaskListGrouping.byPriority:
        return context.tr('按优先级', 'By priority');
      case TaskListGrouping.byStatus:
        return context.tr('按状态', 'By status');
    }
  }
}

class _TaskSectionCard extends StatelessWidget {
  const _TaskSectionCard({
    required this.section,
    required this.onTaskTap,
    required this.onToggleComplete,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleSelect,
    required this.isSelected,
  });

  final TaskSection section;
  final ValueChanged<Task> onTaskTap;
  final void Function(Task task, bool completed) onToggleComplete;
  final ValueChanged<Task> onEdit;
  final ValueChanged<Task> onDelete;
  final ValueChanged<Task> onToggleSelect;
  final bool Function(Task) isSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                section.label,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (section.caption != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Text(
                  section.caption!,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: section.tasks.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final task = section.tasks[index];
                return _TaskTile(
                  task: task,
                  selected: isSelected(task),
                  onToggleComplete: (completed) => onToggleComplete(task, completed),
                  onTap: () => onTaskTap(task),
                  onEdit: () => onEdit(task),
                  onDelete: () => onDelete(task),
                  onToggleSelect: () => onToggleSelect(task),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

enum _TaskTileAction { edit, complete, reopen, delete }

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.task,
    required this.selected,
    required this.onToggleComplete,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleSelect,
  });

  final Task task;
  final bool selected;
  final ValueChanged<bool> onToggleComplete;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleSelect;

  @override
  Widget build(BuildContext context) {
    final due = task.dueAt;
    final dueLabel = due != null
        ? DateFormat('MM-dd HH:mm').format(due)
        : context.tr('未设置日期', 'No due date');
    final subtitleParts = <String>[
      dueLabel,
      if (task.tags.isNotEmpty) task.tags.map((tag) => '#$tag').join(' · '),
    ];
    final subtitle =
        subtitleParts.where((value) => value.isNotEmpty).join(' · ');

    final Color statusColor;
    switch (task.status) {
      case TaskStatus.completed:
        statusColor = Colors.green.shade600;
        break;
      case TaskStatus.cancelled:
        statusColor = Colors.grey;
        break;
      case TaskStatus.inProgress:
        statusColor = Colors.orange;
        break;
      case TaskStatus.pending:
        statusColor = task.priority.color;
        break;
    }

    final isCompleted = task.status == TaskStatus.completed;

    return Dismissible(
      key: ValueKey(task.id),
      background: Container(
        color: Colors.green.shade100,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: const Icon(Icons.check_circle, color: Colors.green),
      ),
      secondaryBackground: Container(
        color: Colors.red.shade100,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: const Icon(Icons.delete_outline, color: Colors.red),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onToggleComplete(true);
          return false;
        }
        final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(context.tr('删除任务', 'Delete Task')),
                content: Text(
                  context.tr('确定要删除该任务吗？', 'Are you sure you want to delete this task?'),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(context.tr('取消', 'Cancel')),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(context.tr('删除', 'Delete')),
                  ),
                ],
              ),
            ) ??
            false;
        if (confirmed) {
          onDelete();
        }
        return confirmed;
      },
      child: ListTile(
        selected: selected,
        selectedTileColor: AppColors.primary.withValues(alpha: 0.08),
        onTap: onTap,
        onLongPress: onToggleSelect,
        leading: Checkbox(
          value: isCompleted,
          onChanged: (value) => onToggleComplete(value ?? false),
        ),
        title: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                task.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (selected)
              const Padding(
                padding: EdgeInsets.only(left: AppSpacing.sm),
                child: Icon(
                  Icons.check_circle,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
          ],
        ),
        subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
        trailing: PopupMenuButton<_TaskTileAction>(
          onSelected: (action) {
            switch (action) {
              case _TaskTileAction.edit:
                onEdit();
                break;
              case _TaskTileAction.complete:
                onToggleComplete(true);
                break;
              case _TaskTileAction.reopen:
                onToggleComplete(false);
                break;
              case _TaskTileAction.delete:
                onDelete();
                break;
            }
          },
          itemBuilder: (context) {
            return <PopupMenuEntry<_TaskTileAction>>[
              PopupMenuItem(
                value: _TaskTileAction.edit,
                child: Text(context.tr('编辑', 'Edit')),
              ),
              PopupMenuItem(
                value: isCompleted ? _TaskTileAction.reopen : _TaskTileAction.complete,
                child: Text(
                  isCompleted
                      ? context.tr('重新打开', 'Reopen')
                      : context.tr('标记完成', 'Mark complete'),
                ),
              ),
              PopupMenuItem(
                value: _TaskTileAction.delete,
                child: Text(context.tr('删除', 'Delete')),
              ),
            ];
          },
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value.toString(),
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.onRetry,
  });

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
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: onRetry,
            child: Text(context.tr('重试', 'Retry')),
          ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onCreate});

  final Future<void> Function() onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.task_alt_outlined,
              size: 64,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              context.tr('今日还没有任务，立即为自己制定一个目标吧',
                  'No tasks yet. Set a goal for today!'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: () => onCreate(),
              icon: const Icon(Icons.add_task),
              label: Text(context.tr('新建任务', 'New Task')),
            ),
          ],
        ),
      ),
    );
  }
}
