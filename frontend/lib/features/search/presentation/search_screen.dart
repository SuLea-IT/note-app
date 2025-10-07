import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/locale_utils.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../notes/presentation/note_list_screen.dart';
import '../../tasks/presentation/task_board_screen.dart';
import '../../audio_notes/presentation/audio_note_list_screen.dart';
import '../../diary/presentation/diary_screen.dart';
import '../application/search_controller.dart' as app;
import '../data/search_repository.dart';
import '../domain/entities/search.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  static Route<dynamic> route() {
    return MaterialPageRoute(builder: (_) => const SearchScreen());
  }

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _searchController;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<app.SearchController>(
      create: (context) => app.SearchController(context.read<SearchRepository>()),
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: _buildSearchField(context),
        ),
        body: const _SearchBody(),
      ),
    );
  }

  Widget _buildSearchField(BuildContext context) {
    final controller = context.read<app.SearchController>();
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.md),
      child: TextField(
        controller: _searchController,
        focusNode: _focusNode,
        autofocus: true,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: '搜索笔记、任务、日记…',
          border: InputBorder.none,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _searchController.clear();
                    controller.updateQuery('');
                  },
                  icon: const Icon(Icons.clear),
                )
              : null,
        ),
        onChanged: controller.updateQuery,
        onSubmitted: controller.performSearch,
      ),
    );
  }
}

class _SearchBody extends StatelessWidget {
  const _SearchBody();

  @override
  Widget build(BuildContext context) {
    return Consumer<app.SearchController>(
      builder: (context, controller, _) {
        final state = controller.state;
        return Column(
          children: [
            _FilterBar(state: state, controller: controller),
            const Divider(height: 1),
            Expanded(child: _buildContent(context, state, controller)),
          ],
        );
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    app.SearchState state,
    app.SearchController controller,
  ) {
    switch (state.status) {
      case app.SearchStatus.idle:
        return _HistoryView(controller: controller, history: state.history);
      case app.SearchStatus.searching:
        return const Center(child: CircularProgressIndicator());
      case app.SearchStatus.failure:
        return _ErrorView(message: state.error ?? '搜索失败，请稍后重试', onRetry: () {
          if (state.query.isNotEmpty) {
            controller.performSearch(state.query);
          }
        });
      case app.SearchStatus.ready:
        if (state.sections.isEmpty) {
          return const _EmptyView();
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.xl + 80,
          ),
          itemCount: state.sections.length,
          itemBuilder: (context, index) {
            final section = state.sections[index];
            return _ResultSection(
              section: section,
              onTap: (result) => _handleResultTap(context, result),
            );
          },
        );
    }
  }

  void _handleResultTap(BuildContext context, SearchResult result) {
    switch (result.type) {
      case SearchResultType.note:
        Navigator.of(context).push(NoteListScreen.route());
        break;
      case SearchResultType.task:
        Navigator.of(context).push(TaskBoardScreen.route());
        break;
      case SearchResultType.audioNote:
        Navigator.of(context).push(AudioNoteListScreen.route());
        break;
      case SearchResultType.diary:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DiaryScreen()));
        break;
      case SearchResultType.habit:
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(context.tr('请在习惯页面查看详情'))));
        break;
    }
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.state, required this.controller});

  final app.SearchState state;
  final app.SearchController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: SearchResultType.values.map((type) {
              final selected = state.selectedTypes.contains(type);
              return FilterChip(
                label: Text(type.label),
                selected: selected,
                onSelected: (_) => controller.toggleType(type),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: state.startDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    controller.setDateRange(start: picked, end: state.endDate);
                  }
                },
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(state.startDate == null
                    ? '开始日期'
                    : DateFormat('yyyy-MM-dd').format(state.startDate!)),
              ),
              const SizedBox(width: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: state.endDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    controller.setDateRange(start: state.startDate, end: picked);
                  }
                },
                icon: const Icon(Icons.event_outlined),
                label: Text(state.endDate == null
                    ? '结束日期'
                    : DateFormat('yyyy-MM-dd').format(state.endDate!)),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (state.startDate != null || state.endDate != null)
                TextButton(
                  onPressed: controller.resetFilters,
                  child: Text(context.tr('清除日期')),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryView extends StatelessWidget {
  const _HistoryView({required this.controller, required this.history});

  final app.SearchController controller;
  final List<String> history;

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return Center(
        child: Text(context.tr('输入关键词，快速查找你的内容')),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(context.tr('搜索历史'), style: TextStyle(fontWeight: FontWeight.w600)),
            TextButton(onPressed: controller.clearHistory, child: Text(context.tr('清除'))),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: history
              .map(
                (item) => InputChip(
                  label: Text(item),
                  onDeleted: () => controller.removeHistory(item),
                  onPressed: () {
                    controller.updateQuery(item);
                    controller.performSearch(item);
                  },
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _ResultSection extends StatelessWidget {
  const _ResultSection({required this.section, required this.onTap});

  final SearchSection section;
  final ValueChanged<SearchResult> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.label,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: section.results.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final result = section.results[index];
                return ListTile(
                  onTap: () => onTap(result),
                  leading: Icon(_iconForType(result.type), color: AppColors.primary),
                  title: Text(result.title),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if ((result.excerpt ?? '').isNotEmpty)
                        Text(
                          result.excerpt!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (result.tags.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xs),
                          child: Wrap(
                            spacing: AppSpacing.xs,
                            runSpacing: AppSpacing.xs,
                            children: result.tags
                                .map((tag) => Chip(
                                      label: Text('#$tag'),
                                      backgroundColor: AppColors.primary.withAlpha(20),
                                    ))
                                .toList(),
                          ),
                        ),
                    ],
                  ),
                  trailing: result.date != null
                      ? Text(DateFormat('MM-dd HH:mm').format(result.date!.toLocal()))
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForType(SearchResultType type) {
    switch (type) {
      case SearchResultType.note:
        return Icons.note_outlined;
      case SearchResultType.task:
        return Icons.check_circle_outline;
      case SearchResultType.diary:
        return Icons.book_outlined;
      case SearchResultType.habit:
        return Icons.calendar_today_outlined;
      case SearchResultType.audioNote:
        return Icons.mic_none_outlined;
    }
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off_outlined, size: 64, color: AppColors.textSecondary),
          const SizedBox(height: AppSpacing.lg),
          Text(context.tr('没有找到匹配结果，换个关键词试试'),
            style: Theme.of(context).textTheme.bodyMedium,
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
          FilledButton(onPressed: onRetry, child: Text(context.tr('重试'))),
        ],
      ),
    );
  }
}
