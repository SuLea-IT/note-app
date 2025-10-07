enum AudioNoteStatus { pending, processing, completed, failed }

extension AudioNoteStatusX on AudioNoteStatus {
  static AudioNoteStatus fromName(String raw) {
    final normalized = raw.trim().toLowerCase();
    switch (normalized) {
      case 'processing':
        return AudioNoteStatus.processing;
      case 'completed':
        return AudioNoteStatus.completed;
      case 'failed':
        return AudioNoteStatus.failed;
      default:
        return AudioNoteStatus.pending;
    }
  }

  String get label {
    switch (this) {
      case AudioNoteStatus.pending:
        return '等待转写';
      case AudioNoteStatus.processing:
        return '转换中';
      case AudioNoteStatus.completed:
        return '已完成';
      case AudioNoteStatus.failed:
        return '转写失败';
    }
  }
}

class AudioNote {
  const AudioNote({
    required this.id,
    required this.userId,
    required this.title,
    required this.fileUrl,
    required this.mimeType,
    this.description,
    this.sizeBytes,
    this.durationSeconds,
    this.transcriptionStatus = AudioNoteStatus.pending,
    this.transcriptionText,
    this.transcriptionLanguage,
    this.transcriptionError,
    this.recordedAt,
    this.createdAt,
    this.updatedAt,
    this.transcriptionUpdatedAt,
  });

  factory AudioNote.fromJson(Map<String, dynamic> json) {
    return AudioNote(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      fileUrl: json['file_url'] as String? ?? '',
      mimeType: json['mime_type'] as String? ?? 'audio/mpeg',
      sizeBytes: (json['size_bytes'] as num?)?.toInt(),
      durationSeconds: (json['duration_seconds'] as num?)?.toDouble(),
      transcriptionStatus:
          AudioNoteStatusX.fromName(json['transcription_status'] as String? ?? ''),
      transcriptionText: json['transcription_text'] as String?,
      transcriptionLanguage: json['transcription_language'] as String?,
      transcriptionError: json['transcription_error'] as String?,
      recordedAt: _parseDateTime(json['recorded_at']),
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
      transcriptionUpdatedAt: _parseDateTime(json['transcription_updated_at']),
    );
  }

  final String id;
  final String userId;
  final String title;
  final String? description;
  final String fileUrl;
  final String mimeType;
  final int? sizeBytes;
  final double? durationSeconds;
  final AudioNoteStatus transcriptionStatus;
  final String? transcriptionText;
  final String? transcriptionLanguage;
  final String? transcriptionError;
  final DateTime? recordedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? transcriptionUpdatedAt;

  bool get isProcessing =>
      transcriptionStatus == AudioNoteStatus.pending ||
      transcriptionStatus == AudioNoteStatus.processing;

  AudioNote copyWith({
    String? title,
    String? description,
    AudioNoteStatus? transcriptionStatus,
    String? transcriptionText,
    String? transcriptionLanguage,
    String? transcriptionError,
    DateTime? recordedAt,
  }) {
    return AudioNote(
      id: id,
      userId: userId,
      title: title ?? this.title,
      description: description ?? this.description,
      fileUrl: fileUrl,
      mimeType: mimeType,
      sizeBytes: sizeBytes,
      durationSeconds: durationSeconds,
      transcriptionStatus: transcriptionStatus ?? this.transcriptionStatus,
      transcriptionText: transcriptionText ?? this.transcriptionText,
      transcriptionLanguage: transcriptionLanguage ?? this.transcriptionLanguage,
      transcriptionError: transcriptionError ?? this.transcriptionError,
      recordedAt: recordedAt ?? this.recordedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
      transcriptionUpdatedAt: transcriptionUpdatedAt,
    );
  }
}

class AudioNoteCollection {
  const AudioNoteCollection({
    required this.total,
    required this.items,
  });

  factory AudioNoteCollection.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(AudioNote.fromJson)
        .toList(growable: false);
    return AudioNoteCollection(
      total: (json['total'] as num?)?.toInt() ?? items.length,
      items: items,
    );
  }

  final int total;
  final List<AudioNote> items;
}

class AudioNoteDraft {
  AudioNoteDraft({
    this.id,
    this.userId,
    this.title = '',
    this.description,
    this.fileUrl = '',
    this.mimeType = 'audio/mpeg',
    this.sizeBytes,
    this.durationSeconds,
    this.transcriptionStatus = AudioNoteStatus.pending,
    this.transcriptionText,
    this.transcriptionLanguage,
    this.transcriptionError,
    this.recordedAt,
  });

  factory AudioNoteDraft.fromAudioNote(AudioNote note) {
    return AudioNoteDraft(
      id: note.id,
      userId: note.userId,
      title: note.title,
      description: note.description,
      fileUrl: note.fileUrl,
      mimeType: note.mimeType,
      sizeBytes: note.sizeBytes,
      durationSeconds: note.durationSeconds,
      transcriptionStatus: note.transcriptionStatus,
      transcriptionText: note.transcriptionText,
      transcriptionLanguage: note.transcriptionLanguage,
      transcriptionError: note.transcriptionError,
      recordedAt: note.recordedAt,
    );
  }

  Map<String, dynamic> toCreatePayload() {
    return {
      'user_id': userId,
      'title': title,
      'description': description,
      'file_url': fileUrl,
      'mime_type': mimeType,
      'size_bytes': sizeBytes,
      'duration_seconds': durationSeconds,
      'transcription_status': transcriptionStatus.name,
      'transcription_text': transcriptionText,
      'transcription_language': transcriptionLanguage,
      'transcription_error': transcriptionError,
      'recorded_at': recordedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toUpdatePayload() {
    return {
      if (title.isNotEmpty) 'title': title,
      'description': description,
      'transcription_status': transcriptionStatus.name,
      'transcription_text': transcriptionText,
      'transcription_language': transcriptionLanguage,
      'transcription_error': transcriptionError,
      'recorded_at': recordedAt?.toIso8601String(),
    };
  }

  String? id;
  String? userId;
  String title;
  String? description;
  String fileUrl;
  String mimeType;
  int? sizeBytes;
  double? durationSeconds;
  AudioNoteStatus transcriptionStatus;
  String? transcriptionText;
  String? transcriptionLanguage;
  String? transcriptionError;
  DateTime? recordedAt;
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is DateTime) {
    return value.toLocal();
  }
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value)?.toLocal();
  }
  return null;
}