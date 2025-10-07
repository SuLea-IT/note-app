import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/localization/locale_utils.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/network/api_client.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../notes/domain/entities/note.dart';
import '../../../notes/presentation/note_detail_screen.dart';

class NoteDetailSheet extends StatefulWidget {
  const NoteDetailSheet({super.key, required this.summary});

  final NoteSummary summary;

  @override
  State<NoteDetailSheet> createState() => _NoteDetailSheetState();
}

class _NoteDetailSheetState extends State<NoteDetailSheet> {
  late Future<NoteDetail> _future;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) {
      return;
    }
    _initialized = true;
    final client = context.read<ApiClient>();
    _future = _loadDetail(client);
  }

  Future<NoteDetail> _loadDetail(ApiClient client) async {
    try {
      final auth = context.read<AuthController>();
      final user = auth.state.user;
      final userId = user?.id;
      final locale = user?.preferredLocale ?? 'zh-CN';
      final buffer = StringBuffer(
        '/notes/${Uri.encodeComponent(widget.summary.id)}?lang=${Uri.encodeComponent(locale)}',
      );
      if (userId != null) {
        buffer.write('&user_id=${Uri.encodeComponent(userId)}');
      }
      final response = await client.getJson(buffer.toString());
      final payload = _unwrap(response);
      if (payload.isEmpty) {
        return NoteDetail.fromSummary(widget.summary);
      }
      return NoteDetail.fromJson(payload);
    } catch (error, stackTrace) {
      debugPrint('NoteDetailSheet fetch error: $error');
      debugPrintStack(stackTrace: stackTrace);
      return NoteDetail.fromSummary(widget.summary);
    }
  }

  Map<String, dynamic> _unwrap(Map<String, dynamic> json) {
    if (json.containsKey('id')) {
      return json;
    }
    final data = json['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    return const {};
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.xl,
          right: AppSpacing.xl,
          top: AppSpacing.lg,
          bottom: AppSpacing.lg + bottomInset,
        ),
        child: Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: FutureBuilder<NoteDetail>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const SizedBox(
                  height: 260,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final detail =
                  snapshot.data ?? NoteDetail.fromSummary(widget.summary);
              return _SheetContent(detail: detail);
            },
          ),
        ),
      ),
    );
  }
}

class _SheetContent extends StatelessWidget {
  const _SheetContent({required this.detail});

  final NoteDetail detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoryColor = detail.category.color;
    final progressLabel = detail.progressPercent != null
        ? '进度 ${(detail.progressPercent! * 100).round()}%'
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 48,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(AppSpacing.xs),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(detail.category.icon, color: categoryColor),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      detail.title.isEmpty ? '未命名笔记' : detail.title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _formatDateTime(detail.createdAt),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (detail.updatedAt != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text('更新于 ${_formatDateTime(detail.updatedAt!)}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _InfoChip(
                label: _categoryLabel(detail.category),
                icon: detail.category.icon,
                foreground: categoryColor,
              ),
              _InfoChip(
                label: _formatDate(detail.date),
                icon: Icons.calendar_today_outlined,
              ),
              if (progressLabel != null)
                _InfoChip(
                  label: progressLabel,
                  icon: Icons.show_chart_outlined,
                ),
              if (detail.hasAttachment)
                _InfoChip(label: '包含附件', icon: Icons.attachment_outlined),
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
          Text(
            (detail.content?.isNotEmpty ?? false)
                ? detail.content!
                : (detail.preview?.isNotEmpty ?? false)
                ? detail.preview!
                : '暂无正文内容。',
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
          ),
          if (detail.attachments.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(context.tr('附件'),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final attachment in detail.attachments)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.insert_drive_file_outlined),
                title: Text(
                  attachment.fileName.isEmpty
                      ? attachment.fileUrl
                      : attachment.fileName,
                ),
                subtitle: Text(attachment.fileUrl),
              ),
          ],
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: () async {
              final result = await Navigator.of(context).push<NoteDetailResult>(
                NoteDetailScreen.route(summary: NoteSummary.fromDetail(detail)),
              );
              if (result != null && context.mounted) {
                Navigator.of(context).pop(result);
              }
            },
            icon: const Icon(Icons.open_in_new),
            label: Text(context.tr('查看全部详情')),
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

class _InfoChip extends StatelessWidget {
  _InfoChip({required this.label, required this.icon, this.foreground});

  final String label;
  final IconData icon;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = foreground ?? theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
