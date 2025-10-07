enum SearchResultType {
  note,
  diary,
  task,
  habit,
  audioNote,
}

extension SearchResultTypeX on SearchResultType {
  static SearchResultType fromName(String raw) {
    final normalized = raw.trim().toLowerCase();
    switch (normalized) {
      case 'diary':
        return SearchResultType.diary;
      case 'task':
        return SearchResultType.task;
      case 'habit':
        return SearchResultType.habit;
      case 'audio_note':
        return SearchResultType.audioNote;
      case 'note':
      default:
        return SearchResultType.note;
    }
  }

  String get label {
    switch (this) {
      case SearchResultType.note:
        return '笔记';
      case SearchResultType.diary:
        return '日记';
      case SearchResultType.task:
        return '任务';
      case SearchResultType.habit:
        return '习惯';
      case SearchResultType.audioNote:
        return '语音';
    }
  }

  String get iconName {
    switch (this) {
      case SearchResultType.note:
        return 'note';
      case SearchResultType.diary:
        return 'book';
      case SearchResultType.task:
        return 'check';
      case SearchResultType.habit:
        return 'calendar';
      case SearchResultType.audioNote:
        return 'mic';
    }
  }
}

class SearchResult {
  const SearchResult({
    required this.id,
    required this.type,
    required this.title,
    this.excerpt,
    this.date,
    this.tags = const [],
    this.metadata = const {},
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    final tags = (json['tags'] as List<dynamic>? ?? [])
        .whereType<String>()
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList(growable: false);

    final metadata = (json['metadata'] as Map<String, dynamic>? ?? const {})
        .map((key, value) => MapEntry(key, value));

    return SearchResult(
      id: json['id'] as String? ?? '',
      type: SearchResultTypeX.fromName(json['type'] as String? ?? ''),
      title: json['title'] as String? ?? '',
      excerpt: json['excerpt'] as String?,
      date: _parseDateTime(json['date']),
      tags: tags,
      metadata: metadata,
    );
  }

  final String id;
  final SearchResultType type;
  final String title;
  final String? excerpt;
  final DateTime? date;
  final List<String> tags;
  final Map<String, dynamic> metadata;
}

class SearchSection {
  const SearchSection({
    required this.type,
    required this.label,
    required this.results,
  });

  factory SearchSection.fromJson(Map<String, dynamic> json) {
    final results = (json['results'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(SearchResult.fromJson)
        .toList(growable: false);
    return SearchSection(
      type: SearchResultTypeX.fromName(json['type'] as String? ?? ''),
      label: json['label'] as String? ?? '',
      results: results,
    );
  }

  final SearchResultType type;
  final String label;
  final List<SearchResult> results;
}

class SearchResponse {
  const SearchResponse({
    required this.query,
    required this.total,
    required this.results,
    required this.sections,
  });

  factory SearchResponse.fromJson(Map<String, dynamic> json) {
    final results = (json['results'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(SearchResult.fromJson)
        .toList(growable: false);
    final sections = (json['sections'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(SearchSection.fromJson)
        .toList(growable: false);
    return SearchResponse(
      query: json['query'] as String? ?? '',
      total: (json['total'] as num?)?.toInt() ?? results.length,
      results: results,
      sections: sections,
    );
  }

  final String query;
  final int total;
  final List<SearchResult> results;
  final List<SearchSection> sections;
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is DateTime) {
    return value.toLocal();
  }
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value)?.toLocal();
  }
  return null;
}