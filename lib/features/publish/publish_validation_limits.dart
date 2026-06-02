/// Validation limits and user-facing copy for the publish flow.
abstract final class PublishValidationLimits {
  static const int maxCaptionLength = 500;
  static const int maxFileSizeMB = 500;
  static const int minFileSizeBytes = 1024;
  static const double minVideoDurationSeconds = 1.0;
  static const double maxVideoDurationSeconds = 300.0;
  static const int minResolutionHeight = 480;

  static const List<String> allowedExtensions = <String>['mp4', 'mov', 'webm'];

  static const String errorFileType =
      'Please upload an MP4, MOV, or WebM file.';
  static const String errorFileSize =
      'File exceeds the 500MB limit. Please compress and retry.';
  static const String errorDuration =
      'Videos must be between 1 second and 5 minutes.';
  static const String errorResolution =
      'Video resolution is too low. Minimum 480p required.';
  static const String errorCaption = 'Please add a caption before publishing.';
  static const String errorCategory = 'Please select a category.';
  static const String warningAspectRatio =
      'Vertical video (9:16) performs best in the feed.';
}
