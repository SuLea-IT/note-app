import 'dart:async';

import 'package:flutter/material.dart';

import '../domain/entities/habit.dart';
import '../domain/entities/home_feed.dart';
import '../../notes/domain/entities/note.dart';
import '../domain/entities/quick_action.dart';
import '../../tasks/domain/entities/task.dart';
import 'home_repository.dart';

class MockHomeRepository implements HomeRepository {
  const MockHomeRepository();

  @override
  Future<HomeFeed> loadFeed() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1, 15);

    return HomeFeed(
      sections: [
        NoteSection(
          label: '本月',
          date: now,
          notes: [
            NoteSummary(
              id: 'note-1',
              userId: 'mock-user',
              title: '欢迎使用 Hidodo 笔记',
              preview: '记录今日灵感与待办，保持手帐节奏。',
              date: now,
              category: NoteCategory.journal,
              hasAttachment: true,
              tags: ['指南'],
            ),
            NoteSummary(
              id: 'note-2',
              userId: 'mock-user',
              title: '项目周报梳理',
              preview: '梳理进度与下周目标，记得同步团队反馈。',
              date: now.subtract(const Duration(days: 1)),
              category: NoteCategory.reminder,
              progressPercent: 0.4,
              tags: ['项目', '周报'],
            ),
          ],
        ),
        NoteSection(
          label: '${lastMonth.year}年${lastMonth.month}月',
          date: lastMonth,
          notes: [
            NoteSummary(
              id: 'note-3',
              userId: 'mock-user',
              title: '日程记录复盘',
              preview: '复盘本月习惯，坚持早起与运动。',
              date: lastMonth,
              category: NoteCategory.checklist,
              progressPercent: 0.8,
              tags: ['复盘'],
            ),
            NoteSummary(
              id: 'note-4',
              userId: 'mock-user',
              title: '旅行计划草稿',
              preview: '制定出行清单，备注当地天气与装备。',
              date: lastMonth.subtract(const Duration(days: 2)),
              category: NoteCategory.idea,
              tags: ['旅行'],
            ),
          ],
        ),
      ],
      quickActions: [
        QuickActionCard(
          id: 'action-diary',
          title: '日记',
          subtitle: '记录心情瞬间',
          background: Color(0xFFFFF1E6),
          foreground: Color(0xFFFF8B3D),
        ),
        QuickActionCard(
          id: 'action-checkin',
          title: '习惯打卡',
          subtitle: '坚持每一天',
          background: Color(0xFFE8F6EF),
          foreground: Color(0xFF4CAF50),
        ),
        QuickActionCard(
          id: 'action-task',
          title: '任务',
          subtitle: '安排待办',
          background: Color(0xFFF0EDFF),
          foreground: Color(0xFF7C4DFF),
        ),
        QuickActionCard(
          id: 'action-voice',
          title: '语音笔记',
          subtitle: '随手捕捉灵感',
          background: Color(0xFFFBE9F0),
          foreground: Color(0xFFE91E63),
        ),
      ],
      habits: [
        DailyHabit(
          id: 'habit-1',
          label: '晨间写作',
          timeRange: '07:00 - 07:30',
          notes: '记录一天的计划与灵感。',
          isCompleted: true,
        ),
        DailyHabit(
          id: 'habit-2',
          label: '午间阅读',
          timeRange: '12:30 - 13:00',
          notes: '阅读行业资讯或喜欢的书籍。',
          isCompleted: false,
        ),
        DailyHabit(
          id: 'habit-3',
          label: '夜间复盘',
          timeRange: '21:00 - 21:20',
          notes: '回顾今日收获，记录下一步行动。',
          isCompleted: false,
        ),
      ],
      taskStats: const TaskStatistics(
        pendingToday: 2,
        overdue: 1,
        upcomingWeek: 4,
        completedToday: 3,
      ),
    );
  }
}