import 'dart:developer';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../models/home_video.dart';
import '../models/connection_lite.dart';
import '../models/share_payload.dart';
import '../models/share_video_payload.dart';
import 'connections_service.dart';
import 'engagement_analytics_service.dart';
import 'logging_service.dart';

/// Non-fatal hint surfaced by [EnhancedShareSheet] after a share action.
class ShareUserNoticeException implements Exception {
  ShareUserNoticeException(this.message);
  final String message;
}

class EnhancedShareService {
  static final EnhancedShareService _instance =
      EnhancedShareService._internal();
  factory EnhancedShareService() => _instance;
  EnhancedShareService._internal() {
    _initializeDefaultUsage();
  }

  // Cache for prefetched share payloads with video previews
  final Map<String, SharePayload> _sharePayloadCache = {};
  final Map<String, ShareVideoPayload> _shareVideoPayloadCache = {};
  final Map<String, Uint8List> _thumbnailCache = {};

  // Platform usage tracking for dynamic ranking
  final Map<String, int> _platformUsageCount = {};

  /// Prefetch share payload immediately; thumbnail generates in background.
  Future<SharePayload> fetchSharePayload(HomeVideo video) async {
    if (_sharePayloadCache.containsKey(video.id)) {
      if (!_shareVideoPayloadCache.containsKey(video.id)) {
        _shareVideoPayloadCache[video.id] =
            ShareVideoPayload.fromHomeVideo(video);
      }
      return _sharePayloadCache[video.id]!;
    }

    try {
      LoggingService.instance.info(
        '🎬 EnhancedShareService: Building share payload for video ${video.id}',
        tag: 'EnhancedShareService',
      );

      final SharePayload payload = SharePayload(
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

      _sharePayloadCache[video.id] = payload;

      Map<String, dynamic> videoDoc = <String, dynamic>{};
      try {
        final DocumentSnapshot<Map<String, dynamic>> snap =
            await FirebaseFirestore.instance
                .collection('videos')
                .doc(video.id)
                .get();
        if (snap.exists) {
          videoDoc = snap.data() ?? <String, dynamic>{};
        }
      } catch (e) {
        log('⚠️ EnhancedShareService: video doc fetch: $e');
      }
      _shareVideoPayloadCache[video.id] =
          ShareVideoPayload.fromHomeVideo(video, videoDoc: videoDoc);

      ConnectionsService().getConnectionsPreview().catchError((Object e) {
        log('⚠️ EnhancedShareService: Failed to prefetch connections: $e');
        return <ConnectionLite>[];
      });

      _generateVideoThumbnail(video).catchError((Object e) {
        log('⚠️ EnhancedShareService: Background thumbnail: $e');
        return null;
      });

      LoggingService.instance.info(
        '✅ EnhancedShareService: Payload ready for ${video.id} (thumbnail in background)',
        tag: 'EnhancedShareService',
      );

      return payload;
    } catch (e, st) {
      LoggingService.instance.error(
        '❌ EnhancedShareService: Error fetching share payload: $e',
        tag: 'EnhancedShareService',
        error: e,
        stackTrace: st,
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
        _shareVideoPayloadCache.remove(key);
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
    } on ShareUserNoticeException {
      rethrow;
    } catch (e, st) {
      LoggingService.instance.error(
        '❌ EnhancedShareService: Error sharing to ${target.displayName}: $e',
        tag: 'EnhancedShareService',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  ShareVideoPayload? shareVideoPayloadFor(String videoId) =>
      _shareVideoPayloadCache[videoId];

  Future<XFile?> _shareableVideoXFile(SharePayload payload) async {
    final ShareVideoPayload? extra = _shareVideoPayloadCache[payload.videoId];
    final String? url = extra?.watermarkUrl;
    if (url == null || url.isEmpty) {
      return null;
    }
    final String lower = url.toLowerCase();
    if (!lower.startsWith('http')) {
      return null;
    }
    if (lower.contains('.m3u8')) {
      return null;
    }
    try {
      final Uri uri = Uri.parse(url);
      final http.Response response = await http
          .get(uri)
          .timeout(const Duration(seconds: 50));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        return null;
      }
      final Directory dir = await getTemporaryDirectory();
      final String ext =
          lower.contains('.mp4') ? 'mp4' : (lower.contains('.mov') ? 'mov' : 'bin');
      final File file =
          File('${dir.path}/st_share_${payload.videoId}.$ext');
      await file.writeAsBytes(response.bodyBytes, flush: true);
      return XFile(file.path);
    } catch (e, st) {
      LoggingService.instance.error(
        '❌ EnhancedShareService: share file download: $e',
        tag: 'EnhancedShareService',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  Future<void> _shareWithOptionalVideoFile(SharePayload payload) async {
    final String message = _buildRichShareText(payload);
    final XFile? file = await _shareableVideoXFile(payload);
    final ShareParams shareParams = file != null
        ? ShareParams(
            text: message,
            files: <XFile>[file],
            subject: 'StreamersTip video',
          )
        : ShareParams(
            text: message,
            subject: 'Check out this video on StreamersTip!',
            uri: Uri.tryParse(payload.links.webShareUrl),
          );
    final ShareResult result = await SharePlus.instance.share(shareParams);
    if (result.status == ShareResultStatus.dismissed) {
      trackShareCancel(payload.videoId);
    }
  }

  /// Copy link with rich preview data
  Future<void> _copyLinkWithPreview(SharePayload payload) async {
    try {
      final String url = ShareVideoPayload.buildPublicUrl(payload.videoId);
      await Clipboard.setData(ClipboardData(text: url));

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

  /// Opens the native share sheet; prefers a watermarked MP4 when available.
  Future<void> _shareToInstagramDirect(SharePayload payload) async {
    try {
      final Uri ig = Uri.parse('instagram://app');
      final bool hasInstagram = await canLaunchUrl(ig);
      await _shareWithOptionalVideoFile(payload);
      if (!hasInstagram) {
        throw ShareUserNoticeException(
          'Instagram not detected. Use the share sheet to open Instagram '
          'or save your clip.',
        );
      }
    } catch (e) {
      if (e is ShareUserNoticeException) {
        rethrow;
      }
      LoggingService.instance.error(
        '❌ EnhancedShareService: Error sharing to Instagram: $e',
        tag: 'EnhancedShareService',
        error: e,
      );
      await _shareWithOptionalVideoFile(payload);
    }
  }

  /// Share via SMS with rich preview
  Future<void> _shareViaSMSWithPreview(SharePayload payload) async {
    try {
      final String message = _buildRichShareText(payload);
      final Uri uri = Uri.parse('sms:&body=${Uri.encodeComponent(message)}');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
      await _shareWithOptionalVideoFile(payload);
      throw ShareUserNoticeException(
        'Messages could not be opened. Use the share sheet instead.',
      );
    } on ShareUserNoticeException {
      rethrow;
    } catch (e, st) {
      LoggingService.instance.error(
        '❌ EnhancedShareService: Error sharing via SMS: $e',
        tag: 'EnhancedShareService',
        error: e,
        stackTrace: st,
      );
      await _shareWithOptionalVideoFile(payload);
    }
  }

  /// Share to WhatsApp with rich preview
  Future<void> _shareToWhatsAppWithPreview(SharePayload payload) async {
    final String message = _buildRichShareText(payload);
    final Uri uri =
        Uri.parse('whatsapp://send?text=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    final Uri webUri =
        Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(webUri)) {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
      return;
    }
    await _shareWithOptionalVideoFile(payload);
    throw ShareUserNoticeException(
      'WhatsApp is not installed. Opened the share sheet with your link.',
    );
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

  /// Native share sheet: text + subject + optional watermarked file.
  Future<void> _shareToSystemWithPreview(SharePayload payload) async {
    try {
      await _shareWithOptionalVideoFile(payload);
    } catch (e, st) {
      LoggingService.instance.error(
        '❌ EnhancedShareService: Error sharing to system: $e',
        tag: 'EnhancedShareService',
        error: e,
        stackTrace: st,
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

  /// TikTok-style row: copy, messages, top social apps, system share.
  List<ShareTarget> getRankedTargets() {
    if (Platform.isIOS) {
      return <ShareTarget>[
        ShareTarget.copyLink,
        ShareTarget.sms,
        ShareTarget.instagramDirect,
        ShareTarget.whatsapp,
        ShareTarget.more,
      ];
    }
    return <ShareTarget>[
      ShareTarget.copyLink,
      ShareTarget.whatsapp,
      ShareTarget.sms,
      ShareTarget.facebook,
      ShareTarget.instagramDirect,
      ShareTarget.more,
    ];
  }
}
