import 'package:flutter/material.dart';
import '../../../../core/localization/locale_utils.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_radius.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../domain/entities/home_feed.dart';
import '../../../notes/domain/entities/note.dart';

class NoteSectionView extends StatelessWidget {
  const NoteSectionView({
    super.key,
    required this.section,
    required this.mode,
    required this.onViewAll,
    this.onNoteTap,
  });

  final NoteSection section;
  final HomeDisplayMode mode;
  final VoidCallback onViewAll;
  final ValueChanged<NoteSummary>? onNoteTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              section.label,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            TextButton(onPressed: onViewAll, child: Text(context.tr('查看全部'))),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        switch (mode) {
          HomeDisplayMode.list => Column(
            children: [
              for (final note in section.notes) ...[
                _NoteListTile(
                  note: note,
                  onTap: onNoteTap != null ? () => onNoteTap!(note) : null,
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ],
          ),
          HomeDisplayMode.card => Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              for (final note in section.notes)
                SizedBox(
                  width:
                      (MediaQuery.sizeOf(context).width -
                          (AppSpacing.xl * 2) -
                          AppSpacing.md) /
                      2,
                  child: _NoteCard(
                    note: note,
                    onTap: onNoteTap != null ? () => onNoteTap!(note) : null,
                  ),
                ),
            ],
          ),
        },
      ],
    );
  }
}

class _NoteListTile extends StatelessWidget {
  const _NoteListTile({required this.note, this.onTap});

  final NoteSummary note;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = note.category.color;
    final borderRadius = BorderRadius.circular(AppRadius.lg);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: Ink(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: borderRadius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 42,
                    width: 42,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(note.category.icon, color: color),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          note.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          note.preview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  const Icon(Icons.more_horiz, color: AppColors.textSecondary),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text('${note.date.year}-${note.date.month.toString().padLeft(2, '0')}-${note.date.day.toString().padLeft(2, '0')}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  if (note.progressPercent != null)
                    _NoteProgressBar(percent: note.progressPercent!),
                  if (note.hasAttachment)
                    _AttachmentChip(label: context.tr('附件', 'Attachment')),
                  for (final tag in note.tags)
                    _TagChip(tag: tag),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note, this.onTap});

  final NoteSummary note;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = note.category.color;
    final borderRadius = BorderRadius.circular(AppRadius.lg);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: Ink(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: borderRadius,
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(note.category.icon, color: color, size: 18),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text('${note.date.month.toString().padLeft(2, '0')}/${note.date.day.toString().padLeft(2, '0')}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                note.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                note.preview,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  if (note.progressPercent != null)
                    _NoteProgressBar(percent: note.progressPercent!),
                  if (note.hasAttachment)
                    _AttachmentChip(label: context.tr('附件', 'Attachment')),
                  for (final tag in note.tags)
                    _TagChip(tag: tag),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoteProgressBar extends StatelessWidget {
  const _NoteProgressBar({required this.percent});

  final double percent;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: const Icon(
        Icons.flag_outlined,
        size: 16,
        color: AppColors.primary,
      ),
      label: Text('${(percent * 100).round()}%'),
      visualDensity: VisualDensity.compact,
      backgroundColor: AppColors.primaryLight,
      labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: AppColors.primary,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _AttachmentChip extends StatelessWidget {
  const _AttachmentChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: const Icon(
        Icons.attach_file,
        size: 16,
        color: AppColors.primary,
      ),
      label: Text(label),
      backgroundColor: AppColors.primaryLight,
      labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.tag});

  final String tag;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('#$tag'),
      backgroundColor: AppColors.accentPurple.withOpacity(0.12),
      labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AppColors.accentPurple,
            fontWeight: FontWeight.w600,
          ),
      visualDensity: VisualDensity.compact,
    );
  }
}
