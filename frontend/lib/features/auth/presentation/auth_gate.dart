import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../home/presentation/home_screen.dart';
import '../application/auth_controller.dart';
import 'auth_shell.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthController>(
      builder: (context, auth, _) {
        final state = auth.state;
        switch (state.status) {
          case AuthStatus.initializing:
            return const _SplashView();
          case AuthStatus.authenticated:
            return const HomeScreen();
          case AuthStatus.authenticating:
          case AuthStatus.unauthenticated:
            return const AuthShell();
        }
      },
    );
  }
}

class _SplashView extends StatelessWidget {
  const _SplashView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
