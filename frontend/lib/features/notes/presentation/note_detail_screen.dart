import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/locale_utils.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../application/note_detail_controller.dart';
import '../data/note_repository.dart';
import '../domain/entities/note.dart';
import 'note_editor_screen.dart';

class NoteDetailScreen extends StatelessWidget {
  const NoteDetailScreen({super.key, required this.summary});

  final NoteSummary summary;

  static Route<NoteDetailResult> route({required NoteSummary summary}) {
    return MaterialPageRoute(
      builder: (_) => NoteDetailScreen(summary: summary),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<NoteDetailController>(
      create: (context) =>
          NoteDetailController(context.read<NoteRepository>())
            ..load(summary.id),
      child: _NoteDetailView(summary: summary),
    );
  }
}

class _NoteDetailView extends StatelessWidget {
  const _NoteDetailView({required this.summary});

  final NoteSummary summary;

  @override
  Widget build(BuildContext context) {
    return Consumer<NoteDetailController>(
      builder: (context, controller, _) {
        final state = controller.state;
        final detail = state.detail;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              detail?.title.isNotEmpty == true ? detail!.title : '笔记详情',
            ),
            actions: [
              if (detail != null)
                IconButton(
                  tooltip: '编辑',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _edit(context, detail),
                ),
              if (detail != null)
                IconButton(
                  tooltip: '删除',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _confirmDelete(context, controller, detail),
                ),
            ],
          ),
          body: Builder(
            builder: (context) {
              switch (state.status) {
                case NoteDetailStatus.initial:
                case NoteDetailStatus.loading:
                  return const Center(child: CircularProgressIndicator());
                case NoteDetailStatus.failure:
                  return _DetailError(
                    message: state.error ?? '加载失败',
                    onRetry: () => controller.load(summary.id),
                  );
                case NoteDetailStatus.ready:
                  if (detail == null) {
                    return const SizedBox.shrink();
                  }
                  return _DetailContent(detail: detail);
              }
            },
          ),
        );
      },
    );
  }

  Future<void> _edit(BuildContext context, NoteDetail detail) async {
    final draft = NoteDraft.fromDetail(detail);
    final result = await Navigator.of(context).push<NoteDetailResult>(
      NoteEditorScreen.route(draft: draft, isEditing: true),
    );

    if (result?.isUpdated ?? false) {
      if (context.mounted) {
        Navigator.of(context).pop(result);
      }
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    NoteDetailController controller,
    NoteDetail detail,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(context.tr('删除笔记')),
          content: Text(context.tr('确定要删除该笔记吗？该操作无法撤销。')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.tr('取消')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.tr('删除')),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }
    final success = await controller.deleteCurrent();
    if (success && context.mounted) {
      Navigator.of(context).pop(NoteDetailResult.deleted(detail.id));
    } else if (!success && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr('删除失败，请稍后重试'))));
    }
  }
}

class _DetailContent extends StatelessWidget {
  const _DetailContent({required this.detail});

  final NoteDetail detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            detail.title.isEmpty ? '未命名笔记' : detail.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              _InfoChip(
                label: _formatDate(detail.date),
                icon: Icons.calendar_today_outlined,
              ),
              _InfoChip(
                label: _categoryLabel(detail.category),
                icon: detail.category.icon,
              ),
              if (detail.progressPercent != null)
                _InfoChip(
                  label: '进度 ${(detail.progressPercent! * 100).round()}%',
                  icon: Icons.show_chart_outlined,
                ),
            ],
          ),
          if (detail.tags.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: detail.tags
                  .map((tag) => Chip(label: Text('#$tag')))
                  .toList(growable: false),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          if ((detail.content ?? detail.preview)?.isNotEmpty ?? false)
            Text(
              detail.content?.isNotEmpty == true
                  ? detail.content!
                  : (detail.preview ?? ''),
              style: theme.textTheme.bodyLarge,
            )
          else
            Text(context.tr('暂无正文内容。'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          if (detail.attachments.isNotEmpty)
            _AttachmentList(attachments: detail.attachments),
          const SizedBox(height: AppSpacing.lg),
          Text('创建于 ${_formatDateTime(detail.createdAt)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (detail.updatedAt != null)
            Text('最近更新 ${_formatDateTime(detail.updatedAt!)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
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

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _AttachmentList extends StatelessWidget {
  const _AttachmentList({required this.attachments});

  final List<NoteAttachment> attachments;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.tr('附件'),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final attachment in attachments)
          Card(
            child: ListTile(
              leading: const Icon(Icons.attachment_outlined),
              title: Text(
                attachment.fileName.isEmpty ? '未命名附件' : attachment.fileName,
              ),
              subtitle: Text(attachment.fileUrl),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => _openLink(context, attachment.fileUrl),
            ),
          ),
      ],
    );
  }

  void _openLink(BuildContext context, String url) {
    // For now, simply show snackbar. Integrate url_launcher if available.
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('请在浏览器中访问：$url')));
  }
}

class _DetailError extends StatelessWidget {
  const _DetailError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline,
            size: 40,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.md),
          FilledButton(onPressed: onRetry, child: Text(context.tr('重新加载'))),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16, color: AppColors.textSecondary),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}
