import 'dart:async';

import '../domain/entities/home_feed.dart';

abstract class HomeRepository {
  Future<HomeFeed> loadFeed();
}
