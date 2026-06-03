import 'package:flutter/material.dart';

import '../services/global_playback_manager.dart';

/// Pauses and blocks all in-app video playback for non-playing screens.
abstract final class PlaybackRouteSuppression {
  static void suppress({required String reason}) {
    final GlobalPlaybackManager manager = GlobalPlaybackManager.instance;
    manager.block(reason: reason);
    manager.pauseAll();
  }
}

/// Wraps a full-screen widget so home feed audio cannot resume underneath.
class PlaybackMutedScope extends StatefulWidget {
  const PlaybackMutedScope({
    super.key,
    required this.reason,
    required this.child,
  });

  final String reason;
  final Widget child;

  @override
  State<PlaybackMutedScope> createState() => _PlaybackMutedScopeState();
}

class _PlaybackMutedScopeState extends State<PlaybackMutedScope> {
  @override
  void initState() {
    super.initState();
    PlaybackRouteSuppression.suppress(reason: widget.reason);
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
