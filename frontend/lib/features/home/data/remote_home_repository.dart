import '../../auth/domain/auth_session.dart';
import '../../auth/domain/entities/auth_user.dart';
import '../../../core/network/api_client.dart';
import '../domain/entities/home_feed.dart';
import 'home_repository.dart';

class RemoteHomeRepository implements HomeRepository {
  RemoteHomeRepository(this._client, this._session);

  final ApiClient _client;
  final AuthSession _session;

  @override
  Future<HomeFeed> loadFeed() async {
    final user = _requireUser();
    final response = await _client.getJson(
      '/home/feed?user_id=${Uri.encodeComponent(user.id)}&lang=${Uri.encodeComponent(user.preferredLocale)}',
    );
    final payload = _unwrap(response);
    return HomeFeed.fromJson(payload);
  }

  Map<String, dynamic> _unwrap(Map<String, dynamic> json) {
    if (json.containsKey('sections')) {
      return json;
    }
    final data = json['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    throw const FormatException('Unexpected home feed payload');
  }

  AuthUser _requireUser() {
    final user = _session.currentUser;
    if (user == null) {
      throw StateError('User session is required');
    }
    return user;
  }
}
