import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/locale_utils.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../habits/application/habit_controller.dart';
import '../domain/entities/habit_history_entry.dart';
import '../domain/entities/habit_status.dart';
import 'add_habit_screen.dart';
import 'widgets/habit_day_timeline.dart';
import 'widgets/habit_entry_tile.dart';
import 'widgets/habit_overview_panel.dart';

class HabitScreen extends StatefulWidget {
  const HabitScreen({super.key});

  @override
  State<HabitScreen> createState() => _HabitScreenState();
}

class _HabitScreenState extends State<HabitScreen> {
  @override
  void initState() {
    super.initState();
    final controller = context.read<HabitController>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<HabitController>();
    final state = controller.state;

    if (state.status == HabitStatusState.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.status == HabitStatusState.failure) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(state.error ?? '加载失败', textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            FilledButton(onPressed: controller.load, child: Text(context.tr('重试'))),
          ],
        ),
      );
    }

    final feed = state.feed;
    if (feed == null) {
      return const SizedBox.shrink();
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HabitHeader(),
                const SizedBox(height: AppSpacing.lg),
                HabitDayTimeline(days: feed.days),
                const SizedBox(height: AppSpacing.xl),
                HabitOverviewPanel(overview: feed.overview),
                if (state.error != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  _HabitErrorBanner(message: state.error!),
                  const SizedBox(height: AppSpacing.lg),
                ],
                const SizedBox(height: AppSpacing.xl),
                Text(context.tr('打卡安排'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          sliver: SliverList.builder(
            itemCount: feed.entries.length,
            itemBuilder: (context, index) {
              final entry = feed.entries[index];
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == feed.entries.length - 1
                      ? AppSpacing.xl
                      : AppSpacing.md,
                ),
                child: HabitEntryTile(
                  entry: entry,
                  onToggle: () => controller.toggleStatus(entry),
                ),
              );
            },
          ),
        ),
        if (feed.history.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.tr('最近打卡'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _HabitHistoryList(history: feed.history),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _HabitHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final headerTitle = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                headerTitle,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(context.tr('Keep it up! Your consistency is visible.'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AddHabitScreen(),
              ),
            );
          },
          icon: const Icon(Icons.add_task_outlined),
          label: Text(context.tr('新建习惯')),
        ),
      ],
    );
  }
}

class _HabitErrorBanner extends StatelessWidget {
  const _HabitErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final errorColor = theme.colorScheme.error;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: errorColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: errorColor.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: errorColor),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(color: errorColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _HabitHistoryList extends StatelessWidget {
  const _HabitHistoryList({required this.history});

  final List<HabitHistoryEntry> history;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: history.take(6).map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            children: [
              Icon(
                _historyIcon(entry.status),
                color: entry.status.color,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  _historyLabel(entry),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              Text(
                DateFormat('MM-dd HH:mm').format(entry.completedAt ?? entry.date),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  IconData _historyIcon(HabitStatus status) {
    switch (status) {
      case HabitStatus.completed:
        return Icons.check_circle;
      case HabitStatus.inProgress:
        return Icons.play_circle_outline;
      case HabitStatus.upcoming:
        return Icons.radio_button_unchecked;
    }
  }

  String _historyLabel(HabitHistoryEntry entry) {
    switch (entry.status) {
      case HabitStatus.completed:
        return '完成 ${entry.title.isEmpty ? entry.habitId : entry.title}';
      case HabitStatus.inProgress:
        return '进行中 ${entry.title.isEmpty ? entry.habitId : entry.title}';
      case HabitStatus.upcoming:
        return '计划中 ${entry.title.isEmpty ? entry.habitId : entry.title}';
    }
  }
}
