import 'package:flutter/material.dart';

enum NoteCategory { diary, checklist, idea, journal, reminder }

extension NoteCategoryColor on NoteCategory {
  Color get color {
    switch (this) {
      case NoteCategory.diary:
        return const Color(0xFFFFA726);
      case NoteCategory.checklist:
        return const Color(0xFF66BB6A);
      case NoteCategory.idea:
        return const Color(0xFF7E57C2);
      case NoteCategory.journal:
        return const Color(0xFF42A5F5);
      case NoteCategory.reminder:
        return const Color(0xFFEF5350);
    }
  }

  IconData get icon {
    switch (this) {
      case NoteCategory.diary:
        return Icons.book_outlined;
      case NoteCategory.checklist:
        return Icons.check_circle_outlined;
      case NoteCategory.idea:
        return Icons.lightbulb_outline;
      case NoteCategory.journal:
        return Icons.edit_note_outlined;
      case NoteCategory.reminder:
        return Icons.notifications_active_outlined;
    }
  }
}

class NoteAttachment {
  const NoteAttachment({
    required this.id,
    required this.fileName,
    required this.fileUrl,
    this.mimeType,
    this.sizeBytes,
    this.createdAt,
  });

  factory NoteAttachment.fromJson(Map<String, dynamic> json) {
    return NoteAttachment(
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

class NoteAttachmentDraft {
  NoteAttachmentDraft({
    this.id,
    this.fileName = '',
    this.fileUrl = '',
    this.mimeType,
    this.sizeBytes,
  });

  factory NoteAttachmentDraft.fromAttachment(NoteAttachment attachment) {
    return NoteAttachmentDraft(
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
      if (mimeType != null) 'mime_type': mimeType,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
    };
  }

  String? id;
  String fileName;
  String fileUrl;
  String? mimeType;
  int? sizeBytes;
}

class NoteSummary {
  const NoteSummary({
    required this.id,
    required this.userId,
    required this.title,
    required this.preview,
    required this.date,
    required this.category,
    this.hasAttachment = false,
    this.progressPercent,
    this.tags = const [],
  });

  factory NoteSummary.fromJson(Map<String, dynamic> json) {
    final rawCategory = (json['category'] as String? ?? '').toLowerCase();
    final category = NoteCategory.values.firstWhere(
      (item) => item.name == rawCategory,
      orElse: () => NoteCategory.journal,
    );

    final tags = (json['tags'] as List<dynamic>? ?? [])
        .whereType<String>()
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList(growable: false);

    return NoteSummary(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      preview: json['preview'] as String? ?? '',
      date: _parseDateTime(json['date']),
      category: category,
      hasAttachment: json['has_attachment'] as bool? ?? false,
      progressPercent: (json['progress_percent'] as num?)?.toDouble(),
      tags: tags,
    );
  }

  factory NoteSummary.fromDetail(NoteDetail detail) {
    return NoteSummary(
      id: detail.id,
      userId: detail.userId,
      title: detail.title,
      preview: detail.preview ?? '',
      date: detail.date,
      category: detail.category,
      hasAttachment: detail.hasAttachment,
      progressPercent: detail.progressPercent,
      tags: detail.tags,
    );
  }

  final String id;
  final String userId;
  final String title;
  final String preview;
  final DateTime date;
  final NoteCategory category;
  final bool hasAttachment;
  final double? progressPercent;
  final List<String> tags;
}

class NoteSection {
  const NoteSection({
    required this.label,
    required this.date,
    required this.notes,
  });

  factory NoteSection.fromJson(Map<String, dynamic> json) {
    final notes = (json['notes'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(NoteSummary.fromJson)
        .toList();

    return NoteSection(
      label: json['label'] as String? ?? '',
      date: _parseDateTime(json['date']),
      notes: notes,
    );
  }

  final String label;
  final DateTime date;
  final List<NoteSummary> notes;
}

class NoteDetail {
  const NoteDetail({
    required this.id,
    required this.userId,
    required this.title,
    required this.date,
    required this.category,
    required this.createdAt,
    required this.hasAttachment,
    required this.defaultLocale,
    this.preview,
    this.content,
    this.progressPercent,
    this.updatedAt,
    this.tags = const [],
    this.attachments = const [],
  });

  factory NoteDetail.fromJson(Map<String, dynamic> json) {
    final rawCategory = (json['category'] as String? ?? '').toLowerCase();
    final category = NoteCategory.values.firstWhere(
      (item) => item.name == rawCategory,
      orElse: () => NoteCategory.journal,
    );

    final attachments = (json['attachments'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(NoteAttachment.fromJson)
        .toList(growable: false);

    final tags = (json['tags'] as List<dynamic>? ?? [])
        .whereType<String>()
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList(growable: false);

    return NoteDetail(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      preview: json['preview'] as String?,
      content: json['content'] as String?,
      date: _parseDateTime(json['date']),
      category: category,
      hasAttachment: json['has_attachment'] as bool? ?? attachments.isNotEmpty,
      progressPercent: (json['progress_percent'] as num?)?.toDouble(),
      createdAt: _parseDateTime(json['created_at'] ?? json['date']),
      updatedAt: _parseOptionalDateTime(json['updated_at']),
      defaultLocale: json['default_locale'] as String? ?? 'en-US',
      tags: tags,
      attachments: attachments,
    );
  }

  factory NoteDetail.fromSummary(NoteSummary summary) {
    return NoteDetail(
      id: summary.id,
      userId: summary.userId,
      title: summary.title,
      preview: summary.preview,
      date: summary.date,
      category: summary.category,
      hasAttachment: summary.hasAttachment,
      progressPercent: summary.progressPercent,
      createdAt: summary.date,
      updatedAt: null,
      defaultLocale: 'en-US',
      tags: summary.tags,
      attachments: [],
    );
  }

  final String id;
  final String userId;
  final String title;
  final String? preview;
  final String? content;
  final DateTime date;
  final NoteCategory category;
  final bool hasAttachment;
  final double? progressPercent;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String defaultLocale;
  final List<String> tags;
  final List<NoteAttachment> attachments;

  NoteDetail copyWith({
    String? userId,
    String? title,
    String? preview,
    String? content,
    DateTime? date,
    NoteCategory? category,
    bool? hasAttachment,
    double? progressPercent,
    DateTime? updatedAt,
    String? defaultLocale,
    List<String>? tags,
    List<NoteAttachment>? attachments,
  }) {
    return NoteDetail(
      id: id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      preview: preview ?? this.preview,
      content: content ?? this.content,
      date: date ?? this.date,
      category: category ?? this.category,
      hasAttachment: hasAttachment ?? this.hasAttachment,
      progressPercent: progressPercent ?? this.progressPercent,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      defaultLocale: defaultLocale ?? this.defaultLocale,
      tags: tags ?? this.tags,
      attachments: attachments ?? this.attachments,
    );
  }
}

class NoteDraft {
  NoteDraft({
    required this.id,
    required this.userId,
    required this.title,
    required this.date,
    required this.category,
    required this.defaultLocale,
    this.preview,
    this.content,
    this.progressPercent,
    List<String>? tags,
    List<NoteAttachmentDraft>? attachments,
  }) : tags = tags ?? <String>[],
       attachments = attachments ?? <NoteAttachmentDraft>[];

  factory NoteDraft.fromDetail(NoteDetail detail) {
    return NoteDraft(
      id: detail.id,
      userId: detail.userId,
      title: detail.title,
      preview: detail.preview,
      content: detail.content,
      date: detail.date,
      category: detail.category,
      progressPercent: detail.progressPercent,
      defaultLocale: detail.defaultLocale,
      tags: List<String>.from(detail.tags),
      attachments: detail.attachments
          .map(NoteAttachmentDraft.fromAttachment)
          .toList(growable: true),
    );
  }

  Map<String, dynamic> toCreatePayload() {
    return {'user_id': userId, ..._commonPayload()};
  }

  Map<String, dynamic> toUpdatePayload() {
    final payload = _commonPayload();
    payload.removeWhere((key, value) => value == null);
    payload['has_attachment'] = attachments.isNotEmpty;
    return payload;
  }

  Map<String, dynamic> _commonPayload() {
    return {
      'title': title,
      'preview': preview,
      'content': content,
      'date': date.toIso8601String(),
      'category': category.name,
      'has_attachment': attachments.isNotEmpty,
      'progress_percent': progressPercent,
      'default_locale': defaultLocale,
      'tags': tags,
      'attachments': attachments.map((item) => item.toJson()).toList(),
    };
  }

  String id;
  String userId;
  String title;
  String? preview;
  String? content;
  DateTime date;
  NoteCategory category;
  double? progressPercent;
  String defaultLocale;
  List<String> tags;
  List<NoteAttachmentDraft> attachments;
}

class NoteFeed {
  const NoteFeed({required this.entries, required this.sections});

  factory NoteFeed.fromJson(Map<String, dynamic> json) {
    final entries = (json['entries'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(NoteSummary.fromJson)
        .toList();
    final sections = (json['sections'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(NoteSection.fromJson)
        .toList();
    return NoteFeed(entries: entries, sections: sections);
  }

  final List<NoteSummary> entries;
  final List<NoteSection> sections;
}

class NoteDetailResult {
  const NoteDetailResult._({this.updatedDetail, this.deletedId});

  factory NoteDetailResult.deleted(String id) =>
      NoteDetailResult._(deletedId: id);

  factory NoteDetailResult.updated(NoteDetail detail) =>
      NoteDetailResult._(updatedDetail: detail);

  final NoteDetail? updatedDetail;
  final String? deletedId;

  bool get isDeleted => deletedId != null;
  bool get isUpdated => updatedDetail != null;
}

DateTime _parseDateTime(Object? value) {
  if (value is DateTime) {
    return value.toLocal();
  }
  if (value is String && value.isNotEmpty) {
    final formatted = value.endsWith('Z') ? value.replaceFirst('Z', '') : value;
    return DateTime.tryParse(formatted)?.toLocal() ?? DateTime.now();
  }
  return DateTime.now();
}

DateTime? _parseOptionalDateTime(Object? value) {
  if (value == null) {
    return null;
  }
  return _parseDateTime(value);
}
