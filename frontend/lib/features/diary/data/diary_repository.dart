import '../domain/entities/diary_draft.dart';
import '../domain/entities/diary_entry.dart'
    show DiaryEntry, DiaryShare, DiaryTemplate;

class DiaryFeed {
  const DiaryFeed({required this.entries, required this.templates});

  final List<DiaryEntry> entries;
  final List<DiaryTemplate> templates;

  DiaryFeed copyWith({
    List<DiaryEntry>? entries,
    List<DiaryTemplate>? templates,
  }) {
    return DiaryFeed(
      entries: entries ?? this.entries,
      templates: templates ?? this.templates,
    );
  }
}

abstract class DiaryRepository {
  Future<DiaryFeed> fetchFeed();
  Future<DiaryEntry> createDiary(DiaryDraft draft);
  Future<DiaryEntry> updateDiary(String id, DiaryDraft draft);
  Future<void> deleteDiary(String id);
  Future<DiaryShare> shareDiary(String id, {int? expiresInHours});
}
