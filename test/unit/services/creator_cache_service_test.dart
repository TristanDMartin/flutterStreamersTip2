import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/models/creator_profile_snapshot.dart';
import 'package:streamers_tip/services/creator_cache_service.dart';

void main() {
  group('CreatorCacheService', () {
    test('stores and returns snapshot by user id', () {
      const CreatorProfileSnapshot input = CreatorProfileSnapshot(
        creatorId: 'user-1',
        displayName: 'Alex',
        username: 'alex',
        avatarUrl: 'https://example.com/a.png',
        followersCount: 42,
      );
      CreatorCacheService.instance.set('user-1', input);
      final CreatorProfileSnapshot? actual =
          CreatorCacheService.instance.get('user-1');
      expect(actual?.displayName, 'Alex');
      expect(actual?.followersCount, 42);
    });

    test('resolveForNavigation prefers initial creator over cache', () {
      const CreatorProfileSnapshot cached = CreatorProfileSnapshot(
        creatorId: 'user-1',
        displayName: 'Cached',
        username: 'cached',
      );
      const CreatorProfileSnapshot initial = CreatorProfileSnapshot(
        creatorId: 'user-1',
        displayName: 'Fresh',
        username: 'fresh',
      );
      CreatorCacheService.instance.set('user-1', cached);
      final CreatorProfileSnapshot? actual =
          CreatorCacheService.instance.resolveForNavigation(
        userId: 'user-1',
        initialCreator: initial,
      );
      expect(actual?.displayName, 'Fresh');
    });
  });
}
