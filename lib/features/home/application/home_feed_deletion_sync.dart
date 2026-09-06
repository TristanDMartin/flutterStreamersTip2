import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../models/home_video.dart';
import '../../../utils/home_video_playback.dart';
import '../../../utils/video_document_rules.dart';

/// TikTok-style: painted Home cards leave as soon as Firestore tombstones them.
class HomeFeedDeletionSync {
  HomeFeedDeletionSync({
    FirebaseFirestore? firestore,
    required this.onVideosRemoved,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final void Function(Set<String> videoIds, String reason) onVideosRemoved;

  final Map<String, StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>
      _subscriptions =
      <String, StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>{};

  void syncPaintedVideos(List<HomeVideo> videos, {int maxListen = 24}) {
    final List<HomeVideo> targets = videos
        .where((HomeVideo video) => !isHomeVideoOwnerPendingLocal(video))
        .take(maxListen)
        .toList(growable: false);
    final Set<String> keepIds =
        targets.map((HomeVideo video) => video.id).toSet();

    for (final String id in _subscriptions.keys.toList(growable: false)) {
      if (!keepIds.contains(id)) {
        unawaited(_subscriptions.remove(id)?.cancel());
      }
    }

    for (final HomeVideo video in targets) {
      if (_subscriptions.containsKey(video.id)) {
        continue;
      }
      _subscriptions[video.id] = _firestore
          .collection('videos')
          .doc(video.id)
          .snapshots()
          .listen((DocumentSnapshot<Map<String, dynamic>> snapshot) {
        final Map<String, dynamic>? data = snapshot.data();
        final String? reason = _removalReason(
          docExists: snapshot.exists,
          data: data,
        );
        if (reason == null) {
          return;
        }
        unawaited(_subscriptions.remove(video.id)?.cancel());
        if (kDebugMode) {
          debugPrint(
            'HOME_FEED_DELETE_SYNC remove videoId=${video.id} reason=$reason',
          );
        }
        onVideosRemoved(<String>{video.id}, reason);
      });
    }
  }

  static String? _removalReason({
    required bool docExists,
    required Map<String, dynamic>? data,
  }) {
    if (!docExists || data == null) {
      return 'missing_doc';
    }
    if (isVideoDeletedFromFirestore(data)) {
      return 'tombstone';
    }
    if (isVideoOwnerFeedTombstoned(data)) {
      return 'owner_tombstone';
    }
    if (!isVideoVisibleInFeed(data) || !isVideoEligibleForPublicFeed(data)) {
      return 'feed_ineligible';
    }
    return null;
  }

  /// Test seam for [_removalReason].
  @visibleForTesting
  static String? removalReasonForTest({
    required bool docExists,
    required Map<String, dynamic>? data,
  }) {
    return _removalReason(docExists: docExists, data: data);
  }

  void dispose() {
    for (final StreamSubscription<DocumentSnapshot<Map<String, dynamic>>> sub
        in _subscriptions.values) {
      unawaited(sub.cancel());
    }
    _subscriptions.clear();
  }
}
