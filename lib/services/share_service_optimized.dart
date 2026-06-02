import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/home_video.dart';
import '../models/share_payload.dart';
import '../models/connection_lite.dart';
import 'engagement_analytics_service.dart';
import 'connections_service.dart';
import 'package:streamers_tip/utils/secure_log.dart';

class ShareServiceOptimized {
  static final ShareServiceOptimized _instance =
      ShareServiceOptimized._internal();
  factory ShareServiceOptimized() => _instance;
  ShareServiceOptimized._internal() {
    _initializeDefaultUsage();
  }

  // Cache for prefetched share payloads
  final Map<String, SharePayload> _sharePayloadCache = {};

  // Platform usage tracking for dynamic ranking
  final Map<String, int> _platformUsageCount = {};

  /// Prefetch share data for instant modal display
  Future<SharePayload> fetchSharePayload(HomeVideo video) async {
    // Check cache first
    if (_sharePayloadCache.containsKey(video.id)) {
      return _sharePayloadCache[video.id]!;
    }

    try {
      // Build share payload
      final payload = SharePayload(
        videoId: video.id,
        links: ShareLinks(
          webShareUrl: _generateShareUrl(video.id),
          deepLink: 'streamerstip://video/${video.id}',
          downloadUrl: video.videoURL,
          embedCode: _generateEmbedCode(video.id),
        ),
        permissions: const SharePermissions(
          canShare: true,
          canDownload: true, // Default to true, can be configured later
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
        platformUsageRanking: Map.from(_platformUsageCount),
      );

      // Cache the payload
      _sharePayloadCache[video.id] = payload;

      // Prefetch connections for connections row (non-blocking)
      ConnectionsService().getConnectionsPreview().catchError((e) {
        secureLog('⚠️ ShareService: Failed to prefetch connections: $e');
        // If no connections exist, create mock connections for testing
        ConnectionsService().createMockConnections().catchError((mockError) {
          secureLog(
              '⚠️ ShareService: Failed to create mock connections: $mockError');
        });
        return <ConnectionLite>[]; // Return empty list on error
      });

      secureLog('✅ ShareService: Prefetched payload for video ${video.id}');

      return payload;
    } catch (e) {
      secureLog('❌ ShareService: Error fetching share payload: $e');
      rethrow;
    }
  }

  /// Get cached share payload (instant access)
  SharePayload? getCachedPayload(String videoId) {
    return _sharePayloadCache[videoId];
  }

  /// Clear old cache entries
  void clearOldCache() {
    if (_sharePayloadCache.length > 10) {
      final keysToRemove =
          _sharePayloadCache.keys.take(_sharePayloadCache.length - 10).toList();
      for (final key in keysToRemove) {
        _sharePayloadCache.remove(key);
      }
    }
  }

  /// Share video with system share sheet
  Future<void> shareVideo(HomeVideo video) async {
    try {
      // Track share engagement
      EngagementAnalyticsService().trackEngagement(
        videoId: video.id,
        event: EngagementEvent.share,
        metadata: {
          'timestamp': DateTime.now().toIso8601String(),
          'shareMethod': 'system_share',
        },
      );

      // Generate share content
      final shareText = _generateShareText(video);
      final shareUrl = _generateShareUrl(video.id);

      // Share using system share sheet
      await SharePlus.instance.share(
        ShareParams(
          text: '$shareText\n\n$shareUrl',
        ),
      );
    } catch (e) {
      // appLog('Error sharing video: $e');
    }
  }

  /// Copy video link to clipboard with analytics
  Future<void> copyLink(String videoId, String webShareUrl) async {
    try {
      await Clipboard.setData(ClipboardData(text: webShareUrl));

      // Track analytics
      trackShareEvent('share_copylink', videoId, 'copylink');
      _trackShareSuccess(videoId, 'copylink');
      _updatePlatformUsage('copylink');

      secureLog('✅ ShareService: Link copied to clipboard');
    } catch (e) {
      secureLog('❌ ShareService: Error copying link: $e');
    }
  }

  /// Share to specific target platform
  Future<void> shareToTarget(
    ShareTarget target,
    SharePayload payload,
  ) async {
    try {
      // Track sheet open and target tap
      trackShareEvent(
          'share_target_tap', payload.videoId, target.analyticsName);

      switch (target) {
        case ShareTarget.copyLink:
          await copyLink(payload.videoId, payload.links.webShareUrl);
          break;
        case ShareTarget.instagramDirect:
          await _shareToInstagramDirect(payload);
          break;
        case ShareTarget.sms:
          await _shareViaSMS(_buildShareMessage(payload));
          break;
        case ShareTarget.whatsapp:
          await _shareToWhatsApp(_buildShareMessage(payload));
          break;
        case ShareTarget.repost:
          await _handleRepost(payload);
          break;
        case ShareTarget.facebook:
          await _shareToFacebook(payload.links.webShareUrl);
          break;
        case ShareTarget.twitter:
          await _shareToTwitter(_buildShareMessage(payload));
          break;
        case ShareTarget.telegram:
          await _shareToTelegram(_buildShareMessage(payload));
          break;
        case ShareTarget.email:
          await _shareViaEmail(payload);
          break;
        case ShareTarget.more:
          await _shareToSystem(payload);
          break;
      }

      // Track success
      _trackShareSuccess(payload.videoId, target.analyticsName);
      _updatePlatformUsage(target.analyticsName);
    } catch (e) {
      secureLog('❌ ShareService: Error sharing to ${target.displayName}: $e');
    }
  }

  /// Handle contextual actions
  Future<void> handleAction(
      ShareAction action, String videoId, String creatorId) async {
    try {
      secureLog(
          '🎬 ShareService: Handling action: ${action.displayName} for video $videoId');

      // Track action
      EngagementAnalyticsService().trackEngagement(
        videoId: videoId,
        event: EngagementEvent.share,
        metadata: {
          'action': action.analyticsName,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      switch (action) {
        case ShareAction.report:
          // Will be handled by UI callback
          break;
        case ShareAction.block:
          // Will be handled by UI callback
          break;
        case ShareAction.sendMessage:
          // Will be handled by UI callback
          break;
        case ShareAction.notInterested:
          // Will be handled by UI callback
          break;
        case ShareAction.favorite:
          // Will be handled by UI callback
          break;
      }
    } catch (e) {
      secureLog('❌ ShareService: Error handling action: $e');
    }
  }

  /// Share to specific social platform
  Future<void> shareToPlatform(HomeVideo video, SharePlatform platform) async {
    try {
      final shareText = _generateShareText(video);
      final shareUrl = _generateShareUrl(video.id);
      final message = '$shareText $shareUrl';

      // Track share engagement
      EngagementAnalyticsService().trackEngagement(
        videoId: video.id,
        event: EngagementEvent.share,
        metadata: {
          'timestamp': DateTime.now().toIso8601String(),
          'shareMethod': platform.name,
        },
      );

      switch (platform) {
        case SharePlatform.whatsapp:
          await _shareToWhatsApp(message);
          break;
        case SharePlatform.instagram:
          await _shareToInstagram(video);
          break;
        case SharePlatform.twitter:
          await _shareToTwitter(message);
          break;
        case SharePlatform.facebook:
          await _shareToFacebook(shareUrl);
          break;
        case SharePlatform.telegram:
          await _shareToTelegram(message);
          break;
        case SharePlatform.sms:
          await _shareViaSMS(message);
          break;
        case SharePlatform.email:
          // Use legacy email sharing for old SharePlatform enum
          await _shareViaEmailLegacy(video, shareText, shareUrl);
          break;
      }
    } catch (e) {
      // appLog('Error sharing to ${platform.name}: $e');
    }
  }

  /// Generate share text for video
  String _generateShareText(HomeVideo video) {
    final creator = video.creator;
    final caption = video.caption.isNotEmpty
        ? video.caption
        : 'Check out this amazing video!';

    return 'Check out this video by @${creator.username} on StreamersTip!\n\n$caption\n\n#StreamersTip #${creator.username}';
  }

  /// Generate share URL for video
  String _generateShareUrl(String videoId) {
    return 'https://streamerstip.com/video/$videoId';
  }

  /// Share to WhatsApp
  Future<void> _shareToWhatsApp(String message) async {
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
  }

  /// Share to Instagram (legacy method - kept for compatibility)
  Future<void> _shareToInstagram(HomeVideo video) async {
    final message = _generateShareText(video);
    final uri = Uri.parse(
        'instagram://library?AssetPath=${Uri.encodeComponent(video.videoURL)}');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      // Fallback to system share
      await SharePlus.instance.share(
        ShareParams(
          text: message,
        ),
      );
    }
  }

  /// Share to Twitter
  Future<void> _shareToTwitter(String message) async {
    final uri =
        Uri.parse('twitter://post?message=${Uri.encodeComponent(message)}');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      // Fallback to web Twitter
      final webUri = Uri.parse(
          'https://twitter.com/intent/tweet?text=${Uri.encodeComponent(message)}');
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  /// Share to Facebook
  Future<void> _shareToFacebook(String url) async {
    final uri = Uri.parse('fb://share?link=${Uri.encodeComponent(url)}');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      // Fallback to web Facebook
      final webUri = Uri.parse(
          'https://www.facebook.com/sharer/sharer.php?u=${Uri.encodeComponent(url)}');
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  /// Share to Telegram
  Future<void> _shareToTelegram(String message) async {
    final uri = Uri.parse('tg://msg?text=${Uri.encodeComponent(message)}');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      // Fallback to web Telegram
      final webUri = Uri.parse(
          'https://t.me/share/url?url=${Uri.encodeComponent(message)}');
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  /// Share via SMS
  Future<void> _shareViaSMS(String message) async {
    final uri = Uri.parse('sms:?body=${Uri.encodeComponent(message)}');
    await launchUrl(uri);
  }

  /// Share via Email (updated)
  Future<void> _shareViaEmail(SharePayload payload) async {
    const subject = 'Check out this video on StreamersTip!';
    final body =
        '${_buildShareMessage(payload)}\n\n${payload.links.webShareUrl}';

    final uri = Uri.parse(
        'mailto:?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}');
    await launchUrl(uri);
  }

  /// Share via Email (legacy method for backward compatibility)
  Future<void> _shareViaEmailLegacy(
      HomeVideo video, String text, String url) async {
    const subject = 'Check out this video on StreamersTip!';
    final body = '$text\n\n$url';

    final uri = Uri.parse(
        'mailto:?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}');
    await launchUrl(uri);
  }

  /// Share to Instagram Direct
  Future<void> _shareToInstagramDirect(SharePayload payload) async {
    final uri = Uri.parse(
        'instagram://library?AssetPath=${Uri.encodeComponent(payload.links.downloadUrl ?? '')}');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      // Fallback to system share
      await _shareToSystem(payload);
    }
  }

  /// Share to system share sheet
  Future<void> _shareToSystem(SharePayload payload) async {
    final message = _buildShareMessage(payload);
    await SharePlus.instance.share(
      ShareParams(
        text: '$message\n\n${payload.links.webShareUrl}',
      ),
    );
  }

  /// Handle in-app repost
  Future<void> _handleRepost(SharePayload payload) async {
    secureLog('🔄 ShareService: Repost requested for video ${payload.videoId}');
    // This will be handled by UI callback to show repost dialog
  }

  /// Build share message from payload
  String _buildShareMessage(SharePayload payload) {
    final caption = payload.metadata.caption?.isNotEmpty == true
        ? payload.metadata.caption!
        : 'Check out this amazing video!';

    return 'Check out this video by @${payload.metadata.creatorUsername} on StreamersTip!\n\n$caption\n\n#StreamersTip #${payload.metadata.creatorUsername}';
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

  /// Generate embed code
  String _generateEmbedCode(String videoId) {
    return '<iframe src="https://streamerstip.com/embed/$videoId" width="100%" height="100%" frameborder="0"></iframe>';
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
      },
    );
  }

  /// Track download blocked
  void trackDownloadBlocked(String videoId, String reason) {
    EngagementAnalyticsService().trackEngagement(
      videoId: videoId,
      event: EngagementEvent.share,
      metadata: {
        'event': 'share_download_blocked',
        'reason': reason,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Update platform usage count for dynamic ranking
  void _updatePlatformUsage(String platform) {
    _platformUsageCount[platform] = (_platformUsageCount[platform] ?? 0) + 1;
  }

  /// Initialize default usage patterns for better initial ranking
  void _initializeDefaultUsage() {
    // Set some realistic initial usage counts to make ranking more interesting
    _platformUsageCount['sms'] = 15;
    _platformUsageCount['whatsapp'] = 12;
    _platformUsageCount['instagram_direct'] = 8;
    _platformUsageCount['facebook'] = 6;
    _platformUsageCount['twitter'] = 4;
    _platformUsageCount['telegram'] = 3;
    _platformUsageCount['email'] = 2;
    _platformUsageCount['system_share'] = 1;
  }

  /// Get ranked share targets based on usage
  /// Always puts Copy Link and StreamersTip Repost in top 3 spots
  List<ShareTarget> getRankedTargets() {
    final rankedTargets = <ShareTarget>[];

    // ALWAYS put Copy Link first (top priority)
    rankedTargets.add(ShareTarget.copyLink);

    // ALWAYS put StreamersTip Repost second (top priority)
    rankedTargets.add(ShareTarget.repost);

    // Get remaining targets sorted by usage frequency
    final remainingTargets = ShareTarget.values
        .where((target) =>
            target != ShareTarget.copyLink && target != ShareTarget.repost)
        .toList();

    remainingTargets.sort((a, b) {
      final aCount = _platformUsageCount[a.analyticsName] ?? 0;
      final bCount = _platformUsageCount[b.analyticsName] ?? 0;
      return bCount.compareTo(aCount); // Descending order by usage
    });

    // Add top 3 most used remaining targets (total of 5: Copy Link + Repost + 3 others)
    rankedTargets.addAll(remainingTargets.take(3));

    return rankedTargets;
  }
}

enum SharePlatform {
  whatsapp('WhatsApp', Icons.chat, Colors.green),
  instagram('Instagram', Icons.camera_alt, Colors.purple),
  twitter('Twitter', Icons.flutter_dash, Colors.blue),
  facebook('Facebook', Icons.facebook, Colors.blue),
  telegram('Telegram', Icons.send, Colors.blue),
  sms('SMS', Icons.message, Colors.green),
  email('Email', Icons.email, Colors.grey);

  const SharePlatform(this.displayName, this.icon, this.color);

  final String displayName;
  final IconData icon;
  final Color color;
}
