import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/localization/locale_utils.dart';
import '../../domain/entities/diary_draft.dart';
import '../../domain/entities/diary_entry.dart';

class DiaryComposeSheet extends StatefulWidget {
  const DiaryComposeSheet({super.key, this.initial, this.templates = const []});

  final DiaryEntry? initial;
  final List<DiaryTemplate> templates;

  @override
  State<DiaryComposeSheet> createState() => _DiaryComposeSheetState();
}

class _DiaryComposeSheetState extends State<DiaryComposeSheet> {
  static const Map<String, ({String zh, String en})> _moodLabels = {
    'joyful': (zh: '愉悦', en: 'Joyful'),
    'calm': (zh: '平静', en: 'Calm'),
    'focused': (zh: '专注', en: 'Focused'),
    'grateful': (zh: '感恩', en: 'Grateful'),
    'anxious': (zh: '紧张', en: 'Anxious'),
    'tired': (zh: '疲惫', en: 'Tired'),
  };

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late final TextEditingController _weatherController;
  late final TextEditingController _tagController;
  late DateTime _selectedDate;
  String? _selectedTemplateId;
  String? _selectedMood;
  late final ValueNotifier<bool> _canShareNotifier;
  late List<String> _tags;
  late List<DiaryAttachmentDraft> _attachments;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _titleController = TextEditingController(text: initial?.title ?? '');
    _contentController = TextEditingController(text: initial?.content ?? '');
    _weatherController = TextEditingController(text: initial?.weather ?? '');
    _tagController = TextEditingController();
    _selectedDate = initial?.date ?? DateTime.now();
    _selectedTemplateId = initial?.templateId;
    final initialMood = initial?.mood;
    _selectedMood = (initialMood != null && initialMood.isNotEmpty)
        ? initialMood
        : null;
    _canShareNotifier = ValueNotifier<bool>(initial?.canShare ?? false);
    _tags = List<String>.from(initial?.tags ?? []);
    _attachments = initial?.attachments
            .map(DiaryAttachmentDraft.fromAttachment)
            .toList(growable: true) ??
        <DiaryAttachmentDraft>[];
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _weatherController.dispose();
    _tagController.dispose();
    _canShareNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      context.tr(
                        widget.initial == null ? '写日记' : '编辑日记',
                        widget.initial == null ? 'Write Diary' : 'Edit Diary',
                      ),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                if (widget.templates.isNotEmpty) ...[
                  Text(
                    context.tr('快速模板', 'Quick templates'),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final template in widget.templates)
                        ChoiceChip(
                          label: Text(template.title),
                          selected: _selectedTemplateId == template.id,
                          onSelected: (_) => _applyTemplate(template),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: context.tr('标题', 'Title'),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return context.tr('请输入标题', 'Please enter a title');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: _contentController,
                  maxLines: 6,
                  decoration: InputDecoration(
                    labelText: context.tr('正文内容', 'Body content'),
                    alignLabelWithHint: true,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return context.tr('请输入正文内容', 'Please enter diary content');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: _weatherController,
                  decoration: InputDecoration(
                    labelText: context.tr('天气', 'Weather'),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  context.tr('心情', 'Mood'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    ChoiceChip(
                      label: Text(context.tr('不设置', 'None')),
                      selected: _selectedMood == null,
                      onSelected: (_) => setState(() => _selectedMood = null),
                    ),
                    for (final entry in _moodLabels.entries)
                      ChoiceChip(
                        label: Text(context.tr(entry.value.zh, entry.value.en)),
                        selected: _selectedMood == entry.key,
                        onSelected: (_) =>
                            setState(() => _selectedMood = entry.key),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  context.tr('标签', 'Tags'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (_tags.isEmpty)
                  Text(
                    context.tr('尚未添加标签', 'No tags yet'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                if (_tags.isNotEmpty)
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: _tags
                        .map(
                          (tag) => Chip(
                            label: Text(tag),
                            onDeleted: () => setState(() => _tags.remove(tag)),
                          ),
                        )
                        .toList(),
                  ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _tagController,
                  decoration: InputDecoration(
                    hintText: context.tr('添加标签', 'Add tag'),
                    suffixIcon: const Icon(Icons.add),
                  ),
                  onSubmitted: _handleAddTag,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  context.tr('附件', 'Attachments'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (_attachments.isEmpty)
                  Text(
                    context.tr(
                      '还没有附件，支持图片或语音链接',
                      'No attachments yet. Images or voice URLs are supported.',
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                if (_attachments.isNotEmpty)
                  ..._attachments.map(
                    (draft) => _AttachmentTile(
                      draft: draft,
                      onEdit: () => _editAttachment(draft),
                      onRemove: () => setState(() {
                        _attachments.remove(draft);
                      }),
                    ),
                  ),
                const SizedBox(height: AppSpacing.sm),
                TextButton.icon(
                  onPressed: _handleAddAttachment,
                  icon: const Icon(Icons.attachment_outlined),
                  label: Text(context.tr('添加附件', 'Add attachment')),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: Text(_formatDate(_selectedDate)),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    ValueListenableBuilder<bool>(
                      valueListenable: _canShareNotifier,
                      builder: (context, value, _) {
                        return Row(
                          children: [
                            Text(context.tr('允许分享', 'Allow sharing')),
                            Switch(
                              value: value,
                              onChanged: (status) =>
                                  _canShareNotifier.value = status,
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                FilledButton(
                  onPressed: _handleSubmit,
                  child: Text(
                    context.tr('保存', widget.initial == null ? 'Create' : 'Save'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _applyTemplate(DiaryTemplate template) {
    setState(() {
      _selectedTemplateId = template.id;
      _titleController.text = template.title;
    });
  }

  void _handleAddTag(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return;
    }
    if (!_tags.contains(normalized)) {
      setState(() {
        _tags.add(normalized);
      });
    }
    _tagController.clear();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _handleAddAttachment() async {
    final draft = await _showAttachmentDialog();
    if (draft == null) {
      return;
    }
    setState(() {
      if (draft.id != null) {
        final index = _attachments.indexWhere((item) => item.id == draft.id);
        if (index >= 0) {
          _attachments[index] = draft;
          return;
        }
      }
      _attachments.add(draft);
    });
  }

  Future<void> _editAttachment(DiaryAttachmentDraft draft) async {
    final edited = await _showAttachmentDialog(initial: draft);
    if (edited == null) {
      return;
    }
    setState(() {
      final index = _attachments.indexOf(draft);
      if (index >= 0) {
        _attachments[index] = edited;
      }
    });
  }

  Future<DiaryAttachmentDraft?> _showAttachmentDialog({DiaryAttachmentDraft? initial}) async {
    final nameController = TextEditingController(text: initial?.fileName ?? '');
    final urlController = TextEditingController(text: initial?.fileUrl ?? '');
    final mimeController = TextEditingController(text: initial?.mimeType ?? '');
    final sizeController = TextEditingController(
      text: initial?.sizeBytes?.toString() ?? '',
    );

    final formKey = GlobalKey<FormState>();

    final draft = await showDialog<DiaryAttachmentDraft>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(context.tr('添加附件', 'Add attachment')),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: context.tr('附件名称（选填）', 'Display name (optional)'),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: urlController,
                  decoration: InputDecoration(
                    labelText: context.tr('链接地址', 'Link URL'),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return context.tr('请输入有效链接', 'Please enter a valid URL');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: mimeController,
                  decoration: InputDecoration(
                    labelText: context.tr('MIME 类型（选填）', 'MIME type (optional)'),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: sizeController,
                  decoration: InputDecoration(
                    labelText: context.tr('大小（字节，选填）', 'Size in bytes (optional)'),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.tr('取消', 'Cancel')),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() != true) {
                  return;
                }
                final parsedSize = int.tryParse(sizeController.text.trim());
                Navigator.of(context).pop(
                  DiaryAttachmentDraft(
                    id: initial?.id,
                    fileName: nameController.text.trim(),
                    fileUrl: urlController.text.trim(),
                    mimeType: mimeController.text.trim().isEmpty
                        ? null
                        : mimeController.text.trim(),
                    sizeBytes: parsedSize,
                  ),
                );
              },
              child: Text(context.tr('确定', 'Confirm')),
            ),
          ],
        );
      },
    );

    nameController.dispose();
    urlController.dispose();
    mimeController.dispose();
    sizeController.dispose();

    return draft;
  }

  void _handleSubmit() {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    Navigator.of(context).pop(
      DiaryDraft(
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        date: _selectedDate,
        mood: _selectedMood ?? '',
        weather: _weatherController.text.trim(),
        templateId: _selectedTemplateId,
        canShare: _canShareNotifier.value,
        tags: _tags,
        attachments: _attachments,
      ),
    );
  }

  String _formatDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({
    required this.draft,
    required this.onEdit,
    required this.onRemove,
  });

  final DiaryAttachmentDraft draft;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = [
      if (draft.mimeType != null && draft.mimeType!.isNotEmpty) draft.mimeType!,
      if (draft.sizeBytes != null && draft.sizeBytes! > 0)
        '${draft.sizeBytes} B',
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: const Icon(Icons.attachment_outlined),
        title: Text(
          draft.fileName.isEmpty ? draft.fileUrl : draft.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              draft.fileUrl,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
            if (subtitle.isNotEmpty)
              Text(
                subtitle,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
          ],
        ),
        trailing: Wrap(
          spacing: 0,
          children: [
            IconButton(
              tooltip: context.tr('编辑附件', 'Edit attachment'),
              icon: const Icon(Icons.edit_outlined),
              onPressed: onEdit,
            ),
            IconButton(
              tooltip: context.tr('移除附件', 'Remove attachment'),
              icon: const Icon(Icons.delete_outline),
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}
