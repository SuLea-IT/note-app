import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import '../core/localization/app_localizations.dart';
import '../core/network/api_client.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/data/remote_auth_repository.dart';
import '../features/auth/domain/entities/auth_tokens.dart';
import '../features/auth/domain/entities/auth_user.dart';
import '../features/auth/presentation/auth_gate.dart';
import '../features/diary/application/diary_controller.dart';
import '../features/diary/data/mock_diary_repository.dart';
import '../features/diary/data/remote_diary_repository.dart';
import '../features/habits/application/habit_controller.dart';
import '../features/habits/data/mock_habit_repository.dart';
import '../features/habits/data/remote_habit_repository.dart';
import '../features/home/application/home_controller.dart';
import '../features/home/data/mock_home_repository.dart';
import '../features/home/data/remote_home_repository.dart';
import '../features/notes/data/mock_note_repository.dart';
import '../features/notes/data/note_repository.dart';
import '../features/notes/data/remote_note_repository.dart';
import '../features/tasks/data/mock_task_repository.dart';
import '../features/tasks/data/remote_task_repository.dart';
import '../features/tasks/data/task_repository.dart';
import '../features/audio_notes/data/audio_note_repository.dart';
import '../features/audio_notes/data/mock_audio_note_repository.dart';
import '../features/audio_notes/data/remote_audio_note_repository.dart';
import '../features/audio_notes/data/audio_upload_service.dart';
import '../features/profile/data/mock_profile_repository.dart';
import '../features/profile/data/profile_repository.dart';
import '../features/profile/data/remote_profile_repository.dart';
import '../features/search/data/mock_search_repository.dart';
import '../features/search/data/remote_search_repository.dart';
import '../features/search/data/search_repository.dart';
import '../features/notifications/application/notification_controller.dart';
import '../features/notifications/data/mock_notification_repository.dart';
import '../features/notifications/data/notification_repository.dart';
import '../features/notifications/data/remote_notification_repository.dart';

class NoteApp extends StatelessWidget {
  const NoteApp({super.key, this.useRemote = true});

  final bool useRemote;

  @override
  Widget build(BuildContext context) {
    if (!useRemote) {
      final mockUser = AuthUser(
        id: 'mock-user',
        email: 'demo@example.com',
        displayName: '演示账号',
        preferredLocale: 'zh-CN',
        createdAt: DateTime.now(),
      );

      final mockRepository = _MockAuthRepository(mockUser);
      final initialSession = mockRepository.seedSession;

      return MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthController>(
            create: (_) =>
                AuthController(mockRepository, initialSession: initialSession),
          ),
          Provider<NoteRepository>(create: (_) => MockNoteRepository()),
          Provider<TaskRepository>(create: (_) => MockTaskRepository()),
          Provider<AudioNoteRepository>(create: (_) => MockAudioNoteRepository()),
          Provider<AudioUploadService>(create: (_) => MockAudioUploadService()),
          Provider<ProfileRepository>(create: (_) => MockProfileRepository()),
          Provider<SearchRepository>(create: (_) => MockSearchRepository()),
          Provider<NotificationRepository>(create: (_) => MockNotificationRepository()),
          ChangeNotifierProvider<NotificationController>(
            create: (context) => NotificationController(
              context.read<AuthController>(),
              context.read<NotificationRepository>(),
              enableMessaging: false,
            ),
          ),
          ChangeNotifierProvider<HomeController>(
            create: (_) => HomeController(const MockHomeRepository()),
          ),
          ChangeNotifierProvider<HabitController>(
            create: (_) => HabitController(MockHabitRepository()),
          ),
          ChangeNotifierProvider<DiaryController>(
            create: (_) => DiaryController(MockDiaryRepository()),
          ),
        ],
        child: const _AppShell(),
      );
    }

    return Provider<ApiClient>(
      create: (_) => ApiClient(),
      dispose: (_, client) => client.close(),
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthController>(
            create: (context) => AuthController(
              RemoteAuthRepository(context.read<ApiClient>()),
              apiClient: context.read<ApiClient>(),
            ),
          ),
          Provider<NoteRepository>(
            create: (context) => RemoteNoteRepository(
              context.read<ApiClient>(),
              context.read<AuthController>(),
            ),
          ),
          ProxyProvider2<ApiClient, AuthController, TaskRepository>(
            update: (_, client, auth, __) => RemoteTaskRepository(auth, client),
          ),
          ProxyProvider2<ApiClient, AuthController, AudioNoteRepository>(
            update: (_, client, auth, __) => RemoteAudioNoteRepository(auth, client),
          ),
          ProxyProvider2<ApiClient, AuthController, AudioUploadService>(
            update: (_, client, auth, __) => RemoteAudioUploadService(client, auth),
          ),
          ProxyProvider2<ApiClient, AuthController, ProfileRepository>(
            update: (_, client, auth, __) => RemoteProfileRepository(auth, client),
          ),
          ProxyProvider2<ApiClient, AuthController, SearchRepository>(
            update: (_, client, auth, __) => RemoteSearchRepository(auth, client),
          ),
          ProxyProvider2<ApiClient, AuthController, NotificationRepository>(
            update: (_, client, auth, __) => RemoteNotificationRepository(client),
          ),
          ChangeNotifierProxyProvider2<AuthController, NotificationRepository, NotificationController>(
            create: (context) => NotificationController(
              context.read<AuthController>(),
              context.read<NotificationRepository>(),
            ),
            update: (_, auth, repo, controller) {
              controller ??= NotificationController(auth, repo);
              return controller;
            },
          ),
          ChangeNotifierProvider<HomeController>(
            create: (context) => HomeController(
              RemoteHomeRepository(
                context.read<ApiClient>(),
                context.read<AuthController>(),
              ),
            ),
          ),
          ChangeNotifierProvider<HabitController>(
            create: (context) => HabitController(
              RemoteHabitRepository(
                context.read<ApiClient>(),
                context.read<AuthController>(),
              ),
            ),
          ),
          ChangeNotifierProvider<DiaryController>(
            create: (context) => DiaryController(
              RemoteDiaryRepository(
                context.read<ApiClient>(),
                context.read<AuthController>(),
              ),
            ),
          ),
        ],
        child: const _AppShell(),
      ),
    );
  }
}

class _AppShell extends StatelessWidget {
  const _AppShell();

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthController, NotificationController>(
      builder: (context, auth, notifications, _) {
        final code = auth.state.user?.preferredLocale ?? 'zh-CN';
        final segments = code.split(RegExp('[-_]'));
        final locale = Locale(
          segments.first,
          segments.length > 1 ? segments[1].toUpperCase() : null,
        );

        WidgetsBinding.instance.addPostFrameCallback((_) {
          final pending = notifications.consumePendingNavigation();
          if (pending != null) {
            notifications.openTask(pending);
          }
        });

        return MaterialApp(
          navigatorKey: notifications.navigatorKey,
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          title: locale.languageCode.startsWith('zh') ? '笔记助手' : 'Note Assistant',
          home: const AuthGate(),
        );
      },
    );
  }
}

class _MockAuthRepository implements AuthRepository {
  _MockAuthRepository(this._seedUser);

  final AuthUser _seedUser;

  AuthSessionPayload get seedSession => _buildSession(_seedUser);

  @override
  Future<AuthSessionPayload> login({
    required String email,
    required String password,
  }) async {
    final user = AuthUser(
      id: _seedUser.id,
      email: email,
      displayName: _seedUser.displayName ?? '演示账号',
      preferredLocale: _seedUser.preferredLocale,
      createdAt: DateTime.now(),
    );
    return _buildSession(user);
  }

  @override
  Future<AuthSessionPayload> register({
    required String email,
    required String password,
    required String displayName,
    required String preferredLocale,
  }) async {
    final resolvedName = displayName.trim().isEmpty
        ? (_seedUser.displayName ?? '演示账号')
        : displayName.trim();
    final user = AuthUser(
      id: _seedUser.id,
      email: email,
      displayName: resolvedName,
      preferredLocale: preferredLocale,
      createdAt: DateTime.now(),
    );
    return _buildSession(user);
  }

  AuthSessionPayload _buildSession(AuthUser user) {
    final now = DateTime.now();
    final tokens = AuthTokens(
      accessToken: 'mock-access-${now.millisecondsSinceEpoch}',
      refreshToken: 'mock-refresh-${now.millisecondsSinceEpoch}',
      tokenType: 'bearer',
      expiresAt: now.add(const Duration(hours: 1)),
      refreshExpiresAt: now.add(const Duration(days: 14)),
    );
    return AuthSessionPayload(user: user, tokens: tokens);
  }
}
