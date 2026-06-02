class UploadJob {
  final String localId;
  final String fileUri;
  final String? thumbUri;
  final String title;
  final List<String> categories;
  final DateTime createdAt;
  final UploadJobState state;
  final String? videoId;
  final double? progress;
  final String? errorMessage;
  final Map<String, dynamic>? metadata;

  const UploadJob({
    required this.localId,
    required this.fileUri,
    this.thumbUri,
    required this.title,
    required this.categories,
    required this.createdAt,
    required this.state,
    this.videoId,
    this.progress,
    this.errorMessage,
    this.metadata,
  });

  factory UploadJob.fromJson(Map<String, dynamic> json) {
    return UploadJob(
      localId: json['localId'] as String,
      fileUri: json['fileUri'] as String,
      thumbUri: json['thumbUri'] as String?,
      title: json['title'] as String,
      categories: List<String>.from(json['categories'] as List),
      createdAt: DateTime.parse(json['createdAt'] as String),
      state: UploadJobState.values.firstWhere(
        (e) => e.name == json['state'] as String,
        orElse: () => UploadJobState.queued,
      ),
      videoId: json['videoId'] as String?,
      progress: (json['progress'] as num?)?.toDouble(),
      errorMessage: json['errorMessage'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'localId': localId,
      'fileUri': fileUri,
      'thumbUri': thumbUri,
      'title': title,
      'categories': categories,
      'createdAt': createdAt.toIso8601String(),
      'state': state.name,
      'videoId': videoId,
      'progress': progress,
      'errorMessage': errorMessage,
      'metadata': metadata,
    };
  }

  UploadJob copyWith({
    String? localId,
    String? fileUri,
    String? thumbUri,
    String? title,
    List<String>? categories,
    DateTime? createdAt,
    UploadJobState? state,
    String? videoId,
    double? progress,
    String? errorMessage,
    Map<String, dynamic>? metadata,
  }) {
    return UploadJob(
      localId: localId ?? this.localId,
      fileUri: fileUri ?? this.fileUri,
      thumbUri: thumbUri ?? this.thumbUri,
      title: title ?? this.title,
      categories: categories ?? this.categories,
      createdAt: createdAt ?? this.createdAt,
      state: state ?? this.state,
      videoId: videoId ?? this.videoId,
      progress: progress ?? this.progress,
      errorMessage: errorMessage ?? this.errorMessage,
      metadata: metadata ?? this.metadata,
    );
  }
}

enum UploadJobState {
  idle,
  validating,
  uploading,
  processing,
  ready,
  failed,

  /// Legacy alias kept for JSON backwards-compat; treated as [uploading].
  queued,

  /// Legacy alias kept for JSON backwards-compat; treated as [ready].
  done,
}

extension UploadJobStateExtension on UploadJobState {
  String get displayName {
    switch (this) {
      case UploadJobState.idle:
        return 'Idle';
      case UploadJobState.validating:
        return 'Validating';
      case UploadJobState.uploading:
      case UploadJobState.queued:
        return 'Uploading';
      case UploadJobState.processing:
        return 'Processing';
      case UploadJobState.ready:
      case UploadJobState.done:
        return 'Live';
      case UploadJobState.failed:
        return 'Failed';
    }
  }

  bool get isActive =>
      this == UploadJobState.validating ||
      this == UploadJobState.uploading ||
      this == UploadJobState.queued ||
      this == UploadJobState.processing;

  bool get isCompleted =>
      this == UploadJobState.ready || this == UploadJobState.done;

  bool get hasFailed => this == UploadJobState.failed;
}
