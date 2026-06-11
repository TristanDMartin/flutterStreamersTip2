import '../../../models/home_video.dart';
import '../../../services/global_playback_manager.dart';
import '../../../services/playback_preload_order.dart';
import '../../../services/playback_warm_window_policy.dart';
import '../../../services/unified_avatar_service.dart';
import 'package:streamers_tip/utils/like_interaction_boundary.dart';
import 'home_feed_engagement_coordinator.dart';

/// Warms video controllers, avatars, and cached engagement for the feed window
/// around [index] without blocking playback.
class HomeFeedSurfaceWarm {
  HomeFeedSurfaceWarm({
    HomeFeedEngagementCoordinator? engagementCoordinator,
    UnifiedAvatarService? avatarService,
  })  : _engagementCoordinator =
            engagementCoordinator ?? HomeFeedEngagementCoordinator(),
        _avatarService = avatarService ?? UnifiedAvatarService();

  final HomeFeedEngagementCoordinator _engagementCoordinator;
  final UnifiedAvatarService _avatarService;
  int _avatarWarmEpoch = 0;

  void warmAround({
    required int index,
    required List<HomeVideo> videos,
    int direction = 1,
    String controllerOwner = 'home',
  }) {
    if (videos.isEmpty || index < 0 || index >= videos.length) {
      return;
    }
    GlobalPlaybackManager.instance.preloadAround(
      index,
      videos,
      direction: direction,
      controllerOwner: controllerOwner,
    );
    final ({int backward, int forward}) radii =
        PlaybackWarmWindowPolicy.radiiForDirection(direction);
    final List<int> warmIndices = computePlaybackPreloadIndices(
      index: index,
      videoCount: videos.length,
      direction: direction,
      backwardRadius: radii.backward,
      forwardRadius: radii.forward,
    );
    _warmAvatars(videos, warmIndices);
    _engagementCoordinator.warmEngagementFromCache(
      warmIndices.map((int i) => videos[i]).toList(growable: false),
    );
  }

  void _warmAvatars(List<HomeVideo> videos, List<int> indices) {
    void warmNow() {
      final List<String> avatarUrls = <String>[];
      for (final int i in indices) {
        final String? avatarUrl = videos[i].creator.avatarURL;
        if (avatarUrl != null &&
            avatarUrl.isNotEmpty &&
            !avatarUrls.contains(avatarUrl)) {
          avatarUrls.add(avatarUrl);
        }
      }
      if (avatarUrls.isEmpty) {
        return;
      }
      final int epoch = ++_avatarWarmEpoch;
      Future<void>.delayed(const Duration(milliseconds: 2500), () {
        if (epoch != _avatarWarmEpoch) {
          return;
        }
        if (LikeInteractionBoundary.shouldDeferHeavyWork) {
          LikeInteractionBoundary.runOrQueue(
            () => _warmAvatars(videos, indices),
            reason: 'surface_warm_avatars',
          );
          return;
        }
        _avatarService.preloadAvatars(avatarUrls).catchError((Object _) {});
      });
    }
    if (LikeInteractionBoundary.shouldDeferHeavyWork) {
      _avatarWarmEpoch++;
      LikeInteractionBoundary.runOrQueue(
        warmNow,
        reason: 'surface_warm_avatars',
      );
      return;
    }
    warmNow();
  }
}
