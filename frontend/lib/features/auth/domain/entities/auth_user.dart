class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.preferredLocale,
    this.displayName,
    this.avatarUrl,
    this.themePreference,
    this.lastActiveAt,
    this.createdAt,
    this.updatedAt,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      displayName: json['display_name'] as String?,
      preferredLocale: json['preferred_locale'] as String? ?? 'en-US',
      avatarUrl: json['avatar_url'] as String?,
      themePreference: json['theme_preference'] as String?,
      lastActiveAt: _parseDateTime(json['last_active_at']),
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'display_name': displayName,
      'preferred_locale': preferredLocale,
      'avatar_url': avatarUrl,
      'theme_preference': themePreference,
      'last_active_at': lastActiveAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  String get resolvedName {
    final candidate = displayName?.trim();
    if (candidate != null && candidate.isNotEmpty) {
      return candidate;
    }
    return email;
  }

  String get initials {
    final candidate = displayName?.trim();
    if (candidate != null && candidate.isNotEmpty) {
      final parts = candidate
          .split(RegExp(r'\s+'))
          .where((value) => value.isNotEmpty)
          .toList(growable: false);
      if (parts.length == 1) {
        final glyph = _firstGlyph(parts.first);
        if (glyph.isNotEmpty) {
          return glyph;
        }
      } else if (parts.length >= 2) {
        final first = _firstGlyph(parts[0]);
        final second = _firstGlyph(parts[1]);
        final combined = (first + second).trim();
        if (combined.trim().isNotEmpty) {
          return combined;
        }
      }
    }
    return email.isNotEmpty ? _firstGlyph(email) : '?';
  }

  final String id;
  final String email;
  final String? displayName;
  final String preferredLocale;
  final String? avatarUrl;
  final String? themePreference;
  final DateTime? lastActiveAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AuthUser copyWith({
    String? displayName,
    String? preferredLocale,
    String? avatarUrl,
    String? themePreference,
    DateTime? lastActiveAt,
  }) {
    return AuthUser(
      id: id,
      email: email,
      preferredLocale: preferredLocale ?? this.preferredLocale,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      themePreference: themePreference ?? this.themePreference,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static DateTime? _parseDateTime(Object? value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value)?.toLocal();
    }
    if (value is DateTime) {
      return value.toLocal();
    }
    return null;
  }

  static String _firstGlyph(String value) {
    if (value.isEmpty) {
      return '';
    }
    final runeIterator = value.runes.iterator;
    if (!runeIterator.moveNext()) {
      return '';
    }
    final glyph = String.fromCharCode(runeIterator.current);
    return glyph.toUpperCase();
  }
}
