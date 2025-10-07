import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/locale_utils.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../auth/application/auth_controller.dart';
import '../application/note_feed_controller.dart';
import '../data/note_repository.dart';
import '../domain/entities/note.dart';
import 'note_detail_screen.dart';
import 'note_editor_screen.dart';

class NoteListScreen extends StatelessWidget {
  const NoteListScreen({super.key});

  static Route<dynamic> route() {
    return MaterialPageRoute(builder: (_) => const NoteListScreen());
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<NoteFeedController>(
      create: (context) =>
          NoteFeedController(context.read<NoteRepository>())..load(),
      child: const _NoteListView(),
    );
  }
}

class _NoteListView extends StatefulWidget {
  const _NoteListView();

  @override
  State<_NoteListView> createState() => _NoteListViewState();
}

class _NoteListViewState extends State<_NoteListView> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(_handleSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    final controller = context.read<NoteFeedController>();
    controller.search(_searchController.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('笔记')),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: () => context.read<NoteFeedController>().refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _handleCreate,
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: Consumer<NoteFeedController>(
          builder: (context, controller, _) {
            final state = controller.state;
            Widget content;
            switch (state.status) {
              case NoteFeedStatus.initial:
              case NoteFeedStatus.loading:
                content = const Center(child: CircularProgressIndicator());
                break;
              case NoteFeedStatus.failure:
                content = _ErrorView(
                  message: state.error ?? '加载失败，请稍后重试',
                  onRetry: controller.refresh,
                );
                break;
              case NoteFeedStatus.ready:
                content = _buildReadyView(controller, state);
                break;
            }
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.lg,
                    AppSpacing.xl,
                    AppSpacing.sm,
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: '搜索笔记标题、内容、标签',
                      suffixIcon: state.isSearching || state.query.isNotEmpty
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
                if (state.status == NoteFeedStatus.ready)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                      vertical: AppSpacing.sm,
                    ),
                    child: _FilterBar(controller: controller),
                  ),
                const Divider(height: 1),
                Expanded(child: content),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildReadyView(NoteFeedController controller, NoteFeedState state) {
    if (state.isSearching && state.query.isNotEmpty) {
      return _SearchResultList(
        results: state.searchResults,
        onTap: _openDetail,
      );
    }

    final sections = controller.filteredSections;
    if (sections.isEmpty) {
      return const _EmptyListPlaceholder();
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: controller.refresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.lg,
        ),
        itemCount: sections.length,
        itemBuilder: (context, index) {
          final section = sections[index];
          return _NoteSectionBlock(section: section, onTap: _openDetail);
        },
      ),
    );
  }

  Future<void> _handleCreate() async {
    final auth = context.read<AuthController>();
    final user = auth.state.user;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr('请先登录后再创建笔记'))));
      return;
    }

    final draft = NoteDraft(
      id: '',
      userId: user.id,
      title: '',
      preview: '',
      content: '',
      date: DateTime.now(),
      category: NoteCategory.journal,
      progressPercent: 0,
      defaultLocale: user.preferredLocale,
    );

    final result = await Navigator.of(context).push<NoteDetailResult>(
      NoteEditorScreen.route(draft: draft, isEditing: false),
    );

    if (!mounted) {
      return;
    }

    if (result?.isUpdated ?? false) {
      await context.read<NoteFeedController>().refresh();
    }
  }

  Future<void> _openDetail(NoteSummary summary) async {
    final result = await Navigator.of(
      context,
    ).push<NoteDetailResult>(NoteDetailScreen.route(summary: summary));

    if (!mounted) {
      return;
    }

    if (result == null) {
      return;
    }
    final controller = context.read<NoteFeedController>();
    if (result.isDeleted && result.deletedId != null) {
      controller.removeFromFeed(result.deletedId!);
    } else if (result.isUpdated) {
      await controller.refresh();
    }
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.controller});

  final NoteFeedController controller;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final availableTags = controller.availableTags;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final category in NoteCategory.values)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: FilterChip(
                    selected: state.selectedCategories.contains(category),
                    label: Text(_categoryLabel(category)),
                    onSelected: (_) => controller.toggleCategory(category),
                  ),
                ),
            ],
          ),
        ),
        if (availableTags.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final tag in availableTags)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: FilterChip(
                      selected: state.selectedTags.contains(tag),
                      label: Text(tag),
                      onSelected: (_) => controller.toggleTag(tag),
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (state.selectedCategories.isNotEmpty ||
            state.selectedTags.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: controller.clearFilters,
              icon: const Icon(Icons.close),
              label: Text(context.tr('清除筛选')),
            ),
          ),
      ],
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
}

class _NoteSectionBlock extends StatelessWidget {
  const _NoteSectionBlock({required this.section, required this.onTap});

  final NoteSection section;
  final ValueChanged<NoteSummary> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.label,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final note in section.notes) ...[
            _NoteListTile(summary: note, onTap: onTap),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _NoteListTile extends StatelessWidget {
  const _NoteListTile({required this.summary, required this.onTap});

  final NoteSummary summary;
  final ValueChanged<NoteSummary> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => onTap(summary),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: summary.category.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Icon(
                      summary.category.icon,
                      color: summary.category.color,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          summary.title.isEmpty ? '未命名笔记' : summary.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          summary.preview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  Text(
                    _formatDate(summary.date),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (summary.progressPercent != null)
                    Chip(
                      label: Text('进度 ${(summary.progressPercent! * 100).round()}%',
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (summary.hasAttachment)
                    Chip(
                      label: Text(context.tr('附件')),
                      visualDensity: VisualDensity.compact,
                    ),
                  for (final tag in summary.tags)
                    Chip(
                      label: Text('#$tag'),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

class _SearchResultList extends StatelessWidget {
  const _SearchResultList({required this.results, required this.onTap});

  final List<NoteSummary> results;
  final ValueChanged<NoteSummary> onTap;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return Center(child: Text(context.tr('未找到相关笔记')));
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      itemCount: results.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final summary = results[index];
        return _NoteListTile(summary: summary, onTap: onTap);
      },
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

class _EmptyListPlaceholder extends StatelessWidget {
  const _EmptyListPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const SizedBox(height: 120),
        const Icon(Icons.auto_awesome, size: 48, color: AppColors.textSecondary),
        const SizedBox(height: AppSpacing.md),
        Text(context.tr('暂无笔记，点击右下角创建第一条！'), textAlign: TextAlign.center),
      ],
    );
  }
}
