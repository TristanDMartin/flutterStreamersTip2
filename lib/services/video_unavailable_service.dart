import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import '../models/home_video.dart';
import '../models/user.dart' as app_user;
import '../utils/home_video_from_firestore.dart';
import '../utils/video_document_rules.dart';
import 'admin_service.dart';

class VideoUnavailableContext {
  const VideoUnavailableContext({
    required this.videoId,
    required this.isDeleted,
    required this.canDelete,
    this.creatorId,
    this.creatorName,
    this.creatorUsername,
    this.category,
    this.uploadedAt,
    this.moreFromCreator = const <HomeVideo>[],
  });

  final String videoId;
  final bool isDeleted;
  final bool canDelete;
  final String? creatorId;
  final String? creatorName;
  final String? creatorUsername;
  final String? category;
  final DateTime? uploadedAt;
  final List<HomeVideo> moreFromCreator;
}

class VideoUnavailableService {
  VideoUnavailableService._({
    FirebaseFirestore? firestore,
    firebase_auth.FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? firebase_auth.FirebaseAuth.instance;

  static final VideoUnavailableService instance = VideoUnavailableService._();

  final FirebaseFirestore _firestore;
  final firebase_auth.FirebaseAuth _auth;

  Future<VideoUnavailableContext?> loadContext(String videoId) async {
    if (videoId.trim().isEmpty) {
      return null;
    }
    final DocumentSnapshot<Map<String, dynamic>> doc =
        await _firestore.collection('videos').doc(videoId).get();
    if (!doc.exists) {
      return null;
    }
    final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
    final String? creatorId = _readCreatorId(data);
    final bool isDeleted = !isVideoVisibleInFeed(data);
    final firebase_auth.User? currentUser = _auth.currentUser;
    final bool isOwner = creatorId != null &&
        currentUser != null &&
        creatorId == currentUser.uid;
    final bool isAdmin = currentUser != null
        ? await AdminService.instance.hasAdminUiAccess()
        : false;

    final List<HomeVideo> moreFromCreator = creatorId == null
        ? const <HomeVideo>[]
        : await _loadMoreFromCreator(
            creatorId: creatorId,
            excludeVideoId: videoId,
          );

    return VideoUnavailableContext(
      videoId: videoId,
      isDeleted: isDeleted,
      canDelete: isOwner || isAdmin,
      creatorId: creatorId,
      creatorName: _readCreatorName(data),
      creatorUsername: _readCreatorUsername(data),
      category: _readCategory(data),
      uploadedAt: _readTimestamp(data['createdAt']),
      moreFromCreator: moreFromCreator,
    );
  }

  Future<List<HomeVideo>> _loadMoreFromCreator({
    required String creatorId,
    required String excludeVideoId,
  }) async {
    final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> byId =
        <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final String field in <String>[
      'userId',
      'creatorId',
      'creator_id',
    ]) {
      final QuerySnapshot<Map<String, dynamic>> snap = await _firestore
          .collection('videos')
          .where(field, isEqualTo: creatorId)
          .limit(12)
          .get();
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in snap.docs) {
        byId[doc.id] = doc;
      }
    }

    final List<HomeVideo> videos = <HomeVideo>[];
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in byId.values) {
      if (doc.id == excludeVideoId) {
        continue;
      }
      final Map<String, dynamic> data = Map<String, dynamic>.from(doc.data());
      if (!isVideoVisibleInFeed(data)) {
        continue;
      }
      final String? visibility = data['visibility'] as String?;
      final String? privacy = data['privacy'] as String?;
      final bool isPublic = visibility == 'public' ||
          privacy == 'Everyone' ||
          privacy == 'Public';
      if (!isPublic) {
        continue;
      }
      data['videoId'] = doc.id;
      final HomeVideo? video = await loadHomeVideoForPlayback(doc.id);
      if (video != null) {
        videos.add(video);
      }
      if (videos.length >= 6) {
        break;
      }
    }
    return videos;
  }

  String? _readCreatorId(Map<String, dynamic> data) {
    for (final String key in <String>[
      'userId',
      'creatorId',
      'creator_id',
    ]) {
      final Object? value = data[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  String? _readCreatorName(Map<String, dynamic> data) {
    for (final String key in <String>[
      'creatorDisplayName',
      'creatorName',
      'displayName',
    ]) {
      final Object? value = data[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  String? _readCreatorUsername(Map<String, dynamic> data) {
    for (final String key in <String>['creatorUsername', 'username']) {
      final Object? value = data[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  String? _readCategory(Map<String, dynamic> data) {
    for (final String key in <String>[
      'category',
      'categoryId',
      'category_id'
    ]) {
      final Object? value = data[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  DateTime? _readTimestamp(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return null;
  }

  app_user.User buildCreatorUser(VideoUnavailableContext context) {
    return app_user.User(
      id: context.creatorId ?? '',
      username: context.creatorUsername ?? 'creator',
      displayName: context.creatorName ?? 'Creator',
      avatarURL: null,
      bio: '',
      onlineStatus: 'offline',
      hashtags: const <String>[],
      followerCount: 0,
      followingCount: 0,
      postCount: 0,
    );
  }
}
