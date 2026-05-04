import 'home_video.dart';

/// Unified payload for outbound video shares (DM, system sheet, social).
class ShareVideoPayload {
  const ShareVideoPayload({
    required this.videoId,
    required this.creatorId,
    required this.creatorUsername,
    this.caption,
    this.thumbnailUrl,
    this.hlsUrl,
    this.muxPlaybackId,
    required this.publicUrl,
    required this.deepLink,
    this.watermarkUrl,
  });

  final String videoId;
  final String creatorId;
  final String creatorUsername;
  final String? caption;
  final String? thumbnailUrl;
  final String? hlsUrl;
  final String? muxPlaybackId;
  final String publicUrl;
  final String deepLink;
  final String? watermarkUrl;

  static String buildPublicUrl(String videoId) =>
      'https://streamerstip.com/video/$videoId';

  static String buildDeepLink(String videoId) =>
      'streamerstip://video/$videoId';

  /// Builds from feed [video] plus optional Firestore `videos/{id}` map.
  factory ShareVideoPayload.fromHomeVideo(
    HomeVideo video, {
    Map<String, dynamic>? videoDoc,
  }) {
    final String videoId = video.id;
    final Map<String, dynamic> d = videoDoc ?? <String, dynamic>{};
    final String? muxId = d['muxPlaybackId'] as String?;
    final String? wm = _readWatermarkedUrl(d);
    return ShareVideoPayload(
      videoId: videoId,
      creatorId: video.creator.id,
      creatorUsername: video.creator.username,
      caption: video.caption.isEmpty ? null : video.caption,
      thumbnailUrl: video.thumbnailURL,
      hlsUrl: video.videoURL.isEmpty ? null : video.videoURL,
      muxPlaybackId: muxId,
      publicUrl: buildPublicUrl(videoId),
      deepLink: buildDeepLink(videoId),
      watermarkUrl: wm,
    );
  }

  static String? _readWatermarkedUrl(Map<String, dynamic> d) {
    const List<String> keys = <String>[
      'watermarkedDownloadUrl',
      'watermarkedUrl',
      'watermarkedVideoUrl',
      'brandedMp4Url',
      'crosspostWatermarkedUrl',
    ];
    for (final String key in keys) {
      final Object? v = d[key];
      if (v is String && v.trim().isNotEmpty) {
        return v.trim();
      }
    }
    final Object? nested = d['shareExports'];
    if (nested is Map<String, dynamic>) {
      final Object? w = nested['watermarked'] ?? nested['watermarkedUrl'];
      if (w is String && w.trim().isNotEmpty) {
        return w.trim();
      }
    }
    return null;
  }
}
