import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/locale_utils.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_spacing.dart';
import '../../auth/application/auth_controller.dart';
import '../../diary/application/diary_controller.dart';
import '../../diary/domain/entities/diary_draft.dart';
import '../../diary/presentation/diary_screen.dart';
import '../../diary/presentation/widgets/diary_compose_sheet.dart';
import '../../habits/application/habit_controller.dart';
import '../../habits/presentation/habit_screen.dart';
import '../application/home_controller.dart';
import '../domain/entities/habit.dart';
import '../domain/entities/home_feed.dart';
import '../../notes/domain/entities/note.dart';
import '../../notes/presentation/note_list_screen.dart';
import '../../search/presentation/search_screen.dart';
import '../../tasks/presentation/task_board_screen.dart';
import '../../audio_notes/presentation/audio_note_list_screen.dart';
import '../domain/entities/quick_action.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../tasks/domain/entities/task.dart';
import 'widgets/habit_list.dart';
import 'widgets/home_header.dart';
import 'widgets/home_mode_toggle.dart';
import 'widgets/note_detail_sheet.dart';
import 'widgets/note_section_view.dart';
import 'widgets/quick_action_grid.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _isOpeningDiary = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<HomeController>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final homeController = context.watch<HomeController>();
    final homeState = homeController.state;
    final authController = context.watch<AuthController>();
    final authUser = authController.state.user;
    final userName = authUser?.resolvedName ?? context.tr('朋友', 'Friend');
    final avatarText = authUser?.initials ?? _firstGlyph(userName);

    final pages = [
      _HomeTab(
        state: homeState,
        controller: homeController,
        userName: userName,
        avatarText: avatarText,
        onQuickActionTap: _handleQuickAction,
        onHabitTap: _handleHabitTap,
        onSearch: _handleSearch,
        onTasksTap: _openTasks,
        onSectionViewAll: _handleSectionViewAll,
        onNoteTap: _handleNoteTap,
      ),
      const HabitScreen(),
      const DiaryScreen(),
      ProfileScreen(onLogout: _performLogout),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: _openDiaryComposer,
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.edit_outlined),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _HomeBottomBar(
        currentIndex: _selectedIndex,
        onTap: _navigateToTab,
      ),
      body: IndexedStack(index: _selectedIndex, children: pages),
    );
  }

  String _firstGlyph(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'U';
    }
    final iterator = trimmed.runes.iterator;
    if (!iterator.moveNext()) {
      return 'U';
    }
    return String.fromCharCode(iterator.current).toUpperCase();
  }

  Future<void> _performLogout() async {
    await context.read<AuthController>().logout();
    if (!mounted) {
      return;
    }
    _showSnackBar(context.tr('已退出登录', 'Signed out'));
    _navigateToTab(0);
  }

  void _navigateToTab(int index) {
    if (_selectedIndex == index) {
      return;
    }
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _openDiaryComposer() async {
    if (_isOpeningDiary || !mounted) {
      return;
    }
    _isOpeningDiary = true;
    try {
      final diaryController = context.read<DiaryController>();
      var diaryState = diaryController.state;
      if (diaryState.status == DiaryStatus.initial || diaryState.feed == null) {
        await diaryController.load();
        if (!mounted) {
          return;
        }
        diaryState = diaryController.state;
      }
      if (diaryState.feed == null) {
        _showSnackBar(diaryState.error ?? context.tr('加载日记模板失败', 'Failed to load diary templates'));
        return;
      }

      final draft = await showModalBottomSheet<DiaryDraft>(
        context: context,
        isScrollControlled: true,
        builder: (context) =>
            DiaryComposeSheet(templates: diaryState.feed!.templates),
      );
      if (!mounted || draft == null) {
        return;
      }

      final created = await diaryController.createEntry(draft);
      if (!mounted) {
        return;
      }
      if (created) {
        _showSnackBar(context.tr('日记创建成功', 'Diary created successfully'));
        _navigateToTab(2);
      } else {
        _showSnackBar(diaryController.state.actionError ?? context.tr('创建日记失败', 'Failed to create diary'));
      }
    } finally {
      _isOpeningDiary = false;
    }
  }

  void _handleQuickAction(QuickActionCard action) {
    switch (action.id) {
      case 'action-diary':
        _openDiaryComposer();
        break;
      case 'action-checkin':
        _navigateToTab(1);
        context.read<HabitController>().load();
        break;
      case 'action-task':
        _openTasks();
        break;
      case 'action-voice':
        Navigator.of(context).push(AudioNoteListScreen.route());
        break;
      default:
        _showSnackBar(context.tr('即将为你打开新的体验', 'New experience coming soon'));
    }
  }

  void _openTasks() {
    Navigator.of(context).push(TaskBoardScreen.route());
  }

  void _handleHabitTap(DailyHabit habit) {
    _navigateToTab(1);
    context.read<HabitController>().load();
  }

  void _handleSectionViewAll(NoteSection section) {
    Navigator.of(context).push(NoteListScreen.route());
  }

  void _handleNoteTap(NoteSummary summary) {
    showModalBottomSheet<NoteDetailResult?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NoteDetailSheet(summary: summary),
    ).then((result) async {
      if (!mounted || result == null) {
        return;
      }
      if (result.isDeleted || result.isUpdated) {
        await context.read<HomeController>().refresh();
      }
    });
  }

  void _handleSearch() {
    Navigator.of(context).push(SearchScreen.route());
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({
    required this.state,
    required this.controller,
    required this.userName,
    required this.avatarText,
    required this.onQuickActionTap,
    required this.onHabitTap,
    required this.onSearch,
    required this.onTasksTap,
    required this.onSectionViewAll,
    required this.onNoteTap,
  });

  final HomeState state;
  final HomeController controller;
  final String userName;
  final String avatarText;
  final ValueChanged<QuickActionCard> onQuickActionTap;
  final ValueChanged<DailyHabit> onHabitTap;
  final VoidCallback onSearch;
  final VoidCallback onTasksTap;
  final ValueChanged<NoteSection> onSectionViewAll;
  final ValueChanged<NoteSummary> onNoteTap;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      displacement: 80,
      color: AppColors.primary,
      onRefresh: controller.refresh,
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (state.status) {
      case HomeStatus.loading:
        return _HomeLoadingView(userName: userName, avatarText: avatarText);
      case HomeStatus.failure:
        return _HomeErrorView(
          message: state.errorMessage ?? context.tr('加载失败', 'Failed to load'),
          onRetry: controller.load,
        );
      case HomeStatus.initial:
        return const _HomeInitialView();
      case HomeStatus.ready:
        final feed = state.feed;
        if (feed == null ||
            (feed.sections.isEmpty &&
                feed.quickActions.isEmpty &&
                feed.habits.isEmpty)) {
          return _HomeEmptyView(
            onRefresh: controller.load,
            userName: userName,
            avatarText: avatarText,
          );
        }
        return _HomeFeedView(
          feed: feed,
          mode: state.mode,
          userName: userName,
          avatarText: avatarText,
          onModeChanged: controller.toggleMode,
          onQuickActionTap: onQuickActionTap,
          onHabitTap: onHabitTap,
          onSearch: onSearch,
          onTasksTap: onTasksTap,
          onSectionViewAll: onSectionViewAll,
          onNoteTap: onNoteTap,
        );
    }
  }
}

class _HomeFeedView extends StatelessWidget {
  const _HomeFeedView({
    required this.feed,
    required this.mode,
    required this.userName,
    required this.avatarText,
    required this.onModeChanged,
    required this.onQuickActionTap,
    required this.onHabitTap,
    required this.onSearch,
    required this.onTasksTap,
    required this.onSectionViewAll,
    required this.onNoteTap,
  });

  final HomeFeed feed;
  final HomeDisplayMode mode;
  final String userName;
  final String avatarText;
  final ValueChanged<HomeDisplayMode> onModeChanged;
  final ValueChanged<QuickActionCard> onQuickActionTap;
  final ValueChanged<DailyHabit> onHabitTap;
  final VoidCallback onSearch;
  final VoidCallback onTasksTap;
  final ValueChanged<NoteSection> onSectionViewAll;
  final ValueChanged<NoteSummary> onNoteTap;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.lg,
            ),
            child: HomeHeader(
              onSearch: onSearch,
              userName: userName,
              avatarText: avatarText,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: HomeModeToggle(
              displayMode: mode,
              onModeChanged: onModeChanged,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: _TaskSummaryCard(stats: feed.taskStats, onTap: onTasksTap),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
        for (final section in feed.sections) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: NoteSectionView(
                section: section,
                mode: mode,
                onViewAll: () => onSectionViewAll(section),
                onNoteTap: onNoteTap,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
        ],
        if (feed.quickActions.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: QuickActionGrid(
                actions: feed.quickActions,
                displayMode: mode,
                onActionTap: onQuickActionTap,
              ),
            ),
          ),
        if (feed.quickActions.isNotEmpty)
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
        if (feed.habits.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: HabitList(
                habits: feed.habits,
                mode: mode,
                onHabitTap: onHabitTap,
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 96)),
      ],
    );
  }
}

class _TaskSummaryCard extends StatelessWidget {
  const _TaskSummaryCard({required this.stats, required this.onTap});

  final TaskStatistics stats;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        color: AppColors.surface,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _TaskStatItem(label: context.tr('今日待办', 'Tasks today'), value: stats.pendingToday, color: const Color(0xFF42A5F5)),
              _TaskStatItem(label: context.tr('已逾期', 'Overdue'), value: stats.overdue, color: const Color(0xFFE57373)),
              _TaskStatItem(label: context.tr('本周计划', 'This week'), value: stats.upcomingWeek, color: const Color(0xFFFFB74D)),
              _TaskStatItem(label: context.tr('今日完成', 'Completed today'), value: stats.completedToday, color: const Color(0xFF66BB6A)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskStatItem extends StatelessWidget {
  const _TaskStatItem({required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value.toString(),
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(color: color, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _HomeLoadingView extends StatelessWidget {
  const _HomeLoadingView({required this.userName, required this.avatarText});

  final String userName;
  final String avatarText;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.lg,
            ),
            child: HomeHeader(
              onSearch: () {},
              userName: userName,
              avatarText: avatarText,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          sliver: SliverList.separated(
            itemCount: 3,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.lg),
            itemBuilder: (context, index) =>
                _SkeletonBlock(height: index == 0 ? 160 : 120),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
      ],
    );
  }
}

class _HomeErrorView extends StatelessWidget {
  const _HomeErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const SizedBox(height: 120),
        Icon(
          Icons.error_outline,
          size: 48,
          color: AppColors.textSecondary.withValues(alpha: 0.7),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(onPressed: onRetry, child: Text(context.tr('重新加载'))),
      ],
    );
  }
}

class _HomeEmptyView extends StatelessWidget {
  const _HomeEmptyView({
    required this.onRefresh,
    required this.userName,
    required this.avatarText,
  });

  final VoidCallback onRefresh;
  final String userName;
  final String avatarText;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      children: [
        HomeHeader(onSearch: () {}, userName: userName, avatarText: avatarText),
        const SizedBox(height: AppSpacing.xl),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.auto_awesome,
                  color: AppColors.primary,
                  size: 40,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(context.tr('还没有内容'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(context.tr('创建第一条日记或笔记，主页就会充实起来。'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton(onPressed: onRefresh, child: Text(context.tr('刷新试试'))),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeInitialView extends StatelessWidget {
  const _HomeInitialView();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _HomeBottomBar extends StatelessWidget {
  const _HomeBottomBar({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: SizedBox(
        height: 64,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _BottomItem(
              icon: Icons.home_outlined,
              label: context.tr('首页', 'Home'),
              selected: currentIndex == 0,
              onTap: () => onTap(0),
            ),
            _BottomItem(
              icon: Icons.calendar_month_outlined,
              label: context.tr('习惯', 'Habits'),
              selected: currentIndex == 1,
              onTap: () => onTap(1),
            ),
            const SizedBox(width: 56),
            _BottomItem(
              icon: Icons.menu_book_outlined,
              label: context.tr('日记', 'Diary'),
              selected: currentIndex == 2,
              onTap: () => onTap(2),
            ),
            _BottomItem(
              icon: Icons.person_outline,
              label: context.tr('我的', 'Profile'),
              selected: currentIndex == 3,
              onTap: () => onTap(3),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomItem extends StatelessWidget {
  const _BottomItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
