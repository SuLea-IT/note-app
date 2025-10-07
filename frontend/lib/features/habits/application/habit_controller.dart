import 'package:flutter/foundation.dart';

import '../data/habit_repository.dart';
import '../domain/entities/habit_entry.dart';
import '../domain/entities/habit_status.dart';

enum HabitStatusState { initial, loading, ready, failure }

class HabitState {
  const HabitState({
    this.status = HabitStatusState.initial,
    this.feed,
    this.error,
  });

  final HabitStatusState status;
  final HabitFeed? feed;
  final String? error;

  HabitState copyWith({
    HabitStatusState? status,
    HabitFeed? feed,
    bool clearFeed = false,
    String? error,
    bool clearError = false,
  }) {
    return HabitState(
      status: status ?? this.status,
      feed: clearFeed ? null : (feed ?? this.feed),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class HabitController extends ChangeNotifier {
  HabitController(this._repository);

  final HabitRepository _repository;

  HabitState _state = const HabitState();
  HabitState get state => _state;

  Future<void> load() async {
    _state = _state.copyWith(
      status: HabitStatusState.loading,
      clearError: true,
    );
    notifyListeners();
    try {
      final feed = await _repository.fetchFeed();
      _state = _state.copyWith(
        status: HabitStatusState.ready,
        feed: feed,
        clearError: true,
      );
    } catch (error, stackTrace) {
      debugPrint('HabitController load error: $error');
      debugPrintStack(stackTrace: stackTrace);
      _state = _state.copyWith(
        status: HabitStatusState.failure,
        error: '加载习惯数据失败',
      );
    }
    notifyListeners();
  }

  void reset() {
    _state = const HabitState();
    notifyListeners();
  }

  Future<void> addHabit(HabitEntry habit) async {
    try {
      await _repository.addHabit(habit);
      await load();
    } catch (error, stackTrace) {
      debugPrint('HabitController addHabit error: $error');
      debugPrintStack(stackTrace: stackTrace);
      _state = _state.copyWith(
        status: HabitStatusState.failure,
        error: '添加习惯失败',
      );
      notifyListeners();
    }
  }

  Future<void> toggleStatus(HabitEntry entry) async {
    final currentFeed = _state.feed;
    if (currentFeed == null) {
      return;
    }

    final index = currentFeed.entries.indexWhere((item) => item.id == entry.id);
    if (index == -1) {
      return;
    }

    final currentEntry = currentFeed.entries[index];
    final nextStatus = currentEntry.status == HabitStatus.completed
        ? HabitStatus.upcoming
        : HabitStatus.completed;
    final optimisticEntry = currentEntry.copyWith(status: nextStatus);

    final updatedEntries = List<HabitEntry>.from(currentFeed.entries);
    updatedEntries[index] = optimisticEntry;

    _state = _state.copyWith(
      feed: currentFeed.copyWith(entries: updatedEntries),
      clearError: true,
    );
    notifyListeners();

    try {
      await _repository.updateEntry(optimisticEntry);
      final refreshed = await _repository.fetchFeed();
      _state = _state.copyWith(
        feed: refreshed,
        status: HabitStatusState.ready,
        clearError: true,
      );
    } catch (error, stackTrace) {
      debugPrint('HabitController toggleStatus error: $error');
      debugPrintStack(stackTrace: stackTrace);
      _state = _state.copyWith(
        feed: currentFeed,
        status: HabitStatusState.ready,
        error: '更新习惯状态失败',
      );
    }
    notifyListeners();
  }
}
