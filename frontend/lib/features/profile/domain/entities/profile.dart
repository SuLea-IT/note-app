class UserStatistics {
  const UserStatistics({
    required this.noteCount,
    required this.diaryCount,
    required this.habitCount,
    required this.habitStreak,
    this.lastActiveAt,
  });

  factory UserStatistics.fromJson(Map<String, dynamic> json) {
    return UserStatistics(
      noteCount: (json['note_count'] as num?)?.toInt() ?? 0,
      diaryCount: (json['diary_count'] as num?)?.toInt() ?? 0,
      habitCount: (json['habit_count'] as num?)?.toInt() ?? 0,
      habitStreak: (json['habit_streak'] as num?)?.toInt() ?? 0,
      lastActiveAt: _parseDateTime(json['last_active_at']),
    );
  }

  final int noteCount;
  final int diaryCount;
  final int habitCount;
  final int habitStreak;
  final DateTime? lastActiveAt;
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    this.displayName,
    this.preferredLocale = 'zh-CN',
    this.avatarUrl,
    this.themePreference,
    this.createdAt,
    this.updatedAt,
    this.statistics,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      displayName: json['display_name'] as String?,
      preferredLocale: json['preferred_locale'] as String? ?? 'zh-CN',
      avatarUrl: json['avatar_url'] as String?,
      themePreference: json['theme_preference'] as String?,
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
      statistics: json['statistics'] is Map<String, dynamic>
          ? UserStatistics.fromJson(json['statistics'] as Map<String, dynamic>)
          : null,
    );
  }

  final String id;
  final String email;
  final String? displayName;
  final String preferredLocale;
  final String? avatarUrl;
  final String? themePreference;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final UserStatistics? statistics;

  String get resolvedName => displayName?.trim().isNotEmpty == true
      ? displayName!.trim()
      : email.split('@').first;
}

class UserProfileUpdate {
  UserProfileUpdate({
    this.displayName,
    this.preferredLocale,
    this.avatarUrl,
    this.themePreference,
    this.password,
  });

  Map<String, dynamic> toPayload() {
    return {
      if (displayName != null) 'display_name': displayName,
      if (preferredLocale != null) 'preferred_locale': preferredLocale,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (themePreference != null) 'theme_preference': themePreference,
      if (password != null) 'password': password,
    };
  }

  String? displayName;
  String? preferredLocale;
  String? avatarUrl;
  String? themePreference;
  String? password;
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is DateTime) {
    return value.toLocal();
  }
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value)?.toLocal();
  }
  return null;
}
