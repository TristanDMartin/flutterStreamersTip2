import 'dart:async';

import '../models/creator_profile_snapshot.dart';
import '../models/trending_creator.dart';
import '../models/user.dart';
import 'public_profile_firestore.dart';

/// In-memory cache so StreamerCard can render before Firestore returns.
class CreatorCacheService {
  CreatorCacheService._();
  static final CreatorCacheService instance = CreatorCacheService._();

  static const int _maxEntries = 120;
  final Map<String, CreatorProfileSnapshot> _cache =
      <String, CreatorProfileSnapshot>{};
  final List<String> _lruKeys = <String>[];
  final Set<String> _warmInFlight = <String>{};

  CreatorProfileSnapshot? get(String userId) {
    final String key = userId.trim();
    if (key.isEmpty) {
      return null;
    }
    return _cache[key];
  }

  void set(String userId, CreatorProfileSnapshot creator) {
    final String key = userId.trim();
    if (key.isEmpty || !creator.hasDisplayIdentity) {
      return;
    }
    _touch(key);
    _cache[key] = creator;
    _evictIfNeeded();
  }

  void setFromUserData(String userId, Map<String, dynamic> data) {
    set(
      userId,
      CreatorProfileSnapshot.fromUserDataMap(userId, data),
    );
  }

  void preload(Iterable<CreatorProfileSnapshot> creators) {
    for (final CreatorProfileSnapshot creator in creators) {
      set(creator.creatorId, creator);
    }
  }

  void preloadUsers(Iterable<User> users) {
    preload(users.map(CreatorProfileSnapshot.fromUser));
  }

  void preloadTrending(Iterable<TrendingCreator> creators) {
    preload(creators.map(CreatorProfileSnapshot.fromTrendingCreator));
  }

  /// Fetches user docs quietly for upcoming profile taps.
  void warmProfilesInBackground(Iterable<String> userIds) {
    for (final String rawId in userIds) {
      final String userId = rawId.trim();
      if (userId.isEmpty || get(userId) != null || _warmInFlight.contains(userId)) {
        continue;
      }
      _warmInFlight.add(userId);
      unawaited(_warmSingleProfile(userId));
    }
  }

  Future<void> _warmSingleProfile(String userId) async {
    try {
      final Map<String, dynamic>? data =
          await PublicProfileFirestore.instance.getProfileMap(userId);
      if (data == null) {
        return;
      }
      setFromUserData(userId, data);
    } finally {
      _warmInFlight.remove(userId);
    }
  }

  CreatorProfileSnapshot? resolveForNavigation({
    String? userId,
    CreatorProfileSnapshot? initialCreator,
  }) {
    if (initialCreator != null && initialCreator.hasDisplayIdentity) {
      set(initialCreator.creatorId, initialCreator);
      return initialCreator;
    }
    if (userId == null || userId.trim().isEmpty) {
      return null;
    }
    return get(userId.trim());
  }

  void _touch(String key) {
    _lruKeys.remove(key);
    _lruKeys.add(key);
  }

  void _evictIfNeeded() {
    while (_lruKeys.length > _maxEntries) {
      final String oldest = _lruKeys.removeAt(0);
      _cache.remove(oldest);
    }
  }
}
