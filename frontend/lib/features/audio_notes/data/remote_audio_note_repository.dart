import '../../../core/network/api_client.dart';
import '../../auth/domain/entities/auth_user.dart';
import '../domain/entities/audio_note.dart';
import 'audio_note_repository.dart';

class RemoteAudioNoteRepository extends AudioNoteSessionRepository {
  RemoteAudioNoteRepository(super.session, this._client);

  final ApiClient _client;

  @override
  Future<AudioNoteCollection> fetchNotes({AudioNoteQuery? query}) async {
    final user = _requireUser();
    final buffer = StringBuffer(
      '/audio-notes/?user_id=${Uri.encodeComponent(user.id)}&limit=${query?.limit ?? 100}&skip=${query?.skip ?? 0}',
    );
    if (query?.statuses != null) {
      for (final status in query!.statuses!) {
        buffer.write('&status=${Uri.encodeComponent(status.name)}');
      }
    }
    if (query?.search != null && query!.search!.isNotEmpty) {
      buffer.write('&search=${Uri.encodeComponent(query.search!.trim())}');
    }
    final response = await _client.getJson(buffer.toString());
    final payload = _unwrap(response);
    return AudioNoteCollection.fromJson(payload);
  }

  @override
  Future<AudioNote> fetchNote(String id) async {
    final user = _requireUser();
    final response = await _client.getJson(
      '/audio-notes/${Uri.encodeComponent(id)}?user_id=${Uri.encodeComponent(user.id)}',
    );
    final payload = _unwrap(response);
    return AudioNote.fromJson(payload);
  }

  @override
  Future<AudioNote> create(AudioNoteDraft draft) async {
    final user = _requireUser();
    draft.userId = user.id;
    final response = await _client.postJson('/audio-notes/', draft.toCreatePayload());
    final payload = _unwrap(response);
    return AudioNote.fromJson(payload);
  }

  @override
  Future<AudioNote> update(String id, AudioNoteDraft draft) async {
    final user = _requireUser();
    final response = await _client.putJson(
      '/audio-notes/${Uri.encodeComponent(id)}?user_id=${Uri.encodeComponent(user.id)}',
      draft.toUpdatePayload(),
    );
    final payload = _unwrap(response);
    return AudioNote.fromJson(payload);
  }

  @override
  Future<AudioNote> updateTranscription(
    String id, {
    required AudioNoteStatus status,
    String? text,
    String? language,
    String? error,
  }) async {
    final user = _requireUser();
    final response = await _client.postJson(
      '/audio-notes/${Uri.encodeComponent(id)}/transcription?user_id=${Uri.encodeComponent(user.id)}',
      {
        'transcription_status': status.name,
        'transcription_text': text,
        'transcription_language': language,
        'transcription_error': error,
      },
    );
    final payload = _unwrap(response);
    return AudioNote.fromJson(payload);
  }

  @override
  Future<void> delete(String id) async {
    final user = _requireUser();
    await _client.delete(
      '/audio-notes/${Uri.encodeComponent(id)}?user_id=${Uri.encodeComponent(user.id)}',
    );
  }

  Map<String, dynamic> _unwrap(Map<String, dynamic> json) {
    if (json.containsKey('id') || json.containsKey('items')) {
      return json;
    }
    final data = json['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    throw const FormatException('Unexpected audio note payload');
  }

  AuthUser _requireUser() {
    final user = session.currentUser;
    if (user == null) {
      throw StateError('Audio note operation requires authenticated user');
    }
    return user;
  }
}
