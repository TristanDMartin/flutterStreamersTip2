import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/home/application/home_view_model.dart';
import '../features/home/models/home_feed_state.dart';
import '../services/following_feed_service.dart';
import '../services/video_service.dart' as video_service;
import 'video_service_provider.dart';

export '../features/home/application/home_view_model.dart';
export '../features/home/models/home_feed_state.dart';

final StateNotifierProvider<HomeViewModel, HomeState> homeProvider =
    StateNotifierProvider<HomeViewModel, HomeState>((Ref ref) {
  final video_service.VideoService videoService =
      ref.read(videoServiceProvider);
  return HomeViewModel(
    videoService: videoService,
    followingFeedService: FollowingFeedService.instance,
  );
});
