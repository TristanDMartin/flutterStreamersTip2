class OptimisticVideo {
  final String videoId;
  final String ownerId;
  final String caption;
  final List<String> categories;
  final DateTime createdAt;
  final VideoStatus status;
  final String? videoUrl;
  final String? thumbnailUrl;
  final String? hlsUrl;
  final int? duration;
  final int? fileSize;
  final Map<String, dynamic>? metadata;
  // Optimistic-specific fields
  final bool isOptimistic;
  final String? localThumbnailPath;
  final String? localVideoPath;
  final double? uploadProgress;
  final String? errorMessage;

  const OptimisticVideo({
    required this.videoId,
    required this.ownerId,
    required this.caption,
    required this.categories,
    required this.createdAt,
    required this.status,
    this.videoUrl,
    this.thumbnailUrl,
    this.hlsUrl,
    this.duration,
    this.fileSize,
    this.metadata,
    required this.isOptimistic,
    this.localThumbnailPath,
    this.localVideoPath,
    this.uploadProgress,
    this.errorMessage,
  });

  factory OptimisticVideo.fromJson(Map<String, dynamic> json) {
    return OptimisticVideo(
      videoId: json['videoId'] as String,
      ownerId: json['ownerId'] as String,
      caption: json['caption'] as String,
      categories: List<String>.from(json['categories'] as List),
      createdAt: DateTime.parse(json['createdAt'] as String),
      status: VideoStatus.values.firstWhere(
        (VideoStatus e) => e.name == json['status'] as String,
        orElse: () => VideoStatus.processing,
      ),
      videoUrl: json['videoUrl'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      hlsUrl: json['hlsUrl'] as String?,
      duration: json['duration'] as int?,
      fileSize: json['fileSize'] as int?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      isOptimistic: json['isOptimistic'] as bool? ?? false,
      localThumbnailPath: json['localThumbnailPath'] as String?,
      localVideoPath: json['localVideoPath'] as String?,
      uploadProgress: (json['uploadProgress'] as num?)?.toDouble(),
      errorMessage: json['errorMessage'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'videoId': videoId,
      'ownerId': ownerId,
      'caption': caption,
      'categories': categories,
      'createdAt': createdAt.toIso8601String(),
      'status': status.name,
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
      'hlsUrl': hlsUrl,
      'duration': duration,
      'fileSize': fileSize,
      'metadata': metadata,
      'isOptimistic': isOptimistic,
      'localThumbnailPath': localThumbnailPath,
      'localVideoPath': localVideoPath,
      'uploadProgress': uploadProgress,
      'errorMessage': errorMessage,
    };
  }

  OptimisticVideo copyWith({
    String? videoId,
    String? ownerId,
    String? caption,
    List<String>? categories,
    DateTime? createdAt,
    VideoStatus? status,
    String? videoUrl,
    String? thumbnailUrl,
    String? hlsUrl,
    int? duration,
    int? fileSize,
    Map<String, dynamic>? metadata,
    bool? isOptimistic,
    String? localThumbnailPath,
    String? localVideoPath,
    double? uploadProgress,
    String? errorMessage,
  }) {
    return OptimisticVideo(
      videoId: videoId ?? this.videoId,
      ownerId: ownerId ?? this.ownerId,
      caption: caption ?? this.caption,
      categories: categories ?? this.categories,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      videoUrl: videoUrl ?? this.videoUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      hlsUrl: hlsUrl ?? this.hlsUrl,
      duration: duration ?? this.duration,
      fileSize: fileSize ?? this.fileSize,
      metadata: metadata ?? this.metadata,
      isOptimistic: isOptimistic ?? this.isOptimistic,
      localThumbnailPath: localThumbnailPath ?? this.localThumbnailPath,
      localVideoPath: localVideoPath ?? this.localVideoPath,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

enum VideoStatus {
  placeholderPending,
  placeholderRejected,
  processing,
  uploadSucceeded,
  uploadFailed,
}

extension VideoStatusExtension on VideoStatus {
  String get displayName {
    switch (this) {
      case VideoStatus.placeholderPending:
        return 'Saving placeholder';
      case VideoStatus.placeholderRejected:
        return 'Placeholder failed';
      case VideoStatus.processing:
        return 'Processing';
      case VideoStatus.uploadSucceeded:
        return 'Published';
      case VideoStatus.uploadFailed:
        return 'Failed';
    }
  }

  bool get isPlaceholderPending => this == VideoStatus.placeholderPending;
  bool get isPlaceholderRejected => this == VideoStatus.placeholderRejected;
  bool get isProcessing => this == VideoStatus.processing;
  bool get isReady => this == VideoStatus.uploadSucceeded;
  bool get hasFailed =>
      this == VideoStatus.uploadFailed ||
      this == VideoStatus.placeholderRejected;

  static VideoStatus fromFirestoreStatus(String? raw) {
    switch (raw) {
      case 'ready':
        return VideoStatus.uploadSucceeded;
      case 'failed':
        return VideoStatus.uploadFailed;
      case 'processing':
      case 'uploading':
        return VideoStatus.processing;
      default:
        return VideoStatus.processing;
    }
  }
}

/// Factory for creating optimistic video placeholders
class OptimisticVideoFactory {
  /// Create optimistic video placeholder
  static OptimisticVideo createPlaceholder({
    required String videoId,
    required String ownerId,
    required String caption,
    required List<String> categories,
    String? localThumbnailPath,
    String? localVideoPath,
    Map<String, dynamic>? metadata,
  }) {
    return OptimisticVideo(
      videoId: videoId,
      ownerId: ownerId,
      caption: caption,
      categories: categories,
      createdAt: DateTime.now(),
      status: VideoStatus.placeholderPending,
      isOptimistic: true,
      localThumbnailPath: localThumbnailPath,
      localVideoPath: localVideoPath,
      metadata: metadata,
      uploadProgress: 0.0,
    );
  }

  /// Convert optimistic video to regular video (when upload completes)
  static OptimisticVideo markAsReady({
    required OptimisticVideo optimisticVideo,
    required String videoUrl,
    required String thumbnailUrl,
    String? hlsUrl,
    int? duration,
    int? fileSize,
  }) {
    return optimisticVideo.copyWith(
      status: VideoStatus.uploadSucceeded,
      videoUrl: videoUrl,
      thumbnailUrl: thumbnailUrl,
      hlsUrl: hlsUrl,
      duration: duration,
      fileSize: fileSize,
      isOptimistic: false,
      uploadProgress: 1.0,
    );
  }

  /// Mark optimistic video as failed
  static OptimisticVideo markAsFailed({
    required OptimisticVideo optimisticVideo,
    required String errorMessage,
  }) {
    return optimisticVideo.copyWith(
      status: VideoStatus.uploadFailed,
      errorMessage: errorMessage,
      isOptimistic: false,
    );
  }

  /// Update upload progress
  static OptimisticVideo updateProgress({
    required OptimisticVideo optimisticVideo,
    required double progress,
  }) {
    return optimisticVideo.copyWith(
      uploadProgress: progress,
    );
  }
}
