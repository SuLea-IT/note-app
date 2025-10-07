import 'dart:math';

import '../domain/entities/audio_note.dart';
import 'audio_note_repository.dart';

class MockAudioNoteRepository implements AudioNoteRepository {
  MockAudioNoteRepository()
    : _random = Random(86420),
      _notes = List<AudioNote>.generate(8, (index) {
        final now = DateTime.now();
        final status = AudioNoteStatus.values[index % AudioNoteStatus.values.length];
        return AudioNote(
          id: 'audio-$index',
          userId: 'mock-user',
          title: '演示语音 #$index',
          description: '示例语音笔记描述，用于展示界面效果。',
          fileUrl: 'https://example.com/audio/$index.mp3',
          mimeType: 'audio/mpeg',
          sizeBytes: 1024 * 120 * (index + 1),
          durationSeconds: 45 + index * 10,
          transcriptionStatus: status,
          transcriptionText:
              status == AudioNoteStatus.completed ? '这是语音的演示转写内容。' : null,
          recordedAt: now.subtract(Duration(minutes: index * 15)),
          createdAt: now.subtract(Duration(minutes: index * 15)),
          updatedAt: now,
        );
      });

  final Random _random;
  final List<AudioNote> _notes;

  @override
  Future<AudioNote> create(AudioNoteDraft draft) async {
    final id = 'audio-${_random.nextInt(99999)}';
    final note = AudioNote(
      id: id,
      userId: draft.userId ?? 'mock-user',
      title: draft.title,
      description: draft.description,
      fileUrl: draft.fileUrl.isEmpty
          ? 'https://example.com/audio/$id.mp3'
          : draft.fileUrl,
      mimeType: draft.mimeType,
      sizeBytes: draft.sizeBytes,
      durationSeconds: draft.durationSeconds,
      transcriptionStatus: draft.transcriptionStatus,
      transcriptionText: draft.transcriptionText,
      transcriptionLanguage: draft.transcriptionLanguage,
      transcriptionError: draft.transcriptionError,
      recordedAt: draft.recordedAt,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _notes.insert(0, note);
    return Future.delayed(const Duration(milliseconds: 120), () => note);
  }

  @override
  Future<void> delete(String id) async {
    _notes.removeWhere((note) => note.id == id);
    await Future<void>.delayed(const Duration(milliseconds: 80));
  }

  @override
  Future<AudioNote> fetchNote(String id) async {
    final note = _notes.firstWhere((note) => note.id == id);
    return Future.delayed(const Duration(milliseconds: 80), () => note);
  }

  @override
  Future<AudioNoteCollection> fetchNotes({AudioNoteQuery? query}) async {
    Iterable<AudioNote> result = _notes;
    if (query?.statuses != null && query!.statuses!.isNotEmpty) {
      result = result.where((note) => query.statuses!.contains(note.transcriptionStatus));
    }
    if (query?.search != null && query!.search!.isNotEmpty) {
      final keyword = query.search!.toLowerCase();
      result = result.where(
        (note) => note.title.toLowerCase().contains(keyword) ||
            (note.description?.toLowerCase().contains(keyword) ?? false),
      );
    }
    final items = result.toList()
      ..sort((a, b) => b.createdAt!.compareTo(a.createdAt!));
    return Future.delayed(
      const Duration(milliseconds: 160),
      () => AudioNoteCollection(total: items.length, items: items),
    );
  }

  @override
  Future<AudioNote> update(String id, AudioNoteDraft draft) async {
    final index = _notes.indexWhere((note) => note.id == id);
    if (index == -1) {
      throw StateError('Audio note not found');
    }
    final updated = _notes[index].copyWith(
      title: draft.title,
      description: draft.description,
      transcriptionStatus: draft.transcriptionStatus,
      transcriptionText: draft.transcriptionText,
      transcriptionLanguage: draft.transcriptionLanguage,
      transcriptionError: draft.transcriptionError,
      recordedAt: draft.recordedAt,
    );
    _notes[index] = updated;
    return Future.delayed(const Duration(milliseconds: 120), () => updated);
  }

  @override
  Future<AudioNote> updateTranscription(
    String id, {
    required AudioNoteStatus status,
    String? text,
    String? language,
    String? error,
  }) async {
    final index = _notes.indexWhere((note) => note.id == id);
    if (index == -1) {
      throw StateError('Audio note not found');
    }
    final updated = _notes[index].copyWith(
      transcriptionStatus: status,
      transcriptionText: text,
      transcriptionLanguage: language,
      transcriptionError: error,
    );
    _notes[index] = updated;
    return Future.delayed(const Duration(milliseconds: 120), () => updated);
  }
}