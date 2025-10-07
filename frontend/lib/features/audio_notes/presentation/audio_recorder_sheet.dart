import 'dart:io';
import '../../../core/localization/locale_utils.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_spacing.dart';
import '../../auth/application/auth_controller.dart';
import '../application/audio_recorder_controller.dart';
import '../data/audio_note_repository.dart';
import '../data/audio_upload_service.dart';
import '../domain/entities/audio_note.dart';

class AudioRecorderSheet extends StatefulWidget {
  const AudioRecorderSheet({
    super.key,
    this.initialTitle,
    this.initialDescription,
    this.existingNote,
  });

  final String? initialTitle;
  final String? initialDescription;
  final AudioNote? existingNote;

  static Future<AudioNote?> show(
    BuildContext context, {
    String? initialTitle,
    String? initialDescription,
    AudioNote? existingNote,
  }) {
    return showModalBottomSheet<AudioNote?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AudioRecorderSheet(
        initialTitle: initialTitle,
        initialDescription: initialDescription,
        existingNote: existingNote,
      ),
    );
  }

  @override
  State<AudioRecorderSheet> createState() => _AudioRecorderSheetState();
}

class _AudioRecorderSheetState extends State<AudioRecorderSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final AudioPlayer _previewPlayer;
  bool _isSaving = false;
  bool _useExistingAudio = true;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle ?? widget.existingNote?.title ?? '');
    _descriptionController = TextEditingController(text: widget.initialDescription ?? widget.existingNote?.description ?? '');
    _previewPlayer = AudioPlayer();
    _useExistingAudio = widget.existingNote != null;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _previewPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return ChangeNotifierProvider<AudioRecorderController>(
      create: (_) => AudioRecorderController(),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(AppRadius.xl),
              topRight: Radius.circular(AppRadius.xl),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.lg,
              ),
              child: Consumer<AudioRecorderController>(
                builder: (context, recorder, _) {
                  final state = recorder.state;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: 4,
                        width: 48,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        children: [
                          Text(
                            widget.existingNote == null ? '录制语音笔记' : '编辑语音笔记',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      TextField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          labelText: '标题',
                          hintText: '为语音起一个标题',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: '备注',
                          hintText: '可补充语音内容说明',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _buildRecorderCard(context, recorder),
                      if (widget.existingNote != null && state.filePath == null) ...[
                        const SizedBox(height: AppSpacing.md),
                        SwitchListTile(
                          title: Text(context.tr('保留原始音频')),
                          subtitle: Text(context.tr('关闭后可重新录制并替换')),
                          value: _useExistingAudio,
                          onChanged: (value) {
                            setState(() {
                              _useExistingAudio = value;
                            });
                          },
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _isSaving ? null : () => _handleSubmit(context, recorder),
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.save_alt),
                          label: Text(widget.existingNote == null ? '保存语音笔记' : '更新语音笔记'),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecorderCard(BuildContext context, AudioRecorderController recorder) {
    final state = recorder.state;
    final isRecording = state.status == RecorderStatus.recording;
    final isPaused = state.status == RecorderStatus.paused;
    final recordedPath = state.filePath;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.mic_outlined, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  _formatDuration(recorder.state.duration),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(width: AppSpacing.sm),
                _buildLevelIndicator(recorder.currentLevel),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filledTonal(
                  iconSize: 32,
                  onPressed: () => recorder.reset(),
                  icon: const Icon(Icons.stop_circle_outlined),
                ),
                const SizedBox(width: AppSpacing.lg),
                FilledButton.icon(
                  onPressed: () async {
                    if (isRecording) {
                      await recorder.pause();
                    } else if (isPaused) {
                      await recorder.resume();
                    } else {
                      await recorder.startRecording();
                    }
                  },
                  icon: Icon(isRecording
                      ? Icons.pause_circle
                      : (isPaused ? Icons.play_circle : Icons.mic)),
                  label: Text(isRecording
                      ? '暂停'
                      : (isPaused ? '继续' : '开始录音')),
                ),
                const SizedBox(width: AppSpacing.lg),
                IconButton.filled(
                  iconSize: 32,
                  onPressed: () async {
                    final path = await recorder.stop();
                    if (path != null && mounted) {
                      await _previewPlayer.setFilePath(path);
                      setState(() {});
                    }
                  },
                  icon: const Icon(Icons.save_alt),
                ),
              ],
            ),
            if (recordedPath != null) ...[
              const SizedBox(height: AppSpacing.lg),
              _buildPreviewPlayer(recordedPath),
            ] else if (widget.existingNote != null && _useExistingAudio) ...[
              const SizedBox(height: AppSpacing.lg),
              _buildExistingPreview(widget.existingNote!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLevelIndicator(double level) {
    final normalized = (level + 45) / 45; // approximate amplitude range
    final clamped = normalized.clamp(0.0, 1.0);
    return Expanded(
      child: LinearProgressIndicator(
        value: clamped,
        minHeight: 6,
        color: AppColors.primary,
        backgroundColor: AppColors.primary.withAlpha(51),
      ),
    );
  }

  Widget _buildPreviewPlayer(String filePath) {
    return Row(
      children: [
        IconButton(
          icon: Icon(_previewPlayer.playing ? Icons.pause_circle : Icons.play_circle),
          onPressed: () async {
            if (_previewPlayer.playing) {
              await _previewPlayer.pause();
            } else {
              if (_previewPlayer.audioSource == null) {
                await _previewPlayer.setFilePath(filePath);
              }
              await _previewPlayer.play();
            }
            if (mounted) {
              setState(() {});
            }
          },
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: StreamBuilder<Duration>(
            stream: _previewPlayer.positionStream,
            builder: (context, snapshot) {
              final position = snapshot.data ?? Duration.zero;
              final duration = _previewPlayer.duration ?? Duration.zero;
              final max = duration.inMilliseconds == 0
                  ? 1.0
                  : duration.inMilliseconds.toDouble();
              final value = position.inMilliseconds
                  .clamp(0, duration.inMilliseconds == 0 ? 1 : duration.inMilliseconds)
                  .toDouble();
              return Slider(
                min: 0,
                max: max,
                value: value,
                onChanged: (sliderValue) =>
                    _previewPlayer.seek(Duration(milliseconds: sliderValue.toInt())),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildExistingPreview(AudioNote note) {
    final formatter = DateFormat('MM-dd HH:mm');
    final updated = note.updatedAt ?? note.createdAt;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.library_music_outlined),
      title: Text(note.title.isEmpty ? '原有音频' : note.title),
      subtitle: Text(updated != null ? formatter.format(updated) : '--'),
      trailing: IconButton(
        tooltip: '播放',
        onPressed: () async {
          try {
            await _previewPlayer.setUrl(note.fileUrl);
            await _previewPlayer.play();
          } catch (error) {
            if (mounted) {
              ScaffoldMessenger.of(context)
                ..clearSnackBars()
                ..showSnackBar(SnackBar(content: Text(context.tr('无法播放原音频'))));
            }
          }
        },
        icon: const Icon(Icons.play_arrow),
      ),
    );
  }

  Future<void> _handleSubmit(
    BuildContext context,
    AudioRecorderController recorder,
  ) async {
    final repository = context.read<AudioNoteRepository>();
    final uploadService = context.read<AudioUploadService>();
    final auth = context.read<AuthController>();
    final userId = auth.state.user?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(context.tr('请先登录账号'))));
      return;
    }

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(context.tr('请填写标题', 'Please enter a title'))));
      return;
    }

    final recordedPath = recorder.state.filePath;
    File? file;
    if (recordedPath != null) {
      file = File(recordedPath);
      if (!await file.exists()) {
        file = null;
      }
    }

    if (widget.existingNote == null && file == null) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(context.tr('请先录制语音', 'Please record audio first'))));
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      String fileUrl;
      int? size;
      double? durationSeconds;
      if (file != null) {
        fileUrl = await uploadService.upload(file, fileName: _buildFileName(title));
        size = await file.length();
        durationSeconds = recorder.state.duration.inSeconds.toDouble();
      } else if (widget.existingNote != null && _useExistingAudio) {
        fileUrl = widget.existingNote!.fileUrl;
        size = widget.existingNote!.sizeBytes;
        durationSeconds = widget.existingNote!.durationSeconds;
      } else {
        throw StateError('缺少音频文件');
      }

      final draft = AudioNoteDraft(
        id: widget.existingNote?.id,
        userId: userId,
        title: title,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        fileUrl: fileUrl,
        mimeType: 'audio/m4a',
        sizeBytes: size,
        durationSeconds: durationSeconds,
        transcriptionStatus: widget.existingNote?.transcriptionStatus ?? AudioNoteStatus.pending,
        transcriptionText: widget.existingNote?.transcriptionText,
        transcriptionLanguage: widget.existingNote?.transcriptionLanguage,
      );

      final result = widget.existingNote == null
          ? await repository.create(draft)
          : await repository.update(widget.existingNote!.id, draft);

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(result);
    } catch (error, stackTrace) {
      debugPrint('AudioRecorderSheet submit error: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text('保存失败：$error')));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _buildFileName(String title) {
    final normalized = title.replaceAll(RegExp(r'[^a-zA-Z0-9\u4e00-\u9fa5]+'), '-');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${normalized.isEmpty ? 'audio' : normalized}-$timestamp.m4a';
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = duration.inHours;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}
