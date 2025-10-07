import 'package:flutter/foundation.dart';

import '../data/diary_repository.dart';
import '../domain/entities/diary_draft.dart';
import '../domain/entities/diary_entry.dart';

enum DiaryStatus { initial, loading, ready, failure }

class DiaryState {
  const DiaryState({
    this.status = DiaryStatus.initial,
    this.feed,
    this.error,
    this.actionError,
    this.isMutating = false,
    this.lastShare,
  });

  final DiaryStatus status;
  final DiaryFeed? feed;
  final String? error;
  final String? actionError;
  final bool isMutating;
  final DiaryShare? lastShare;

  DiaryState copyWith({
    DiaryStatus? status,
    DiaryFeed? feed,
    bool clearFeed = false,
    String? error,
    bool resetError = false,
    String? actionError,
    bool clearActionError = false,
    bool? isMutating,
    DiaryShare? lastShare,
    bool clearLastShare = false,
  }) {
    return DiaryState(
      status: status ?? this.status,
      feed: clearFeed ? null : (feed ?? this.feed),
      error: resetError ? null : (error ?? this.error),
      actionError: clearActionError ? null : (actionError ?? this.actionError),
      isMutating: isMutating ?? this.isMutating,
      lastShare: clearLastShare ? null : (lastShare ?? this.lastShare),
    );
  }
}

class DiaryController extends ChangeNotifier {
  DiaryController(this._repository);

  final DiaryRepository _repository;

  DiaryState _state = const DiaryState();
  DiaryState get state => _state;

  Future<void> load() async {
    _state = _state.copyWith(
      status: DiaryStatus.loading,
      resetError: true,
      clearActionError: true,
      clearLastShare: true,
    );
    notifyListeners();

    try {
      final feed = await _repository.fetchFeed();
      _state = _state.copyWith(status: DiaryStatus.ready, feed: feed);
    } catch (error, stackTrace) {
      debugPrint('DiaryController load error: $error');
      debugPrintStack(stackTrace: stackTrace);
      _state = _state.copyWith(status: DiaryStatus.failure, error: '加载日记失败');
    }

    notifyListeners();
  }

  void reset() {
    _state = const DiaryState();
    notifyListeners();
  }

  Future<bool> createEntry(DiaryDraft draft) async {
    return _performMutation(() async {
      final entry = await _repository.createDiary(draft);
      final current = _state.feed;
      if (current == null) {
        _state = _state.copyWith(
          feed: DiaryFeed(entries: [entry], templates: []),
          clearLastShare: true,
        );
        return;
      }
      final updated = <DiaryEntry>[entry, ...current.entries];
      _state = _state.copyWith(
        feed: current.copyWith(entries: updated),
        clearLastShare: true,
      );
    }, failureMessage: '创建日记失败');
  }

  Future<bool> updateEntry(String id, DiaryDraft draft) async {
    return _performMutation(() async {
      final updated = await _repository.updateDiary(id, draft);
      final current = _state.feed;
      if (current == null) {
        return;
      }
      final entries = current.entries
          .map((entry) => entry.id == id ? updated : entry)
          .toList(growable: false);
      _state = _state.copyWith(
        feed: current.copyWith(entries: entries),
        clearLastShare: true,
      );
    }, failureMessage: '更新日记失败');
  }

  Future<bool> deleteEntry(String id) async {
    return _performMutation(() async {
      await _repository.deleteDiary(id);
      final current = _state.feed;
      if (current == null) {
        return;
      }
      final entries = current.entries.where((entry) => entry.id != id).toList();
      _state = _state.copyWith(
        feed: current.copyWith(entries: entries),
        clearLastShare: true,
      );
    }, failureMessage: '删除日记失败');
  }

  void clearActionError() {
    if (_state.actionError == null) {
      return;
    }
    _state = _state.copyWith(clearActionError: true);
    notifyListeners();
  }

  Future<bool> _performMutation(
    Future<void> Function() action, {
    required String failureMessage,
  }) async {
    _state = _state.copyWith(
      isMutating: true,
      clearActionError: true,
    );
    notifyListeners();

    try {
      await action();
      _state = _state.copyWith(isMutating: false);
      notifyListeners();
      return true;
    } catch (error, stackTrace) {
      debugPrint('DiaryController mutation error: $error');
      debugPrintStack(stackTrace: stackTrace);
      _state = _state.copyWith(isMutating: false, actionError: failureMessage);
      notifyListeners();
      return false;
    }
  }

  Future<DiaryShare?> shareEntry(
    DiaryEntry entry, {
    int? expiresInHours,
  }) async {
    DiaryShare? result;
    final success = await _performMutation(() async {
      final share = await _repository.shareDiary(
        entry.id,
        expiresInHours: expiresInHours,
      );
      result = share;
      final current = _state.feed;
      if (current == null) {
        return;
      }
      final entries = current.entries
          .map((item) => item.id == entry.id ? item.copyWith(share: share) : item)
          .toList(growable: false);
      _state = _state.copyWith(
        feed: current.copyWith(entries: entries),
        lastShare: share,
      );
    }, failureMessage: '生成分享链接失败');

    if (!success) {
      return null;
    }
    return result;
  }
}