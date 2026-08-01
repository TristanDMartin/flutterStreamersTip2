import 'user_profile_firestore.dart';

/// Classifies `users/{uid}` Firestore fields so likes/gamification/stats
/// updates do not rebuild profile, favorites, or avatar caches.
abstract final class ProfileUserDocFields {
  static const Set<String> ignored = <String>{
    'status',
    'userStatus',
    'onlineStatus',
    'isOnline',
    'lastSeen',
    'lastActive',
    'updatedAt',
    'liked_videos',
    'likedVideos',
    'stats',
    'tippyCredits',
    'onboarding',
    'progressionSummary',
    'gamification',
    'contentPlanProfileCalendarEvents',
    'contentPlanStreamerCalendarEvents',
    'contentPlanCalendarEvents',
    'recentSearches',
    'calendarEvents',
    'totalLikes',
    'totalViews',
    'totalComments',
    'totalShares',
    'privacy',
    'hashtags',
    'connectedPlatforms',
    UserProfileFirestore.platformsField,
    'reconciliationDetails',
    'lastPostCountReconciliation',
    'postCount',
    'postsCount',
    'videoCount',
    'videos',
    'creatorVideos',
  };

  static const Set<String> avatarKeys = <String>{
    'avatarURL',
    'avatarUrl',
    'photoURL',
    'photoUrl',
    'profileImageUrl',
    'profile_image_url',
  };

  /// Fields that should rebuild profile header / shell UI when changed.
  static const Set<String> profileShellKeys = <String>{
    'displayName',
    'username',
    'bio',
    'aiSelf',
    'followersCount',
    'followerCount',
    'followingCount',
  };

  static List<String> changedRelevantFields({
    required Map<String, dynamic>? before,
    required Map<String, dynamic> after,
  }) {
    if (before == null) {
      return after.keys
          .where((String key) => !ignored.contains(key))
          .toList(growable: false);
    }
    final Set<String> keys = <String>{...before.keys, ...after.keys};
    final List<String> changed = <String>[];
    for (final String key in keys) {
      if (ignored.contains(key)) {
        continue;
      }
      if (before[key] != after[key]) {
        changed.add(key);
      }
    }
    return changed;
  }

  static bool affectsAvatar(Iterable<String> changedFields) {
    for (final String field in changedFields) {
      if (avatarKeys.contains(field)) {
        return true;
      }
    }
    return false;
  }

  static bool affectsProfileShell(Iterable<String> changedFields) {
    for (final String field in changedFields) {
      if (profileShellKeys.contains(field)) {
        return true;
      }
    }
    return false;
  }

  static bool hasOnlyIgnoredChanges({
    required Map<String, dynamic>? before,
    required Map<String, dynamic> after,
  }) {
    return changedRelevantFields(before: before, after: after).isEmpty;
  }
}
