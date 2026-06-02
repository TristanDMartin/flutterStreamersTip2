import 'package:flutter/services.dart';

import '../../../utils/safe_video_controller.dart';

class AndroidMedia3HomeController {
  AndroidMedia3HomeController(int viewId)
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
    if (_disposed) {
      return;
    }
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } catch (e, st) {
      logPlaybackSwallowed('android_media3_home.$method', e, st);
    }
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    if (_disposed || call.method != 'event') {
      return;
    }
    final Object? args = call.arguments;
    if (args is! Map) {
      return;
    }
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
