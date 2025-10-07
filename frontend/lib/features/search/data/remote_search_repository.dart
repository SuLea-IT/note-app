import '../../../core/network/api_client.dart';
import '../../auth/domain/entities/auth_user.dart';
import '../domain/entities/search.dart';
import 'search_repository.dart';

class RemoteSearchRepository extends SearchSessionRepository {
  RemoteSearchRepository(super.session, this._client);

  final ApiClient _client;

  @override
  Future<SearchResponse> search(SearchQuery query) async {
    final user = _requireUser();
    final buffer = StringBuffer(
      '/search/?q=${Uri.encodeComponent(query.keyword)}&user_id=${Uri.encodeComponent(user.id)}&lang=${Uri.encodeComponent(user.preferredLocale)}&limit=${query.limit}',
    );
    if (query.types != null) {
      for (final type in query.types!) {
        buffer.write('&types=${Uri.encodeComponent(_mapType(type))}');
      }
    }
    if (query.startDate != null) {
      buffer.write('&start_date=${Uri.encodeComponent(query.startDate!.toIso8601String())}');
    }
    if (query.endDate != null) {
      buffer.write('&end_date=${Uri.encodeComponent(query.endDate!.toIso8601String())}');
    }
    final response = await _client.getJson(buffer.toString());
    final payload = _unwrap(response);
    return SearchResponse.fromJson(payload);
  }

  String _mapType(SearchResultType type) {
    switch (type) {
      case SearchResultType.note:
        return 'note';
      case SearchResultType.diary:
        return 'diary';
      case SearchResultType.task:
        return 'task';
      case SearchResultType.habit:
        return 'habit';
      case SearchResultType.audioNote:
        return 'audio_note';
    }
  }

  Map<String, dynamic> _unwrap(Map<String, dynamic> json) {
    if (json.containsKey('results')) {
      return json;
    }
    final data = json['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    throw const FormatException('Unexpected search payload');
  }

  AuthUser _requireUser() {
    final user = session.currentUser;
    if (user == null) {
      throw StateError('Search operation requires authenticated user');
    }
    return user;
  }
}
