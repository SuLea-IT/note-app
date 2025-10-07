import 'package:flutter/material.dart';

import '../../../../core/constants/app_radius.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/localization/locale_utils.dart';
import '../../domain/entities/home_feed.dart';
import '../../domain/entities/quick_action.dart';

class QuickActionGrid extends StatelessWidget {
  const QuickActionGrid({
    super.key,
    required this.actions,
    required this.displayMode,
    required this.onActionTap,
  });

  final List<QuickActionCard> actions;
  final HomeDisplayMode displayMode;
  final ValueChanged<QuickActionCard> onActionTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('快速操作', 'Quick Actions'),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: AppSpacing.md),
        switch (displayMode) {
          HomeDisplayMode.card => _QuickActionCardGrid(
              actions: actions,
              onActionTap: onActionTap,
            ),
          HomeDisplayMode.list => _QuickActionList(
              actions: actions,
              onActionTap: onActionTap,
            ),
        },
      ],
    );
  }
}

class _QuickActionCardGrid extends StatelessWidget {
  const _QuickActionCardGrid({required this.actions, required this.onActionTap});

  final List<QuickActionCard> actions;
  final ValueChanged<QuickActionCard> onActionTap;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final cardWidth = (width - (AppSpacing.xl * 2) - AppSpacing.md) / 2;

    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: [
        for (final action in actions)
          SizedBox(
            width: cardWidth,
            child: _QuickCard(
              action: action,
              onTap: () => onActionTap(action),
            ),
          ),
      ],
    );
  }
}

class _QuickActionList extends StatelessWidget {
  const _QuickActionList({required this.actions, required this.onActionTap});

  final List<QuickActionCard> actions;
  final ValueChanged<QuickActionCard> onActionTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final action in actions) ...[
          _QuickListTile(
            action: action,
            onTap: () => onActionTap(action),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _QuickCard extends StatelessWidget {
  const _QuickCard({required this.action, required this.onTap});

  final QuickActionCard action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(AppRadius.lg);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: Ink(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: action.background,
            borderRadius: borderRadius,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: action.foreground.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  action.icon ?? Icons.add_circle_outline,
                  color: action.foreground,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                action.title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: action.foreground,
                    ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                action.subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: action.foreground.withValues(alpha: 0.7),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickListTile extends StatelessWidget {
  const _QuickListTile({required this.action, required this.onTap});

  final QuickActionCard action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
            border: Border.all(color: action.background.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: action.background.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  action.icon ?? Icons.add_circle_outline,
                  color: action.foreground,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      action.subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: action.foreground.withValues(alpha: 0.7),
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: action.foreground.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
