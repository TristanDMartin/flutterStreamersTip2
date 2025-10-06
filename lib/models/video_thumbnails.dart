import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'video_thumbnails.freezed.dart';

/// Model for video thumbnails with multiple sizes and metadata
@freezed
class VideoThumbnails with _$VideoThumbnails {
  const factory VideoThumbnails({
    /// Thumbnail URLs by width (e.g., {360: "url1", 540: "url2", 720: "url3"})
    @Default({}) Map<int, String> urls,

    /// Timestamp when thumbnails were generated (for cache busting)
    Timestamp? generatedAt,

    /// Aspect ratio of the thumbnails (should be 9:16 for consistency)
    @Default(9.0 / 16.0) double aspectRatio,

    /// Source frame timestamp (in seconds) used for thumbnail generation
    @Default(0.0) double sourceTimestamp,

    /// Quality score of the thumbnail (0.0 - 1.0)
    @Default(1.0) double qualityScore,

    /// Whether thumbnails are still being generated
    @Default(false) bool isGenerating,

    /// Error message if thumbnail generation failed
    String? errorMessage,
  }) = _VideoThumbnails;
}

/// Extension methods for VideoThumbnails
extension VideoThumbnailsExtension on VideoThumbnails {
  /// Get the best available thumbnail URL for a given width
  String? getUrlForSize(int width) {
    return urls[width];
  }

  /// Get the largest available thumbnail URL
  String? getLargestUrl() {
    if (urls.isEmpty) return null;

    final sortedSizes = urls.keys.toList()..sort();
    return urls[sortedSizes.last];
  }

  /// Get the smallest available thumbnail URL
  String? getSmallestUrl() {
    if (urls.isEmpty) return null;

    final sortedSizes = urls.keys.toList()..sort();
    return urls[sortedSizes.first];
  }

  /// Check if thumbnails are available for a given width
  bool hasSize(int width) {
    return urls.containsKey(width);
  }

  /// Get all available sizes
  List<int> getAvailableSizes() {
    return urls.keys.toList()..sort();
  }

  /// Check if thumbnails are valid (not generating, no errors, has URLs)
  bool get isValid => !isGenerating && errorMessage == null && urls.isNotEmpty;

  /// Get thumbnail count
  int get count => urls.length;

  /// Check if thumbnails are empty
  bool get isEmpty => urls.isEmpty;

  /// Get the optimal thumbnail URL for a given container width and device pixel ratio
  String? getOptimalUrl(double containerWidth, double devicePixelRatio) {
    if (urls.isEmpty) return null;

    final effectivePixels = (containerWidth * devicePixelRatio).round();
    final sortedSizes = urls.keys.toList()..sort();

    // Find the smallest thumbnail that meets or exceeds the effective pixel need
    for (final size in sortedSizes) {
      if (size >= effectivePixels) {
        return urls[size];
      }
    }

    // If no thumbnail is large enough, use the largest available
    return urls[sortedSizes.last];
  }

  /// Create a copy with updated URLs
  VideoThumbnails withUrls(Map<int, String> newUrls) {
    return copyWith(
      urls: newUrls,
      generatedAt: Timestamp.now(),
      isGenerating: false,
      errorMessage: null,
    );
  }

  /// Create a copy with a single URL added
  VideoThumbnails withUrlAdded(int width, String url) {
    final newUrls = Map<int, String>.from(urls);
    newUrls[width] = url;
    return copyWith(
      urls: newUrls,
      generatedAt: Timestamp.now(),
    );
  }

  /// Create a copy with generation state
  VideoThumbnails withGenerationState({
    required bool isGenerating,
    String? errorMessage,
  }) {
    return copyWith(
      isGenerating: isGenerating,
      errorMessage: errorMessage,
      generatedAt: isGenerating ? null : Timestamp.now(),
    );
  }
}

/// Helper class for creating VideoThumbnails
class VideoThumbnailsBuilder {
  final Map<int, String> _urls = {};
  Timestamp? _generatedAt;
  double _aspectRatio = 9.0 / 16.0;
  double _sourceTimestamp = 0.0;
  double _qualityScore = 1.0;
  bool _isGenerating = false;
  String? _errorMessage;

  /// Add a thumbnail URL for a specific width
  VideoThumbnailsBuilder addUrl(int width, String url) {
    _urls[width] = url;
    return this;
  }

  /// Set the generation timestamp
  VideoThumbnailsBuilder setGeneratedAt(Timestamp timestamp) {
    _generatedAt = timestamp;
    return this;
  }

  /// Set the aspect ratio
  VideoThumbnailsBuilder setAspectRatio(double ratio) {
    _aspectRatio = ratio;
    return this;
  }

  /// Set the source timestamp
  VideoThumbnailsBuilder setSourceTimestamp(double timestamp) {
    _sourceTimestamp = timestamp;
    return this;
  }

  /// Set the quality score
  VideoThumbnailsBuilder setQualityScore(double score) {
    _qualityScore = score;
    return this;
  }

  /// Set the generating state
  VideoThumbnailsBuilder setGenerating(bool generating) {
    _isGenerating = generating;
    return this;
  }

  /// Set the error message
  VideoThumbnailsBuilder setErrorMessage(String? error) {
    _errorMessage = error;
    return this;
  }

  /// Build the VideoThumbnails instance
  VideoThumbnails build() {
    return VideoThumbnails(
      urls: Map.unmodifiable(_urls),
      generatedAt: _generatedAt,
      aspectRatio: _aspectRatio,
      sourceTimestamp: _sourceTimestamp,
      qualityScore: _qualityScore,
      isGenerating: _isGenerating,
      errorMessage: _errorMessage,
    );
  }
}

/// Factory methods for common VideoThumbnails patterns
class VideoThumbnailsFactory {
  /// Create empty thumbnails (generating state)
  static VideoThumbnails generating() {
    return const VideoThumbnails(
      isGenerating: true,
      generatedAt: null,
    );
  }

  /// Create thumbnails with error state
  static VideoThumbnails error(String errorMessage) {
    return VideoThumbnails(
      isGenerating: false,
      errorMessage: errorMessage,
      generatedAt: Timestamp.now(),
    );
  }

  /// Create thumbnails from a single URL (legacy support)
  static VideoThumbnails fromSingleUrl(String url, {int width = 540}) {
    return VideoThumbnails(
      urls: {width: url},
      generatedAt: Timestamp.now(),
    );
  }

  /// Create thumbnails with standard sizes
  static VideoThumbnails standard({
    String? w360,
    String? w540,
    String? w720,
    Timestamp? generatedAt,
  }) {
    final urls = <int, String>{};
    if (w360 != null) urls[360] = w360;
    if (w540 != null) urls[540] = w540;
    if (w720 != null) urls[720] = w720;

    return VideoThumbnails(
      urls: urls,
      generatedAt: generatedAt ?? Timestamp.now(),
    );
  }

  /// Create thumbnails from Firestore document data
  static VideoThumbnails fromFirestoreData(Map<String, dynamic> data) {
    final thumbnailsData = data['thumbnails'] as Map<String, dynamic>?;
    if (thumbnailsData == null) {
      return VideoThumbnailsFactory.generating();
    }

    final urls = <int, String>{};
    final urlsData = thumbnailsData['urls'] as Map<String, dynamic>?;
    if (urlsData != null) {
      urlsData.forEach((key, value) {
        final width = int.tryParse(key);
        if (width != null && value is String) {
          urls[width] = value;
        }
      });
    }

    return VideoThumbnails(
      urls: urls,
      generatedAt: thumbnailsData['generatedAt'] as Timestamp?,
      aspectRatio:
          (thumbnailsData['aspectRatio'] as num?)?.toDouble() ?? 9.0 / 16.0,
      sourceTimestamp:
          (thumbnailsData['sourceTimestamp'] as num?)?.toDouble() ?? 0.0,
      qualityScore: (thumbnailsData['qualityScore'] as num?)?.toDouble() ?? 1.0,
      isGenerating: thumbnailsData['isGenerating'] as bool? ?? false,
      errorMessage: thumbnailsData['errorMessage'] as String?,
    );
  }
}
