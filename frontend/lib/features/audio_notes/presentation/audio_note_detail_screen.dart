import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/locale_utils.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../application/audio_note_detail_controller.dart';
import '../domain/entities/audio_note.dart';
import 'audio_recorder_sheet.dart';

class AudioNoteDetailScreen extends StatefulWidget {
  const AudioNoteDetailScreen({
    super.key,
    required this.noteId,
    this.onUpdated,
    this.onDeleted,
  });

  final String noteId;
  final ValueChanged<AudioNote>? onUpdated;
  final VoidCallback? onDeleted;

  @override
  State<AudioNoteDetailScreen> createState() => _AudioNoteDetailScreenState();
}

class _AudioNoteDetailScreenState extends State<AudioNoteDetailScreen> {
  late final AudioPlayer _player;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioNoteDetailController>(
      builder: (context, controller, _) {
        final state = controller.state;
        return Scaffold(
          appBar: AppBar(
            title: Text(context.tr('语音详情', 'Audio note detail')),
            actions: [
              IconButton(
                tooltip: '刷新',
                onPressed: controller.refresh,
                icon: const Icon(Icons.refresh),
              ),
              IconButton(
                tooltip: '删除',
                onPressed: () => _confirmDelete(context, controller),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          body: SafeArea(child: _buildBody(context, state, controller)),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    AudioNoteDetailState state,
    AudioNoteDetailController controller,
  ) {
    switch (state.status) {
      case AudioNoteDetailStatus.initial:
      case AudioNoteDetailStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case AudioNoteDetailStatus.failure:
        return _ErrorView(
          message: state.error ?? '加载失败',
          onRetry: controller.refresh,
        );
      case AudioNoteDetailStatus.ready:
        final note = state.note!;
        return _AudioNoteDetailContent(
          note: note,
          player: _player,
          onEdit: () async {
            final result = await AudioRecorderSheet.show(
              context,
              initialTitle: note.title,
              initialDescription: note.description,
              existingNote: note,
            );
            if (result != null) {
              await controller.refresh();
              widget.onUpdated?.call(result);
            }
          },
        );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    AudioNoteDetailController controller,
  ) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.tr('删除语音笔记', 'Delete voice note')),
            content: Text(context.tr('确定要删除该语音笔记吗？', 'Delete this voice note?')),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(context.tr('取消', 'Cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(context.tr('删除', 'Delete')),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) {
      return;
    }
    final success = await controller.delete();
    if (!success || !context.mounted) {
      return;
    }
    widget.onDeleted?.call();
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(context.tr('语音笔记已删除', 'Voice note deleted'))));
  }
}

class _AudioNoteDetailContent extends StatefulWidget {
  const _AudioNoteDetailContent({
    required this.note,
    required this.player,
    required this.onEdit,
  });

  final AudioNote note;
  final AudioPlayer player;
  final VoidCallback onEdit;

  @override
  State<_AudioNoteDetailContent> createState() => _AudioNoteDetailContentState();
}

class _AudioNoteDetailContentState extends State<_AudioNoteDetailContent> {
  late Stream<Duration> _positionStream;
  late Stream<PlayerState> _playerStateStream;

  @override
  void initState() {
    super.initState();
    _positionStream = widget.player.positionStream;
    _playerStateStream = widget.player.playerStateStream;
    _loadSource();
  }

  Future<void> _loadSource() async {
    try {
      await widget.player.setUrl(widget.note.fileUrl);
    } catch (error) {
      debugPrint('Audio player load error: $error');
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(context.tr('无法播放该音频', 'Unable to play this audio'))));
    }
  }

  @override
  void didUpdateWidget(covariant _AudioNoteDetailContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.note.id != widget.note.id ||
        oldWidget.note.fileUrl != widget.note.fileUrl) {
      _loadSource();
    }
  }

  @override
  Widget build(BuildContext context) {
    final note = widget.note;
    final formatter = DateFormat('yyyy年MM月dd日 HH:mm', 'zh_CN');
    final created = note.createdAt != null ? formatter.format(note.createdAt!) : '--';
    final updated = note.updatedAt != null ? formatter.format(note.updatedAt!) : '--';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  note.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              IconButton(
                tooltip: '编辑',
                onPressed: widget.onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _buildPlayer(context),
          const SizedBox(height: AppSpacing.lg),
          if ((note.description ?? '').trim().isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  note.description!,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          _buildTranscription(note),
          const SizedBox(height: AppSpacing.lg),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.tr('元信息', 'Metadata'), style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.md),
                  _InfoRow(label: '音频地址', value: note.fileUrl),
                  _InfoRow(label: '时长', value: _durationLabel(note.durationSeconds)),
                  _InfoRow(label: '文件大小', value: _sizeLabel(note.sizeBytes)),
                  _InfoRow(label: '创建时间', value: created),
                  _InfoRow(label: '最近更新', value: updated),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayer(BuildContext context) {
    return StreamBuilder<PlayerState>(
      stream: _playerStateStream,
      builder: (context, snapshot) {
        final playerState = snapshot.data;
        final playing = playerState?.playing ?? false;
        final completed = playerState?.processingState == ProcessingState.completed;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      iconSize: 40,
                      onPressed: () {
                        if (completed) {
                          widget.player.seek(Duration.zero);
                          widget.player.play();
                        } else if (playing) {
                          widget.player.pause();
                        } else {
                          widget.player.play();
                        }
                      },
                      icon: Icon(
                        completed
                            ? Icons.replay
                            : (playing ? Icons.pause_circle_filled : Icons.play_circle_fill),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: StreamBuilder<Duration>(
                        stream: _positionStream,
                        builder: (context, snapshot) {
                          final position = snapshot.data ?? Duration.zero;
                          final duration = widget.player.duration ?? Duration.zero;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Slider(
                                min: 0,
                                max: duration.inMilliseconds.toDouble(),
                                value: position.inMilliseconds.clamp(0, duration.inMilliseconds).toDouble(),
                                onChanged: (value) => widget.player.seek(Duration(milliseconds: value.toInt())),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(_formatDuration(position)),
                                  Text(_formatDuration(duration)),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTranscription(AudioNote note) {
    switch (note.transcriptionStatus) {
      case AudioNoteStatus.pending:
        return _TranscriptionCard(
          title: '等待转写',
          icon: Icons.pending_outlined,
          color: Colors.orange,
          child: Text(context.tr('录音已上传，稍后将自动生成文本', 'Recording uploaded, text will be generated soon')),
        );
      case AudioNoteStatus.processing:
        return _TranscriptionCard(
          title: '转写中…',
          icon: Icons.sync,
          color: Colors.blue,
          child: Text(context.tr('后台正在识别语音，请耐心等待', 'Processing transcription, please wait')),
        );
      case AudioNoteStatus.failed:
        return _TranscriptionCard(
          title: '转写失败',
          icon: Icons.error_outline,
          color: Colors.red,
          child: Text(note.transcriptionError ?? '请稍后重试或重新录制'),
        );
      case AudioNoteStatus.completed:
        final text = note.transcriptionText ?? '暂无文本';
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.text_snippet_outlined, color: AppColors.primary),
                    const SizedBox(width: AppSpacing.sm),
                    Text(context.tr('转写文本', 'Transcription'), style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    if (note.transcriptionLanguage != null)
                      Chip(
                        label: Text(note.transcriptionLanguage!),
                        backgroundColor: AppColors.primary.withAlpha(31),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  text,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        );
    }
  }

  String _durationLabel(double? seconds) {
    if (seconds == null) {
      return '--';
    }
    final duration = Duration(seconds: seconds.round());
    return _formatDuration(duration);
  }

  String _sizeLabel(int? bytes) {
    if (bytes == null || bytes <= 0) {
      return '--';
    }
    final kb = bytes / 1024;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(1)} KB';
    }
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
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

class _TranscriptionCard extends StatelessWidget {
  const _TranscriptionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: AppSpacing.sm),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            child,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: AppSpacing.md),
          Text(message),
          const SizedBox(height: AppSpacing.md),
          FilledButton(onPressed: onRetry, child: Text(context.tr('重试', 'Retry'))),
        ],
      ),
    );
  }
}
