import 'package:flutter/foundation.dart';

import '../data/home_repository.dart';
import '../domain/entities/home_feed.dart';

enum HomeStatus { initial, loading, ready, failure }

class HomeState {
  const HomeState({
    this.status = HomeStatus.initial,
    this.feed,
    this.mode = HomeDisplayMode.list,
    this.errorMessage,
  });

  final HomeStatus status;
  final HomeFeed? feed;
  final HomeDisplayMode mode;
  final String? errorMessage;

  HomeState copyWith({
    HomeStatus? status,
    HomeFeed? feed,
    bool clearFeed = false,
    HomeDisplayMode? mode,
    String? errorMessage,
    bool clearError = false,
  }) {
    return HomeState(
      status: status ?? this.status,
      feed: clearFeed ? null : (feed ?? this.feed),
      mode: mode ?? this.mode,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class HomeController extends ChangeNotifier {
  HomeController(this._repository);

  final HomeRepository _repository;

  HomeState _state = const HomeState();
  HomeState get state => _state;

  Future<void> load() async {
    _state = _state.copyWith(status: HomeStatus.loading, clearError: true);
    notifyListeners();
    try {
      final feed = await _repository.loadFeed();
      _state = _state.copyWith(
        status: HomeStatus.ready,
        feed: feed,
        clearError: true,
      );
    } catch (error, stackTrace) {
      debugPrint('HomeController load error: $error');
      debugPrintStack(stackTrace: stackTrace);
      _state = _state.copyWith(
        status: HomeStatus.failure,
        errorMessage: '加载主页内容失败',
        clearFeed: true,
      );
    }
    notifyListeners();
  }

  Future<void> refresh() => load();

  void reset() {
    _state = const HomeState();
    notifyListeners();
  }

  void toggleMode(HomeDisplayMode mode) {
    if (_state.mode == mode) {
      return;
    }
    _state = _state.copyWith(mode: mode);
    notifyListeners();
  }
}