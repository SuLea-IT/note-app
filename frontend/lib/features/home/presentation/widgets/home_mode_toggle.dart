import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_radius.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/localization/locale_utils.dart';
import '../../domain/entities/home_feed.dart';

class HomeModeToggle extends StatelessWidget {
  const HomeModeToggle({
    super.key,
    required this.displayMode,
    required this.onModeChanged,
  });

  final HomeDisplayMode displayMode;
  final ValueChanged<HomeDisplayMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _ModeButton(
            zhLabel: '列表模式',
            enLabel: 'List view',
            icon: Icons.view_list_outlined,
            isSelected: displayMode == HomeDisplayMode.list,
            onTap: () => onModeChanged(HomeDisplayMode.list),
          ),
          _ModeButton(
            zhLabel: '卡片模式',
            enLabel: 'Card view',
            icon: Icons.grid_view,
            isSelected: displayMode == HomeDisplayMode.card,
            onTap: () => onModeChanged(HomeDisplayMode.card),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.zhLabel,
    required this.enLabel,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String zhLabel;
  final String enLabel;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md,
            horizontal: AppSpacing.lg,
          ),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                context.tr(zhLabel, enLabel),
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

