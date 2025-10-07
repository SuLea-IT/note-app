import 'package:flutter/material.dart';
import '../../../../core/localization/locale_utils.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_radius.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../domain/entities/diary_entry.dart';

class DiaryEntryCard extends StatelessWidget {
  const DiaryEntryCard({
    super.key,
    required this.entry,
    this.onEdit,
    this.onDelete,
    this.onShare,
    this.onTap,
  });

  final DiaryEntry entry;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onShare;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasMenuActions = onEdit != null || onDelete != null;
    final shareAvailable = (entry.canShare || entry.share != null) && onShare != null;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.book_outlined, color: AppColors.accentPurple),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.xs,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _InfoPill(
                              icon: Icons.calendar_today_outlined,
                              label: _formatDate(entry.date),
                            ),
                            if (entry.weather.isNotEmpty)
                              _InfoPill(
                                icon: Icons.wb_sunny_outlined,
                                label: entry.weather,
                              ),
                            if (entry.mood.isNotEmpty)
                              _InfoPill(
                                icon: Icons.mood_outlined,
                                label: entry.mood,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (hasMenuActions) ...[
                    const SizedBox(width: AppSpacing.xs),
                    _EntryMenu(onEdit: onEdit, onDelete: onDelete),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                entry.content,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              if (entry.tags.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
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
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final attachment in entry.attachments)
                      Chip(
                        avatar: const Icon(Icons.link, size: 16),
                        label: Text(
                          attachment.fileName.isEmpty
                              ? attachment.fileUrl
                              : attachment.fileName,
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  if (shareAvailable)
                    FilledButton.icon(
                      onPressed: onShare,
                      icon: Icon(
                        entry.share == null ? Icons.ios_share : Icons.copy,
                      ),
                      label: Text(
                        entry.share == null ? '分享' : '复制链接',
                      ),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.lock_outline),
                      label: Text(context.tr('私密')),
                    ),
                  const Spacer(),
                  Text(
                    _formatTime(entry.date),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
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

enum _DiaryMenuAction { edit, delete }

class _EntryMenu extends StatelessWidget {
  const _EntryMenu({this.onEdit, this.onDelete});

  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_DiaryMenuAction>(
      tooltip: '更多操作',
      onSelected: (action) {
        switch (action) {
          case _DiaryMenuAction.edit:
            onEdit?.call();
            break;
          case _DiaryMenuAction.delete:
            onDelete?.call();
            break;
        }
      },
      itemBuilder: (context) {
        return [
          if (onEdit != null)
            PopupMenuItem<_DiaryMenuAction>(
              value: _DiaryMenuAction.edit,
              child: ListTile(
                leading: Icon(Icons.edit_outlined),
                title: Text(context.tr('编辑')),
                dense: true,
                visualDensity: VisualDensity.compact,
              ),
            ),
          if (onDelete != null)
            PopupMenuItem<_DiaryMenuAction>(
              value: _DiaryMenuAction.delete,
              child: ListTile(
                leading: Icon(Icons.delete_outline),
                title: Text(context.tr('删除')),
                dense: true,
                visualDensity: VisualDensity.compact,
              ),
            ),
        ];
      },
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

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
          Icon(icon, size: 14, color: AppColors.primary),
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
