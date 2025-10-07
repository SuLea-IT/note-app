import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/locale_utils.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../application/diary_controller.dart';
import '../data/diary_repository.dart';
import '../domain/entities/diary_draft.dart';
import '../domain/entities/diary_entry.dart';
import 'widgets/diary_compose_sheet.dart';
import 'widgets/diary_entry_card.dart';
import 'widgets/diary_detail_sheet.dart';
import 'widgets/diary_template_strip.dart';

class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key});

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  @override
  void initState() {
    super.initState();
    final controller = context.read<DiaryController>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DiaryController>();
    final state = controller.state;

    if (state.actionError != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(state.actionError!)));
        controller.clearActionError();
      });
    }

    switch (state.status) {
      case DiaryStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case DiaryStatus.failure:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(state.error ?? '加载失败', textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.md),
              FilledButton(onPressed: controller.load, child: Text(context.tr('重试'))),
            ],
          ),
        );
      case DiaryStatus.initial:
        return const SizedBox.shrink();
      case DiaryStatus.ready:
        final feed = state.feed;
        if (feed == null) {
          return const SizedBox.shrink();
        }
        final slivers = <Widget>[];
        if (state.isMutating) {
          slivers.add(
            const SliverToBoxAdapter(
              child: LinearProgressIndicator(minHeight: 2),
            ),
          );
        }
        slivers.add(
          SliverPadding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DiaryHeader(onCreate: () => _openComposer(controller, feed)),
                  const SizedBox(height: AppSpacing.lg),
                  DiaryTemplateStrip(templates: feed.templates),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ),
        );
        slivers.add(
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final entry = feed.entries[index];
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == feed.entries.length - 1
                        ? AppSpacing.xl
                        : AppSpacing.md,
                  ),
                  child: DiaryEntryCard(
                    entry: entry,
                    onEdit: () => _openComposer(controller, feed, entry: entry),
                    onDelete: () => _confirmDelete(controller, entry),
                    onShare: (entry.canShare || entry.share != null)
                        ? () => _shareEntry(controller, entry)
                        : null,
                    onTap: () => _openDetail(controller, feed, entry),
                  ),
                );
              }, childCount: feed.entries.length),
            ),
          ),
        );
        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: slivers,
        );
    }
  }

  Future<void> _openComposer(
    DiaryController controller,
    DiaryFeed feed, {
    DiaryEntry? entry,
  }) async {
    final draft = await showModalBottomSheet<DiaryDraft>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DiaryComposeSheet(initial: entry, templates: feed.templates);
      },
    );
    if (!mounted || draft == null) return;

    final success = entry == null
        ? await controller.createEntry(draft)
        : await controller.updateEntry(entry.id, draft);
    if (!mounted || !success) return;

    _showSnackBar(entry == null ? '已创建新日记' : '日记已更新');
  }

  Future<void> _confirmDelete(
    DiaryController controller,
    DiaryEntry entry,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(context.tr('删除日记')),
          content: Text('确定删除“${entry.title}”吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.tr('取消')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(context.tr('删除')),
            ),
          ],
        );
      },
    );

    if (confirm != true || !mounted) return;
    final success = await controller.deleteEntry(entry.id);
    if (!mounted || !success) return;
    _showSnackBar('已删除日记');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _shareEntry(
    DiaryController controller,
    DiaryEntry entry,
  ) async {
    final share = await controller.shareEntry(entry);
    if (!mounted || share == null) return;
    final copied = await _showShareSheet(share);
    if (!mounted) return;
    if (copied == true) {
      _showSnackBar('分享链接已复制');
    }
  }

  Future<bool?> _showShareSheet(DiaryShare share) {
    return showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (context) => _ShareSheet(share: share),
    );
  }

  Future<void> _openDetail(
    DiaryController controller,
    DiaryFeed feed,
    DiaryEntry entry,
  ) async {
    final latestFeed = controller.state.feed ?? feed;
    final currentEntry = latestFeed.entries.firstWhere(
      (item) => item.id == entry.id,
      orElse: () => entry,
    );
    final shareEnabled = currentEntry.canShare || currentEntry.share != null;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: DiaryDetailSheet(
            entry: currentEntry,
            onEdit: () {
              Navigator.of(context).pop();
              _openComposer(controller, latestFeed, entry: currentEntry);
            },
            onDelete: () {
              Navigator.of(context).pop();
              _confirmDelete(controller, currentEntry);
            },
            onShare: shareEnabled
                ? () {
                    Navigator.of(context).pop();
                    _shareEntry(controller, currentEntry);
                  }
                : null,
          ),
        );
      },
    );
  }
}

class _ShareSheet extends StatelessWidget {
  const _ShareSheet({required this.share});

  final DiaryShare share;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr('分享链接'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SelectableText(share.url),
            if (share.expiresAt != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text('有效期至 ${_formatDate(share.expiresAt!)} ${_formatTime(share.expiresAt!)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: share.url));
                if (context.mounted) {
                  Navigator.of(context).pop(true);
                }
              },
              icon: const Icon(Icons.copy),
              label: Text(context.tr('复制链接')),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  static String _formatTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _DiaryHeader extends StatelessWidget {
  const _DiaryHeader({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('日记记录', 'Diary log'),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                context.tr('记录生活点滴，随时管理与分享',
                    'Capture life moments to manage and share.'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        FilledButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.edit_outlined),
          label: Text(context.tr('写日记', 'Write diary')),
        ),
      ],
    );
  }
}
