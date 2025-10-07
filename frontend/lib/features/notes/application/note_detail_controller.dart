import 'package:flutter/foundation.dart';

import '../data/note_repository.dart';
import '../domain/entities/note.dart';

enum NoteDetailStatus { initial, loading, ready, failure }

class NoteDetailState {
  const NoteDetailState({
    this.status = NoteDetailStatus.initial,
    this.detail,
    this.error,
    this.isDeleting = false,
  });

  final NoteDetailStatus status;
  final NoteDetail? detail;
  final String? error;
  final bool isDeleting;

  NoteDetailState copyWith({
    NoteDetailStatus? status,
    NoteDetail? detail,
    bool clearDetail = false,
    String? error,
    bool clearError = false,
    bool? isDeleting,
  }) {
    return NoteDetailState(
      status: status ?? this.status,
      detail: clearDetail ? null : (detail ?? this.detail),
      error: clearError ? null : (error ?? this.error),
      isDeleting: isDeleting ?? this.isDeleting,
    );
  }
}

class NoteDetailController extends ChangeNotifier {
  NoteDetailController(this._repository);

  final NoteRepository _repository;

  NoteDetailState _state = const NoteDetailState();
  NoteDetailState get state => _state;

  Future<void> load(String noteId) async {
    _state = _state.copyWith(
      status: NoteDetailStatus.loading,
      clearError: true,
    );
    notifyListeners();
    try {
      final detail = await _repository.fetchDetail(noteId);
      _state = _state.copyWith(
        status: NoteDetailStatus.ready,
        detail: detail,
        clearError: true,
      );
    } catch (error, stackTrace) {
      debugPrint('NoteDetailController load error: $error');
      debugPrintStack(stackTrace: stackTrace);
      _state = _state.copyWith(
        status: NoteDetailStatus.failure,
        error: '加载笔记详情失败，请稍后再试',
      );
    }
    notifyListeners();
  }

  Future<bool> deleteCurrent() async {
    final detail = _state.detail;
    if (detail == null || _state.isDeleting) {
      return false;
    }
    _state = _state.copyWith(isDeleting: true, clearError: true);
    notifyListeners();
    try {
      await _repository.delete(detail.id);
      _state = _state.copyWith(
        status: NoteDetailStatus.initial,
        clearDetail: true,
        isDeleting: false,
      );
      notifyListeners();
      return true;
    } catch (error, stackTrace) {
      debugPrint('NoteDetailController delete error: $error');
      debugPrintStack(stackTrace: stackTrace);
      _state = _state.copyWith(isDeleting: false, error: '删除失败，请稍后重试');
      notifyListeners();
      return false;
    }
  }
}