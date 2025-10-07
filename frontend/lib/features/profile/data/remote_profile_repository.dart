import '../../../core/network/api_client.dart';
import '../../auth/domain/entities/auth_user.dart';
import '../domain/entities/profile.dart';
import 'profile_repository.dart';

class RemoteProfileRepository extends ProfileSessionRepository {
  RemoteProfileRepository(super.session, this._client);

  final ApiClient _client;

  @override
  Future<UserProfile> fetchProfile() async {
    final user = _requireUser();
    final response = await _client.getJson(
      '/users/me?user_id=${Uri.encodeComponent(user.id)}',
    );
    final payload = _unwrap(response);
    return UserProfile.fromJson(payload);
  }

  @override
  Future<UserProfile> updateProfile(UserProfileUpdate update) async {
    final user = _requireUser();
    final response = await _client.patchJson(
      '/users/${Uri.encodeComponent(user.id)}',
      update.toPayload(),
    );
    final payload = _unwrap(response);
    return UserProfile.fromJson(payload);
  }

  Map<String, dynamic> _unwrap(Map<String, dynamic> json) {
    if (json.containsKey('id')) {
      return json;
    }
    final data = json['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    throw const FormatException('Unexpected profile payload');
  }

  AuthUser _requireUser() {
    final user = session.currentUser;
    if (user == null) {
      throw StateError('Profile operation requires authenticated user');
    }
    return user;
  }
}
