import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';
import '../data/auth_repository.dart';
import '../domain/auth_session.dart';
import '../domain/entities/auth_tokens.dart';
import '../domain/entities/auth_user.dart';

enum AuthStatus { initializing, unauthenticated, authenticating, authenticated }

class AuthState {
  const AuthState({
    this.status = AuthStatus.initializing,
    this.session,
    this.errorMessage,
  });

  final AuthStatus status;
  final AuthSessionPayload? session;
  final String? errorMessage;

  AuthUser? get user => session?.user;
  AuthTokens? get tokens => session?.tokens;

  AuthState copyWith({
    AuthStatus? status,
    AuthSessionPayload? session,
    bool clearSession = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      session: clearSession ? null : (session ?? this.session),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  AuthState withUpdatedTokens(AuthTokens tokens) {
    final current = session;
    if (current == null) {
      return this;
    }
    return copyWith(
      session: AuthSessionPayload(user: current.user, tokens: tokens),
    );
  }
}

class AuthController extends ChangeNotifier implements AuthSession {
  AuthController(
    this._repository, {
    SharedPreferences? preferences,
    AuthSessionPayload? initialSession,
    ApiClient? apiClient,
  }) : _apiClient = apiClient {
    if (initialSession != null) {
      _preferences = preferences;
      _state = AuthState(
        status: AuthStatus.authenticated,
        session: initialSession,
      );
      _applyToken(initialSession.tokens);
      notifyListeners();
    } else {
      _bootstrap(preferences);
    }
  }

  static const String _storageKey = 'auth.session';

  final AuthRepository _repository;
  final ApiClient? _apiClient;

  AuthState _state = const AuthState();
  SharedPreferences? _preferences;
  bool _disposed = false;

  AuthState get state => _state;

  @override
  AuthUser? get currentUser => _state.user;

  void updateCachedUser(AuthUser? Function(AuthUser?) updater) {
    final current = _state.user;
    final updated = updater(current);
    if (updated == null) {
      return;
    }
    final tokens = _state.tokens;
    if (tokens == null) {
      return;
    }
    final payload = AuthSessionPayload(user: updated, tokens: tokens);
    _setState((state) => state.copyWith(session: payload));
    unawaited(_storeSession(payload));
  }

  Future<void> login(String email, String password) async {
    _setState(
      (state) =>
          state.copyWith(status: AuthStatus.authenticating, clearError: true),
    );
    try {
      final session = await _repository.login(
        email: email.trim(),
        password: password,
      );
      await _storeSession(session);
      _setState(
        (state) => state.copyWith(
          status: AuthStatus.authenticated,
          session: session,
          clearError: true,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('AuthController login error: $error');
      debugPrintStack(stackTrace: stackTrace);
      _clearToken();
      _setState(
        (state) => state.copyWith(
          status: AuthStatus.unauthenticated,
          errorMessage: '登录失败，请检查邮箱或密码',
          clearSession: true,
        ),
      );
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
    required String preferredLocale,
  }) async {
    _setState(
      (state) =>
          state.copyWith(status: AuthStatus.authenticating, clearError: true),
    );
    try {
      final session = await _repository.register(
        email: email.trim(),
        password: password,
        displayName: displayName.trim(),
        preferredLocale: preferredLocale,
      );
      await _storeSession(session);
      _setState(
        (state) => state.copyWith(
          status: AuthStatus.authenticated,
          session: session,
          clearError: true,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('AuthController register error: $error');
      debugPrintStack(stackTrace: stackTrace);
      _clearToken();
      _setState(
        (state) => state.copyWith(
          status: AuthStatus.unauthenticated,
          errorMessage: '注册失败，请稍后再试',
          clearSession: true,
        ),
      );
    }
  }

  Future<void> logout() async {
    await _ensurePreferences();
    await _preferences?.remove(_storageKey);
    _clearToken();
    _setState((state) => const AuthState(status: AuthStatus.unauthenticated));
  }

  void dismissError() {
    if (_state.errorMessage == null) {
      return;
    }
    _setState((state) => state.copyWith(clearError: true));
  }

  Future<void> _bootstrap(SharedPreferences? preferences) async {
    _setState((state) => state.copyWith(status: AuthStatus.initializing));
    try {
      _preferences = preferences ?? await SharedPreferences.getInstance();
      final cached = _preferences?.getString(_storageKey);
      if (cached != null && cached.isNotEmpty) {
        final decoded = jsonDecode(cached);
        if (decoded is Map<String, dynamic>) {
          try {
            final session = AuthSessionPayload.fromJson(decoded);
            _applyToken(session.tokens);
            _setState(
              (state) => state.copyWith(
                status: AuthStatus.authenticated,
                session: session,
                clearError: true,
              ),
            );
            return;
          } catch (error, stackTrace) {
            debugPrint('AuthController decode session error: $error');
            debugPrintStack(stackTrace: stackTrace);
          }
        }
      }
      _clearToken();
      _setState(
        (state) => state.copyWith(
          status: AuthStatus.unauthenticated,
          clearSession: true,
          clearError: true,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('AuthController bootstrap error: $error');
      debugPrintStack(stackTrace: stackTrace);
      _clearToken();
      _setState(
        (state) => state.copyWith(
          status: AuthStatus.unauthenticated,
          clearSession: true,
          errorMessage: '无法加载登录状态，请稍后再试',
        ),
      );
    }
  }

  Future<void> _storeSession(AuthSessionPayload session) async {
    final prefs = await _ensurePreferences();
    await prefs.setString(_storageKey, session.toStorageString());
    _applyToken(session.tokens);
  }

  Future<void> updateAccessToken(AuthTokens tokens) async {
    final current = _state.session;
    if (current == null) {
      return;
    }
    final updatedSession = AuthSessionPayload(
      user: current.user,
      tokens: tokens,
    );
    await _storeSession(updatedSession);
    _setState((state) => state.copyWith(session: updatedSession));
  }

  Future<SharedPreferences> _ensurePreferences() async {
    if (_preferences != null) {
      return _preferences!;
    }
    _preferences = await SharedPreferences.getInstance();
    return _preferences!;
  }

  void _applyToken(AuthTokens tokens) {
    if (_apiClient != null) {
      _apiClient.setBearerToken(tokens.accessToken);
    }
  }

  void _clearToken() {
    _apiClient?.clearBearerToken();
  }

  void _setState(AuthState Function(AuthState) update) {
    if (_disposed) {
      return;
    }
    _state = update(_state);
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}