import 'package:flutter/material.dart';
import '../../core/localization/locale_utils.dart';

import '../../core/constants/app_spacing.dart';

class ProfilePlaceholder extends StatelessWidget {
  const ProfilePlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircleAvatar(
            radius: 36,
            child: Icon(Icons.person_outline, size: 32),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(context.tr('个人中心建设中'),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(context.tr('可在此拓展资料、统计面板、主题设置等功能。'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
