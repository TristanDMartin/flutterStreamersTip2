import 'dart:io';
import 'package:flutter/material.dart';

class VideoWatermarkService {
  static final VideoWatermarkService _instance = VideoWatermarkService._internal();
  factory VideoWatermarkService() => _instance;
  VideoWatermarkService._internal();

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
      print('🎬 Adding watermark for platforms: ${selectedPlatforms.join(', ')}');
      
      // TODO: Implement actual video watermarking with FFmpeg
      // This would involve:
      // 1. Loading the logo image
      // 2. Using FFmpeg to overlay the logo on the video
      // 3. Saving the watermarked video to a new file
      
      return videoFile;
    } catch (e) {
      print('❌ Error adding watermark: $e');
      return videoFile; // Return original file if watermarking fails
    }
  }

  /// Creates a watermark overlay widget
  Widget createWatermarkOverlay({
    required String logoPath,
    Alignment alignment = Alignment.bottomRight,
    double opacity = 0.8,
    double size = 60.0,
  }) {
    return Positioned(
      right: 16,
      bottom: 16,
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(logoPath),
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }

  /// Checks if watermark should be applied based on selected platforms
  bool shouldApplyWatermark(Set<String> selectedPlatforms) {
    return selectedPlatforms.isNotEmpty;
  }

  /// Gets watermark configuration for specific platform
  Map<String, dynamic> getWatermarkConfig(String platform) {
    switch (platform.toLowerCase()) {
      case 'instagram':
        return {
          'position': 'bottom_right',
          'size': 0.1, // 10% of video width
          'opacity': 0.8,
          'margin': 16,
        };
      case 'tiktok':
        return {
          'position': 'bottom_right',
          'size': 0.08, // 8% of video width
          'opacity': 0.9,
          'margin': 12,
        };
      case 'youtube':
        return {
          'position': 'bottom_right',
          'size': 0.12, // 12% of video width
          'opacity': 0.7,
          'margin': 20,
        };
      default:
        return {
          'position': 'bottom_right',
          'size': 0.1,
          'opacity': 0.8,
          'margin': 16,
        };
    }
  }
}
