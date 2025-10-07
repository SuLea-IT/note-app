import 'package:flutter/material.dart';
import '../../../../core/localization/locale_utils.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_radius.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../domain/entities/diary_entry.dart';

class DiaryDetailSheet extends StatelessWidget {
  const DiaryDetailSheet({
    super.key,
    required this.entry,
    this.onEdit,
    this.onDelete,
    this.onShare,
  });

  final DiaryEntry entry;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shareAvailable = entry.canShare && onShare != null;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.title,
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
                            icon: Icons.calendar_today_outlined,
                            label: _formatDate(entry.date),
                          ),
                          _InfoChip(
                            icon: Icons.access_time,
                            label: _formatTime(entry.date),
                          ),
                          if (entry.weather.isNotEmpty)
                            _InfoChip(
                              icon: Icons.wb_sunny_outlined,
                              label: entry.weather,
                            ),
                          if (entry.mood.isNotEmpty)
                            _InfoChip(
                              icon: Icons.mood_outlined,
                              label: entry.mood,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (onEdit != null)
                      FilledButton.icon(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_outlined),
                        label: Text(context.tr('编辑')),
                      ),
                    if (onDelete != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      OutlinedButton.icon(
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline),
                        label: Text(context.tr('删除')),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              entry.content,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
            if (entry.tags.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(context.tr('标签'),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final tag in entry.tags)
                    Chip(
                      label: Text(tag),
                      side: BorderSide.none,
                      backgroundColor: AppColors.primaryLight,
                      labelStyle: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                ],
              ),
            ],
            if (entry.attachments.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(context.tr('附件'),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Column(
                children: [
                  for (final attachment in entry.attachments)
                    Card(
                      elevation: 0,
                      color: theme.colorScheme.surfaceVariant.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.attach_file),
                        title: Text(
                          attachment.fileName.isEmpty
                              ? attachment.fileUrl
                              : attachment.fileName,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(attachment.fileUrl),
                            if ((attachment.mimeType ?? '').isNotEmpty)
                              Text(attachment.mimeType!),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            if (shareAvailable)
              FilledButton.icon(
                onPressed: onShare,
                icon: Icon(
                  entry.share == null ? Icons.ios_share : Icons.copy,
                ),
                label: Text(entry.share == null ? '生成分享链接' : '复制分享链接'),
              )
            else if (entry.share != null)
              FilledButton.icon(
                onPressed: onShare,
                icon: const Icon(Icons.copy),
                label: Text(context.tr('复制分享链接')),
              )
            else
              Row(
                children: [
                  const Icon(Icons.lock_outline, size: 18),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(context.tr('此日记设为私密，若需分享可在编辑时开启“允许分享”。'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            if (entry.share != null) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.tr('分享链接'),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SelectableText(entry.share!.url),
                    if (entry.share!.expiresAt != null)
                      Text('链接有效期至：${_formatDate(entry.share!.expiresAt!)} ${_formatTime(entry.share!.expiresAt!)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  String _formatTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
