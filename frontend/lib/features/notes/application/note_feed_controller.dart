import 'package:flutter/foundation.dart';

import '../data/note_repository.dart';
import '../domain/entities/note.dart';

enum NoteFeedStatus { initial, loading, ready, failure }

class NoteFeedState {
  const NoteFeedState({
    this.status = NoteFeedStatus.initial,
    this.feed,
    this.error,
    Set<NoteCategory>? selectedCategories,
    Set<String>? selectedTags,
    this.isSearching = false,
    this.searchResults = const [],
    this.query = '',
  }) : selectedCategories = selectedCategories ?? const <NoteCategory>{},
       selectedTags = selectedTags ?? const <String>{};

  final NoteFeedStatus status;
  final NoteFeed? feed;
  final String? error;
  final Set<NoteCategory> selectedCategories;
  final Set<String> selectedTags;
  final bool isSearching;
  final List<NoteSummary> searchResults;
  final String query;

  NoteFeedState copyWith({
    NoteFeedStatus? status,
    NoteFeed? feed,
    bool clearFeed = false,
    String? error,
    bool clearError = false,
    Set<NoteCategory>? selectedCategories,
    Set<String>? selectedTags,
    bool? isSearching,
    List<NoteSummary>? searchResults,
    String? query,
  }) {
    return NoteFeedState(
      status: status ?? this.status,
      feed: clearFeed ? null : (feed ?? this.feed),
      error: clearError ? null : (error ?? this.error),
      selectedCategories: selectedCategories ?? this.selectedCategories,
      selectedTags: selectedTags ?? this.selectedTags,
      isSearching: isSearching ?? this.isSearching,
      searchResults: searchResults ?? this.searchResults,
      query: query ?? this.query,
    );
  }
}

class NoteFeedController extends ChangeNotifier {
  NoteFeedController(this._repository);

  final NoteRepository _repository;

  NoteFeedState _state = const NoteFeedState();
  NoteFeedState get state => _state;

  Future<void> load({bool refresh = false}) async {
    _state = _state.copyWith(
      status: NoteFeedStatus.loading,
      clearError: true,
      isSearching: false,
      searchResults: [],
      query: refresh ? _state.query : '',
    );
    notifyListeners();
    try {
      final feed = await _repository.fetchFeed();
      _state = _state.copyWith(
        status: NoteFeedStatus.ready,
        feed: feed,
        clearError: true,
      );
    } catch (error, stackTrace) {
      debugPrint('NoteFeedController load error: $error');
      debugPrintStack(stackTrace: stackTrace);
      _state = _state.copyWith(
        status: NoteFeedStatus.failure,
        error: '加载笔记失败，请稍后再试',
      );
    }
    notifyListeners();
  }

  Future<void> refresh() => load(refresh: true);

  Future<void> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      _state = _state.copyWith(
        isSearching: false,
        searchResults: [],
        query: '',
      );
      notifyListeners();
      return;
    }

    _state = _state.copyWith(
      isSearching: true,
      query: trimmed,
      searchResults: [],
    );
    notifyListeners();

    try {
      final results = await _repository.search(trimmed, limit: 100);
      _state = _state.copyWith(searchResults: results);
    } catch (error, stackTrace) {
      debugPrint('NoteFeedController search error: $error');
      debugPrintStack(stackTrace: stackTrace);
      _state = _state.copyWith(error: '搜索失败，请稍后重试');
    }
    notifyListeners();
  }

  void clearSearch() {
    if (!_state.isSearching && _state.query.isEmpty) {
      return;
    }
    _state = _state.copyWith(
      isSearching: false,
      query: '',
      searchResults: [],
    );
    notifyListeners();
  }

  void toggleCategory(NoteCategory category) {
    final updated = Set<NoteCategory>.from(_state.selectedCategories);
    if (!updated.add(category)) {
      updated.remove(category);
    }
    _state = _state.copyWith(selectedCategories: updated);
    notifyListeners();
  }

  void toggleTag(String tag) {
    final updated = Set<String>.from(_state.selectedTags);
    final normalized = tag.trim();
    if (normalized.isEmpty) {
      return;
    }
    if (!updated.add(normalized)) {
      updated.remove(normalized);
    }
    _state = _state.copyWith(selectedTags: updated);
    notifyListeners();
  }

  void clearFilters() {
    if (_state.selectedCategories.isEmpty && _state.selectedTags.isEmpty) {
      return;
    }
    _state = _state.copyWith(
      selectedCategories: <NoteCategory>{},
      selectedTags: <String>{},
    );
    notifyListeners();
  }

  void removeFromFeed(String noteId) {
    final feed = _state.feed;
    if (feed == null) {
      return;
    }
    final updatedEntries = feed.entries
        .where((item) => item.id != noteId)
        .toList();
    final updatedSections = feed.sections
        .map(
          (section) => NoteSection(
            label: section.label,
            date: section.date,
            notes: section.notes.where((item) => item.id != noteId).toList(),
          ),
        )
        .where((section) => section.notes.isNotEmpty)
        .toList();
    _state = _state.copyWith(
      feed: NoteFeed(entries: updatedEntries, sections: updatedSections),
    );
    notifyListeners();
  }

  List<NoteSection> get filteredSections {
    final feed = _state.feed;
    if (feed == null) {
      return [];
    }
    final categories = _state.selectedCategories;
    final tags = _state.selectedTags;

    List<NoteSection> sections = feed.sections;
    if (categories.isEmpty && tags.isEmpty) {
      return sections;
    }

    return sections
        .map(
          (section) => NoteSection(
            label: section.label,
            date: section.date,
            notes: section.notes.where((note) {
              final categoryMatch =
                  categories.isEmpty || categories.contains(note.category);
              final tagMatch = tags.isEmpty || note.tags.any(tags.contains);
              return categoryMatch && tagMatch;
            }).toList(),
          ),
        )
        .where((section) => section.notes.isNotEmpty)
        .toList();
  }

  List<NoteSummary> get filteredEntries {
    final feed = _state.feed;
    if (feed == null) {
      return [];
    }
    final categories = _state.selectedCategories;
    final tags = _state.selectedTags;

    return feed.entries.where((note) {
      final categoryMatch =
          categories.isEmpty || categories.contains(note.category);
      final tagMatch = tags.isEmpty || note.tags.any(tags.contains);
      return categoryMatch && tagMatch;
    }).toList();
  }

  Set<String> get availableTags {
    final feed = _state.feed;
    if (feed == null) {
      return const <String>{};
    }
    final tags = <String>{};
    for (final note in feed.entries) {
      tags.addAll(note.tags);
    }
    return tags;
  }
}