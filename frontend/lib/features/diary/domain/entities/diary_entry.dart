enum DiaryCategory { diary, checklist, idea, journal, reminder }

class DiaryAttachment {
  const DiaryAttachment({
    required this.id,
    required this.fileName,
    required this.fileUrl,
    this.mimeType,
    this.sizeBytes,
    this.createdAt,
  });

  factory DiaryAttachment.fromJson(Map<String, dynamic> json) {
    return DiaryAttachment(
      id: json['id'] as String? ?? '',
      fileName: json['file_name'] as String? ?? '',
      fileUrl: json['file_url'] as String? ?? '',
      mimeType: json['mime_type'] as String?,
      sizeBytes: (json['size_bytes'] as num?)?.toInt(),
      createdAt: _parseDateTime(json['created_at']),
    );
  }

  final String id;
  final String fileName;
  final String fileUrl;
  final String? mimeType;
  final int? sizeBytes;
  final DateTime? createdAt;
}

class DiaryAttachmentDraft {
  DiaryAttachmentDraft({
    this.id,
    this.fileName = '',
    this.fileUrl = '',
    this.mimeType,
    this.sizeBytes,
  });

  factory DiaryAttachmentDraft.fromAttachment(DiaryAttachment attachment) {
    return DiaryAttachmentDraft(
      id: attachment.id,
      fileName: attachment.fileName,
      fileUrl: attachment.fileUrl,
      mimeType: attachment.mimeType,
      sizeBytes: attachment.sizeBytes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'file_name': fileName,
      'file_url': fileUrl,
      if (mimeType != null && mimeType!.isNotEmpty) 'mime_type': mimeType,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
    };
  }

  String? id;
  String fileName;
  String fileUrl;
  String? mimeType;
  int? sizeBytes;
}

class DiaryEntry {
  const DiaryEntry({
    required this.id,
    required this.date,
    required this.category,
    required this.weather,
    required this.mood,
    required this.title,
    required this.content,
    required this.tags,
    required this.canShare,
    required this.attachments,
    this.templateId,
    this.share,
  });

  factory DiaryEntry.fromJson(Map<String, dynamic> json) {
    final rawDate = json['date'] ?? json['created_at'];
    final parsedDate = rawDate is String
        ? DateTime.tryParse(rawDate) ?? DateTime.now()
        : DateTime.now();
    final tags = (json['tags'] as List<dynamic>? ?? [])
        .whereType<String>()
        .toList();
    final sharePayload = json['share'];
    final share = sharePayload is Map<String, dynamic>
        ? DiaryShare.fromJson(sharePayload)
        : null;
    final attachments = (json['attachments'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(DiaryAttachment.fromJson)
        .toList(growable: false);
    final rawCategory = (json['category'] as String? ?? '').toLowerCase();
    final category = DiaryCategory.values.firstWhere(
      (item) => item.name == rawCategory,
      orElse: () => DiaryCategory.journal,
    );

    return DiaryEntry(
      id: json['id'] as String? ?? '',
      date: parsedDate,
      category: category,
      weather: json['weather'] as String? ?? '',
      mood: json['mood'] as String? ?? '',
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      tags: tags,
      canShare: json['can_share'] as bool? ?? false,
      attachments: attachments,
      templateId: json['template_id'] as String?,
      share: share,
    );
  }

  final String id;
  final DateTime date;
  final DiaryCategory category;
  final String weather;
  final String mood;
  final String title;
  final String content;
  final List<String> tags;
  final bool canShare;
  final List<DiaryAttachment> attachments;
  final String? templateId;
  final DiaryShare? share;

  DiaryEntry copyWith({
    String? id,
    DateTime? date,
    DiaryCategory? category,
    String? weather,
    String? mood,
    String? title,
    String? content,
    List<String>? tags,
    bool? canShare,
    List<DiaryAttachment>? attachments,
    String? templateId,
    DiaryShare? share,
  }) {
    return DiaryEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      category: category ?? this.category,
      weather: weather ?? this.weather,
      mood: mood ?? this.mood,
      title: title ?? this.title,
      content: content ?? this.content,
      tags: tags ?? List<String>.from(this.tags),
      canShare: canShare ?? this.canShare,
      attachments: attachments ?? List<DiaryAttachment>.from(this.attachments),
      templateId: templateId ?? this.templateId,
      share: share ?? this.share,
    );
  }
}

class DiaryTemplate {
  const DiaryTemplate({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.accentColor,
  });

  factory DiaryTemplate.fromJson(Map<String, dynamic> json) {
    return DiaryTemplate(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      accentColor: json['accent_color'] as int? ?? 0xFFFF8B3D,
    );
  }

  final String id;
  final String title;
  final String subtitle;
  final int accentColor;
}

DateTime? _parseDateTime(Object? value) {
  if (value is DateTime) {
    return value.toLocal();
  }
  if (value is String && value.isNotEmpty) {
    final formatted = value.endsWith('Z') ? value.replaceFirst('Z', '') : value;
    return DateTime.tryParse(formatted)?.toLocal();
  }
  return null;
}

class DiaryShare {
  const DiaryShare({
    required this.id,
    required this.url,
    this.createdAt,
    this.expiresAt,
  });

  factory DiaryShare.fromJson(Map<String, dynamic> json) {
    return DiaryShare(
      id: json['share_id'] as String? ?? '',
      url: json['share_url'] as String? ?? '',
      createdAt: _parseDateTime(json['created_at']),
      expiresAt: _parseDateTime(json['expires_at']),
    );
  }

  final String id;
  final String url;
  final DateTime? createdAt;
  final DateTime? expiresAt;
}
