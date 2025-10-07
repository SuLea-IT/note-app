import 'package:flutter/foundation.dart';

import '../data/audio_note_repository.dart';
import '../domain/entities/audio_note.dart';

enum AudioNoteListStatus { initial, loading, ready, failure }

class AudioNoteListState {
  const AudioNoteListState({
    this.status = AudioNoteListStatus.initial,
    this.notes = const [],
    this.error,
    this.query = '',
    Set<AudioNoteStatus>? filters,
    this.isRefreshing = false,
  }) : filters = filters ?? const <AudioNoteStatus>{};

  final AudioNoteListStatus status;
  final List<AudioNote> notes;
  final String? error;
  final String query;
  final Set<AudioNoteStatus> filters;
  final bool isRefreshing;

  AudioNoteListState copyWith({
    AudioNoteListStatus? status,
    List<AudioNote>? notes,
    String? error,
    bool clearError = false,
    String? query,
    Set<AudioNoteStatus>? filters,
    bool? isRefreshing,
  }) {
    return AudioNoteListState(
      status: status ?? this.status,
      notes: notes ?? this.notes,
      error: clearError ? null : (error ?? this.error),
      query: query ?? this.query,
      filters: filters ?? this.filters,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }
}

class AudioNoteListController extends ChangeNotifier {
  AudioNoteListController(this._repository);

  final AudioNoteRepository _repository;

  AudioNoteListState _state = const AudioNoteListState();
  AudioNoteListState get state => _state;

  Future<void> load({bool refresh = false}) async {
    if (_state.status == AudioNoteListStatus.loading && !refresh) {
      return;
    }
    _setState(
      (state) => state.copyWith(
        status: AudioNoteListStatus.loading,
        isRefreshing: refresh,
        clearError: true,
      ),
    );
    try {
      final query = AudioNoteQuery(
        statuses: _state.filters.isEmpty ? null : _state.filters.toList(growable: false),
        search: _state.query.isEmpty ? null : _state.query,
        limit: 200,
      );
      final collection = await _repository.fetchNotes(query: query);
      final items = List<AudioNote>.from(collection.items)
        ..sort((a, b) {
          final dateA = a.updatedAt ?? a.createdAt ?? DateTime.now();
          final dateB = b.updatedAt ?? b.createdAt ?? DateTime.now();
          return dateB.compareTo(dateA);
        });
      _setState(
        (state) => state.copyWith(
          status: AudioNoteListStatus.ready,
          notes: items,
          isRefreshing: false,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('AudioNoteListController load error: $error');
      debugPrintStack(stackTrace: stackTrace);
      _setState(
        (state) => state.copyWith(
          status: AudioNoteListStatus.failure,
          isRefreshing: false,
          error: '加载语音笔记失败，请稍后再试',
        ),
      );
    }
  }

  Future<void> refresh() => load(refresh: true);

  Future<void> search(String keyword) async {
    final normalized = keyword.trim();
    if (_state.query == normalized) {
      return;
    }
    _setState((state) => state.copyWith(query: normalized));
    await load(refresh: true);
  }

  void clearSearch() {
    if (_state.query.isEmpty) {
      return;
    }
    _setState((state) => state.copyWith(query: ''));
    load(refresh: true);
  }

  void toggleFilter(AudioNoteStatus status) {
    final updated = Set<AudioNoteStatus>.from(_state.filters);
    if (!updated.add(status)) {
      updated.remove(status);
    }
    _setState((state) => state.copyWith(filters: updated));
    load(refresh: true);
  }

  void addOrUpdate(AudioNote note) {
    final notes = List<AudioNote>.from(_state.notes);
    final index = notes.indexWhere((item) => item.id == note.id);
    if (index == -1) {
      notes.insert(0, note);
    } else {
      notes[index] = note;
    }
    _setState((state) => state.copyWith(notes: notes));
  }

  void remove(String noteId) {
    final notes = _state.notes.where((note) => note.id != noteId).toList();
    _setState((state) => state.copyWith(notes: notes));
  }

  void setError(String message) {
    _setState((state) => state.copyWith(error: message));
  }

  void _setState(AudioNoteListState Function(AudioNoteListState) updater) {
    _state = updater(_state);
    notifyListeners();
  }
}