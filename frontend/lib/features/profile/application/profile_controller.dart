import 'package:flutter/foundation.dart';

import '../../auth/application/auth_controller.dart';
import '../data/profile_repository.dart';
import '../domain/entities/profile.dart';

enum ProfileStatus { initial, loading, ready, failure }

class ProfileState {
  const ProfileState({
    this.status = ProfileStatus.initial,
    this.profile,
    this.error,
    this.isUpdating = false,
  });

  final ProfileStatus status;
  final UserProfile? profile;
  final String? error;
  final bool isUpdating;

  ProfileState copyWith({
    ProfileStatus? status,
    UserProfile? profile,
    bool clearProfile = false,
    String? error,
    bool clearError = false,
    bool? isUpdating,
  }) {
    return ProfileState(
      status: status ?? this.status,
      profile: clearProfile ? null : (profile ?? this.profile),
      error: clearError ? null : (error ?? this.error),
      isUpdating: isUpdating ?? this.isUpdating,
    );
  }
}

class ProfileController extends ChangeNotifier {
  ProfileController(this._repository, this._authController);

  final ProfileRepository _repository;
  final AuthController _authController;

  ProfileState _state = const ProfileState();
  ProfileState get state => _state;

  Future<void> load() async {
    _setState((state) => state.copyWith(status: ProfileStatus.loading, clearError: true));
    try {
      final profile = await _repository.fetchProfile();
      _setState(
        (state) => state.copyWith(
          status: ProfileStatus.ready,
          profile: profile,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('ProfileController load error: $error');
      debugPrintStack(stackTrace: stackTrace);
      _setState(
        (state) => state.copyWith(
          status: ProfileStatus.failure,
          error: '加载个人资料失败，请稍后再试',
        ),
      );
    }
  }

  Future<void> refresh() => load();

  Future<bool> update(UserProfileUpdate update) async {
    if (_state.isUpdating) {
      return false;
    }
    _setState((state) => state.copyWith(isUpdating: true, clearError: true));
    try {
      await _repository.updateProfile(update);
      final profile = await _repository.fetchProfile();
      _authController.updateCachedUser((current) {
        if (current == null) {
          return null;
        }
        return current.copyWith(
          displayName: profile.displayName,
          preferredLocale: profile.preferredLocale,
          avatarUrl: profile.avatarUrl,
          themePreference: profile.themePreference,
          lastActiveAt: profile.statistics?.lastActiveAt ?? current.lastActiveAt,
        );
      });
      _setState(
        (state) => state.copyWith(
          profile: profile,
          isUpdating: false,
        ),
      );
      return true;
    } catch (error, stackTrace) {
      debugPrint('ProfileController update error: $error');
      debugPrintStack(stackTrace: stackTrace);
      _setState(
        (state) => state.copyWith(
          isUpdating: false,
          error: '更新失败，请稍后重试',
        ),
      );
      return false;
    }
  }

  void setError(String message) {
    _setState((state) => state.copyWith(error: message));
  }

  void _setState(ProfileState Function(ProfileState) updater) {
    _state = updater(_state);
    notifyListeners();
  }
}