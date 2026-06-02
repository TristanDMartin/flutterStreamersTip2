import 'dart:async';
import 'package:streamers_tip/utils/secure_log.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../models/home_video.dart';
import '../services/global_playback_manager.dart';
import '../services/performance_service.dart';
import '../utils/safe_video_controller.dart';
import '../utils/video_url_resolver.dart';

class AndroidMedia3HomePlayer extends StatefulWidget {
  const AndroidMedia3HomePlayer({
    super.key,
    required this.video,
    required this.isActive,
    required this.ownerKey,
    this.onFirstFrame,
    this.onError,
    this.onPlaySuccess,
  });

  final HomeVideo? video;
  final bool isActive;
  final String ownerKey;
  final VoidCallback? onFirstFrame;
  final ValueChanged<String>? onError;
  final VoidCallback? onPlaySuccess;

  static bool get isEnabled {
    return defaultTargetPlatform == TargetPlatform.android &&
        const bool.fromEnvironment(
          'STREAMERSTIP_ANDROID_MEDIA3_HOME',
          defaultValue: false,
        );
  }

  @override
  State<AndroidMedia3HomePlayer> createState() =>
      _AndroidMedia3HomePlayerState();
}

class _AndroidMedia3HomePlayerState extends State<AndroidMedia3HomePlayer> {
  _PersistentMedia3Controller? _controller;
  StreamSubscription<String?>? _activeOwnerSubscription;
  StreamSubscription<bool>? _blockedSubscription;
  String? _currentUrl;
  String? _currentVideoId;
  bool _hasPlayedCurrent = false;

  @override
  void initState() {
    super.initState();
    _activeOwnerSubscription =
        GlobalPlaybackManager.instance.activeOwnerStream.listen((_) {
      _syncPlayback('activeOwner');
    });
    _blockedSubscription =
        GlobalPlaybackManager.instance.playbackBlockedStream.listen((_) {
      _syncPlayback('blocked');
    });
  }

  @override
  void didUpdateWidget(covariant AndroidMedia3HomePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.video?.id != widget.video?.id) {
      _hasPlayedCurrent = false;
    }
    _syncPlayback('didUpdateWidget');
  }

  @override
  void dispose() {
    _activeOwnerSubscription?.cancel();
    _blockedSubscription?.cancel();
    unawaited(_controller?.dispose());
    super.dispose();
  }

  void _onPlatformViewCreated(int id) {
    final controller = _PersistentMedia3Controller(id);
    controller.onFirstFrame = () {
      if (!mounted) return;
      widget.onFirstFrame?.call();
      final video = widget.video;
      if (video != null) {
        GlobalPlaybackManager.instance.noteFirstFrameRendered(
          video.id,
          controllerId: id,
          size: Size.zero,
        );
      }
    };
    controller.onError = (String message) {
      if (!mounted) return;
      widget.onError?.call(message);
    };
    _controller = controller;
    _syncPlayback('platformViewCreated');
  }

  Future<void> _syncPlayback(String reason) async {
    if (!mounted) return;
    final controller = _controller;
    final video = widget.video;
    if (controller == null || video == null) return;

    final url = resolveReadyPlaybackUrl({
      'canonicalPlaybackUrl': video.videoURL,
      'status': video.status,
      'isReadyForFeed': true,
    });
    if (url == null) {
      await controller.setMuted(true);
      await controller.pause();
      widget.onError?.call('missing_playback_url');
      return;
    }

    final playbackManager = GlobalPlaybackManager.instance;
    if (widget.isActive && playbackManager.activeOwner == null) {
      playbackManager.setActiveOwner(widget.ownerKey);
    }

    final activeOwner = playbackManager.activeOwner;
    final ownerCanPlay = activeOwner != null &&
        (widget.ownerKey == activeOwner ||
            widget.ownerKey.startsWith('$activeOwner/'));
    final canPlay =
        widget.isActive && ownerCanPlay && !playbackManager.isPlaybackBlocked;

    if (widget.isActive) {
      playbackManager.setDesiredFocus(video.id, widget.ownerKey);
    }

    final sourceChanged = _currentUrl != url || _currentVideoId != video.id;
    _currentUrl = url;
    _currentVideoId = video.id;

    await controller.setSource(url, autoplay: canPlay);
    if (!canPlay) {
      await controller.setMuted(true);
      await controller.pause();
      secureLog('⏸️ PersistentMedia3Home: paused ${video.id} ($reason)');
      return;
    }

    await controller.setMuted(false);
    await controller.play();
    if (!_hasPlayedCurrent || sourceChanged) {
      _hasPlayedCurrent = true;
      widget.onPlaySuccess?.call();
      PerformanceService().trackVideoPlayback(video.id, PlaybackEvent.play);
    }
    secureLog('✅ PersistentMedia3Home: playing ${video.id} ($reason)');
  }

  @override
  Widget build(BuildContext context) {
    if (!AndroidMedia3HomePlayer.isEnabled) {
      return const SizedBox.shrink();
    }
    return AndroidView(
      key: const ValueKey<String>('PersistentMedia3HomePlayer'),
      viewType: 'streamers_tip/media3_player',
      hitTestBehavior: PlatformViewHitTestBehavior.transparent,
      creationParamsCodec: const StandardMessageCodec(),
      creationParams: const <String, Object?>{
        'autoplay': false,
        'muted': true,
        'loop': true,
      },
      onPlatformViewCreated: _onPlatformViewCreated,
    );
  }
}

class _PersistentMedia3Controller {
  _PersistentMedia3Controller(int viewId)
      : _channel = MethodChannel('streamers_tip/media3_player_$viewId') {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  final MethodChannel _channel;
  VoidCallback? onFirstFrame;
  ValueChanged<String>? onError;
  bool _disposed = false;

  Future<void> setSource(String url, {required bool autoplay}) {
    return _invoke('setSource', <String, Object?>{
      'url': url,
      'autoplay': autoplay,
    });
  }

  Future<void> play() => _invoke('play');

  Future<void> pause() => _invoke('pause');

  Future<void> setMuted(bool muted) {
    return _invoke('setMuted', <String, Object?>{'muted': muted});
  }

  Future<void> dispose() async {
    _disposed = true;
    _channel.setMethodCallHandler(null);
  }

  Future<void> _invoke(String method, [Object? arguments]) async {
    if (_disposed) return;
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } catch (e, st) {
      logPlaybackSwallowed('persistent_android_media3.$method', e, st);
    }
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    if (_disposed || call.method != 'event') return;
    final args = call.arguments;
    if (args is! Map) return;
    switch (args['type']) {
      case 'firstFrame':
        onFirstFrame?.call();
        break;
      case 'error':
        onError?.call('${args['message'] ?? 'Media3 playback error'}');
        break;
    }
  }
}
