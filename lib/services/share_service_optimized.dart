import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/home_video.dart';
import 'engagement_analytics_service.dart';

class ShareServiceOptimized {
  static final ShareServiceOptimized _instance = ShareServiceOptimized._internal();
  factory ShareServiceOptimized() => _instance;
  ShareServiceOptimized._internal();

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
      await Share.share(
        '$shareText\n\n$shareUrl',
        subject: 'StreamersTip Video',
      );
    } catch (e) {
      print('Error sharing video: $e');
    }
  }

  /// Copy video link to clipboard
  Future<void> copyLink(HomeVideo video) async {
    try {
      final link = _generateShareUrl(video.id);
      await Clipboard.setData(ClipboardData(text: link));
      
      // Track copy engagement
      EngagementAnalyticsService().trackEngagement(
        videoId: video.id,
        event: EngagementEvent.share,
        metadata: {
          'timestamp': DateTime.now().toIso8601String(),
          'shareMethod': 'copy_link',
        },
      );
    } catch (e) {
      print('Error copying link: $e');
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
          await _shareViaEmail(video, shareText, shareUrl);
          break;
      }
    } catch (e) {
      print('Error sharing to ${platform.name}: $e');
    }
  }

  /// Generate share text for video
  String _generateShareText(HomeVideo video) {
    final creator = video.creator;
    final caption = video.caption.isNotEmpty ? video.caption : 'Check out this amazing video!';
    
    return 'Check out this video by @${creator.username} on StreamersTip!\n\n$caption\n\n#StreamersTip #${creator.username}';
  }

  /// Generate share URL for video
  String _generateShareUrl(String videoId) {
    return 'https://streamerstip.com/video/$videoId';
  }

  /// Share to WhatsApp
  Future<void> _shareToWhatsApp(String message) async {
    final uri = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      // Fallback to web WhatsApp
      final webUri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}');
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  /// Share to Instagram
  Future<void> _shareToInstagram(HomeVideo video) async {
    // For Instagram, we can only share the link as Instagram doesn't support direct video sharing
    final message = _generateShareText(video);
    final uri = Uri.parse('instagram://library?AssetPath=${Uri.encodeComponent(video.videoURL)}');
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      // Fallback to system share
      await Share.share(message);
    }
  }

  /// Share to Twitter
  Future<void> _shareToTwitter(String message) async {
    final uri = Uri.parse('twitter://post?message=${Uri.encodeComponent(message)}');
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      // Fallback to web Twitter
      final webUri = Uri.parse('https://twitter.com/intent/tweet?text=${Uri.encodeComponent(message)}');
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
      final webUri = Uri.parse('https://www.facebook.com/sharer/sharer.php?u=${Uri.encodeComponent(url)}');
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
      final webUri = Uri.parse('https://t.me/share/url?url=${Uri.encodeComponent(message)}');
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  /// Share via SMS
  Future<void> _shareViaSMS(String message) async {
    final uri = Uri.parse('sms:?body=${Uri.encodeComponent(message)}');
    await launchUrl(uri);
  }

  /// Share via Email
  Future<void> _shareViaEmail(HomeVideo video, String text, String url) async {
    final subject = 'Check out this video on StreamersTip!';
    final body = '$text\n\n$url';
    
    final uri = Uri.parse('mailto:?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}');
    await launchUrl(uri);
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
