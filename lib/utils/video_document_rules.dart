import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/home_video.dart';

/// Feed-visible statuses (legacy `active`; target is `ready`).
const Set<String> kVideoVisibleInFeedStatuses = {
  'ready',
  'published',
  'active',
};

/// Mirror of web `isVideoVisibleInFeed` — use for every Firestore/API list.
bool isVideoVisibleInFeed(Map<String, dynamic>? data) {
  if (data == null) {
    return false;
  }
  if (data['isDeleted'] == true) {
    return false;
  }
  if (data['status'] == 'deleted') {
    return false;
  }
  if (data['deletedAt'] != null) {
    return false;
  }
  final String status = (data['status'] as String? ?? '').toLowerCase();
  return kVideoVisibleInFeedStatuses.contains(status);
}

/// [HomeVideo] rows built in-memory (no `deletedAt` on model; `status` is set).
bool isHomeVideoVisibleInFeed(HomeVideo video) {
  return isVideoVisibleInFeed(<String, dynamic>{'status': video.status});
}

bool isVideoDeletedFromFirestore(Map<String, dynamic> data) {
  if (data['isDeleted'] == true || data['deleted'] == true) {
    return true;
  }
  final String? status = (data['status'] as String?)?.toLowerCase();
  if (status == 'deleted' || status == 'removed') {
    return true;
  }
  final Object? deletedAt = data['deletedAt'];
  if (deletedAt is Timestamp || deletedAt is DateTime) {
    return true;
  }
  return false;
}

/// Home/discover public feed: visible status + not deleted + feed-ready flags.
bool isVideoEligibleForPublicFeed(Map<String, dynamic> data) {
  if (!isVideoVisibleInFeed(data)) {
    return false;
  }
  if (data['visible'] == false || data['isReadyForFeed'] == false) {
    return false;
  }
  return true;
}
