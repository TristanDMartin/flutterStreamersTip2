import 'dart:async';
import 'dart:typed_data';

import 'package:video_thumbnail/video_thumbnail.dart';

/// In-memory filmstrip frames so Trim/Cover open without a loading screen.
class VideoFilmstripCache {
  VideoFilmstripCache._internal();

  static final VideoFilmstripCache instance = VideoFilmstripCache._internal();

  final Map<String, Uint8List?> _frames = <String, Uint8List?>{};
  final Map<String, Future<Uint8List?>> _inflight = <String, Future<Uint8List?>>{};

  String _key(String path, int timeMs) => '$path@$timeMs';

  Uint8List? peek(String path, int timeMs) => _frames[_key(path, timeMs)];

  Future<Uint8List?> loadFrame({
    required String path,
    required int timeMs,
    int maxWidth = 120,
    int quality = 70,
  }) {
    final String key = _key(path, timeMs);
    if (_frames.containsKey(key)) {
      return Future<Uint8List?>.value(_frames[key]);
    }
    final Future<Uint8List?>? existing = _inflight[key];
    if (existing != null) {
      return existing;
    }
    final Future<Uint8List?> future = () async {
      try {
        final Uint8List? bytes = await VideoThumbnail.thumbnailData(
          video: path,
          imageFormat: ImageFormat.JPEG,
          maxWidth: maxWidth,
          timeMs: timeMs,
          quality: quality,
        );
        _frames[key] = bytes;
        return bytes;
      } catch (_) {
        _frames[key] = null;
        return null;
      } finally {
        _inflight.remove(key);
      }
    }();
    _inflight[key] = future;
    return future;
  }

  /// Loads [count] evenly spaced frames. Calls [onFrame] as each arrives.
  Future<List<Uint8List?>> loadStrip({
    required String path,
    required double startSeconds,
    required double endSeconds,
    required int count,
    void Function(int index, Uint8List? bytes)? onFrame,
  }) async {
    final double start = startSeconds < 0 ? 0 : startSeconds;
    final double end = endSeconds > start ? endSeconds : start + 0.001;
    final List<Uint8List?> out = List<Uint8List?>.filled(count, null);
    final List<Future<void>> jobs = <Future<void>>[];
    for (int i = 0; i < count; i++) {
      final double t = count <= 1
          ? start
          : start + ((end - start) * i / (count - 1));
      final int timeMs = (t * 1000).round();
      jobs.add(() async {
        final Uint8List? bytes = await loadFrame(path: path, timeMs: timeMs);
        out[i] = bytes;
        onFrame?.call(i, bytes);
      }());
    }
    await Future.wait(jobs);
    return out;
  }

  void prefetchFull({
    required String path,
    required Duration duration,
    int count = 12,
  }) {
    final double max = duration.inMilliseconds / 1000.0;
    if (max <= 0 || path.isEmpty) {
      return;
    }
    unawaited(
      loadStrip(
        path: path,
        startSeconds: 0,
        endSeconds: max,
        count: count,
      ),
    );
  }

  void clearPath(String path) {
    final List<String> keys = _frames.keys
        .where((String key) => key.startsWith('$path@'))
        .toList();
    for (final String key in keys) {
      _frames.remove(key);
    }
  }
}
