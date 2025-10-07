import '../../../core/network/api_client.dart';
import '../../auth/domain/auth_session.dart';
import '../../auth/domain/entities/auth_user.dart';
import '../domain/entities/note.dart';
import 'note_repository.dart';

class RemoteNoteRepository implements NoteRepository {
  RemoteNoteRepository(this._client, this._session);

  final ApiClient _client;
  final AuthSession _session;

  @override
  Future<NoteFeed> fetchFeed() async {
    final user = _requireUser();
    final response = await _client.getJson(
      '/notes/feed?user_id=${Uri.encodeComponent(user.id)}&lang=${Uri.encodeComponent(user.preferredLocale)}',
    );
    final payload = _unwrap(response);
    return NoteFeed.fromJson(payload);
  }

  @override
  Future<NoteDetail> fetchDetail(String id) async {
    final user = _requireUser();
    final response = await _client.getJson(
      '/notes/${Uri.encodeComponent(id)}?user_id=${Uri.encodeComponent(user.id)}&lang=${Uri.encodeComponent(user.preferredLocale)}',
    );
    final payload = _unwrap(response);
    return NoteDetail.fromJson(payload);
  }

  @override
  Future<List<NoteSummary>> search(String query, {int? limit}) async {
    final user = _requireUser();
    final buffer = StringBuffer(
      '/notes/search?q=${Uri.encodeComponent(query)}&user_id=${Uri.encodeComponent(user.id)}&lang=${Uri.encodeComponent(user.preferredLocale)}',
    );
    if (limit != null) {
      buffer.write('&limit=$limit');
    }
    final response = await _client.getJson(buffer.toString());
    final data = _unwrapList(response);
    return data.map(NoteSummary.fromJson).toList(growable: false);
  }

  @override
  Future<NoteDetail> create(NoteDraft draft) async {
    final user = _requireUser();
    draft.userId = user.id;
    draft.defaultLocale = user.preferredLocale;
    final response = await _client.postJson(
      '/notes?lang=${Uri.encodeComponent(user.preferredLocale)}',
      draft.toCreatePayload(),
    );
    final payload = _unwrap(response);
    return NoteDetail.fromJson(payload);
  }

  @override
  Future<NoteDetail> update(String id, NoteDraft draft) async {
    final user = _requireUser();
    final response = await _client.putJson(
      '/notes/${Uri.encodeComponent(id)}?user_id=${Uri.encodeComponent(user.id)}&lang=${Uri.encodeComponent(user.preferredLocale)}',
      draft.toUpdatePayload(),
    );
    final payload = _unwrap(response);
    return NoteDetail.fromJson(payload);
  }

  @override
  Future<void> delete(String id) async {
    final user = _requireUser();
    await _client.delete(
      '/notes/${Uri.encodeComponent(id)}?user_id=${Uri.encodeComponent(user.id)}',
    );
  }

  Map<String, dynamic> _unwrap(Map<String, dynamic> json) {
    if (json.containsKey('id')) {
      return json;
    }
    final data = json['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    throw const FormatException('Unexpected note payload');
  }

  List<Map<String, dynamic>> _unwrapList(Map<String, dynamic> json) {
    if (json['items'] is List) {
      return (json['items'] as List).whereType<Map<String, dynamic>>().toList(
        growable: false,
      );
    }
    final data = json['data'];
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().toList(growable: false);
    }
    return [];
  }

  AuthUser _requireUser() {
    final user = _session.currentUser;
    if (user == null) {
      throw StateError('User session is required');
    }
    return user;
  }
}
