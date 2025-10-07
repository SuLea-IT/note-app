import '../domain/entities/auth_tokens.dart';

abstract class AuthRepository {
  Future<AuthSessionPayload> login({
    required String email,
    required String password,
  });

  Future<AuthSessionPayload> register({
    required String email,
    required String password,
    required String displayName,
    required String preferredLocale,
  });
}
