import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'category_schema.dart';
import 'video_caption_resolver.dart';
import 'video_url_resolver.dart';

const Set<String> kClientVideoMetadataBackfillFields = <String>{
  'ownerId',
  'userId',
  'creatorId',
  'creator_id',
  'privacy',
  'visibility',
  'caption',
  'category',
  'categoryId',
  'category_id',
  'categoryName',
  'categories',
  'updatedAt',
};

/// Client may only backfill docs the signed-in user owns (rules-enforced).
bool canClientPersistVideoMetadataBackfill({
  required String videoId,
  required Map<String, dynamic> data,
}) {
  final String? authUid = FirebaseAuth.instance.currentUser?.uid;
  if (authUid == null || authUid.isEmpty) {
    return false;
  }
  final String? resolvedOwner =
      getOwnerId(data) ?? inferOwnerIdFromVideoDocumentId(videoId);
  if (resolvedOwner == null || resolvedOwner != authUid) {
    return false;
  }
  final String? existingOwner = getOwnerId(data);
  if (existingOwner != null && existingOwner != authUid) {
    return false;
  }
  return true;
}

const String kDefaultVideoPrivacy = 'Public';
const String kDefaultVideoVisibility = 'public';

/// True when canonical owner/privacy/visibility/caption fields need repair.
bool videoNeedsMetadataBackfill(
  Map<String, dynamic> data,
  String videoId,
) {
  final String? ownerId = getOwnerId(data);
  if (ownerId == null || ownerId.isEmpty) {
    return true;
  }
  if (data['ownerId'] == null) {
    return true;
  }
  if (data['creatorId'] == null || data['creator_id'] == null) {
    return true;
  }
  if (data['privacy'] == null) {
    return true;
  }
  if (data['visibility'] == null) {
    return true;
  }
  if (data['caption'] == null &&
      resolveVideoCaptionFromFirestoreData(data).isEmpty) {
    return true;
  }
  if (!readCanonicalCategoryFromVideo(data).isPopulated) {
    return true;
  }
  return false;
}

/// Builds a merge patch for legacy `videos/{id}` docs missing required fields.
Map<String, dynamic> buildVideoMetadataBackfillPatch(
  Map<String, dynamic> data,
  String videoId,
) {
  final Map<String, dynamic> patch = <String, dynamic>{};
  String? ownerId = getOwnerId(data);
  ownerId ??= inferOwnerIdFromVideoDocumentId(videoId);
  if (ownerId != null && ownerId.isNotEmpty) {
    if (data['ownerId'] == null) {
      patch['ownerId'] = ownerId;
    }
    if (data['userId'] == null) {
      patch['userId'] = ownerId;
    }
    if (data['creatorId'] == null) {
      patch['creatorId'] = ownerId;
    }
    if (data['creator_id'] == null) {
      patch['creator_id'] = ownerId;
    }
  }
  if (data['privacy'] == null) {
    patch['privacy'] = kDefaultVideoPrivacy;
  }
  if (data['visibility'] == null) {
    final String privacy = (patch['privacy'] ?? data['privacy'] ?? '')
        .toString()
        .toLowerCase();
    patch['visibility'] = switch (privacy) {
      'followers' || 'followers_only' => 'followers_only',
      'private' => 'private',
      _ => kDefaultVideoVisibility,
    };
  }
  if (data['caption'] == null &&
      resolveVideoCaptionFromFirestoreData(data).isEmpty) {
    patch['caption'] = '';
  }
  if (!readCanonicalCategoryFromVideo(data).isPopulated) {
    patch.addAll(buildCanonicalCategoryFields(kDefaultCategoryId));
  }
  return patch;
}

Future<bool> persistVideoMetadataBackfillIfNeeded({
  required FirebaseFirestore firestore,
  required String videoId,
  Map<String, dynamic>? cachedData,
}) async {
  if (videoId.isEmpty) {
    return false;
  }
  try {
    Map<String, dynamic> data = cachedData ?? <String, dynamic>{};
    if (cachedData == null) {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await firestore
          .collection('videos')
          .doc(videoId)
          .get(const GetOptions(source: Source.server));
      if (!snapshot.exists || snapshot.data() == null) {
        return false;
      }
      data = snapshot.data()!;
    }
    if (!videoNeedsMetadataBackfill(data, videoId)) {
      return false;
    }
    if (!canClientPersistVideoMetadataBackfill(
      videoId: videoId,
      data: data,
    )) {
      return false;
    }
    final Map<String, dynamic> patch =
        buildVideoMetadataBackfillPatch(data, videoId);
    if (patch.isEmpty) {
      return false;
    }
    patch['updatedAt'] = FieldValue.serverTimestamp();
    patch.removeWhere(
      (String key, Object? value) =>
          !kClientVideoMetadataBackfillFields.contains(key),
    );
    if (patch.isEmpty) {
      return false;
    }
    await firestore.collection('videos').doc(videoId).set(
          patch,
          SetOptions(merge: true),
        );
    if (kDebugMode) {
      debugPrint(
        '✅ persistVideoMetadataBackfillIfNeeded: repaired videos/$videoId '
        'fields=${patch.keys.join(', ')}',
      );
    }
    return true;
  } catch (e) {
    if (kDebugMode) {
      debugPrint(
        '⚠️ persistVideoMetadataBackfillIfNeeded: failed for videos/$videoId: $e',
      );
    }
    return false;
  }
}

void scheduleVideoMetadataBackfill({
  required FirebaseFirestore firestore,
  required String videoId,
  Map<String, dynamic>? cachedData,
}) {
  if (videoId.isEmpty) {
    return;
  }
  final Map<String, dynamic> data = cachedData ?? <String, dynamic>{};
  if (cachedData != null &&
      (!videoNeedsMetadataBackfill(data, videoId) ||
          !canClientPersistVideoMetadataBackfill(
            videoId: videoId,
            data: data,
          ))) {
    return;
  }
  Future<void>.delayed(const Duration(seconds: 2), () async {
    await persistVideoMetadataBackfillIfNeeded(
      firestore: firestore,
      videoId: videoId,
      cachedData: cachedData,
    );
  });
}
