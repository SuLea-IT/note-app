import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_radius.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../domain/entities/habit_day.dart';

class HabitDayTimeline extends StatelessWidget {
  const HabitDayTimeline({super.key, required this.days});

  final List<HabitDay> days;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final day in days)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: _HabitDayChip(day: day),
            ),
        ],
      ),
    );
  }
}

class _HabitDayChip extends StatelessWidget {
  const _HabitDayChip({required this.day});

  final HabitDay day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dayLabel = DateFormat('d', 'zh_CN').format(day.date);
    final weekLabel = DateFormat('E', 'zh_CN').format(day.date);
    final double completion = day.totalCount == 0
        ? 0.0
        : math.min(1.0, math.max(0.0, day.completedCount / day.totalCount));
    final baseColor = day.isToday ? AppColors.primary : AppColors.textSecondary;
    final percentage = (day.completionRate ?? completion) * 100;

    return Container(
      width: 64,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        color: day.isToday ? AppColors.primaryLight : Colors.white,
        border: Border.all(
          color: day.isToday ? AppColors.primary : AppColors.border,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            weekLabel,
            style: theme.textTheme.labelMedium?.copyWith(
              color: baseColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            height: 18,
            width: 18,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: day.isToday ? AppColors.primary : AppColors.border,
            ),
            child: Text(
              dayLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: day.isToday ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _ProgressIndicator(value: completion, highlighted: day.isToday),
          const SizedBox(height: AppSpacing.xs),
          Text('${day.completedCount}/${day.totalCount}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text('${percentage.toStringAsFixed(0)}%',
            style: theme.textTheme.labelSmall?.copyWith(
              color: baseColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressIndicator extends StatelessWidget {
  const _ProgressIndicator({required this.value, required this.highlighted});

  final double value;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final double width = math.min(1.0, math.max(0.0, value));

    return Container(
      height: 6,
      width: 32,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: highlighted ? AppColors.primaryLight : AppColors.divider,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: width,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: highlighted ? AppColors.primary : AppColors.accentGreen,
            ),
          ),
        ),
      ),
    );
  }
}
