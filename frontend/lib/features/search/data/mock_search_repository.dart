import '../domain/entities/search.dart';
import 'search_repository.dart';

class MockSearchRepository implements SearchRepository {
  MockSearchRepository();

  @override
  Future<SearchResponse> search(SearchQuery query) async {
    final keyword = query.keyword;
    final sections = <SearchSection>[
      SearchSection(
        type: SearchResultType.note,
        label: '笔记',
        results: [
          SearchResult(
            id: 'note-1',
            type: SearchResultType.note,
            title: '关于“$keyword”的笔记',
            excerpt: '这是一个示例笔记摘要，展示搜索结果效果。',
            tags: ['示例'],
          ),
        ],
      ),
      SearchSection(
        type: SearchResultType.task,
        label: '任务',
        results: [
          SearchResult(
            id: 'task-1',
            type: SearchResultType.task,
            title: '待处理任务：$keyword',
            excerpt: '请在今天完成该任务。',
            tags: ['待办'],
          ),
        ],
      ),
    ];

    return Future.delayed(
      const Duration(milliseconds: 180),
      () => SearchResponse(
        query: keyword,
        total: sections.fold<int>(0, (sum, section) => sum + section.results.length),
        results: sections.expand((section) => section.results).toList(),
        sections: sections,
      ),
    );
  }
}