import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/locale_utils.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_spacing.dart';
import '../application/audio_note_detail_controller.dart';
import '../application/audio_note_list_controller.dart';
import '../data/audio_note_repository.dart';
import '../domain/entities/audio_note.dart';
import 'audio_note_detail_screen.dart';
import 'audio_recorder_sheet.dart';

class AudioNoteListScreen extends StatelessWidget {
  const AudioNoteListScreen({super.key});

  static Route<dynamic> route() {
    return MaterialPageRoute(builder: (_) => const AudioNoteListScreen());
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AudioNoteListController>(
      create: (context) => AudioNoteListController(context.read<AudioNoteRepository>())..load(),
      child: const _AudioNoteListView(),
    );
  }
}

class _AudioNoteListView extends StatefulWidget {
  const _AudioNoteListView();

  @override
  State<_AudioNoteListView> createState() => _AudioNoteListViewState();
}

class _AudioNoteListViewState extends State<_AudioNoteListView> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(_handleSearch);
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearch);
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearch() {
    context.read<AudioNoteListController>().search(_searchController.text);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioNoteListController>(
      builder: (context, controller, _) {
        final state = controller.state;
        return Scaffold(
          appBar: AppBar(
            title: Text(context.tr('语音笔记', 'Voice notes')),
            actions: [
              IconButton(
                tooltip: '刷新',
                icon: const Icon(Icons.refresh),
                onPressed: controller.refresh,
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openRecorder(context),
            icon: const Icon(Icons.mic),
            label: Text(context.tr('录制语音', 'Record voice')),
          ),
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.lg,
                    AppSpacing.xl,
                    AppSpacing.md,
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: '搜索语音标题或描述…',
                      suffixIcon: state.query.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                _searchController.clear();
                                controller.clearSearch();
                              },
                              icon: const Icon(Icons.clear),
                            )
                          : null,
                    ),
                  ),
                ),
                _buildFilterChips(state, controller),
                const Divider(height: 1),
                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: controller.refresh,
                    child: _buildBody(state, controller),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterChips(AudioNoteListState state, AudioNoteListController controller) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.md,
      ),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: AudioNoteStatus.values.map((status) {
          final selected = state.filters.contains(status);
          return FilterChip(
            label: Text(status.label),
            selected: selected,
            onSelected: (_) => controller.toggleFilter(status),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBody(AudioNoteListState state, AudioNoteListController controller) {
    switch (state.status) {
      case AudioNoteListStatus.initial:
      case AudioNoteListStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case AudioNoteListStatus.failure:
        return _ErrorView(
          message: state.error ?? '加载失败，请稍后再试',
          onRetry: controller.refresh,
        );
      case AudioNoteListStatus.ready:
        if (state.notes.isEmpty) {
          return const _EmptyView();
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.md,
            AppSpacing.xl,
            AppSpacing.xl + 80,
          ),
          itemCount: state.notes.length,
          itemBuilder: (context, index) {
            final note = state.notes[index];
            return _AudioNoteTile(
              note: note,
              onTap: () => _openDetail(context, note.id),
              onDelete: () async {
                final repo = context.read<AudioNoteRepository>();
                await repo.delete(note.id);
                controller.remove(note.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                    ..clearSnackBars()
                    ..showSnackBar(SnackBar(content: Text(context.tr('语音笔记已删除', 'Voice note deleted'))));
                }
              },
            );
          },
        );
    }
  }

  Future<void> _openRecorder(BuildContext context) async {
    final controller = context.read<AudioNoteListController>();
    final result = await AudioRecorderSheet.show(context);
    if (result != null) {
      controller.addOrUpdate(result);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(context.tr('语音笔记已保存', 'Voice note saved'))));
      }
    }
  }

  Future<void> _openDetail(BuildContext context, String id) async {
    final repository = context.read<AudioNoteRepository>();
    final listController = context.read<AudioNoteListController>();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider<AudioNoteDetailController>(
          create: (context) => AudioNoteDetailController(repository, id)..load(),
          child: AudioNoteDetailScreen(
            noteId: id,
            onUpdated: (note) => listController.addOrUpdate(note),
            onDeleted: () => listController.remove(id),
          ),
        ),
      ),
    );
  }
}

class _AudioNoteTile extends StatelessWidget {
  const _AudioNoteTile({required this.note, required this.onTap, required this.onDelete});

  final AudioNote note;
  final VoidCallback onTap;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('MM-dd HH:mm');
    final updated = note.updatedAt ?? note.createdAt;
    final durationLabel = note.durationSeconds != null
        ? '${note.durationSeconds!.toStringAsFixed(0)} 秒'
        : '--';
    final statusColor = _statusColor(note.transcriptionStatus);
    final subtitle = [
      if (updated != null) formatter.format(updated),
      durationLabel,
      note.transcriptionStatus.label,
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: statusColor.withAlpha(31),
          foregroundColor: statusColor,
          child: _statusIcon(note.transcriptionStatus),
        ),
        title: Text(
          note.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle),
            if ((note.transcriptionText ?? '').isNotEmpty)
              Text(
                note.transcriptionText!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
          ],
        ),
        trailing: IconButton(
          tooltip: '删除',
          onPressed: () async {
            final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(context.tr('删除语音笔记', 'Delete voice note')),
                    content: Text(context.tr('确定删除该语音笔记吗？', 'Delete this voice note?')),
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
            if (confirmed) {
              await onDelete();
            }
          },
          icon: const Icon(Icons.delete_outline),
        ),
      ),
    );
  }

  Icon _statusIcon(AudioNoteStatus status) {
    switch (status) {
      case AudioNoteStatus.pending:
        return const Icon(Icons.pending_outlined);
      case AudioNoteStatus.processing:
        return const Icon(Icons.sync);
      case AudioNoteStatus.completed:
        return const Icon(Icons.text_snippet_outlined);
      case AudioNoteStatus.failed:
        return const Icon(Icons.error_outline);
    }
  }

  Color _statusColor(AudioNoteStatus status) {
    switch (status) {
      case AudioNoteStatus.pending:
        return Colors.orange;
      case AudioNoteStatus.processing:
        return Colors.blue;
      case AudioNoteStatus.completed:
        return Colors.green;
      case AudioNoteStatus.failed:
        return Colors.red;
    }
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
          FilledButton(onPressed: onRetry, child: Text(context.tr('重试'))),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mic_none_outlined, size: 64, color: AppColors.textSecondary),
            const SizedBox(height: AppSpacing.lg),
            Text(context.tr('还没有语音笔记，点击下方按钮开始录制灵感'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: () => AudioRecorderSheet.show(context),
              icon: const Icon(Icons.mic),
              label: Text(context.tr('立即录制')),
            ),
          ],
        ),
      ),
    );
  }
}
