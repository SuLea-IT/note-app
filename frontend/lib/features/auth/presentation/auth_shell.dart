import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/locale_utils.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_spacing.dart';
import '../application/auth_controller.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class AuthShell extends StatefulWidget {
  const AuthShell({super.key});

  @override
  State<AuthShell> createState() => _AuthShellState();
}

class _AuthShellState extends State<AuthShell> {
  bool _showLogin = true;

  void _onSwitchToRegister() {
    if (_showLogin) {
      setState(() {
        _showLogin = false;
      });
    }
  }

  void _onSwitchToLogin() {
    if (!_showLogin) {
      setState(() {
        _showLogin = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Consumer<AuthController>(
        builder: (context, auth, _) {
          final state = auth.state;
          final isLoading = state.status == AuthStatus.authenticating;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            final message = auth.state.errorMessage;
            if (message != null && mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(message)));
              auth.dismissError();
            }
          });

          return SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final content = _showLogin
                    ? LoginScreen(
                        isLoading: isLoading,
                        onSwitchToRegister: _onSwitchToRegister,
                      )
                    : RegisterScreen(
                        isLoading: isLoading,
                        onSwitchToLogin: _onSwitchToLogin,
                      );

                final double availableHeight =
                    (constraints.maxHeight - AppSpacing.xl * 2).clamp(
                      0.0,
                      double.infinity,
                    );

                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: availableHeight),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: AppSpacing.xl),
                        _AuthHeader(showLogin: _showLogin),
                        const SizedBox(height: AppSpacing.lg),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          transitionBuilder: (child, animation) =>
                              FadeTransition(opacity: animation, child: child),
                          child: content,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _AuthHeader extends StatelessWidget {
  const _AuthHeader({required this.showLogin});

  final bool showLogin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = showLogin ? context.tr('欢迎回来', 'Welcome back') : context.tr('注册新账号', 'Create a new account');
    final subtitle = showLogin
        ? context.tr('登录后即可跨设备同步笔记、日记与习惯数据',
            'Sign in to sync notes, diaries, and habits across devices')
        : context.tr('注册完成即可在多设备间保持数据一致',
            'Register to keep your data in sync across devices');

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFA05F), AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
