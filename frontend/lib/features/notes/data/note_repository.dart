import '../domain/entities/note.dart';

abstract class NoteRepository {
  Future<NoteFeed> fetchFeed();

  Future<NoteDetail> fetchDetail(String id);

  Future<List<NoteSummary>> search(String query, {int? limit});

  Future<NoteDetail> create(NoteDraft draft);

  Future<NoteDetail> update(String id, NoteDraft draft);

  Future<void> delete(String id);
}
