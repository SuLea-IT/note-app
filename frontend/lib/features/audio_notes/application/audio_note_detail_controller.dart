import 'package:flutter/foundation.dart';

import '../data/audio_note_repository.dart';
import '../domain/entities/audio_note.dart';

enum AudioNoteDetailStatus { initial, loading, ready, failure }

class AudioNoteDetailState {
  const AudioNoteDetailState({
    this.status = AudioNoteDetailStatus.initial,
    this.note,
    this.error,
  });

  final AudioNoteDetailStatus status;
  final AudioNote? note;
  final String? error;

  AudioNoteDetailState copyWith({
    AudioNoteDetailStatus? status,
    AudioNote? note,
    bool clearNote = false,
    String? error,
    bool clearError = false,
  }) {
    return AudioNoteDetailState(
      status: status ?? this.status,
      note: clearNote ? null : (note ?? this.note),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AudioNoteDetailController extends ChangeNotifier {
  AudioNoteDetailController(this._repository, this.noteId);

  final AudioNoteRepository _repository;
  final String noteId;

  AudioNoteDetailState _state = const AudioNoteDetailState();
  AudioNoteDetailState get state => _state;

  Future<void> load() async {
    _setState((state) => state.copyWith(status: AudioNoteDetailStatus.loading, clearError: true));
    try {
      final note = await _repository.fetchNote(noteId);
      _setState(
        (state) => state.copyWith(
          status: AudioNoteDetailStatus.ready,
          note: note,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('AudioNoteDetailController load error: $error');
      debugPrintStack(stackTrace: stackTrace);
      _setState(
        (state) => state.copyWith(
          status: AudioNoteDetailStatus.failure,
          error: '加载语音笔记失败，请稍后重试',
        ),
      );
    }
  }

  Future<void> refresh() => load();

  Future<void> updateTranscription({
    required AudioNoteStatus status,
    String? text,
    String? language,
    String? error,
  }) async {
    try {
      final updated = await _repository.updateTranscription(
        noteId,
        status: status,
        text: text,
        language: language,
        error: error,
      );
      _setState((state) => state.copyWith(note: updated, clearError: true));
    } catch (err, stackTrace) {
      debugPrint('AudioNoteDetailController update transcription error: $err');
      debugPrintStack(stackTrace: stackTrace);
      _setState((state) => state.copyWith(error: '更新转写失败，请稍后再试'));
    }
  }

  Future<bool> delete() async {
    try {
      await _repository.delete(noteId);
      _setState((state) => state.copyWith(clearNote: true));
      return true;
    } catch (error, stackTrace) {
      debugPrint('AudioNoteDetailController delete error: $error');
      debugPrintStack(stackTrace: stackTrace);
      _setState((state) => state.copyWith(error: '删除失败，请稍后再试'));
      return false;
    }
  }

  void _setState(AudioNoteDetailState Function(AudioNoteDetailState) updater) {
    _state = updater(_state);
    notifyListeners();
  }
}