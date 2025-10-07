import '../../auth/domain/auth_session.dart';
import '../domain/entities/audio_note.dart';

class AudioNoteQuery {
  const AudioNoteQuery({
    this.statuses,
    this.search,
    this.skip = 0,
    this.limit = 100,
  });

  final List<AudioNoteStatus>? statuses;
  final String? search;
  final int skip;
  final int limit;
}

abstract class AudioNoteRepository {
  Future<AudioNoteCollection> fetchNotes({AudioNoteQuery? query});

  Future<AudioNote> fetchNote(String id);

  Future<AudioNote> create(AudioNoteDraft draft);

  Future<AudioNote> update(String id, AudioNoteDraft draft);

  Future<AudioNote> updateTranscription(
    String id, {
    required AudioNoteStatus status,
    String? text,
    String? language,
    String? error,
  });

  Future<void> delete(String id);
}

abstract class AudioNoteSessionRepository extends AudioNoteRepository {
  AudioNoteSessionRepository(this.session);

  final AuthSession session;
}
