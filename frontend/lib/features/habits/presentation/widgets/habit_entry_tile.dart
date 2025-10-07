import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_radius.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/localization/locale_utils.dart';
import '../../domain/entities/habit_entry.dart';
import '../../domain/entities/habit_status.dart';

class HabitEntryTile extends StatelessWidget {
  const HabitEntryTile({super.key, required this.entry, this.onToggle});

  final HabitEntry entry;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = entry.accentColor;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusBadge(status: entry.status),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      entry.timeLabel,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _statusLabel(context, entry.status),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (entry.reminderTime != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Icon(
                        Icons.alarm,
                        size: 16,
                        color: color,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        '${entry.reminderTime!.hour.toString().padLeft(2, '0')}:${entry.reminderTime!.minute.toString().padLeft(2, '0')}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: color,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  entry.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  entry.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                if (entry.repeatRule != null && entry.repeatRule!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${context.tr('重复：', 'Repeats: ')}${entry.repeatRule}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    _ChipBadge(
                      icon: Icons.local_fire_department,
                      label: context.tr(
                        '${entry.streakDays} 天连击',
                        '${entry.streakDays}-day streak',
                      ),
                      color: color,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    if (entry.completedToday)
                      _ChipBadge(
                        icon: Icons.check_circle,
                        label: context.tr('今天已完成', 'Completed today'),
                        color: color,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          IconButton(
            onPressed: onToggle,
            icon: Icon(
              entry.status == HabitStatus.completed
                  ? Icons.undo
                  : Icons.check_circle_outline,
            ),
            color: onToggle != null ? color : AppColors.textSecondary,
            tooltip: entry.status == HabitStatus.completed
                ? context.tr('撤销完成', 'Undo completion')
                : context.tr('标记完成', 'Mark as done'),
          ),
        ],
      ),
    );
  }

  String _statusLabel(BuildContext context, HabitStatus status) {
    return switch (status) {
      HabitStatus.upcoming => context.tr('待开始', 'Upcoming'),
      HabitStatus.inProgress => context.tr('进行中', 'In progress'),
      HabitStatus.completed => context.tr('已完成', 'Completed'),
    };
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final HabitStatus status;

  @override
  Widget build(BuildContext context) {
    final color = status.color;
    return Container(
      height: 46,
      width: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.15),
      ),
      child: Icon(
        switch (status) {
          HabitStatus.upcoming => Icons.schedule,
          HabitStatus.inProgress => Icons.play_arrow,
          HabitStatus.completed => Icons.check,
        },
        color: color,
      ),
    );
  }
}

class _ChipBadge extends StatelessWidget {
  const _ChipBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
