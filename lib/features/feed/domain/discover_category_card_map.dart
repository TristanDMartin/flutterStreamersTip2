import 'package:flutter/foundation.dart';

import '../../../models/home_video.dart';
import '../../../models/user.dart';
import '../../../models/video_thumbnails.dart';
import '../../../services/real_user_data_service.dart';
import 'discover_eligible_videos.dart';

/// Grid card maps with the same display fields as [_fullCategoryVideoMap].
class DiscoverCategoryCardMap {
  const DiscoverCategoryCardMap._();

  static Future<List<HomeVideo>> hydrateCreators(List<HomeVideo> videos) async {
    final RealUserDataService users = RealUserDataService();
    final Set<String> pendingIds = <String>{};
    for (final HomeVideo video in videos) {
      if (_needsCreatorHydration(video.creator)) {
        pendingIds.add(video.creator.id);
      }
    }
    if (pendingIds.isEmpty) {
      return videos;
    }
    final Map<String, User> resolved = <String, User>{};
    for (final String userId in pendingIds) {
      try {
        final User? user = await users.getUserById(userId);
        if (user != null && !_needsCreatorHydration(user)) {
          resolved[userId] = user;
        }
      } catch (_) {
        continue;
      }
    }
    if (resolved.isEmpty) {
      return videos;
    }
    return videos
        .map((HomeVideo video) {
          final User? user = resolved[video.creator.id];
          if (user == null) {
            return video;
          }
          return video.copyWith(creator: user);
        })
        .toList(growable: false);
  }

  static Future<List<Map<String, dynamic>>> buildFromHomeVideos(
    List<HomeVideo> videos,
  ) async {
    final List<HomeVideo> hydrated = await hydrateCreators(videos);
    return hydrated.map(fromHomeVideo).toList(growable: false);
  }

  static Map<String, dynamic> fromHomeVideo(HomeVideo video) {
    final String thumbnailUrl = resolveDiscoverThumbnailUrl(video);
    final String playbackUrl = video.videoURL.trim();
    final String? muxPlaybackId = muxPlaybackIdFromPlaybackUrl(playbackUrl);
    final String creatorUsername = resolveDiscoverCreatorUsername(video);
    final String creatorAvatar = resolveDiscoverCreatorAvatar(video);
    final String creatorDisplayName = video.creator.displayName.trim().isNotEmpty
        ? video.creator.displayName.trim()
        : creatorUsername;
    final Map<String, dynamic> data = <String, dynamic>{
      ...homeVideoToFirestoreShape(video),
      'thumbnailUrl': thumbnailUrl,
      'thumbnailURL': thumbnailUrl,
      'thumbnail': thumbnailUrl,
      'muxPlaybackId': muxPlaybackId ?? '',
      'playbackId': muxPlaybackId ?? '',
      'videoUrl': playbackUrl,
      'videoURL': playbackUrl,
      'hlsUrl': playbackUrl,
      'creatorUsername': creatorUsername,
      'creator_username': creatorUsername,
      'username': creatorUsername,
      'creatorDisplayName': creatorDisplayName,
      'creator_display_name': creatorDisplayName,
      'displayName': creatorDisplayName,
      'creatorAvatar': creatorAvatar,
      'creator_avatar_url': creatorAvatar,
      'avatarURL': creatorAvatar,
      'likes': video.likes,
      'likeCount': video.likes,
      'comments': video.comments,
      'commentCount': video.comments,
      'views': video.views,
      'viewCount': video.views,
      'duration': video.duration,
    };
    final Map<String, dynamic> card = <String, dynamic>{
      'id': video.id,
      'docId': video.id,
      'videoId': video.id,
      'userId': video.creator.id,
      'creatorId': video.creator.id,
      'caption': video.caption,
      'title': video.caption,
      'muxPlaybackId': muxPlaybackId ?? '',
      'hlsUrl': playbackUrl,
      'videoUrl': playbackUrl,
      'videoURL': playbackUrl,
      'thumbnailUrl': thumbnailUrl,
      'thumbnail': thumbnailUrl,
      'thumbnailURL': thumbnailUrl,
      'status': video.status,
      'categoryId': data['categoryId'],
      'category': data['category'],
      'categoryName': data['categoryName'],
      'likeCount': video.likes,
      'likes': video.likes,
      'comments': video.comments,
      'commentCount': video.comments,
      'views': video.views,
      'viewCount': video.views,
      'duration': video.duration,
      'creator': creatorDisplayName,
      'creatorUsername': creatorUsername,
      'creatorDisplayName': creatorDisplayName,
      'creatorAvatar': creatorAvatar,
      'isLiked': video.isLiked,
      'isFavorited': video.isFavorited,
      'data': data,
    };
    logDiscoverCardDebug(video, card);
    return card;
  }
}

bool _needsCreatorHydration(User creator) {
  final String username = creator.username.trim().toLowerCase();
  if (username.isEmpty ||
      username == 'creator' ||
      username == 'unknown') {
    return true;
  }
  return false;
}

String resolveDiscoverThumbnailUrl(HomeVideo video) {
  final String legacy = video.thumbnailURL?.trim() ?? '';
  if (legacy.isNotEmpty) {
    return legacy;
  }
  final VideoThumbnails? thumbs = video.thumbnails;
  if (thumbs != null) {
    final String? largest = thumbs.getLargestUrl();
    if (largest != null && largest.trim().isNotEmpty) {
      return largest.trim();
    }
    final String? size720 = thumbs.getUrlForSize(720) ??
        thumbs.getUrlForSize(540) ??
        thumbs.getUrlForSize(360);
    if (size720 != null && size720.trim().isNotEmpty) {
      return size720.trim();
    }
  }
  final String? muxId = muxPlaybackIdFromPlaybackUrl(video.videoURL);
  if (muxId != null && muxId.isNotEmpty) {
    return 'https://image.mux.com/$muxId/thumbnail.jpg?width=720&time=0';
  }
  return '';
}

String? muxPlaybackIdFromPlaybackUrl(String playbackUrl) {
  final String trimmed = playbackUrl.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  final RegExp muxPattern = RegExp(
    r'stream\.mux\.com/([A-Za-z0-9]+)',
    caseSensitive: false,
  );
  final RegExpMatch? match = muxPattern.firstMatch(trimmed);
  return match?.group(1);
}

String resolveDiscoverCreatorUsername(HomeVideo video) {
  final String username = video.creator.username.trim();
  if (username.isNotEmpty && !_needsCreatorHydration(video.creator)) {
    return username;
  }
  final String displayName = video.creator.displayName.trim();
  if (displayName.isNotEmpty &&
      displayName.toLowerCase() != 'creator' &&
      displayName.toLowerCase() != 'unknown') {
    return displayName.replaceAll(' ', '').toLowerCase();
  }
  return username.isNotEmpty ? username : '';
}

String resolveDiscoverCreatorAvatar(HomeVideo video) {
  final String? avatar = video.creator.avatarURL?.trim();
  if (avatar != null && avatar.isNotEmpty) {
    return avatar;
  }
  return '';
}

void logDiscoverCardDebug(HomeVideo video, Map<String, dynamic> card) {
  if (!kDebugMode) {
    return;
  }
  final Map<String, dynamic> raw =
      card['data'] as Map<String, dynamic>? ?? card;
  debugPrint(
    'DISCOVER_CARD '
    'video=${video.id} '
    'thumbnail=${raw['thumbnailUrl']} '
    'username=${raw['creatorUsername']} '
    'playback=${raw['videoUrl'] ?? raw['videoURL']}',
  );
}
