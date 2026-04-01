import 'dart:developer';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../models/home_video.dart';
import '../models/share_payload.dart';
import '../models/connection_lite.dart';
import 'engagement_analytics_service.dart';
import 'connections_service.dart';
import 'logging_service.dart';

class EnhancedShareService {
  static final EnhancedShareService _instance =
      EnhancedShareService._internal();
  factory EnhancedShareService() => _instance;
  EnhancedShareService._internal() {
    _initializeDefaultUsage();
  }

  // Cache for prefetched share payloads with video previews
  final Map<String, SharePayload> _sharePayloadCache = {};
  final Map<String, Uint8List> _thumbnailCache = {};

  // Platform usage tracking for dynamic ranking
  final Map<String, int> _platformUsageCount = {};

  /// Prefetch share data with video thumbnail for instant modal display
  Future<SharePayload> fetchSharePayload(HomeVideo video) async {
    // Check cache first
    if (_sharePayloadCache.containsKey(video.id)) {
      return _sharePayloadCache[video.id]!;
    }

    try {
      LoggingService.instance.info(
        '🎬 EnhancedShareService: Prefetching share payload for video ${video.id}',
        tag: 'EnhancedShareService',
      );

      // Generate video thumbnail for preview
      await _generateVideoThumbnail(video);

      // Build enhanced share payload
      final payload = SharePayload(
        videoId: video.id,
        links: ShareLinks(
          webShareUrl: _generateShareUrl(video.id),
          deepLink: _generateDeepLink(video.id),
          downloadUrl: video.videoURL,
          embedCode: _generateEmbedCode(video.id),
        ),
        permissions: const SharePermissions(
          canShare: true,
          canDownload: true,
          canDuet: true,
          canRemix: true,
          canRepost: true,
        ),
        metadata: ShareMetadata(
          creatorUsername: video.creator.username,
          creatorDisplayName: video.creator.displayName,
          caption: video.caption,
          thumbnailUrl: video.thumbnailURL,
          hashtags: _extractHashtags(video.caption),
          createdAt: video.createdAt?.toDate(),
        ),
        trackingToken: _generateTrackingToken(video.id),
        platformUsageRanking: Map.from(_platformUsageCount),
      );

      // Cache the payload
      _sharePayloadCache[video.id] = payload;

      // Prefetch connections for connections row (non-blocking)
      ConnectionsService().getConnectionsPreview().catchError((e) {
        log('⚠️ EnhancedShareService: Failed to prefetch connections: $e');
        return <ConnectionLite>[];
      });

      LoggingService.instance.info(
        '✅ EnhancedShareService: Prefetched payload with thumbnail for video ${video.id}',
        tag: 'EnhancedShareService',
      );

      return payload;
    } catch (e) {
      LoggingService.instance.error(
        '❌ EnhancedShareService: Error fetching share payload: $e',
        tag: 'EnhancedShareService',
        error: e,
      );
      rethrow;
    }
  }

  /// Generate high-quality video thumbnail for sharing
  Future<Uint8List?> _generateVideoThumbnail(HomeVideo video) async {
    try {
      // Check cache first
      if (_thumbnailCache.containsKey(video.id)) {
        return _thumbnailCache[video.id];
      }

      LoggingService.instance.info(
        '🖼️ EnhancedShareService: Generating thumbnail for video ${video.id}',
        tag: 'EnhancedShareService',
      );

      // Generate thumbnail from video
      final thumbnailBytes = await VideoThumbnail.thumbnailData(
        video: video.videoURL,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 720,
        maxHeight: 1280,
        timeMs: 1000, // 1 second into video
        quality: 95,
      );

      if (thumbnailBytes != null) {
        _thumbnailCache[video.id] = thumbnailBytes;
        LoggingService.instance.info(
          '✅ EnhancedShareService: Generated thumbnail for video ${video.id}',
          tag: 'EnhancedShareService',
        );
      }

      return thumbnailBytes;
    } catch (e) {
      LoggingService.instance.error(
        '❌ EnhancedShareService: Error generating thumbnail: $e',
        tag: 'EnhancedShareService',
        error: e,
      );
      return null;
    }
  }

  /// Get cached share payload (instant access)
  SharePayload? getCachedPayload(String videoId) {
    return _sharePayloadCache[videoId];
  }

  /// Get cached thumbnail
  Uint8List? getCachedThumbnail(String videoId) {
    return _thumbnailCache[videoId];
  }

  /// Clear old cache entries
  void clearOldCache() {
    if (_sharePayloadCache.length > 10) {
      final keysToRemove =
          _sharePayloadCache.keys.take(_sharePayloadCache.length - 10).toList();
      for (final key in keysToRemove) {
        _sharePayloadCache.remove(key);
        _thumbnailCache.remove(key);
      }
    }
  }

  /// Enhanced platform-specific sharing with video preview
  Future<void> shareToTarget(
    ShareTarget target,
    SharePayload payload,
  ) async {
    try {
      LoggingService.instance.info(
        '📤 EnhancedShareService: Sharing to ${target.displayName}',
        tag: 'EnhancedShareService',
      );

      // Track share event
      trackShareEvent(
          'share_target_tap', payload.videoId, target.analyticsName);

      switch (target) {
        case ShareTarget.copyLink:
          await _copyLinkWithPreview(payload);
          break;
        case ShareTarget.instagramDirect:
          await _shareToInstagramDirect(payload);
          break;
        case ShareTarget.sms:
          await _shareViaSMSWithPreview(payload);
          break;
        case ShareTarget.whatsapp:
          await _shareToWhatsAppWithPreview(payload);
          break;
        case ShareTarget.repost:
          await _handleRepost(payload);
          break;
        case ShareTarget.facebook:
          await _shareToFacebookWithPreview(payload);
          break;
        case ShareTarget.twitter:
          await _shareToTwitterWithPreview(payload);
          break;
        case ShareTarget.telegram:
          await _shareToTelegramWithPreview(payload);
          break;
        case ShareTarget.email:
          await _shareViaEmailWithPreview(payload);
          break;
        case ShareTarget.more:
          await _shareToSystemWithPreview(payload);
          break;
      }

      // Track success
      _trackShareSuccess(payload.videoId, target.analyticsName);
      _updatePlatformUsage(target.analyticsName);

      LoggingService.instance.info(
        '✅ EnhancedShareService: Successfully shared to ${target.displayName}',
        tag: 'EnhancedShareService',
      );
    } catch (e) {
      LoggingService.instance.error(
        '❌ EnhancedShareService: Error sharing to ${target.displayName}: $e',
        tag: 'EnhancedShareService',
        error: e,
      );
    }
  }

  /// Copy link with rich preview data
  Future<void> _copyLinkWithPreview(SharePayload payload) async {
    try {
      final richText = _buildRichShareText(payload);
      await Clipboard.setData(ClipboardData(text: richText));

      trackShareEvent('share_copylink', payload.videoId, 'copylink');
      _trackShareSuccess(payload.videoId, 'copylink');
      _updatePlatformUsage('copylink');

      LoggingService.instance.info(
        '✅ EnhancedShareService: Link copied with preview',
        tag: 'EnhancedShareService',
      );
    } catch (e) {
      LoggingService.instance.error(
        '❌ EnhancedShareService: Error copying link: $e',
        tag: 'EnhancedShareService',
        error: e,
      );
    }
  }

  /// Share to Instagram Direct with video file
  Future<void> _shareToInstagramDirect(SharePayload payload) async {
    try {
      // Try to share video file directly to Instagram
      final videoUri = Uri.parse(payload.links.downloadUrl ?? '');
      if (await canLaunchUrl(videoUri)) {
        await launchUrl(videoUri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback to system share with rich content
        await _shareToSystemWithPreview(payload);
      }
    } catch (e) {
      LoggingService.instance.error(
        '❌ EnhancedShareService: Error sharing to Instagram Direct: $e',
        tag: 'EnhancedShareService',
        error: e,
      );
      // Fallback to system share
      await _shareToSystemWithPreview(payload);
    }
  }

  /// Share via SMS with rich preview
  Future<void> _shareViaSMSWithPreview(SharePayload payload) async {
    try {
      final message = _buildRichShareText(payload);
      final uri = Uri.parse('sms:?body=${Uri.encodeComponent(message)}');
      await launchUrl(uri);
    } catch (e) {
      LoggingService.instance.error(
        '❌ EnhancedShareService: Error sharing via SMS: $e',
        tag: 'EnhancedShareService',
        error: e,
      );
    }
  }

  /// Share to WhatsApp with rich preview
  Future<void> _shareToWhatsAppWithPreview(SharePayload payload) async {
    try {
      final message = _buildRichShareText(payload);
      final uri =
          Uri.parse('whatsapp://send?text=${Uri.encodeComponent(message)}');

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        // Fallback to web WhatsApp
        final webUri =
            Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}');
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      LoggingService.instance.error(
        '❌ EnhancedShareService: Error sharing to WhatsApp: $e',
        tag: 'EnhancedShareService',
        error: e,
      );
    }
  }

  /// Share to Facebook with rich preview
  Future<void> _shareToFacebookWithPreview(SharePayload payload) async {
    try {
      final uri = Uri.parse(
          'fb://share?link=${Uri.encodeComponent(payload.links.webShareUrl)}');

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        // Fallback to web Facebook with Open Graph data
        final webUri = Uri.parse(
          'https://www.facebook.com/sharer/sharer.php?u=${Uri.encodeComponent(payload.links.webShareUrl)}',
        );
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      LoggingService.instance.error(
        '❌ EnhancedShareService: Error sharing to Facebook: $e',
        tag: 'EnhancedShareService',
        error: e,
      );
    }
  }

  /// Share to Twitter with rich preview
  Future<void> _shareToTwitterWithPreview(SharePayload payload) async {
    try {
      final message = _buildRichShareText(payload);
      final uri =
          Uri.parse('twitter://post?message=${Uri.encodeComponent(message)}');

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        // Fallback to web Twitter
        final webUri = Uri.parse(
          'https://twitter.com/intent/tweet?text=${Uri.encodeComponent(message)}',
        );
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      LoggingService.instance.error(
        '❌ EnhancedShareService: Error sharing to Twitter: $e',
        tag: 'EnhancedShareService',
        error: e,
      );
    }
  }

  /// Share to Telegram with rich preview
  Future<void> _shareToTelegramWithPreview(SharePayload payload) async {
    try {
      final message = _buildRichShareText(payload);
      final uri = Uri.parse('tg://msg?text=${Uri.encodeComponent(message)}');

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        // Fallback to web Telegram
        final webUri = Uri.parse(
          'https://t.me/share/url?url=${Uri.encodeComponent(message)}',
        );
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      LoggingService.instance.error(
        '❌ EnhancedShareService: Error sharing to Telegram: $e',
        tag: 'EnhancedShareService',
        error: e,
      );
    }
  }

  /// Share via Email with rich preview
  Future<void> _shareViaEmailWithPreview(SharePayload payload) async {
    try {
      const subject = 'Check out this video on StreamersTip!';
      final body = _buildRichEmailBody(payload);

      final uri = Uri.parse(
        'mailto:?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
      );
      await launchUrl(uri);
    } catch (e) {
      LoggingService.instance.error(
        '❌ EnhancedShareService: Error sharing via email: $e',
        tag: 'EnhancedShareService',
        error: e,
      );
    }
  }

  /// Share to system share sheet with rich content
  Future<void> _shareToSystemWithPreview(SharePayload payload) async {
    try {
      final message = _buildRichShareText(payload);

      // Create share parameters with rich content
      final shareParams = ShareParams(
        text: message,
        subject: 'Check out this video on StreamersTip!',
      );

      await SharePlus.instance.share(shareParams);
    } catch (e) {
      LoggingService.instance.error(
        '❌ EnhancedShareService: Error sharing to system: $e',
        tag: 'EnhancedShareService',
        error: e,
      );
    }
  }

  /// Handle in-app repost
  Future<void> _handleRepost(SharePayload payload) async {
    LoggingService.instance.info(
      '🔄 EnhancedShareService: Repost requested for video ${payload.videoId}',
      tag: 'EnhancedShareService',
    );
    // This will be handled by UI callback to show repost dialog
  }

  /// Build rich share text with enhanced formatting
  String _buildRichShareText(SharePayload payload) {
    final caption = payload.metadata.caption?.isNotEmpty == true
        ? payload.metadata.caption!
        : 'Check out this amazing video!';

    final hashtags = payload.metadata.hashtags.isNotEmpty
        ? ' ${payload.metadata.hashtags.map((tag) => '#$tag').join(' ')}'
        : '';

    return '''🎬 ${payload.metadata.creatorDisplayName} (@${payload.metadata.creatorUsername})

$caption$hashtags

📱 Watch on StreamersTip: ${payload.links.webShareUrl}

#StreamersTip #Video #${payload.metadata.creatorUsername}''';
  }

  /// Build rich email body
  String _buildRichEmailBody(SharePayload payload) {
    final caption = payload.metadata.caption?.isNotEmpty == true
        ? payload.metadata.caption!
        : 'Check out this amazing video!';

    return '''Hi there!

${payload.metadata.creatorDisplayName} (@${payload.metadata.creatorUsername}) shared this video on StreamersTip:

"$caption"

Watch it here: ${payload.links.webShareUrl}

Download StreamersTip to discover more amazing content:
- iOS: https://apps.apple.com/app/streamerstip
- Android: https://play.google.com/store/apps/details?id=com.streamerstip.app

Best regards,
The StreamersTip Team''';
  }

  /// Generate enhanced share URL with tracking
  String _generateShareUrl(String videoId) {
    return 'https://streamerstip.com/video/$videoId?utm_source=app&utm_medium=share';
  }

  /// Generate deep link for app
  String _generateDeepLink(String videoId) {
    return 'streamerstip://video/$videoId';
  }

  /// Generate embed code with enhanced parameters
  String _generateEmbedCode(String videoId) {
    return '''<iframe 
  src="https://streamerstip.com/embed/$videoId" 
  width="100%" 
  height="100%" 
  frameborder="0" 
  allowfullscreen
  loading="lazy">
</iframe>''';
  }

  /// Generate tracking token for share analytics
  String _generateTrackingToken(String videoId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 10000).toString().padLeft(4, '0');
    return '${videoId}_${timestamp}_$random';
  }

  /// Extract hashtags from caption
  List<String> _extractHashtags(String caption) {
    final regex = RegExp(r'#(\w+)');
    return regex
        .allMatches(caption)
        .map((match) => match.group(1) ?? '')
        .where((tag) => tag.isNotEmpty)
        .toList();
  }

  /// Track share event
  void trackShareEvent(String eventName, String videoId, String method) {
    EngagementAnalyticsService().trackEngagement(
      videoId: videoId,
      event: EngagementEvent.share,
      metadata: {
        'event': eventName,
        'method': method,
        'timestamp': DateTime.now().toIso8601String(),
        'platform': Platform.operatingSystem,
      },
    );
  }

  /// Track share success
  void _trackShareSuccess(String videoId, String method) {
    EngagementAnalyticsService().trackEngagement(
      videoId: videoId,
      event: EngagementEvent.share,
      metadata: {
        'event': 'share_success',
        'method': method,
        'timestamp': DateTime.now().toIso8601String(),
        'platform': Platform.operatingSystem,
      },
    );
  }

  /// Track share sheet open
  void trackShareSheetOpen(String videoId) {
    EngagementAnalyticsService().trackEngagement(
      videoId: videoId,
      event: EngagementEvent.share,
      metadata: {
        'event': 'share_sheet_open',
        'timestamp': DateTime.now().toIso8601String(),
        'platform': Platform.operatingSystem,
      },
    );
  }

  /// Track share cancel
  void trackShareCancel(String videoId) {
    EngagementAnalyticsService().trackEngagement(
      videoId: videoId,
      event: EngagementEvent.share,
      metadata: {
        'event': 'share_cancel',
        'timestamp': DateTime.now().toIso8601String(),
        'platform': Platform.operatingSystem,
      },
    );
  }

  /// Update platform usage count for dynamic ranking
  void _updatePlatformUsage(String platform) {
    _platformUsageCount[platform] = (_platformUsageCount[platform] ?? 0) + 1;
  }

  /// Initialize default usage patterns for better initial ranking
  void _initializeDefaultUsage() {
    // Set realistic initial usage counts based on platform
    if (Platform.isIOS) {
      _platformUsageCount['sms'] = 20;
      _platformUsageCount['instagram_direct'] = 15;
      _platformUsageCount['whatsapp'] = 12;
      _platformUsageCount['facebook'] = 8;
      _platformUsageCount['twitter'] = 6;
      _platformUsageCount['telegram'] = 4;
      _platformUsageCount['email'] = 3;
      _platformUsageCount['system_share'] = 2;
    } else {
      _platformUsageCount['whatsapp'] = 18;
      _platformUsageCount['sms'] = 15;
      _platformUsageCount['instagram_direct'] = 10;
      _platformUsageCount['facebook'] = 8;
      _platformUsageCount['telegram'] = 6;
      _platformUsageCount['twitter'] = 5;
      _platformUsageCount['email'] = 4;
      _platformUsageCount['system_share'] = 3;
    }
  }

  /// Get ranked share targets based on usage and platform
  List<ShareTarget> getRankedTargets() {
    final rankedTargets = <ShareTarget>[];

    // Only Copy Link for now
    rankedTargets.add(ShareTarget.copyLink);

    return rankedTargets;
  }
}
