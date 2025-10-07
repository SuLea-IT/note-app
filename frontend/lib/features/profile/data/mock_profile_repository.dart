import '../domain/entities/profile.dart';
import 'profile_repository.dart';

class MockProfileRepository implements ProfileRepository {
  MockProfileRepository()
    : _profile = UserProfile(
        id: 'mock-user',
        email: 'demo@example.com',
        displayName: '演示账号',
        preferredLocale: 'zh-CN',
        avatarUrl: null,
        themePreference: 'system',
        createdAt: DateTime.now().subtract(const Duration(days: 120)),
        statistics: const UserStatistics(
          noteCount: 48,
          diaryCount: 26,
          habitCount: 5,
          habitStreak: 12,
        ),
      );

  UserProfile _profile;

  @override
  Future<UserProfile> fetchProfile() async {
    return Future.delayed(const Duration(milliseconds: 120), () => _profile);
  }

  @override
  Future<UserProfile> updateProfile(UserProfileUpdate update) async {
    _profile = UserProfile(
      id: _profile.id,
      email: _profile.email,
      displayName: update.displayName ?? _profile.displayName,
      preferredLocale: update.preferredLocale ?? _profile.preferredLocale,
      avatarUrl: update.avatarUrl ?? _profile.avatarUrl,
      themePreference: update.themePreference ?? _profile.themePreference,
      createdAt: _profile.createdAt,
      updatedAt: DateTime.now(),
      statistics: _profile.statistics,
    );
    return Future.delayed(const Duration(milliseconds: 160), () => _profile);
  }
}