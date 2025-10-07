import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/locale_utils.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../application/note_editor_controller.dart';
import '../data/note_repository.dart';
import '../domain/entities/note.dart';

class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({
    super.key,
    required this.draft,
    required this.isEditing,
  });

  final NoteDraft draft;
  final bool isEditing;

  static Route<NoteDetailResult> route({
    required NoteDraft draft,
    required bool isEditing,
  }) {
    return MaterialPageRoute(
      builder: (_) => NoteEditorScreen(draft: draft, isEditing: isEditing),
    );
  }

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _previewController;
  late final TextEditingController _contentController;
  late final TextEditingController _tagInputController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.draft.title)
      ..addListener(_onTitleChanged);
    _previewController = TextEditingController(text: widget.draft.preview ?? '')
      ..addListener(_onPreviewChanged);
    _contentController = TextEditingController(text: widget.draft.content ?? '')
      ..addListener(_onContentChanged);
    _tagInputController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController
      ..removeListener(_onTitleChanged)
      ..dispose();
    _previewController
      ..removeListener(_onPreviewChanged)
      ..dispose();
    _contentController
      ..removeListener(_onContentChanged)
      ..dispose();
    _tagInputController.dispose();
    super.dispose();
  }

  void _onTitleChanged() {
    context.read<NoteEditorController>().updateTitle(_titleController.text);
  }

  void _onPreviewChanged() {
    context.read<NoteEditorController>().updatePreview(_previewController.text);
  }

  void _onContentChanged() {
    context.read<NoteEditorController>().updateContent(_contentController.text);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<NoteEditorController>(
      create: (context) => NoteEditorController(
        context.read<NoteRepository>(),
        widget.draft,
        isEditing: widget.isEditing,
      ),
      child: Consumer<NoteEditorController>(
        builder: (context, controller, _) {
          final state = controller.state;
          final draft = state.draft;
          final theme = Theme.of(context);

          return Scaffold(
            appBar: AppBar(title: Text(widget.isEditing ? '编辑笔记' : '新建笔记')),
            body: SafeArea(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(labelText: '标题'),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? '请输入标题'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextFormField(
                      controller: _previewController,
                      decoration: InputDecoration(labelText: '摘要'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _DatePickerField(
                      label: '日期',
                      value: draft.date,
                      onChanged: controller.updateDate,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    DropdownButtonFormField<NoteCategory>(
                      initialValue: draft.category,
                      decoration: InputDecoration(labelText: '分类'),
                      items: NoteCategory.values
                          .map(
                            (category) => DropdownMenuItem(
                              value: category,
                              child: Text(_categoryLabel(category)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          controller.updateCategory(value);
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _ProgressSlider(
                      value: draft.progressPercent ?? 0,
                      onChanged: controller.updateProgress,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextFormField(
                      controller: _contentController,
                      decoration: InputDecoration(labelText: '正文'),
                      maxLines: 8,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _TagEditor(
                      tags: draft.tags,
                      tagInputController: _tagInputController,
                      onAdd: controller.addTag,
                      onRemove: controller.removeTag,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _AttachmentEditorList(
                      attachments: draft.attachments,
                      onAdd: controller.addAttachment,
                      onUpdate: controller.updateAttachment,
                      onRemove: controller.removeAttachment,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    if (state.error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                        child: Text(
                          state.error!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                    FilledButton.icon(
                      onPressed: state.isSubmitting
                          ? null
                          : () => _handleSubmit(controller),
                      icon: state.isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(state.isSubmitting ? '保存中...' : '保存'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleSubmit(NoteEditorController controller) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final success = await controller.submit();
    if (success && mounted) {
      final result = controller.state.result;
      if (result != null) {
        Navigator.of(context).pop(NoteDetailResult.updated(result));
      } else {
        Navigator.of(context).pop();
      }
    }
  }

  String _categoryLabel(NoteCategory category) {
    switch (category) {
      case NoteCategory.diary:
        return '日记';
      case NoteCategory.checklist:
        return '清单';
      case NoteCategory.idea:
        return '灵感';
      case NoteCategory.journal:
        return '记录';
      case NoteCategory.reminder:
        return '提醒';
    }
  }
}

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text('${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}',
      ),
      trailing: const Icon(Icons.calendar_today_outlined),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) {
          onChanged(picked);
        }
      },
    );
  }
}

class _ProgressSlider extends StatelessWidget {
  const _ProgressSlider({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text(context.tr('进度')), Text('${(value * 100).round()}%')],
        ),
        Slider(value: value.clamp(0, 1), onChanged: (next) => onChanged(next)),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => onChanged(null),
            child: Text(context.tr('清除进度')),
          ),
        ),
      ],
    );
  }
}

class _TagEditor extends StatelessWidget {
  const _TagEditor({
    required this.tags,
    required this.tagInputController,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> tags;
  final TextEditingController tagInputController;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.sell_outlined,
              size: 18,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(context.tr('标签'),
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            for (final tag in tags)
              InputChip(label: Text(tag), onDeleted: () => onRemove(tag)),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: tagInputController,
                decoration: InputDecoration(labelText: '添加标签'),
                onSubmitted: (value) {
                  onAdd(value);
                  tagInputController.clear();
                },
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            FilledButton(
              onPressed: () {
                onAdd(tagInputController.text);
                tagInputController.clear();
              },
              child: Text(context.tr('添加')),
            ),
          ],
        ),
      ],
    );
  }
}

class _AttachmentEditorList extends StatelessWidget {
  const _AttachmentEditorList({
    required this.attachments,
    required this.onAdd,
    required this.onUpdate,
    required this.onRemove,
  });

  final List<NoteAttachmentDraft> attachments;
  final VoidCallback onAdd;
  final void Function(int index, NoteAttachmentDraft draft) onUpdate;
  final void Function(int index) onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.attachment_outlined,
              size: 18,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(context.tr('附件'),
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        for (var i = 0; i < attachments.length; i++)
          _AttachmentCard(
            key: ValueKey(attachments[i].id ?? 'new-$i'),
            draft: attachments[i],
            onChanged: (updated) => onUpdate(i, updated),
            onRemove: () => onRemove(i),
          ),
        TextButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: Text(context.tr('添加附件')),
        ),
      ],
    );
  }
}

class _AttachmentCard extends StatefulWidget {
  const _AttachmentCard({
    super.key,
    required this.draft,
    required this.onChanged,
    required this.onRemove,
  });

  final NoteAttachmentDraft draft;
  final ValueChanged<NoteAttachmentDraft> onChanged;
  final VoidCallback onRemove;

  @override
  State<_AttachmentCard> createState() => _AttachmentCardState();
}

class _AttachmentCardState extends State<_AttachmentCard> {
  late final TextEditingController _nameController;
  late final TextEditingController _urlController;
  late final TextEditingController _mimeController;
  late final TextEditingController _sizeController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.draft.fileName)
      ..addListener(_emitChange);
    _urlController = TextEditingController(text: widget.draft.fileUrl)
      ..addListener(_emitChange);
    _mimeController = TextEditingController(text: widget.draft.mimeType ?? '')
      ..addListener(_emitChange);
    _sizeController = TextEditingController(
      text: widget.draft.sizeBytes?.toString() ?? '',
    )..addListener(_emitChange);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _mimeController.dispose();
    _sizeController.dispose();
    super.dispose();
  }

  void _emitChange() {
    final updated = NoteAttachmentDraft(
      id: widget.draft.id,
      fileName: _nameController.text,
      fileUrl: _urlController.text,
      mimeType: _mimeController.text.isEmpty ? null : _mimeController.text,
      sizeBytes: int.tryParse(_sizeController.text),
    );
    widget.onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(labelText: '文件名'),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? '请输入文件名' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _urlController,
              decoration: InputDecoration(labelText: '访问链接'),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? '请输入链接地址' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _mimeController,
              decoration: InputDecoration(labelText: 'MIME 类型 (可选)'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _sizeController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: '文件大小（字节，可选）'),
            ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: widget.onRemove,
                icon: const Icon(Icons.delete_outline),
                label: Text(context.tr('移除')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
