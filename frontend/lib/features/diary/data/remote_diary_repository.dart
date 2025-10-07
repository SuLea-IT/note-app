import 'package:uuid/uuid.dart';

import '../../auth/domain/auth_session.dart';
import '../../auth/domain/entities/auth_user.dart';
import '../../../core/network/api_client.dart';
import '../domain/entities/diary_draft.dart';
import '../domain/entities/diary_entry.dart';
import 'diary_repository.dart';

class RemoteDiaryRepository implements DiaryRepository {
  RemoteDiaryRepository(this._client, this._session);

  final ApiClient _client;
  final AuthSession _session;
  final Uuid _uuid = const Uuid();

  List<DiaryEntry> _entries = [];
  List<DiaryTemplate> _templates = [];

  @override
  Future<DiaryFeed> fetchFeed() async {
    final user = _requireUser();
    final response = await _client.getJson(
      '/diaries/feed?user_id=${Uri.encodeComponent(user.id)}&lang=${Uri.encodeComponent(user.preferredLocale)}',
    );
    final payload = _unwrapFeed(response);
    final entries = (payload['entries'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(_mapEntry)
        .toList();
    final templates = (payload['templates'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(_mapTemplate)
        .toList();

    _entries = entries;
    _templates = templates.isEmpty ? _defaultTemplates : templates;
    return DiaryFeed(entries: _entries, templates: _templates);
  }

  @override
  Future<DiaryEntry> createDiary(DiaryDraft draft) async {
    final user = _requireUser();
    final response = await _client.postJson(
      '/diaries?user_id=${Uri.encodeComponent(user.id)}',
      _draftPayload(draft, user),
    );
    final entry = _mapEntry(response, fallback: draft, generatedId: _uuid.v4());
    _entries = [entry, ..._entries];
    return entry;
  }

  @override
  Future<DiaryEntry> updateDiary(String id, DiaryDraft draft) async {
    final user = _requireUser();
    final response = await _client.putJson(
      '/diaries/$id?user_id=${Uri.encodeComponent(user.id)}',
      _draftPayload(draft, user),
    );
    DiaryEntry? existing;
    for (final entry in _entries) {
      if (entry.id == id) {
        existing = entry;
        break;
      }
    }

    final updated = _mapEntry(
      response,
      fallback: draft,
      existing: existing,
      generatedId: id,
    );
    _entries = _entries
        .map((entry) => entry.id == id ? updated : entry)
        .toList(growable: false);
    return updated;
  }

  @override
  Future<void> deleteDiary(String id) async {
    final user = _requireUser();
    await _client.delete(
      '/diaries/$id?user_id=${Uri.encodeComponent(user.id)}',
    );
    _entries = _entries.where((entry) => entry.id != id).toList();
  }

  @override
  Future<DiaryShare> shareDiary(String id, {int? expiresInHours}) async {
    final user = _requireUser();
    final buffer = StringBuffer(
      '/diaries/$id/share?user_id=${Uri.encodeComponent(user.id)}',
    );
    if (expiresInHours != null) {
      buffer.write('&expires_in_hours=$expiresInHours');
    }

    final response = await _client.postJson(
      buffer.toString(),
      <String, dynamic>{},
    );
    final payload = _unwrapShare(response);
    final share = DiaryShare.fromJson(payload);
    _entries = _entries
        .map((entry) => entry.id == id ? entry.copyWith(share: share) : entry)
        .toList(growable: false);
    return share;
  }

  Map<String, dynamic> _draftPayload(DiaryDraft draft, AuthUser user) {
    final payload = draft.toJson();
    payload['user_id'] = user.id;
    payload['default_locale'] = user.preferredLocale;
    payload['translations'] = [
      {
        'locale': user.preferredLocale,
        'title': draft.title,
        'preview': draft.content.length > 60
            ? draft.content.substring(0, 60)
            : draft.content,
        'content': draft.content,
      },
    ];
    return payload;
  }

  Map<String, dynamic> _unwrapFeed(Map<String, dynamic> json) {
    if (json.containsKey('entries')) {
      return json;
    }
    final data = json['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    throw const FormatException('Unexpected diary feed payload');
  }

  Map<String, dynamic> _unwrapShare(Map<String, dynamic> json) {
    if (json.containsKey('share_id')) {
      return json;
    }
    final data = json['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    throw const FormatException('Unexpected diary share payload');
  }

  DiaryEntry _mapEntry(
    Map<String, dynamic> json, {
    DiaryDraft? fallback,
    DiaryEntry? existing,
    String? generatedId,
  }) {
    final dateValue = json['date'] ?? json['created_at'];
    final date = dateValue is String
        ? DateTime.tryParse(dateValue) ?? DateTime.now()
        : DateTime.now();
    final tags = (json['tags'] as List<dynamic>? ?? [])
        .whereType<String>()
        .toList();
    final sharePayload = json['share'];
    final share = sharePayload is Map<String, dynamic>
        ? DiaryShare.fromJson(sharePayload)
        : existing?.share;
    final rawAttachments = (json['attachments'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(DiaryAttachment.fromJson)
        .toList(growable: false);
    final rawCategory =
        (json['category'] as String? ?? fallback?.category.name ?? '')
            .toLowerCase();
    final category = DiaryCategory.values.firstWhere(
      (item) => item.name == rawCategory,
      orElse: () => fallback?.category ?? DiaryCategory.journal,
    );

    return DiaryEntry(
      id: json['id'] as String? ?? generatedId ?? _uuid.v4(),
      date: date,
      category: category,
      weather: json['weather'] as String? ?? fallback?.weather ?? '',
      mood: json['mood'] as String? ?? fallback?.mood ?? '',
      title: json['title'] as String? ?? fallback?.title ?? '',
      content: json['content'] as String? ?? fallback?.content ?? '',
      tags: tags.isEmpty ? List<String>.from(fallback?.tags ?? []) : tags,
      canShare: json['can_share'] as bool? ?? fallback?.canShare ?? false,
      attachments: rawAttachments.isEmpty && fallback != null
          ? fallback.attachments
                .map(
                  (attachment) => DiaryAttachment(
                    id: attachment.id ?? _uuid.v4(),
                    fileName: attachment.fileName,
                    fileUrl: attachment.fileUrl,
                    mimeType: attachment.mimeType,
                    sizeBytes: attachment.sizeBytes,
                    createdAt: DateTime.now(),
                  ),
                )
                .toList(growable: false)
          : rawAttachments,
      templateId: json['template_id'] as String? ?? fallback?.templateId,
      share: share,
    );
  }

  DiaryTemplate _mapTemplate(Map<String, dynamic> json) {
    return DiaryTemplate(
      id: json['id'] as String? ?? _uuid.v4(),
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      accentColor: json['accent_color'] as int? ?? 0xFFFF8B3D,
    );
  }

  List<DiaryTemplate> get _defaultTemplates => [
    DiaryTemplate(
      id: 'tpl-inspiration',
      title: 'Inspiration Log',
      subtitle: 'Capture sparks from each day',
      accentColor: 0xFFFF8B3D,
    ),
    DiaryTemplate(
      id: 'tpl-mood',
      title: 'Mood Journal',
      subtitle: 'Track your feelings across the day',
      accentColor: 0xFF7C4DFF,
    ),
    DiaryTemplate(
      id: 'tpl-retro',
      title: 'Project Retro',
      subtitle: 'Review goals and next steps',
      accentColor: 0xFFF06292,
    ),
  ];

  AuthUser _requireUser() {
    final user = _session.currentUser;
    if (user == null) {
      throw StateError('User session is required');
    }
    return user;
  }
}
