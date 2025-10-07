import 'package:flutter/foundation.dart';

import '../data/note_repository.dart';
import '../domain/entities/note.dart';

class NoteEditorState {
  const NoteEditorState({
    required this.draft,
    this.isSubmitting = false,
    this.error,
    this.result,
  });

  final NoteDraft draft;
  final bool isSubmitting;
  final String? error;
  final NoteDetail? result;

  NoteEditorState copyWith({
    NoteDraft? draft,
    bool? isSubmitting,
    String? error,
    bool clearError = false,
    NoteDetail? result,
  }) {
    return NoteEditorState(
      draft: draft ?? this.draft,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : (error ?? this.error),
      result: result ?? this.result,
    );
  }
}

class NoteEditorController extends ChangeNotifier {
  NoteEditorController(
    this._repository,
    NoteDraft draft, {
    required this.isEditing,
  }) : _state = NoteEditorState(draft: draft);

  final NoteRepository _repository;
  final bool isEditing;

  NoteEditorState _state;
  NoteEditorState get state => _state;

  NoteDraft get draft => _state.draft;

  void updateTitle(String value) {
    draft.title = value;
    _markDirty();
  }

  void updatePreview(String? value) {
    draft.preview = value;
    _markDirty();
  }

  void updateContent(String? value) {
    draft.content = value;
    _markDirty();
  }

  void updateDate(DateTime value) {
    draft.date = value;
    _markDirty();
  }

  void updateCategory(NoteCategory category) {
    draft.category = category;
    _markDirty();
  }

  void updateProgress(double? progress) {
    draft.progressPercent = progress;
    _markDirty();
  }

  void addTag(String tag) {
    final normalized = tag.trim();
    if (normalized.isEmpty) {
      return;
    }
    if (!draft.tags.contains(normalized)) {
      draft.tags.add(normalized);
      _markDirty();
    }
  }

  void removeTag(String tag) {
    draft.tags.remove(tag);
    _markDirty();
  }

  void replaceTags(List<String> tags) {
    draft.tags = tags
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();
    _markDirty();
  }

  void addAttachment() {
    draft.attachments.add(NoteAttachmentDraft());
    _markDirty();
  }

  void updateAttachment(int index, NoteAttachmentDraft attachment) {
    if (index < 0 || index >= draft.attachments.length) {
      return;
    }
    draft.attachments[index] = attachment;
    _markDirty();
  }

  void removeAttachment(int index) {
    if (index < 0 || index >= draft.attachments.length) {
      return;
    }
    draft.attachments.removeAt(index);
    _markDirty();
  }

  Future<bool> submit() async {
    if (_state.isSubmitting) {
      return false;
    }
    _state = _state.copyWith(isSubmitting: true, clearError: true);
    notifyListeners();
    try {
      final result = isEditing
          ? await _repository.update(draft.id, draft)
          : await _repository.create(draft);
      _state = _state.copyWith(
        isSubmitting: false,
        result: result,
        draft: NoteDraft.fromDetail(result),
      );
      notifyListeners();
      return true;
    } catch (error, stackTrace) {
      debugPrint('NoteEditorController submit error: $error');
      debugPrintStack(stackTrace: stackTrace);
      _state = _state.copyWith(isSubmitting: false, error: '保存失败，请检查表单后重试');
      notifyListeners();
      return false;
    }
  }

  void _markDirty() {
    _state = _state.copyWith(draft: draft, clearError: true);
    notifyListeners();
  }
}