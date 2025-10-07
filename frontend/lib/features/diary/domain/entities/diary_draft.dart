import 'diary_entry.dart';

class DiaryDraft {
  DiaryDraft({
    required this.title,
    required this.content,
    this.category = DiaryCategory.journal,
    this.weather = '',
    this.mood = '',
    List<String>? tags,
    this.canShare = false,
    this.date,
    this.templateId,
    List<DiaryAttachmentDraft>? attachments,
  }) : tags = tags ?? <String>[],
       attachments = attachments ?? <DiaryAttachmentDraft>[];

  final String title;
  final String content;
  final DiaryCategory category;
  final String weather;
  final String mood;
  final List<String> tags;
  final bool canShare;
  final DateTime? date;
  final String? templateId;
  final List<DiaryAttachmentDraft> attachments;

  DiaryDraft copyWith({
    String? title,
    String? content,
    DiaryCategory? category,
    String? weather,
    String? mood,
    List<String>? tags,
    bool? canShare,
    DateTime? date,
    String? templateId,
    List<DiaryAttachmentDraft>? attachments,
  }) {
    return DiaryDraft(
      title: title ?? this.title,
      content: content ?? this.content,
      category: category ?? this.category,
      weather: weather ?? this.weather,
      mood: mood ?? this.mood,
      tags: tags ?? List<String>.from(this.tags),
      canShare: canShare ?? this.canShare,
      date: date ?? this.date,
      templateId: templateId ?? this.templateId,
      attachments:
          attachments ?? List<DiaryAttachmentDraft>.from(this.attachments),
    );
  }

  Map<String, dynamic> toJson() {
    final targetDate = (date ?? DateTime.now()).toIso8601String();
    final preview = content.length > 120 ? content.substring(0, 120) : content;
    return {
      'title': title,
      'preview': preview,
      'content': content,
      'category': category.name,
      'weather': weather,
      'mood': mood,
      'tags': tags,
      'can_share': canShare,
      'date': targetDate,
      'has_attachment': attachments.isNotEmpty,
      'attachments': attachments.map((item) => item.toJson()).toList(),
      if (templateId != null && templateId!.isNotEmpty)
        'template_id': templateId,
    };
  }

  factory DiaryDraft.fromEntry(DiaryEntry entry) {
    return DiaryDraft(
      title: entry.title,
      content: entry.content,
      category: entry.category,
      weather: entry.weather,
      mood: entry.mood,
      tags: List<String>.from(entry.tags),
      canShare: entry.canShare,
      date: entry.date,
      templateId: entry.templateId,
      attachments: entry.attachments
          .map(DiaryAttachmentDraft.fromAttachment)
          .toList(growable: true),
    );
  }
}
