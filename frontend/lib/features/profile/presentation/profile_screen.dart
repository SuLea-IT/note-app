import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/locale_utils.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_spacing.dart';
import '../../auth/application/auth_controller.dart';
import '../application/profile_controller.dart';
import '../data/profile_repository.dart';
import '../domain/entities/profile.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.onLogout,
  });

  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ProfileController>(
      create: (context) => ProfileController(
        context.read<ProfileRepository>(),
        context.read<AuthController>(),
      )..load(),
      child: _ProfileView(onLogout: onLogout),
    );
  }
}

class _ProfileView extends StatelessWidget {
  const _ProfileView({required this.onLogout});

  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return Consumer<ProfileController>(
      builder: (context, controller, _) {
        final state = controller.state;
        switch (state.status) {
          case ProfileStatus.initial:
          case ProfileStatus.loading:
            return const Center(child: CircularProgressIndicator());
          case ProfileStatus.failure:
            return _ErrorView(
              message: state.error ?? '加载失败，请稍后再试',
              onRetry: controller.refresh,
            );
          case ProfileStatus.ready:
            final profile = state.profile!;
            return _ProfileContent(
              profile: profile,
              controller: controller,
              onLogout: onLogout,
              isUpdating: state.isUpdating,
            );
        }
      },
    );
  }
}

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({
    required this.profile,
    required this.controller,
    required this.onLogout,
    required this.isUpdating,
  });

  final UserProfile profile;
  final ProfileController controller;
  final Future<void> Function() onLogout;
  final bool isUpdating;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stats = profile.statistics;
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final joinedAt = profile.createdAt != null
        ? DateFormat.yMMMd(localeTag).format(profile.createdAt!.toLocal())
        : '--';

    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.xl + 80,
        ),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: AppColors.primary,
                  backgroundImage: profile.avatarUrl != null
                      ? NetworkImage(profile.avatarUrl!)
                      : null,
                  child: profile.avatarUrl == null
                      ? Text(
                          profile.resolvedName.characters.first.toUpperCase(),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  profile.resolvedName,
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  profile.email,
                  style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.md),
                Text('${context.tr('加入时间', 'Joined on')}: $joinedAt',
                    style: theme.textTheme.bodySmall),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: () => _showEditNameDialog(context, controller, profile),
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(context.tr('编辑昵称')),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          if (stats != null) _StatsGrid(stats: stats),
          const SizedBox(height: AppSpacing.xl),
          _SectionCard(
            title: context.tr('偏好设置', 'Preferences'),
            children: [
              ListTile(
                leading: const Icon(Icons.language_outlined),
                title: Text(context.tr('界面语言')),
                subtitle: Text(_languageLabel(context, profile.preferredLocale)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showLanguageSheet(context, controller, profile),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.dark_mode_outlined),
                title: Text(context.tr('主题模式')),
                subtitle: Text(_themeLabel(context, profile.themePreference)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showThemeSheet(context, controller, profile),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionCard(
            title: context.tr('安全与隐私', 'Security & Privacy'),
            children: [
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: Text(context.tr('修改密码')),
                subtitle: Text(context.tr('保持良好的安全习惯')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showChangePasswordDialog(context, controller),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.verified_user_outlined),
                title: Text(context.tr('双重验证')),
                subtitle: Text(context.tr('提升账号安全等级')),
                trailing: Switch(
                  value: false,
                  onChanged: (_) => _showComingSoon(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (controller.state.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Text(
                controller.state.error!,
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.error),
              ),
            ),
          FilledButton.icon(
            onPressed: isUpdating ? null : onLogout,
            icon: const Icon(Icons.logout),
            label: Text(isUpdating ? '正在处理…' : '退出登录'),
          ),
        ],
      ),
    );
  }

  void _showEditNameDialog(
    BuildContext context,
    ProfileController controller,
    UserProfile profile,
  ) {
    final nameController = TextEditingController(text: profile.displayName ?? '');
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('编辑昵称')),
        content: TextField(
          controller: nameController,
          maxLength: 30,
          decoration: InputDecoration(hintText: '输入新的昵称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.tr('取消')),
          ),
          FilledButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              await controller.update(UserProfileUpdate(displayName: newName));
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            child: Text(context.tr('保存')),
          ),
        ],
      ),
    );
  }

  void _showLanguageSheet(
    BuildContext context,
    ProfileController controller,
    UserProfile profile,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(context.tr('简体中文')),
              trailing: profile.preferredLocale == 'zh-CN'
                  ? const Icon(Icons.check, color: AppColors.primary)
                  : null,
              onTap: () async {
                await controller.update(UserProfileUpdate(preferredLocale: 'zh-CN'));
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
            ListTile(
              title: Text(context.tr('English')),
              trailing: profile.preferredLocale == 'en-US'
                  ? const Icon(Icons.check, color: AppColors.primary)
                  : null,
              onTap: () async {
                await controller.update(UserProfileUpdate(preferredLocale: 'en-US'));
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showThemeSheet(
    BuildContext context,
    ProfileController controller,
    UserProfile profile,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in ['system', 'light', 'dark'])
              ListTile(
                title: Text(_themeLabel(context, option)),
                trailing: profile.themePreference == option
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () async {
                  await controller.update(UserProfileUpdate(themePreference: option));
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog(
    BuildContext context,
    ProfileController controller,
  ) {
    final pwdController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('修改密码')),
        content: TextField(
          controller: pwdController,
          obscureText: true,
          decoration: InputDecoration(hintText: '新密码（至少 6 位）'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.tr('取消')),
          ),
          FilledButton(
            onPressed: () async {
              final value = pwdController.text.trim();
              if (value.length < 6) {
                ScaffoldMessenger.of(context)
                  ..clearSnackBars()
                  ..showSnackBar(SnackBar(content: Text(context.tr('密码长度至少 6 位'))));
                return;
              }
              await controller.update(UserProfileUpdate(password: value));
              if (context.mounted) Navigator.of(context).pop();
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                  ..clearSnackBars()
                  ..showSnackBar(SnackBar(content: Text(context.tr('密码已更新'))));
              }
            },
            child: Text(context.tr('保存')),
          ),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(context.tr('功能即将上线，敬请期待'))));
  }

  String _languageLabel(BuildContext context, String locale) {
    switch (locale) {
      case 'zh-CN':
        return context.tr('简体中文', 'Simplified Chinese');
      case 'en-US':
        return context.tr('English', 'English');
      default:
        return locale;
    }
  }

  String _themeLabel(BuildContext context, String? themePreference) {
    switch (themePreference) {
      case 'light':
        return context.tr('浅色模式', 'Light mode');
      case 'dark':
        return context.tr('深色模式', 'Dark mode');
      case 'system':
      default:
        return context.tr('跟随系统', 'System default');
    }
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});

  final UserStatistics stats;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _StatItem(label: context.tr('笔记', 'Notes'), value: stats.noteCount),
            _StatItem(label: context.tr('日记', 'Diaries'), value: stats.diaryCount),
            _StatItem(label: context.tr('习惯', 'Habits'), value: stats.habitCount),
            _StatItem(label: context.tr('连续打卡', 'Streak'), value: stats.habitStreak),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value.toString(),
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const Divider(height: 1),
          ...children,
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
