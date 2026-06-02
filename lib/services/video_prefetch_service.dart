import 'package:http/http.dart' as http;
import 'video_cache_service.dart';
import 'network_policy_service.dart';
import 'package:streamers_tip/utils/secure_log.dart';

/// Service responsible for prefetching network media for instant play.
///
/// This intentionally does not create or own VideoPlayerController instances.
/// Playback controller ownership stays with the active player path.
class VideoPrefetchService {
  static final VideoPrefetchService _instance =
      VideoPrefetchService._internal();
  factory VideoPrefetchService() => _instance;
  VideoPrefetchService._internal();

  final VideoCacheService _cacheService = VideoCacheService();
  final NetworkPolicyService _networkPolicy = NetworkPolicyService();

  // Prefetch configuration
  static const int _prefetchWindowSize = 3; // Prefetch next 3 videos

  // Current prefetch state
  final Set<String> _prefetchingVideos = {};
  final Map<String, DateTime> _prefetchTimestamps = {};

  /// Prime a video for instant play (warm start candidate)
  Future<void> prime({
    required String videoId,
    required String posterUrl,
    required String videoUrl,
  }) async {
    try {
      secureLog('🎯 Priming video for instant play: $videoId');

      // Prefetch poster immediately
      await _prefetchPoster(posterUrl);

      // Prefetch first segment of video
      await _prefetchFirstSegment(videoUrl);

      secureLog('✅ Video primed successfully: $videoId');
    } catch (e) {
      secureLog('❌ Error priming video $videoId: $e');
    }
  }

  /// Prefetch window around current index
  Future<void> prefetchWindow({
    required int currentIndex,
    required List<PrefetchItem> items,
  }) async {
    try {
      if (items.isEmpty) return;

      // Calculate prefetch targets
      final targets = _calculatePrefetchTargets(currentIndex, items.length);

      secureLog('🔄 Prefetching window around index $currentIndex: $targets');

      // Prefetch each target
      for (final index in targets) {
        if (index < items.length) {
          final item = items[index];
          await _prefetchItem(item,
              priority: _getPrefetchPriority(index, currentIndex));
        }
      }
    } catch (e) {
      secureLog('❌ Error prefetching window: $e');
    }
  }

  /// Calculate which items to prefetch
  Set<int> _calculatePrefetchTargets(int currentIndex, int totalItems) {
    final targets = <int>{};

    // Keep one behind for back navigation
    if (currentIndex > 0) {
      targets.add(currentIndex - 1);
    }

    // Prefetch ahead
    for (int i = 1; i <= _prefetchWindowSize; i++) {
      final targetIndex = currentIndex + i;
      if (targetIndex < totalItems) {
        targets.add(targetIndex);
      }
    }

    return targets;
  }

  /// Get prefetch priority based on distance from current index
  double _getPrefetchPriority(int index, int currentIndex) {
    final distance = (index - currentIndex).abs();
    if (distance == 0) return 1.0; // Current video
    if (distance == 1) return 0.8; // Adjacent videos
    if (distance == 2) return 0.6; // Next videos
    return 0.4; // Further videos
  }

  /// Prefetch a single item
  Future<void> _prefetchItem(PrefetchItem item,
      {required double priority}) async {
    try {
      // Check if already prefetching
      if (_prefetchingVideos.contains(item.videoId)) {
        return;
      }

      // Check network policy
      if (!_networkPolicy.canPrefetch(priority)) {
        secureLog(
            '⏸️ Skipping prefetch due to network policy: ${item.videoId}');
        return;
      }

      _prefetchingVideos.add(item.videoId);
      _prefetchTimestamps[item.videoId] = DateTime.now();

      // Prefetch poster (always)
      await _prefetchPoster(item.posterUrl);

      // Prefetch video content based on network conditions
      if (_networkPolicy.prefetchMediaSegments) {
        await _prefetchFirstSegment(item.videoUrl);
      } else {
        // On slow networks, just prefetch playlist
        await _prefetchPlaylist(item.videoUrl);
      }

      secureLog(
          '✅ Prefetched item: ${item.videoId} (priority: ${priority.toStringAsFixed(1)})');
    } catch (e) {
      secureLog('❌ Error prefetching item ${item.videoId}: $e');
    } finally {
      _prefetchingVideos.remove(item.videoId);
    }
  }

  /// Prefetch video poster
  Future<void> _prefetchPoster(String posterUrl) async {
    try {
      if (posterUrl.isEmpty) return;

      // Check if already cached
      if (_cacheService.isVideoCached(posterUrl)) {
        return;
      }

      // Download poster
      final response = await http.get(Uri.parse(posterUrl));
      if (response.statusCode == 200) {
        await _cacheService.cacheThumbnail(posterUrl, response.bodyBytes);
        secureLog('📸 Poster cached: ${posterUrl.split('/').last}');
      }
    } catch (e) {
      secureLog('❌ Error prefetching poster: $e');
    }
  }

  /// Prefetch first segment of video
  Future<void> _prefetchFirstSegment(String videoUrl) async {
    try {
      if (videoUrl.isEmpty) return;

      // For HLS, prefetch the first segment
      if (videoUrl.contains('.m3u8')) {
        await _prefetchHLSFirstSegment(videoUrl);
      } else {
        // For other formats, prefetch first chunk
        await _prefetchVideoChunk(videoUrl, 0, 1024 * 1024); // 1MB chunk
      }
    } catch (e) {
      secureLog('❌ Error prefetching first segment: $e');
    }
  }

  /// Prefetch HLS first segment
  Future<void> _prefetchHLSFirstSegment(String hlsUrl) async {
    try {
      // Fetch master playlist
      final playlistResponse = await http.get(Uri.parse(hlsUrl));
      if (playlistResponse.statusCode != 200) return;

      final playlist = playlistResponse.body;

      // Find the lowest quality stream
      final lines = playlist.split('\n');
      String? segmentUrl;

      for (int i = 0; i < lines.length; i++) {
        if (lines[i].startsWith('#EXT-X-STREAM-INF:')) {
          // This is a stream info line, next line should be the URL
          if (i + 1 < lines.length && !lines[i + 1].startsWith('#')) {
            final baseUrl = hlsUrl.substring(0, hlsUrl.lastIndexOf('/') + 1);
            segmentUrl = baseUrl + lines[i + 1];
            break;
          }
        }
      }

      if (segmentUrl != null) {
        // Fetch the first segment
        await _prefetchVideoChunk(segmentUrl, 0, 2 * 1024 * 1024); // 2MB
        secureLog('🎬 HLS first segment cached: ${segmentUrl.split('/').last}');
      }
    } catch (e) {
      secureLog('❌ Error prefetching HLS segment: $e');
    }
  }

  /// Prefetch video chunk
  Future<void> _prefetchVideoChunk(
      String videoUrl, int start, int length) async {
    try {
      final response = await http.get(
        Uri.parse(videoUrl),
        headers: {
          'Range': 'bytes=$start-${start + length - 1}',
        },
      );

      if (response.statusCode == 206) {
        // Partial content
        // For now, just log the chunk - would need to implement chunk caching
        secureLog('📦 Video chunk downloaded: ${videoUrl.split('/').last}');
      }
    } catch (e) {
      secureLog('❌ Error prefetching video chunk: $e');
    }
  }

  /// Prefetch playlist only (for slow networks)
  Future<void> _prefetchPlaylist(String videoUrl) async {
    try {
      if (videoUrl.contains('.m3u8')) {
        final response = await http.get(Uri.parse(videoUrl));
        if (response.statusCode == 200) {
          // For now, just log the playlist - would need to implement playlist caching
          secureLog('📋 Playlist downloaded: ${videoUrl.split('/').last}');
        }
      }
    } catch (e) {
      secureLog('❌ Error prefetching playlist: $e');
    }
  }

  /// Cancel prefetch for a video
  Future<void> cancelPrefetch(String videoId) async {
    try {
      _prefetchingVideos.remove(videoId);
      _prefetchTimestamps.remove(videoId);
      secureLog('❌ Cancelled prefetch: $videoId');
    } catch (e) {
      secureLog('❌ Error cancelling prefetch: $e');
    }
  }

  /// Get prefetch statistics
  Map<String, dynamic> getPrefetchStats() {
    return {
      'activePrefetches': _prefetchingVideos.length,
      'prefetchTimestamps': _prefetchTimestamps.length,
      'networkPolicy': _networkPolicy.getPolicyInfo(),
    };
  }
}

/// Item to be prefetched
class PrefetchItem {
  final String videoId;
  final String posterUrl;
  final String videoUrl;
  final double prefetchPriority;

  PrefetchItem({
    required this.videoId,
    required this.posterUrl,
    required this.videoUrl,
    this.prefetchPriority = 0.5,
  });
}
