import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/home_video.dart';
import '../models/user.dart';
import '../models/user_count_fields.dart';
import 'avatar_url_resolver.dart';
import 'firestore_map_readers.dart';
import 'swallow_non_fatal.dart';
import 'video_caption_resolver.dart';
import 'video_document_rules.dart';
import 'video_url_resolver.dart';

/// Loads a non-deleted `videos/{id}` document for full-screen playback.
Future<HomeVideo?> loadHomeVideoForPlayback(String videoId) async {
  if (videoId.isEmpty) {
    return null;
  }
  final DocumentSnapshot<Map<String, dynamic>> doc =
      await FirebaseFirestore.instance.collection('videos').doc(videoId).get();
  if (!doc.exists) {
    return null;
  }
  final Map<String, dynamic> data = Map<String, dynamic>.from(doc.data()!);
  data['id'] = videoId;
  data['videoId'] = videoId;
  if (!isVideoVisibleInFeed(data)) {
    return null;
  }
  return _buildHomeVideoFromDoc(data, videoId);
}

Map<String, dynamic>? _nestedCreator(Map<String, dynamic> data) {
  final Object? raw = data['creator'];
  if (raw is Map<String, dynamic>) {
    return raw;
  }
  if (raw is Map) {
    return Map<String, dynamic>.from(raw);
  }
  return null;
}

User _creatorFromVideoDoc(Map<String, dynamic> data, String? ownerId) {
  final Map<String, dynamic>? nested = _nestedCreator(data);
  final String id = (ownerId ?? '').trim();
  final String displayName = firstNonEmptyStringFromValues(<Object?>[
        nested?['displayName'],
        nested?['name'],
        data['creatorDisplayName'],
        data['creatorName'],
        data['displayName'],
        data['channelName'],
        data['authorName'],
      ]) ??
      (id.isNotEmpty ? 'Creator' : 'Unknown');
  final String username = firstNonEmptyStringFromValues(<Object?>[
        nested?['username'],
        nested?['handle'],
        data['creatorUsername'],
        data['username'],
        data['creator'],
        data['channelUsername'],
      ]) ??
      (id.isNotEmpty ? 'creator' : 'unknown');
  final String? avatarUrl = firstNonEmptyStringFromValues(<Object?>[
    nested?['avatarURL'],
    nested?['avatarUrl'],
    nested?['photoURL'],
    data['userAvatarUrl'],
    data['creatorAvatarUrl'],
    data['avatarURL'],
  ]);
  return User(
    id: id,
    displayName: displayName,
    username: username,
    avatarURL: avatarUrl,
    bio: data['bio'] as String? ?? '',
    onlineStatus: data['onlineStatus'] as String? ?? 'offline',
    hashtags:
        (data['hashtags'] as List<dynamic>?)?.cast<String>() ?? <String>[],
    followerCount: UserCountFields.readFollowersCount(data),
    followingCount: UserCountFields.readFollowingCount(data),
    postCount: (data['postCount'] as num?)?.toInt() ?? 0,
  );
}

Future<User?> _loadUserProfile(String uid) async {
  if (uid.isEmpty) {
    return null;
  }
  try {
    final DocumentSnapshot<Map<String, dynamic>> snap =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (!snap.exists) {
      return null;
    }
    final Map<String, dynamic> m = snap.data() ?? <String, dynamic>{};
    return User.fromMap(<String, dynamic>{...m, 'id': uid, 'uid': uid});
  } catch (_) {
    return null;
  }
}

Future<String?> _resolvePlaybackOwnerId(
  Map<String, dynamic> data,
  String videoId,
) async {
  final String? fromFields = getOwnerId(data);
  if (fromFields != null && fromFields.isNotEmpty) {
    return fromFields;
  }
  final String? fromDocId = inferOwnerIdFromVideoDocumentId(videoId);
  if (fromDocId != null && fromDocId.isNotEmpty) {
    return fromDocId;
  }
  final Set<String> usernameCandidates = <String>{
    (data['creatorUsername'] as String?)?.trim() ?? '',
    (data['username'] as String?)?.trim() ?? '',
    if (data['creator'] is String) (data['creator'] as String).trim() else '',
    (data['handle'] as String?)?.trim() ?? '',
  }..removeWhere((String v) => v.isEmpty);
  for (final String username in usernameCandidates) {
    try {
      final DocumentSnapshot<Map<String, dynamic>> snap =
          await FirebaseFirestore.instance
              .collection('usernames')
              .doc(username)
              .get();
      final String? uid = snap.data()?['uid'] as String?;
      final String? trimmed = uid?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        return trimmed;
      }
    } catch (e, st) {
      swallowNonFatal('resolveCreatorUidFromUsername', e, st);
    }
  }
  return null;
}

Future<HomeVideo> _buildHomeVideoFromDoc(
  Map<String, dynamic> data,
  String videoId,
) async {
  final String? ownerId = await _resolvePlaybackOwnerId(data, videoId);
  User creator = _creatorFromVideoDoc(data, ownerId);
  if (ownerId != null && ownerId.isNotEmpty) {
    final User? profile = await _loadUserProfile(ownerId);
    if (profile != null) {
      final bool profileHasName = profile.displayName.trim().isNotEmpty ||
          profile.username.trim().isNotEmpty;
      if (profileHasName) {
        final String? profileAvatar = resolveAvatarUrl(profile.toMap());
        creator = User(
          id: ownerId,
          username: profile.username.trim().isNotEmpty
              ? profile.username
              : creator.username,
          displayName: profile.displayName.trim().isNotEmpty
              ? profile.displayName
              : creator.displayName,
          bio: profile.bio ?? creator.bio,
          avatarURL: profileAvatar ?? creator.avatarURL,
          onlineStatus: profile.onlineStatus,
          hashtags:
              profile.hashtags.isNotEmpty ? profile.hashtags : creator.hashtags,
          followerCount: profile.followerCount,
          followingCount: profile.followingCount,
          postCount: profile.postCount,
          calendarEvents: profile.calendarEvents,
          privacy: profile.privacy,
          pinnedVideoIds: profile.pinnedVideoIds,
          role: profile.role,
        );
      }
    }
  }
  final String? readyPlaybackUrl = resolveReadyPlaybackUrl(data);
  return HomeVideo(
    id: videoId,
    creator: creator,
    videoURL: readyPlaybackUrl ?? '',
    thumbnailURL:
        data['thumbnailUrl'] as String? ?? data['thumbnailURL'] as String?,
    likes: (data['likeCount'] as num?)?.toInt() ??
        (data['likes'] as num?)?.toInt() ??
        0,
    comments: (data['commentCount'] as num?)?.toInt() ??
        (data['comments'] as num?)?.toInt() ??
        0,
    views: (data['viewCount'] as num?)?.toInt() ??
        (data['views'] as num?)?.toInt() ??
        0,
    caption: resolveVideoCaptionFromFirestoreData(data),
    overlayCaption: resolveVideoOverlayCaptionFromFirestoreData(data),
    categoryId: data['category'] as String? ??
        data['categoryId'] as String? ??
        'general',
    createdAt:
        data['timestamp'] as Timestamp? ?? data['createdAt'] as Timestamp?,
    status: data['status'] as String? ?? 'processing',
  );
}
