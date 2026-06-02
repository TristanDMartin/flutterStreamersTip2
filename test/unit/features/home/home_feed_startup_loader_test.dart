import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/home/application/home_feed_startup_loader.dart';
import 'package:streamers_tip/models/home_video.dart';
import 'package:streamers_tip/models/user.dart';

void main() {
  HomeVideo video({required String id}) {
    return HomeVideo(
      id: id,
      creator: const User(
        id: 'u1',
        username: 'u',
        displayName: 'U',
        bio: '',
        hashtags: <String>[],
      ),
      videoURL: 'https://cdn.example/$id.mp4',
    );
  }

  group('HomeFeedStartupRecovery', () {
    test('showEmptyError carries message', () {
      const HomeFeedStartupRecovery recovery = HomeFeedStartupRecovery(
        kind: HomeFeedStartupRecoveryKind.showEmptyError,
        errorMessage: 'Unable to load videos right now. Please try again.',
      );
      expect(recovery.videos, isEmpty);
      expect(recovery.errorMessage, isNotNull);
    });

    test('restoredFromWarmCache includes cached videos', () {
      final HomeFeedStartupRecovery recovery = HomeFeedStartupRecovery(
        kind: HomeFeedStartupRecoveryKind.restoredFromWarmCache,
        videos: <HomeVideo>[video(id: 'v1')],
        errorMessage: 'Connection is unstable. Showing your last loaded feed.',
      );
      expect(recovery.videos.single.id, 'v1');
    });
  });
}
