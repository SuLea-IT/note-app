import '../../auth/domain/auth_session.dart';
import '../domain/entities/search.dart';

class SearchQuery {
  const SearchQuery({
    required this.keyword,
    this.types,
    this.startDate,
    this.endDate,
    this.limit = 50,
  });

  final String keyword;
  final List<SearchResultType>? types;
  final DateTime? startDate;
  final DateTime? endDate;
  final int limit;
}

abstract class SearchRepository {
  Future<SearchResponse> search(SearchQuery query);
}

abstract class SearchSessionRepository extends SearchRepository {
  SearchSessionRepository(this.session);

  final AuthSession session;
}
