import 'dart:io';
import 'package:flutter/material.dart';

class VideoWatermarkService {
  static const String starterTier = 'starter';
  static const String proTier = 'pro';
  static const String studioTier = 'studio';
  static const String defaultWatermarkAsset =
      'assets/091225_ST_logo_white.PNG';

  static final VideoWatermarkService _instance = VideoWatermarkService._internal();
  factory VideoWatermarkService() => _instance;
  VideoWatermarkService._internal();

  int maxPlatformsForTier(String tier) {
    switch (tier.toLowerCase()) {
      case proTier:
        return 5;
      case studioTier:
        return 999;
      case starterTier:
      default:
        return 1;
    }
  }

  bool requiresWatermarkForTier(String tier) {
    return tier.toLowerCase() == starterTier;
  }

  String planLabel(String tier) {
    switch (tier.toLowerCase()) {
      case proTier:
        return 'Pro';
      case studioTier:
        return 'Studio';
      case starterTier:
      default:
        return 'Free';
    }
  }

  /// Adds watermark to video file when cross-platform sharing is enabled
  Future<File?> addWatermarkToVideo({
    required File videoFile,
    required Set<String> selectedPlatforms,
    String? logoPath,
  }) async {
    // If no platforms are selected, return original file
    if (selectedPlatforms.isEmpty) {
      return videoFile;
    }

    try {
      // For now, we'll return the original file
      // In a real implementation, you would use FFmpeg or similar to add watermark
    // print('🎬 Adding watermark for platforms: ${selectedPlatforms.join(', ')}');
      
      // Placeholder - would implement video watermarking with FFmpeg
      // This would involve:
      // 1. Loading the logo image
      // 2. Using FFmpeg to overlay the logo on the video
      // 3. Saving the watermarked video to a new file
      
      return videoFile;
    } catch (e) {
    // print('❌ Error adding watermark: $e');
      return videoFile; // Return original file if watermarking fails
    }
  }

  /// Creates a watermark overlay widget
  Widget createWatermarkOverlay({
    required String logoPath,
    double opacity = 0.8,
    double size = 48.0,
  }) {
    return Positioned(
      right: 18,
      bottom: 74,
      child: Opacity(
        opacity: opacity,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.34),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.26),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(
                    image: AssetImage(logoPath),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'StreamersTip',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.95),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Checks if watermark should be applied based on selected platforms
  bool shouldApplyWatermark(Set<String> selectedPlatforms) {
    return selectedPlatforms.isNotEmpty;
  }

  bool shouldApplyWatermarkForTier(String tier, Set<String> selectedPlatforms) {
    if (selectedPlatforms.isEmpty) {
      return false;
    }
    return requiresWatermarkForTier(tier);
  }

  /// Gets watermark configuration for specific platform
  Map<String, dynamic> getWatermarkConfig(String platform) {
    switch (platform.toLowerCase()) {
      case 'instagram':
        return {
          'position': 'lower_float',
          'size': 0.075,
          'opacity': 0.88,
          'marginRight': 18,
          'marginBottom': 74,
        };
      case 'tiktok':
        return {
          'position': 'lower_float',
          'size': 0.07,
          'opacity': 0.9,
          'marginRight': 18,
          'marginBottom': 74,
        };
      case 'youtube':
        return {
          'position': 'lower_float',
          'size': 0.08,
          'opacity': 0.86,
          'marginRight': 18,
          'marginBottom': 74,
        };
      default:
        return {
          'position': 'lower_float',
          'size': 0.075,
          'opacity': 0.88,
          'marginRight': 18,
          'marginBottom': 74,
        };
    }
  }
}
