import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../utils/swallow_non_fatal.dart';

/// iOS native channel: reads/writes GIF bytes on the pasteboard so animated GIFs
/// are preserved (the `pasteboard` package uses PNG on iOS).
class GifPasteboardChannel {
  GifPasteboardChannel._();

  static const MethodChannel _channel =
      MethodChannel('streamers_tip/gif_pasteboard');

  static bool get _isIos => !kIsWeb && Platform.isIOS;

  static Future<Uint8List?> readGifBytes() async {
    if (!_isIos) {
      return null;
    }
    try {
      final Object? out = await _channel.invokeMethod<Object>('readGifBytes');
      if (out is Uint8List && out.isNotEmpty) {
        return out;
      }
      if (out is List<int> && out.isNotEmpty) {
        return Uint8List.fromList(out);
      }
      return null;
    } on PlatformException catch (_) {
      return null;
    }
  }

  static Future<void> writeGifBytes(Uint8List bytes) async {
    if (!_isIos || bytes.isEmpty) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('writeGifBytes', bytes);
    } on PlatformException catch (e, st) {
      swallowNonFatal('GifPasteboardChannel.writeGifBytes', e, st);
    }
  }
}
