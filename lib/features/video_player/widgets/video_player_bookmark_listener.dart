import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../bookmarks/models/video_bookmark_stream_event.dart';
import '../../../services/unified_bookmark_service.dart';

typedef VideoPlayerBookmarkChanged = void Function(bool isBookmarked);

/// Listens to [UnifiedBookmarkService] bookmark events for one video.
class VideoPlayerBookmarkListener {
  VideoPlayerBookmarkListener({
    required this.videoId,
    required this.initialIsBookmarked,
    required this.onBookmarkChanged,
  });

  final String videoId;
  final bool initialIsBookmarked;
  final VideoPlayerBookmarkChanged onBookmarkChanged;

  final UnifiedBookmarkService _service = UnifiedBookmarkService.instance;
  StreamSubscription<VideoBookmarkStreamEvent>? _subscription;

  UnifiedBookmarkService get service => _service;

  bool resolveInitialBookmarkState() {
    if (initialIsBookmarked) {
      return true;
    }
    return _service.isBookmarked(videoId);
  }

  void startListening() {
    _subscription = _service.eventStream.listen(_handleEvent);
  }

  void ensureUserInitialized() {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return;
    }
    unawaited(
      _service.initialize(currentUser.uid).then((_) {
        onBookmarkChanged(_service.isBookmarked(videoId));
      }).catchError((Object error) {
        if (kDebugMode) {
          debugPrint('⚠️ VideoPlayerBookmarkListener: init failed: $error');
        }
      }),
    );
  }

  void _handleEvent(VideoBookmarkStreamEvent event) {
    if (event.videoId != videoId) {
      return;
    }
    switch (event.type) {
      case VideoBookmarkStreamEventType.toggle:
      case VideoBookmarkStreamEventType.success:
        onBookmarkChanged(event.isBookmarked ?? false);
        break;
      case VideoBookmarkStreamEventType.error:
        onBookmarkChanged(_service.isBookmarked(videoId));
        break;
    }
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
