import 'dart:async';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../services/analytics_service.dart';
import '../services/device_capability_service.dart';
import 'video_url_resolver.dart';
import 'package:streamers_tip/utils/secure_log.dart';

/// Result of video health check
sealed class VideoPlayableResult {}

class Playable extends VideoPlayableResult {
  final String url;
  final String quality;
  final String sourceType; // 'canonical', '720p', '480p', 'primary'

  Playable({
    required this.url,
    required this.quality,
    required this.sourceType,
  });
}

class Unplayable extends VideoPlayableResult {
  final String reason;
  final Map<String, dynamic> debugInfo;

  Unplayable({
    required this.reason,
    this.debugInfo = const {},
  });
}

/// Video Health Gate - Validates video can be played before controller creation
class VideoHealthGate {
  static final VideoHealthGate instance = VideoHealthGate._();
  VideoHealthGate._();

  void _logSourceDiagnostics(
    String videoId,
    Map<String, dynamic>? data, {
    required String selectedQuality,
    required String selectedSourceType,
  }) {
    final sourceSummary = <String, bool>{
      'muxPlaybackId':
          (data?['muxPlaybackId'] as String?)?.trim().isNotEmpty ?? false,
      'hlsUrl': (data?['hlsUrl'] ?? data?['hls_url']) is String &&
          ((data?['hlsUrl'] ?? data?['hls_url']) as String).trim().isNotEmpty,
      'canonicalPlaybackUrl':
          (data?['canonicalPlaybackUrl'] as String?)?.trim().isNotEmpty ??
              false,
      'mp4_1080_url':
          (data?['mp4_1080_url'] as String?)?.trim().isNotEmpty ?? false,
      'mp4_720_url':
          (data?['mp4_720_url'] as String?)?.trim().isNotEmpty ?? false,
      'mp4_480_url':
          (data?['mp4_480_url'] as String?)?.trim().isNotEmpty ?? false,
      'videoUrl': ((data?['videoUrl'] ?? data?['videoURL']) as String?)
              ?.trim()
              .isNotEmpty ??
          false,
    };
    secureLog(
      '🎥 VideoQuality: video=$videoId selected=$selectedSourceType/$selectedQuality '
      'available=$sourceSummary',
    );
  }

  /// Resolve playable source for a video
  /// Returns Playable(url, quality, sourceType) or Unplayable(reason, debugInfo)
  ///
  /// [fallbackUrl] - Optional URL to use if health gate doesn't find one (from widget.video.videoURL)
  Future<VideoPlayableResult> resolvePlayableSource(
    String videoId, {
    Map<String, dynamic>? cachedData,
    String? fallbackUrl,
  }) async {
    try {
      // 🔥 FIX: If fallback URL is provided, use it immediately (non-blocking)
      // Only fetch Firestore if no fallback URL is available
      Map<String, dynamic>? data = cachedData;

      if (data == null &&
          fallbackUrl != null &&
          fallbackUrl.trim().isNotEmpty) {
        if (containsOriginalMp4(fallbackUrl)) {
          secureLog(
              'FATAL: VideoHealthGate fallback is original.mp4 - rejecting on mobile');
          if (!kIsWeb) {
            return Unplayable(
                reason: 'original_mp4_forbidden',
                debugInfo: {'videoId': videoId});
          }
        }
        if (_isValidUrl(fallbackUrl.trim())) {
          final urlLower = fallbackUrl.toLowerCase();
          final isMuxHls =
              urlLower.contains('stream.mux.com') && urlLower.contains('.m3u8');
          if (isMuxHls) {
            developer
                .log('✅ VideoHealthGate: Using Mux fallback URL instantly');
            return _playableIfNotOriginal(
                fallbackUrl.trim(), 'fallback', 'fallback', videoId);
          }
        }
      }

      // Only fetch Firestore if no cached data AND no valid fallback URL
      if (data == null) {
        try {
          final snapshot = await FirebaseFirestore.instance
              .collection('videos')
              .doc(videoId)
              .get()
              .timeout(const Duration(
                  seconds: 2)); // Reduced timeout to prevent freezes

          if (!snapshot.exists) {
            if (fallbackUrl != null &&
                fallbackUrl.trim().isNotEmpty &&
                _isValidUrl(fallbackUrl.trim())) {
              if (containsOriginalMp4(fallbackUrl) && !kIsWeb) {
                return Unplayable(
                    reason: 'original_mp4_forbidden',
                    debugInfo: {'videoId': videoId});
              }
              final urlLower = fallbackUrl.toLowerCase();
              if (urlLower.contains('.mp4') || urlLower.contains('.m3u8')) {
                return _playableIfNotOriginal(
                    fallbackUrl.trim(), 'fallback', 'fallback', videoId);
              }
            }
            return Unplayable(
              reason: 'video_not_found',
              debugInfo: {'videoId': videoId},
            );
          }

          data = snapshot.data();
          if (data == null) {
            if (fallbackUrl != null &&
                fallbackUrl.trim().isNotEmpty &&
                _isValidUrl(fallbackUrl.trim())) {
              if (containsOriginalMp4(fallbackUrl) && !kIsWeb) {
                return Unplayable(
                    reason: 'original_mp4_forbidden',
                    debugInfo: {'videoId': videoId});
              }
              final urlLower = fallbackUrl.toLowerCase();
              if (urlLower.contains('.mp4') || urlLower.contains('.m3u8')) {
                return _playableIfNotOriginal(
                    fallbackUrl.trim(), 'fallback', 'fallback', videoId);
              }
            }
            return Unplayable(
              reason: 'no_data',
              debugInfo: {'videoId': videoId},
            );
          }
        } catch (e) {
          if (fallbackUrl != null && fallbackUrl.trim().isNotEmpty) {
            if (containsOriginalMp4(fallbackUrl) && !kIsWeb) {
              return Unplayable(
                  reason: 'original_mp4_forbidden',
                  debugInfo: {'videoId': videoId});
            }
            if (_isValidUrl(fallbackUrl.trim())) {
              final urlLower = fallbackUrl.toLowerCase();
              if (urlLower.contains('.mp4') || urlLower.contains('.m3u8')) {
                secureLog(
                    '⚠️ VideoHealthGate: Firestore fetch failed, using fallback URL');
                return _playableIfNotOriginal(
                    fallbackUrl.trim(), 'fallback', 'fallback', videoId);
              }
            }
          }

          return Unplayable(
            reason: 'fetch_timeout',
            debugInfo: {
              'videoId': videoId,
              'error': e.toString(),
              'hasFallbackUrl': fallbackUrl != null && fallbackUrl.isNotEmpty,
            },
          );
        }
      }

      final status = data['status'] as String?;
      final resolvedPlaybackUrl = resolveReadyPlaybackUrl(data);
      final rawMuxId = data['muxPlaybackId'] ??
          data['playbackId'] ??
          data['mux_playback_id'];
      final muxId = rawMuxId?.toString().trim() ?? '';
      final hasMux = muxId.isNotEmpty;
      if (data['deleted'] == true ||
          data['isDeleted'] == true ||
          status == 'deleted' ||
          data['visible'] == false ||
          status == 'failed') {
        return Unplayable(
          reason: 'hidden_or_failed',
          debugInfo: {
            'videoId': videoId,
            'status': status,
            'visible': data['visible'],
          },
        );
      }
      final bool isReadyForFeed = data['isReadyForFeed'] == true;
      if (!isReadyPlaybackStatus(status, isReadyForFeed: isReadyForFeed)) {
        return Unplayable(
          reason: status == 'processing' || status == 'uploading'
              ? 'processing'
              : 'not_ready',
          debugInfo: {
            'videoId': videoId,
            'status': status,
            'hasPlaybackUrl': resolvedPlaybackUrl != null,
          },
        );
      }

      // Check playbackReady flag if exists
      final playbackReady = data['playbackReady'] as bool?;
      if (playbackReady == false) {
        return Unplayable(
          reason: 'playback_not_ready',
          debugInfo: {'videoId': videoId},
        );
      }

      final raw = data['raw'] as String?;
      final isOriginal = data['isOriginal'] == true;
      if (raw == 'YES' || isOriginal) {
        return Unplayable(
          reason: 'raw_or_original_forbidden',
          debugInfo: {'videoId': videoId, 'raw': raw, 'isOriginal': isOriginal},
        );
      }

      // Prefer Mux adaptive HLS immediately. For non-Mux sources, try lighter
      // startup variants below before canonical/high-bitrate URLs.
      if (resolvedPlaybackUrl != null &&
          resolvedPlaybackUrl.trim().isNotEmpty) {
        if (hasMux) {
          _logSourceDiagnostics(
            videoId,
            data,
            selectedQuality: 'mux_hls',
            selectedSourceType: 'mux',
          );
          return _playableIfNotOriginal(
            resolvedPlaybackUrl.trim(),
            'mux_hls',
            'mux',
            videoId,
            data: data,
          );
        }
      }

      // Prefer the sharpest safe source first, then step down only if needed.
      final deviceResolution =
          await DeviceCapabilityService.instance.getRecommendedResolution();
      final isLowMemory = deviceResolution == '720';

      final hlsUrl = (data['hlsUrl'] ?? data['hls_url']) as String?;
      if (hlsUrl != null &&
          hlsUrl.toString().trim().isNotEmpty &&
          !containsOriginalMp4(hlsUrl.toString()) &&
          _isValidUrl(normalizeMuxHlsUrl(hlsUrl.toString().trim()))) {
        final normalizedHlsUrl = normalizeMuxHlsUrl(hlsUrl.toString().trim());
        _logSourceDiagnostics(
          videoId,
          data,
          selectedQuality: 'hls',
          selectedSourceType: 'hls',
        );
        return _playableIfNotOriginal(normalizedHlsUrl, 'hls', 'hls', videoId,
            data: data);
      }
      final startup720 = data['mp4_720_url'] as String?;
      if (startup720 != null &&
          startup720.trim().isNotEmpty &&
          !containsOriginalMp4(startup720) &&
          _isValidUrl(startup720.trim())) {
        final normalized720 = normalizeMuxHlsUrl(startup720.trim());
        _logSourceDiagnostics(
          videoId,
          data,
          selectedQuality: '720p_startup',
          selectedSourceType: '720p',
        );
        return _playableIfNotOriginal(
          normalized720,
          '720p_startup',
          '720p',
          videoId,
          data: data,
        );
      }
      final startup480 = data['mp4_480_url'] as String?;
      if (startup480 != null &&
          startup480.trim().isNotEmpty &&
          !containsOriginalMp4(startup480) &&
          _isValidUrl(startup480.trim())) {
        final normalized480 = normalizeMuxHlsUrl(startup480.trim());
        _logSourceDiagnostics(
          videoId,
          data,
          selectedQuality: '480p_startup',
          selectedSourceType: '480p',
        );
        return _playableIfNotOriginal(
          normalized480,
          '480p_startup',
          '480p',
          videoId,
          data: data,
        );
      }
      final canonical = data['canonicalPlaybackUrl'] as String?;
      if (canonical != null &&
          canonical.trim().isNotEmpty &&
          !containsOriginalMp4(canonical)) {
        final normalizedCanonical = normalizeMuxHlsUrl(canonical.trim());
        if (_isValidUrl(normalizedCanonical)) {
          final canonicalLower = normalizedCanonical.toLowerCase();
          if (isLowMemory && canonicalLower.contains('1080')) {
            secureLog(
                '⚠️ VideoHealthGate: Skipping 1080p canonical URL on low-memory device');
          } else {
            _logSourceDiagnostics(
              videoId,
              data,
              selectedQuality: 'canonical',
              selectedSourceType: 'canonical',
            );
            return _playableIfNotOriginal(
                normalizedCanonical, 'canonical', 'canonical', videoId,
                data: data);
          }
        }
      }
      if (resolvedPlaybackUrl != null &&
          resolvedPlaybackUrl.trim().isNotEmpty) {
        _logSourceDiagnostics(
          videoId,
          data,
          selectedQuality: 'resolved',
          selectedSourceType: 'resolved',
        );
        return _playableIfNotOriginal(
          resolvedPlaybackUrl.trim(),
          'resolved',
          'resolved',
          videoId,
          data: data,
        );
      }

      // 2. For low-memory devices: Prefer 720p → 480p (NEVER 1080p)
      // 🔥 FIX: Prefer 720p over 480p for better quality (only avoid 1080p)
      if (isLowMemory) {
        // Try 720p first (better quality, still safe for low-memory)
        final url720 = data['mp4_720_url'] as String?;
        if (url720 != null &&
            url720.trim().isNotEmpty &&
            !containsOriginalMp4(url720) &&
            _isValidUrl(url720.trim())) {
          final normalized720 = normalizeMuxHlsUrl(url720.trim());
          _logSourceDiagnostics(
            videoId,
            data,
            selectedQuality: '720p',
            selectedSourceType: '720p',
          );
          return _playableIfNotOriginal(normalized720, '720p', '720p', videoId,
              data: data);
        }
        final url480 = data['mp4_480_url'] as String?;
        if (url480 != null &&
            url480.trim().isNotEmpty &&
            !containsOriginalMp4(url480) &&
            _isValidUrl(url480.trim())) {
          final normalized480 = normalizeMuxHlsUrl(url480.trim());
          _logSourceDiagnostics(
            videoId,
            data,
            selectedQuality: '480p',
            selectedSourceType: '480p',
          );
          return _playableIfNotOriginal(normalized480, '480p', '480p', videoId,
              data: data);
        }
        if (fallbackUrl != null && fallbackUrl.trim().isNotEmpty) {
          final normalizedFallback = normalizeMuxHlsUrl(fallbackUrl.trim());
          final urlLower = normalizedFallback.toLowerCase();
          if (!urlLower.contains('1080') &&
              !containsOriginalMp4(normalizedFallback) &&
              _isValidUrl(normalizedFallback)) {
            if (urlLower.contains('.mp4') || urlLower.contains('.m3u8')) {
              _logSourceDiagnostics(
                videoId,
                data,
                selectedQuality: 'fallback',
                selectedSourceType: 'fallback',
              );
              return _playableIfNotOriginal(
                  normalizedFallback, 'fallback', 'fallback', videoId);
            }
          }
        }

        // For low-memory: DO NOT fallback to 1080p - mark as Unplayable
        return Unplayable(
          reason: 'missing_variants_low_memory',
          debugInfo: {
            'videoId': videoId,
            'deviceResolution': deviceResolution,
            'has480p': url480 != null && url480.trim().isNotEmpty,
            'has720p': url720 != null && url720.trim().isNotEmpty,
            'hasFallbackUrl': fallbackUrl != null && fallbackUrl.isNotEmpty,
          },
        );
      }

      final url720 = data['mp4_720_url'] as String?;
      if (url720 != null &&
          url720.trim().isNotEmpty &&
          !containsOriginalMp4(url720) &&
          _isValidUrl(url720.trim())) {
        final normalized720 = normalizeMuxHlsUrl(url720.trim());
        _logSourceDiagnostics(
          videoId,
          data,
          selectedQuality: '720p',
          selectedSourceType: '720p',
        );
        return _playableIfNotOriginal(normalized720, '720p', '720p', videoId,
            data: data);
      }
      final url1080 = data['mp4_1080_url'] as String?;
      if (url1080 != null &&
          url1080.trim().isNotEmpty &&
          !containsOriginalMp4(url1080) &&
          _isValidUrl(url1080.trim())) {
        final normalized1080 = normalizeMuxHlsUrl(url1080.trim());
        _logSourceDiagnostics(
          videoId,
          data,
          selectedQuality: '1080p',
          selectedSourceType: '1080p',
        );
        return _playableIfNotOriginal(normalized1080, '1080p', '1080p', videoId,
            data: data);
      }
      final url480 = data['mp4_480_url'] as String?;
      if (url480 != null &&
          url480.trim().isNotEmpty &&
          !containsOriginalMp4(url480) &&
          _isValidUrl(url480.trim())) {
        final normalized480 = normalizeMuxHlsUrl(url480.trim());
        _logSourceDiagnostics(
          videoId,
          data,
          selectedQuality: '480p',
          selectedSourceType: '480p',
        );
        return _playableIfNotOriginal(normalized480, '480p', '480p', videoId,
            data: data);
      }
      final legacyKeys = [
        'hlsUrl',
        'hls_url',
        'primaryUrl',
        'mp4Url',
        'videoUrl',
        'videoURL'
      ];
      for (final key in legacyKeys) {
        final url = data[key] as String?;
        if (url != null &&
            url.trim().isNotEmpty &&
            !containsOriginalMp4(url) &&
            _isValidUrl(url.trim())) {
          final normalizedUrl = normalizeMuxHlsUrl(url.trim());
          final urlLower = normalizedUrl.toLowerCase();
          if (urlLower.contains('.mp4') || urlLower.contains('.m3u8')) {
            if (isLowMemory && urlLower.contains('1080')) {
              secureLog(
                  '⚠️ VideoHealthGate: Skipping 1080p legacy URL on low-memory device');
              continue;
            }
            _logSourceDiagnostics(
              videoId,
              data,
              selectedQuality: 'legacy',
              selectedSourceType: key,
            );
            return _playableIfNotOriginal(normalizedUrl, 'legacy', key, videoId,
                data: data);
          }
        }
      }
      if (fallbackUrl != null && fallbackUrl.trim().isNotEmpty) {
        final normalizedFallback = normalizeMuxHlsUrl(fallbackUrl.trim());
        if (!containsOriginalMp4(normalizedFallback) &&
            _isValidUrl(normalizedFallback)) {
          final urlLower = normalizedFallback.toLowerCase();
          if (urlLower.contains('.mp4') || urlLower.contains('.m3u8')) {
            if (!(isLowMemory && urlLower.contains('1080'))) {
              _logSourceDiagnostics(
                videoId,
                data,
                selectedQuality: 'fallback',
                selectedSourceType: 'fallback',
              );
              return _playableIfNotOriginal(
                  normalizedFallback, 'fallback', 'fallback', videoId,
                  data: data);
            }
          }
        }
      }

      // No valid URL found
      return Unplayable(
        reason: 'no_valid_url',
        debugInfo: {
          'videoId': videoId,
          'deviceResolution': deviceResolution,
          'hasCanonical': canonical != null,
          'has480p': data['mp4_480_url'] != null,
          'has720p': data['mp4_720_url'] != null,
          'has1080p': data['mp4_1080_url'] != null,
          'hasFallbackUrl': fallbackUrl != null && fallbackUrl.isNotEmpty,
        },
      );
    } catch (e, stackTrace) {
      secureLog('❌ VideoHealthGate: Error resolving playable source: $e',
          error: e, stackTrace: stackTrace);
      return Unplayable(
        reason: 'resolver_error',
        debugInfo: {
          'videoId': videoId,
          'error': e.toString(),
        },
      );
    }
  }

  bool _isImageUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('placehold.co') ||
        lower.contains('via.placeholder.com') ||
        lower.contains('.png') ||
        lower.contains('.jpg') ||
        lower.contains('.jpeg') ||
        lower.contains('.webp') ||
        lower.contains('.gif');
  }

  VideoPlayableResult _playableIfNotOriginal(
    String url,
    String quality,
    String sourceType,
    String videoId, {
    Map<String, dynamic>? data,
  }) {
    if (!kIsWeb && containsOriginalMp4(url)) {
      developer
          .log('FATAL: original.mp4 attempted on mobile in VideoHealthGate');
      return Unplayable(
          reason: 'original_mp4_forbidden', debugInfo: {'videoId': videoId});
    }
    // Note: Firebase Storage URLs are allowed — playback errors (e.g. 402)
    // are handled at the player level rather than rejected here.
    if (_isImageUrl(url)) {
      secureLog('VideoHealthGate: Rejecting image URL - $videoId');
      return Unplayable(
        reason: 'image_url_not_video',
        debugInfo: {'videoId': videoId},
      );
    }
    final playableUrl = toFirebaseStorageUrlIfNeeded(url);
    return Playable(url: playableUrl, quality: quality, sourceType: sourceType);
  }

  /// Check if URL is valid format
  bool _isValidUrl(String url) {
    if (url.isEmpty) return false;

    final urlLower = url.toLowerCase();
    final isValidFormat = urlLower.startsWith('http://') ||
        urlLower.startsWith('https://') ||
        urlLower.startsWith('gs://');

    if (!isValidFormat) return false;

    // Try to parse as URI
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && uri.hasAuthority;
    } catch (_) {
      return false;
    }
  }

  /// Log unplayable video for backend recovery
  void logUnplayableVideo(
    String videoId,
    String reason,
    Map<String, dynamic> debugInfo,
  ) {
    secureLog('🚫 VideoHealthGate: Unplayable video detected',
        name: 'video_playback_unplayable');

    unawaited(
      AnalyticsService.instance.trackEvent(
        'video_playback_unplayable',
        parameters: <String, Object>{
          'video_id': videoId,
          'reason': reason,
          'debug_info': debugInfo.toString(),
        },
      ),
    );

    secureLog('  VideoId: $videoId');
    secureLog('  Reason: $reason');
    secureLog('  Debug: $debugInfo');
  }
}
