import '../../auth/domain/auth_session.dart';
import '../../auth/domain/entities/auth_user.dart';
import '../../../core/network/api_client.dart';
import '../domain/entities/habit_day.dart';
import '../domain/entities/habit_entry.dart';
import '../domain/entities/habit_history_entry.dart';
import '../domain/entities/habit_overview.dart';
import 'habit_repository.dart';

class RemoteHabitRepository implements HabitRepository {
  RemoteHabitRepository(this._client, this._session);

  final ApiClient _client;
  final AuthSession _session;

  @override
  Future<HabitFeed> fetchFeed() async {
    final user = _requireUser();
    final response = await _client.getJson(
      '/habits/feed?user_id=${Uri.encodeComponent(user.id)}&lang=${Uri.encodeComponent(user.preferredLocale)}',
    );
    final payload = _unwrap(response);

    final days = (payload['days'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(_mapDay)
        .toList();
    final entries = (payload['entries'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(_mapEntry)
        .toList();
    final overview = _mapOverview(
      payload['overview'] as Map<String, dynamic>?,
      entries.length,
    );
    final history = (payload['history'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(HabitHistoryEntry.fromJson)
        .toList();

    return HabitFeed(
      days: days,
      entries: entries,
      overview: overview,
      history: history,
    );
  }

  @override
  Future<HabitEntry> updateEntry(HabitEntry entry) async {
    final user = _requireUser();
    final payload = {
      ...entry.toApiPayload(),
      'default_locale': user.preferredLocale,
    };
    final response = await _client.putJson(
      '/habits/${Uri.encodeComponent(entry.id)}?user_id=${Uri.encodeComponent(user.id)}',
      payload,
    );
    final decoded = _unwrapHabit(response);
    return _mapEntry(decoded);
  }

  @override
  Future<void> addHabit(HabitEntry habit) async {
    final user = _requireUser();
    final payload = {
      ...habit.toApiPayload(),
      'user_id': user.id,
      'default_locale': user.preferredLocale,
      'translations': [
        {
          'locale': user.preferredLocale,
          'title': habit.title,
          'description': habit.description,
          'time_label': habit.timeLabel,
        },
      ],
    };
    await _client.postJson(
      '/habits?user_id=${Uri.encodeComponent(user.id)}',
      payload,
    );
  }

  Map<String, dynamic> _unwrap(Map<String, dynamic> json) {
    if (json.containsKey('entries') || json.containsKey('days')) {
      return json;
    }
    final data = json['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    throw const FormatException('Unexpected habit feed payload');
  }

  Map<String, dynamic> _unwrapHabit(Map<String, dynamic> json) {
    if (json.containsKey('id')) {
      return json;
    }
    final data = json['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    throw const FormatException('Unexpected habit payload');
  }

  HabitDay _mapDay(Map<String, dynamic> json) {
    final dateValue = json['date'];
    final date = dateValue is String
        ? DateTime.tryParse(dateValue) ?? DateTime.now()
        : DateTime.now();
    return HabitDay(
      date: date,
      isToday: json['is_today'] as bool? ?? false,
      completedCount: json['completed_count'] as int? ?? 0,
      totalCount: json['total_count'] as int? ?? 0,
      completionRate: (json['completion_rate'] as num?)?.toDouble(),
    );
  }

  HabitEntry _mapEntry(Map<String, dynamic> json) {
    return HabitEntry.fromJson(json);
  }

  HabitOverview _mapOverview(Map<String, dynamic>? json, int fallbackTotal) {
    if (json == null) {
      return HabitOverview(
        focusMinutes: fallbackTotal * 30,
        completedStreak: 0,
        totalHabits: fallbackTotal,
        completionRate: 0.0,
        activeDays: 0,
      );
    }

    return HabitOverview(
      focusMinutes: json['focus_minutes'] as int? ?? fallbackTotal * 30,
      completedStreak: json['completed_streak'] as int? ?? 0,
      totalHabits: json['total_habits'] as int? ?? fallbackTotal,
      completionRate: (json['completion_rate'] as num?)?.toDouble() ?? 0.0,
      activeDays: json['active_days'] as int? ?? 0,
    );
  }

  AuthUser _requireUser() {
    final user = _session.currentUser;
    if (user == null) {
      throw StateError('User session is required');
    }
    return user;
  }
}
