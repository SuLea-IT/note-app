import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/search_repository.dart';
import '../domain/entities/search.dart';

enum SearchStatus { idle, searching, ready, failure }

class SearchState {
  const SearchState({
    this.status = SearchStatus.idle,
    this.query = '',
    this.results = const [],
    this.sections = const [],
    this.error,
    this.history = const [],
    this.isFiltering = false,
    List<SearchResultType>? selectedTypes,
    this.startDate,
    this.endDate,
  }) : selectedTypes = selectedTypes ?? const <SearchResultType>[];

  final SearchStatus status;
  final String query;
  final List<SearchResult> results;
  final List<SearchSection> sections;
  final String? error;
  final List<String> history;
  final bool isFiltering;
  final List<SearchResultType> selectedTypes;
  final DateTime? startDate;
  final DateTime? endDate;

  SearchState copyWith({
    SearchStatus? status,
    String? query,
    List<SearchResult>? results,
    List<SearchSection>? sections,
    String? error,
    bool clearError = false,
    List<String>? history,
    bool? isFiltering,
    List<SearchResultType>? selectedTypes,
    DateTime? startDate,
    bool clearStartDate = false,
    DateTime? endDate,
    bool clearEndDate = false,
  }) {
    return SearchState(
      status: status ?? this.status,
      query: query ?? this.query,
      results: results ?? this.results,
      sections: sections ?? this.sections,
      error: clearError ? null : (error ?? this.error),
      history: history ?? this.history,
      isFiltering: isFiltering ?? this.isFiltering,
      selectedTypes: selectedTypes ?? this.selectedTypes,
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
    );
  }
}

class SearchController extends ChangeNotifier {
  SearchController(this._repository);

  final SearchRepository _repository;

  SearchState _state = const SearchState();
  SearchState get state => _state;

  Timer? _debounce;

  void disposeController() {
    _debounce?.cancel();
    _debounce = null;
    dispose();
  }

  void updateQuery(String query) {
    _setState((state) => state.copyWith(query: query));
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      _setState(
        (state) => state.copyWith(
          status: SearchStatus.idle,
          results: [],
          sections: [],
          clearError: true,
        ),
      );
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 320), () {
      performSearch(query.trim());
    });
  }

  Future<void> performSearch(String keyword) async {
    if (keyword.isEmpty) {
      return;
    }
    _debounce?.cancel();
    _setState(
      (state) => state.copyWith(
        status: SearchStatus.searching,
        query: keyword,
        clearError: true,
      ),
    );
    try {
      final query = SearchQuery(
        keyword: keyword,
        types: _state.selectedTypes.isEmpty ? null : _state.selectedTypes,
        startDate: _state.startDate,
        endDate: _state.endDate,
      );
      final response = await _repository.search(query);
      final history = <String>{keyword, ..._state.history}.take(10).toList();
      _setState(
        (state) => state.copyWith(
          status: SearchStatus.ready,
          results: response.results,
          sections: response.sections,
          history: history,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('SearchController search error: $error');
      debugPrintStack(stackTrace: stackTrace);
      _setState(
        (state) => state.copyWith(
          status: SearchStatus.failure,
          error: '搜索失败，请稍后重试',
        ),
      );
    }
  }

  void clearHistory() {
    _setState((state) => state.copyWith(history: []));
  }

  void removeHistory(String keyword) {
    final updated = _state.history.where((item) => item != keyword).toList();
    _setState((state) => state.copyWith(history: updated));
  }

  void toggleType(SearchResultType type) {
    final updated = List<SearchResultType>.from(_state.selectedTypes);
    if (updated.contains(type)) {
      updated.remove(type);
    } else {
      updated.add(type);
    }
    _setState((state) => state.copyWith(selectedTypes: updated));
    if (_state.query.trim().isNotEmpty) {
      performSearch(_state.query.trim());
    }
  }

  void setDateRange({DateTime? start, DateTime? end}) {
    _setState(
      (state) => state.copyWith(
        startDate: start,
        endDate: end,
        clearStartDate: start == null,
        clearEndDate: end == null,
      ),
    );
    if (_state.query.trim().isNotEmpty) {
      performSearch(_state.query.trim());
    }
  }

  void resetFilters() {
    _setState(
      (state) => state.copyWith(
        selectedTypes: const <SearchResultType>[],
        clearStartDate: true,
        clearEndDate: true,
      ),
    );
    if (_state.query.trim().isNotEmpty) {
      performSearch(_state.query.trim());
    }
  }

  void _setState(SearchState Function(SearchState) updater) {
    _state = updater(_state);
    notifyListeners();
  }
}