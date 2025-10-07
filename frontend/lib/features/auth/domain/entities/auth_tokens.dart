import 'dart:convert';

import 'auth_user.dart';

class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresAt,
    required this.refreshExpiresAt,
  });

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: json['access_token'] as String? ?? '',
      refreshToken: json['refresh_token'] as String? ?? '',
      tokenType: json['token_type'] as String? ?? 'bearer',
      expiresAt: _parseDateTime(json['expires_at']),
      refreshExpiresAt: _parseDateTime(json['refresh_expires_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'token_type': tokenType,
      'expires_at': expiresAt.toIso8601String(),
      'refresh_expires_at': refreshExpiresAt.toIso8601String(),
    };
  }

  bool get isAccessExpired => DateTime.now().isAfter(expiresAt);

  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final DateTime expiresAt;
  final DateTime refreshExpiresAt;

  static DateTime _parseDateTime(Object? value) {
    if (value is DateTime) {
      return value.toLocal();
    }
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value)?.toLocal() ?? DateTime.now();
    }
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(
        value.toInt() * 1000,
        isUtc: true,
      ).toLocal();
    }
    return DateTime.now();
  }
}

class AuthSessionPayload {
  const AuthSessionPayload({required this.user, required this.tokens});

  factory AuthSessionPayload.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'];
    final tokensJson = json['tokens'];
    if (userJson is! Map) {
      throw const FormatException('Missing user payload in auth session');
    }
    if (tokensJson is! Map) {
      throw const FormatException('Missing token payload in auth session');
    }
    return AuthSessionPayload(
      user: AuthUser.fromJson(Map<String, dynamic>.from(userJson)),
      tokens: AuthTokens.fromJson(Map<String, dynamic>.from(tokensJson)),
    );
  }

  Map<String, dynamic> toJson() {
    return {'user': user.toJson(), 'tokens': tokens.toJson()};
  }

  String toStorageString() => jsonEncode(toJson());

  final AuthUser user;
  final AuthTokens tokens;
}
