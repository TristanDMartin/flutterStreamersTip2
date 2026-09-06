import 'dart:io';

import '../features/publish/publish_validation_limits.dart';

class VideoModerationResult {
  final bool isApproved;
  final List<String> violations;
  final String? reason;
  final double confidence;
  final Map<String, dynamic>? metadata;

  const VideoModerationResult({
    required this.isApproved,
    required this.violations,
    this.reason,
    required this.confidence,
    this.metadata,
  });

  bool get hasViolations => violations.isNotEmpty;
  bool get isBlocked => !isApproved;
}

class VideoModerationService {
  static final VideoModerationService _instance =
      VideoModerationService._internal();
  factory VideoModerationService() => _instance;
  VideoModerationService._internal();

  // Content moderation rules
  static const List<String> _hateSpeechTerms = [
    // Racial slurs and derogatory terms
    'nigger', 'nigga', 'chink', 'gook', 'wetback', 'spic', 'kike', 'fag',
    'faggot',
    'tranny', 'dyke', 'retard', 'retarded', 'cripple', 'midget', 'retard',

    // Hate speech patterns
    'kill all', 'exterminate', 'genocide', 'ethnic cleansing', 'white power',
    'black power', 'jew hater', 'muslim hater', 'christian hater', 'hate jews',
    'hate muslims', 'hate blacks', 'hate whites', 'hate asians',
    'hate mexicans',

    // Violent threats
    'i will kill', 'i will murder', 'i will rape', 'i will beat', 'i will hurt',
    'you should die', 'you should kill yourself', 'go kill yourself', 'kys',
    'i hope you die', 'i wish you were dead', 'you deserve to die',

    // Harassment and bullying
    'you are ugly', 'you are stupid', 'you are worthless', 'you are trash',
    'nobody likes you', 'everyone hates you', 'you should disappear',
    'you are a mistake', 'you are garbage', 'you are pathetic',

    // Sexual harassment
    'show me your', 'send nudes', 'send pics', 'you are hot', 'you are sexy',
    'i want to fuck', 'i want to rape', 'i want to touch', 'i want to see',

    // Discriminatory language
    'all women are', 'all men are', 'all blacks are', 'all whites are',
    'all asians are', 'all muslims are', 'all jews are', 'all gays are',
    'women belong in', 'men are better', 'blacks are', 'whites are superior',

    // Workarounds and leetspeak
    'n1gg3r', 'n1gga', 'ch1nk', 'g00k', 'w3tb4ck', 'sp1c', 'k1k3', 'f4g',
    'f4gg0t', 'tr4nny', 'dyk3', 'r3t4rd', 'cr1ppl3', 'm1dg3t',
    'n!gg3r', 'n!gga', 'ch!nk', 'g00k', 'w3tb4ck', 'sp!c', 'k!k3', 'f4g',
    'f4gg0t', 'tr4nny', 'dyk3', 'r3t4rd', 'cr1ppl3', 'm1dg3t',

    // Common misspellings and variations
    'niggar', 'niggah', 'nigguh', 'niggur', 'niggir', 'niggur',
    'chinkie', 'chinky', 'gooker', 'gooky', 'wetbacker', 'wetbacky',
    'spick', 'spic', 'kikey', 'kiky', 'faggy', 'faggoty', 'faggoty',
    'tranny', 'trannie', 'dykey', 'dyky', 'retardy', 'retardie',
    'cripply', 'cripplie', 'midgety', 'midgetie',
  ];

  static const List<String> _sexualContentTerms = [
    'porn',
    'pornography',
    'xxx',
    'sex',
    'sexual',
    'nude',
    'naked',
    'breast',
    'boob',
    'ass',
    'butt',
    'penis',
    'vagina',
    'dick',
    'pussy',
    'cock',
    'fuck',
    'fucking',
    'fucked',
    'fucker',
    'fuck you',
    'fuck off',
    'shit',
    'shitty',
    'shitting',
    'bitch',
    'bitches',
    'whore',
    'slut',
    'prostitute',
    'hooker',
    'escort',
    'stripper',
    'pornstar',
    'adult',
    'masturbate',
    'masturbation',
    'orgasm',
    'cum',
    'cumming',
    'ejaculate',
  ];

  // Moderation categories
  static const Map<String, List<String>> _moderationCategories = {
    'hate_speech': _hateSpeechTerms,
    'sexual_content': _sexualContentTerms,
  };

  /// Main moderation method for video content
  Future<VideoModerationResult> moderateVideo({
    required File videoFile,
    String? caption,
    List<String>? hashtags,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // 1. Check video file size and duration (same limits as publish validation)
      final int fileSize = await videoFile.length();
      final double duration = await _getVideoDuration(videoFile);
      final int maxBytes =
          PublishValidationLimits.maxFileSizeMB * 1024 * 1024;

      if (fileSize > maxBytes) {
        return const VideoModerationResult(
          isApproved: false,
          violations: <String>['file_too_large'],
          reason: PublishValidationLimits.errorFileSize,
          confidence: 1.0,
        );
      }

      if (duration > PublishValidationLimits.maxVideoDurationSeconds) {
        return const VideoModerationResult(
          isApproved: false,
          violations: <String>['duration_too_long'],
          reason: PublishValidationLimits.errorDuration,
          confidence: 1.0,
        );
      }

      // 2. Check text content (caption and hashtags)
      final textViolations = <String>[];
      final textContent = <String>[];

      if (caption != null && caption.isNotEmpty) {
        textContent.add(caption);
      }

      if (hashtags != null) {
        textContent.addAll(hashtags);
      }

      if (textContent.isNotEmpty) {
        final textResult = _moderateText(textContent.join(' '));
        textViolations.addAll(textResult.violations);
      }

      // 3. Check video metadata
      final metadataViolations = <String>[];
      if (metadata != null) {
        final metadataResult = _moderateMetadata(metadata);
        metadataViolations.addAll(metadataResult.violations);
      }

      // 4. Perform video content analysis (placeholder for ML/AI)
      final videoViolations = await _analyzeVideoContent(videoFile);

      // 5. Combine all violations
      final allViolations = <String>[];
      allViolations.addAll(textViolations);
      allViolations.addAll(metadataViolations);
      allViolations.addAll(videoViolations);

      // 6. Determine approval status
      final isApproved = allViolations.isEmpty;
      final confidence = _calculateConfidence(allViolations);

      return VideoModerationResult(
        isApproved: isApproved,
        violations: allViolations,
        reason: isApproved ? null : _generateRejectionReason(allViolations),
        confidence: confidence,
        metadata: {
          'file_size': fileSize,
          'duration': duration,
          'text_violations': textViolations,
          'metadata_violations': metadataViolations,
          'video_violations': videoViolations,
        },
      );
    } catch (e) {
      // If moderation fails, err on the side of caution
      return VideoModerationResult(
        isApproved: false,
        violations: ['moderation_error'],
        reason: 'Unable to moderate content. Please try again.',
        confidence: 0.0,
        metadata: {'error': e.toString()},
      );
    }
  }

  /// Moderate text content for inappropriate language
  VideoModerationResult _moderateText(String text) {
    final violations = <String>[];
    final normalizedText = _normalizeText(text);

    for (final category in _moderationCategories.keys) {
      final terms = _moderationCategories[category]!;
      for (final term in terms) {
        if (normalizedText.contains(term.toLowerCase())) {
          violations.add(category);
          break; // Only add category once
        }
      }
    }

    return VideoModerationResult(
      isApproved: violations.isEmpty,
      violations: violations,
      confidence: violations.isEmpty ? 1.0 : 0.8,
    );
  }

  /// Moderate metadata for inappropriate content
  VideoModerationResult _moderateMetadata(Map<String, dynamic> metadata) {
    final violations = <String>[];
    final metadataString =
        metadata.values.whereType<String>().join(' ').toLowerCase();

    if (metadataString.isNotEmpty) {
      final textResult = _moderateText(metadataString);
      violations.addAll(textResult.violations);
    }

    return VideoModerationResult(
      isApproved: violations.isEmpty,
      violations: violations,
      confidence: violations.isEmpty ? 1.0 : 0.7,
    );
  }

  /// Analyze video content for inappropriate material (placeholder)
  Future<List<String>> _analyzeVideoContent(File videoFile) async {
    // This would integrate with ML/AI services like:
    // - Google Cloud Video Intelligence API
    // - AWS Rekognition
    // - Azure Video Indexer
    // - On-device ML models

    // For now, return empty list (no violations detected)
    // In production, this would analyze:
    // - Visual content for violence, nudity, etc.
    // - Audio content for inappropriate language
    // - Scene detection for harmful content

    return [];
  }

  /// Get video duration in seconds
  Future<double> _getVideoDuration(File videoFile) async {
    try {
      // This would use a video processing library like:
      // - video_player package
      // - ffmpeg_kit_flutter
      // - video_thumbnail package

      // For now, return a placeholder duration
      return 30.0; // 30 seconds placeholder
    } catch (e) {
      return 0.0;
    }
  }

  /// Normalize text for better detection
  String _normalizeText(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '') // Remove punctuation
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
        .trim();
  }

  /// Calculate confidence score based on violations
  double _calculateConfidence(List<String> violations) {
    if (violations.isEmpty) return 1.0;

    // Higher confidence for more serious violations
    final seriousViolations = ['hate_speech', 'violence', 'sexual_content'];
    final seriousCount =
        violations.where((v) => seriousViolations.contains(v)).length;

    return (1.0 - (violations.length * 0.2) - (seriousCount * 0.3))
        .clamp(0.0, 1.0);
  }

  /// Generate human-readable rejection reason
  String _generateRejectionReason(List<String> violations) {
    if (violations.isEmpty) return 'Content approved';

    final reasons = <String>[];

    if (violations.contains('hate_speech')) {
      reasons.add('hate speech or discriminatory language');
    }
    if (violations.contains('sexual_content')) {
      reasons.add('inappropriate sexual content');
    }
    if (violations.contains('file_too_large')) {
      reasons.add('file size exceeds limit');
    }
    if (violations.contains('duration_too_long')) {
      reasons.add('video duration exceeds limit');
    }

    return 'Content rejected due to: ${reasons.join(', ')}';
  }

  /// Check if content is safe for upload
  Future<bool> isContentSafe({
    required File videoFile,
    String? caption,
    List<String>? hashtags,
    Map<String, dynamic>? metadata,
  }) async {
    final result = await moderateVideo(
      videoFile: videoFile,
      caption: caption,
      hashtags: hashtags,
      metadata: metadata,
    );

    return result.isApproved;
  }

  /// Get moderation report for debugging
  Future<Map<String, dynamic>> getModerationReport({
    required File videoFile,
    String? caption,
    List<String>? hashtags,
    Map<String, dynamic>? metadata,
  }) async {
    final result = await moderateVideo(
      videoFile: videoFile,
      caption: caption,
      hashtags: hashtags,
      metadata: metadata,
    );

    return {
      'approved': result.isApproved,
      'violations': result.violations,
      'reason': result.reason,
      'confidence': result.confidence,
      'metadata': result.metadata,
    };
  }
}
