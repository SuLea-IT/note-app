import 'dart:async';

import '../domain/entities/diary_draft.dart';
import '../domain/entities/diary_entry.dart';
import 'diary_repository.dart';

class MockDiaryRepository implements DiaryRepository {
  MockDiaryRepository()
    : _entries = [
        DiaryEntry(
          id: 'diary-1',
          date: DateTime.now(),
          category: DiaryCategory.journal,
          weather: 'Sunny',
          mood: 'joyful',
          title: 'Daily Reflections',
          content:
              "Captured today's inspirations and kept the writing momentum going.",
          tags: ['inspiration', 'life'],
          canShare: true,
          templateId: 'tpl-1',
          attachments: [],
          share: DiaryShare(
            id: 'share-1',
            url: 'https://note-app.example.com/share/share-1',
            createdAt: DateTime.now(),
          ),
        ),
        DiaryEntry(
          id: 'diary-2',
          date: DateTime.now().subtract(const Duration(days: 2)),
          category: DiaryCategory.idea,
          weather: 'Cloudy',
          mood: 'reflective',
          title: 'Weekend Notes',
          content:
              'Outlined weekend plans, time with family, and prep for the new project.',
          tags: ['weekend'],
          canShare: false,
          templateId: 'tpl-2',
          attachments: [],
          share: null,
        ),
      ];

  final List<DiaryEntry> _entries;

  static const List<DiaryTemplate> _templates = [
    DiaryTemplate(
      id: 'tpl-1',
      title: 'Inspiration Log',
      subtitle: 'Capture sparks from each day',
      accentColor: 0xFFFF8B3D,
    ),
    DiaryTemplate(
      id: 'tpl-2',
      title: 'Mood Journal',
      subtitle: 'Track your feelings across the day',
      accentColor: 0xFF7C4DFF,
    ),
    DiaryTemplate(
      id: 'tpl-3',
      title: 'Project Retro',
      subtitle: 'Review goals and next steps',
      accentColor: 0xFFF06292,
    ),
  ];

  @override
  Future<DiaryFeed> fetchFeed() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final entries = _sortedEntries();
    return DiaryFeed(entries: entries, templates: _templates);
  }

  @override
  Future<DiaryEntry> createDiary(DiaryDraft draft) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final attachments = draft.attachments
        .map(
          (attachment) => DiaryAttachment(
            id: attachment.id ?? _newId(),
            fileName: attachment.fileName,
            fileUrl: attachment.fileUrl,
            mimeType: attachment.mimeType,
            sizeBytes: attachment.sizeBytes,
            createdAt: DateTime.now(),
          ),
        )
        .toList(growable: false);
    final entry = DiaryEntry(
      id: _newId(),
      date: draft.date ?? DateTime.now(),
      category: draft.category,
      weather: draft.weather,
      mood: draft.mood,
      title: draft.title,
      content: draft.content,
      tags: List<String>.from(draft.tags),
      canShare: draft.canShare,
      templateId: draft.templateId,
      attachments: attachments,
      share: null,
    );
    _entries.add(entry);
    return entry;
  }

  @override
  Future<DiaryEntry> updateDiary(String id, DiaryDraft draft) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final index = _entries.indexWhere((entry) => entry.id == id);
    if (index == -1) {
      throw StateError('Diary entry not found: $id');
    }
    final current = _entries[index];
    final attachments = draft.attachments
        .map(
          (attachment) => DiaryAttachment(
            id: attachment.id ?? _newId(),
            fileName: attachment.fileName,
            fileUrl: attachment.fileUrl,
            mimeType: attachment.mimeType,
            sizeBytes: attachment.sizeBytes,
            createdAt: DateTime.now(),
          ),
        )
        .toList(growable: false);
    final updated = current.copyWith(
      title: draft.title,
      content: draft.content,
      category: draft.category,
      weather: draft.weather,
      mood: draft.mood,
      tags: List<String>.from(draft.tags),
      canShare: draft.canShare,
      date: draft.date ?? current.date,
      templateId: draft.templateId,
      attachments: attachments,
    );
    _entries[index] = updated;
    return updated;
  }

  @override
  Future<void> deleteDiary(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    _entries.removeWhere((entry) => entry.id == id);
  }

  @override
  Future<DiaryShare> shareDiary(String id, {int? expiresInHours}) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final index = _entries.indexWhere((entry) => entry.id == id);
    if (index == -1) {
      throw StateError('Diary entry not found: $id');
    }
    final expiresAt = expiresInHours != null
        ? DateTime.now().add(Duration(hours: expiresInHours))
        : null;
    final share = DiaryShare(
      id: 'mock-share-$id',
      url: 'https://note-app.example.com/share/$id',
      createdAt: DateTime.now(),
      expiresAt: expiresAt,
    );
    final updated = _entries[index].copyWith(share: share);
    _entries[index] = updated;
    return share;
  }

  String _newId() => 'mock-${DateTime.now().microsecondsSinceEpoch}';

  List<DiaryEntry> _sortedEntries() {
    final entries = List<DiaryEntry>.from(_entries);
    entries.sort((a, b) => b.date.compareTo(a.date));
    return entries;
  }
}
