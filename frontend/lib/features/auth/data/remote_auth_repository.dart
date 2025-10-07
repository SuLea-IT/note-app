import '../../../core/network/api_client.dart';
import '../domain/entities/auth_tokens.dart';
import 'auth_repository.dart';

class RemoteAuthRepository implements AuthRepository {
  RemoteAuthRepository(this._client);

  final ApiClient _client;

  @override
  Future<AuthSessionPayload> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.postJson('/auth/login', {
      'email': email,
      'password': password,
    });
    final payload = _unwrapSession(response);
    final session = AuthSessionPayload.fromJson(payload);
    _client.setBearerToken(session.tokens.accessToken);
    return session;
  }

  @override
  Future<AuthSessionPayload> register({
    required String email,
    required String password,
    required String displayName,
    required String preferredLocale,
  }) async {
    final response = await _client.postJson('/users', {
      'email': email,
      'password': password,
      'display_name': displayName,
      'preferred_locale': preferredLocale,
    });
    final payload = _unwrapSession(response);
    final session = AuthSessionPayload.fromJson(payload);
    _client.setBearerToken(session.tokens.accessToken);
    return session;
  }

  Map<String, dynamic> _unwrapSession(Map<String, dynamic> json) {
    if (json.containsKey('user') && json.containsKey('tokens')) {
      return json;
    }
    final data = json['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    throw const FormatException('Unexpected auth payload');
  }
}
