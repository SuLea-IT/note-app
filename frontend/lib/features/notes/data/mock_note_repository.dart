import 'dart:math';

import '../domain/entities/note.dart';
import 'note_repository.dart';

class MockNoteRepository implements NoteRepository {
  MockNoteRepository() {
    _seed();
  }

  final List<NoteDetail> _notes = [];
  final Random _random = Random();

  void _seed() {
    if (_notes.isNotEmpty) {
      return;
    }
    final now = DateTime.now();
    _notes.addAll([
      NoteDetail(
        id: 'mock-note-1',
        userId: 'mock-user',
        title: '会议记录',
        preview: '整理同步会议中的关键行动项……',
        content: '整理同步会议中的关键行动项，以及后续跟进人。',
        date: now,
        category: NoteCategory.journal,
        hasAttachment: true,
        progressPercent: 0.5,
        createdAt: now,
        updatedAt: now,
        defaultLocale: 'zh-CN',
        tags: ['项目', '会议'],
        attachments: [
          NoteAttachment(
            id: 'att-1',
            fileName: '会议录音.mp3',
            fileUrl: 'https://example.com/audio.mp3',
            mimeType: 'audio/mpeg',
            sizeBytes: 2048,
            createdAt: null,
          ),
        ],
      ),
      NoteDetail(
        id: 'mock-note-2',
        userId: 'mock-user',
        title: '每日感想',
        preview: '记录今天的灵感……',
        content: '记录今天的灵感和心情，并思考下一步行动。',
        date: now.subtract(const Duration(days: 1)),
        category: NoteCategory.diary,
        hasAttachment: false,
        progressPercent: null,
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: null,
        defaultLocale: 'zh-CN',
        tags: ['灵感'],
        attachments: [],
      ),
    ]);
  }

  @override
  Future<NoteFeed> fetchFeed() async {
    final entries = _notes.map(NoteSummary.fromDetail).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final sections = <DateTime, List<NoteSummary>>{};
    for (final note in entries) {
      final key = DateTime(note.date.year, note.date.month);
      sections.putIfAbsent(key, () => []).add(note);
    }

    final sectionList =
        sections.entries
            .map(
              (entry) => NoteSection(
                label: '${entry.key.year}年${entry.key.month}月',
                date: entry.key,
                notes: entry.value,
              ),
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));

    return NoteFeed(entries: entries, sections: sectionList);
  }

  @override
  Future<NoteDetail> fetchDetail(String id) async {
    final note = _notes.firstWhere(
      (item) => item.id == id,
      orElse: () => throw StateError('Not found'),
    );
    return note;
  }

  @override
  Future<List<NoteSummary>> search(String query, {int? limit}) async {
    final lowered = query.toLowerCase();
    final results = _notes
        .where((note) {
          return note.title.toLowerCase().contains(lowered) ||
              (note.content?.toLowerCase().contains(lowered) ?? false) ||
              note.tags.any((tag) => tag.toLowerCase().contains(lowered));
        })
        .map(NoteSummary.fromDetail);
    final list = results.toList()..sort((a, b) => b.date.compareTo(a.date));
    if (limit != null && list.length > limit) {
      return list.sublist(0, limit);
    }
    return list;
  }

  @override
  Future<NoteDetail> create(NoteDraft draft) async {
    final id = 'mock-note-${_random.nextInt(1 << 32)}';
    final detail = NoteDetail(
      id: id,
      userId: draft.userId,
      title: draft.title,
      preview: draft.preview,
      content: draft.content,
      date: draft.date,
      category: draft.category,
      hasAttachment: draft.attachments.isNotEmpty,
      progressPercent: draft.progressPercent,
      createdAt: DateTime.now(),
      updatedAt: null,
      defaultLocale: draft.defaultLocale,
      tags: List<String>.from(draft.tags),
      attachments: draft.attachments
          .map(
            (attachment) => NoteAttachment(
              id: attachment.id ?? 'att-${_random.nextInt(1 << 32)}',
              fileName: attachment.fileName,
              fileUrl: attachment.fileUrl,
              mimeType: attachment.mimeType,
              sizeBytes: attachment.sizeBytes,
              createdAt: DateTime.now(),
            ),
          )
          .toList(),
    );
    _notes.add(detail);
    return detail;
  }

  @override
  Future<NoteDetail> update(String id, NoteDraft draft) async {
    final index = _notes.indexWhere((note) => note.id == id);
    if (index == -1) {
      throw StateError('笔记不存在');
    }
    final updated = NoteDetail(
      id: id,
      userId: draft.userId,
      title: draft.title,
      preview: draft.preview,
      content: draft.content,
      date: draft.date,
      category: draft.category,
      hasAttachment: draft.attachments.isNotEmpty,
      progressPercent: draft.progressPercent,
      createdAt: _notes[index].createdAt,
      updatedAt: DateTime.now(),
      defaultLocale: draft.defaultLocale,
      tags: List<String>.from(draft.tags),
      attachments: draft.attachments
          .map(
            (attachment) => NoteAttachment(
              id: attachment.id ?? 'att-${_random.nextInt(1 << 32)}',
              fileName: attachment.fileName,
              fileUrl: attachment.fileUrl,
              mimeType: attachment.mimeType,
              sizeBytes: attachment.sizeBytes,
              createdAt: DateTime.now(),
            ),
          )
          .toList(),
    );
    _notes[index] = updated;
    return updated;
  }

  @override
  Future<void> delete(String id) async {
    _notes.removeWhere((note) => note.id == id);
  }
}