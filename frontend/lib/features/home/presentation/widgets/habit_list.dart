import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_radius.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/localization/locale_utils.dart';
import '../../domain/entities/habit.dart';
import '../../domain/entities/home_feed.dart';

class HabitList extends StatelessWidget {
  const HabitList({
    super.key,
    required this.habits,
    required this.mode,
    this.onHabitTap,
  });

  final List<DailyHabit> habits;
  final HomeDisplayMode mode;
  final ValueChanged<DailyHabit>? onHabitTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('今日习惯', 'Today\'s Habits'),
          style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: AppSpacing.md),
        switch (mode) {
          HomeDisplayMode.list => Column(
              children: [
                for (final habit in habits) ...[
                  _HabitTile(
                    habit: habit,
                    onTap: onHabitTap != null ? () => onHabitTap!(habit) : null,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ),
          HomeDisplayMode.card => _HabitCardGrid(
              habits: habits,
              onHabitTap: onHabitTap,
            ),
        },
      ],
    );
  }
}

class _HabitCardGrid extends StatelessWidget {
  const _HabitCardGrid({required this.habits, required this.onHabitTap});

  final List<DailyHabit> habits;
  final ValueChanged<DailyHabit>? onHabitTap;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final cardWidth = (width - (AppSpacing.xl * 2) - AppSpacing.md) / 2;

    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: [
        for (final habit in habits)
          SizedBox(
            width: cardWidth,
            child: _HabitCard(
              habit: habit,
              onTap: onHabitTap != null ? () => onHabitTap!(habit) : null,
            ),
          ),
      ],
    );
  }
}

class _HabitTile extends StatelessWidget {
  const _HabitTile({required this.habit, this.onTap});

  final DailyHabit habit;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderRadius = BorderRadius.circular(AppRadius.lg);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: Ink(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: borderRadius,
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              _CheckCircle(completed: habit.isCompleted),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            habit.label,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          habit.timeRange,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      habit.notes,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HabitCard extends StatelessWidget {
  const _HabitCard({required this.habit, this.onTap});

  final DailyHabit habit;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderRadius = BorderRadius.circular(AppRadius.lg);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: Ink(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: borderRadius,
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _CheckCircle(completed: habit.isCompleted),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    habit.timeRange,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                habit.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                habit.notes,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckCircle extends StatelessWidget {
  const _CheckCircle({required this.completed});

  final bool completed;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 32,
      width: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: completed ? AppColors.accentGreen : Colors.white,
        border: Border.all(
          color: completed ? Colors.transparent : AppColors.border,
        ),
        boxShadow: [
          if (completed)
            BoxShadow(
              color: AppColors.accentGreen.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      child: Icon(
        completed ? Icons.check : Icons.add,
        color: completed ? Colors.white : AppColors.textSecondary,
      ),
    );
  }
}
