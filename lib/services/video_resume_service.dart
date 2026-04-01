import 'dart:async';
import 'package:flutter/foundation.dart';

/// Playback state memo for resume logic
class PlaybackMemo {
  final Duration lastPlaybackPosition;
  final DateTime lastSeenAt;
  final Duration lastKnownDuration;
  final bool finished;

  const PlaybackMemo({
    required this.lastPlaybackPosition,
    required this.lastSeenAt,
    required this.lastKnownDuration,
    this.finished = false,
  });
}

/// Service to manage video resume logic with grace window
class VideoResumeService {
  static final VideoResumeService _instance = VideoResumeService._internal();
  factory VideoResumeService() => _instance;
  VideoResumeService._internal();

  static const Duration _resumeGraceWindow = Duration(minutes: 30);
  static const Duration _minimumResumePosition = Duration(seconds: 1);

  // Store playback state per video ID
  final Map<String, PlaybackMemo> _playbackState = {};

  // Debounce timer for page changes
  Timer? _debounceTimer;
  static const Duration _debounceDelay = Duration(milliseconds: 150);

  /// Save playback state when user leaves a video
  void onPageLeave(String postId, Duration position, Duration duration) {
    // Debounce rapid page changes
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDelay, () {
      final isFinished =
          position >= (duration - const Duration(milliseconds: 300));

      _playbackState[postId] = PlaybackMemo(
        lastPlaybackPosition: position,
        lastSeenAt: DateTime.now(),
        lastKnownDuration: duration,
        finished: isFinished,
      );

      debugPrint(
          '📝 VideoResumeService: Saved state for $postId - position: ${position.inSeconds}s, finished: $isFinished');
    });
  }

  /// Get target position when user returns to a video
  /// Returns null if should restart from beginning
  Future<Duration?> onPageEnter(String postId) async {
    await Future.delayed(_debounceDelay); // Wait for debounce to complete

    final memo = _playbackState[postId];
    if (memo == null) {
      debugPrint(
          '📝 VideoResumeService: No saved state for $postId - starting from beginning');
      return null;
    }

    final away = DateTime.now().difference(memo.lastSeenAt);
    final resumeAllowed = away <= _resumeGraceWindow && !memo.finished;

    if (resumeAllowed && memo.lastPlaybackPosition >= _minimumResumePosition) {
      debugPrint(
          '📝 VideoResumeService: Resuming $postId from ${memo.lastPlaybackPosition.inSeconds}s (away: ${away.inMilliseconds}ms)');
      return memo.lastPlaybackPosition;
    } else {
      debugPrint(
          '📝 VideoResumeService: Restarting $postId (away: ${away.inMilliseconds}ms, grace: ${_resumeGraceWindow.inMilliseconds}ms, finished: ${memo.finished}, position: ${memo.lastPlaybackPosition.inSeconds}s)');
      // Clear state if beyond grace window
      if (away > _resumeGraceWindow) {
        _playbackState.remove(postId);
      }
      return null;
    }
  }

  /// Clear saved state for a video (e.g., when video is removed from feed)
  void clearState(String postId) {
    _playbackState.remove(postId);
    debugPrint('📝 VideoResumeService: Cleared state for $postId');
  }

  /// Clear all saved states
  void clearAll() {
    _playbackState.clear();
    _debounceTimer?.cancel();
    debugPrint('📝 VideoResumeService: Cleared all states');
  }

  /// Dispose resources
  void dispose() {
    _debounceTimer?.cancel();
    _playbackState.clear();
  }
}
