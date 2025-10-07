import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_radius.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/localization/locale_utils.dart';
import '../../domain/entities/habit_overview.dart';

class HabitOverviewPanel extends StatelessWidget {
  const HabitOverviewPanel({super.key, required this.overview});

  final HabitOverview overview;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 520;
          final tiles = [
            _OverviewTile(
              label: context.tr('专注时长', 'Focus time'),
              value: '${overview.focusMinutes} min',
              color: AppColors.accentPurple,
            ),
            _OverviewTile(
              label: context.tr('连续打卡', 'Streak'),
              value: '${overview.completedStreak} ${context.tr('天', 'days')}',
              color: AppColors.accentGreen,
            ),
            _OverviewTile(
              label: context.tr('达成率', 'Completion rate'),
              value: '${(overview.completionRate * 100).toStringAsFixed(0)}%',
              color: AppColors.accentPink,
            ),
            _OverviewTile(
              label: context.tr('活跃天数', 'Active days'),
              value: '${overview.activeDays}',
              color: AppColors.accentYellow,
            ),
          ];

          if (isCompact) {
            return Column(
              children: [
                Row(
                  children: [tiles[0], const SizedBox(width: AppSpacing.lg), tiles[1]],
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [tiles[2], const SizedBox(width: AppSpacing.lg), tiles[3]],
                ),
              ],
            );
          }

          final children = <Widget>[];
          for (final tile in tiles) {
            if (children.isNotEmpty) {
              children.add(const SizedBox(width: AppSpacing.lg));
            }
            children.add(tile);
          }

          return Row(children: children);
        },
      ),
    );
  }
}

class _OverviewTile extends StatelessWidget {
  const _OverviewTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              value,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: _darken(color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _darken(Color color, [double amount = .15]) {
  final hsl = HSLColor.fromColor(color);
  final lightness = (hsl.lightness - amount).clamp(0.0, 1.0);
  return hsl.withLightness(lightness).toColor();
}