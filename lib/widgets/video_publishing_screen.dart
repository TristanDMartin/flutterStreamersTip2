import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:math';
import '../services/video_upload_service.dart';
import '../services/local_draft_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/video_moderation_service.dart';
import '../services/enhanced_error_handling_service.dart';
import '../services/video_watermark_service.dart';
import '../services/optimistic_video_service.dart';
import '../services/hashtag_lock_service.dart';
import '../widgets/schedule_post_widget.dart';
import '../models/scheduled_post.dart';
import '../services/firebase_ios_service.dart';
import '../services/network_connectivity_service.dart';
import '../services/video_processing_service.dart';
import '../services/upload_status_manager.dart';
import '../services/cross_post_service.dart';
import '../providers/publish_provider.dart';
import '../providers/feed_state_provider.dart';
import '../providers/video_service_provider.dart' as video_providers;
import '../routing/app_navigator.dart';
import '../widgets/platform_row.dart';
import '../constants/app_colors.dart';
import '../utils/category_schema.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:developer' as developer;

// Constants for video publishing validation
class _VideoPublishingConstants {
  static const int maxCaptionLength = 500;
  static const int maxFileSizeMB = 500;
  static const int minFileSizeBytes = 1024;
  static const double minVideoDurationSeconds = 1.0;
  static const double maxVideoDurationSeconds = 300.0;
  static const int minResolutionHeight = 480;

  static const List<String> allowedExtensions = ['mp4', 'mov', 'webm'];

  // Spec-exact error messages
  static const String errorFileType =
      'Please upload an MP4, MOV, or WebM file.';
  static const String errorFileSize =
      'File exceeds the 500MB limit. Please compress and retry.';
  static const String errorDuration =
      'Videos must be between 1 second and 5 minutes.';
  static const String errorResolution =
      'Video resolution is too low. Minimum 480p required.';
  static const String errorCaption =
      'Please add a caption before publishing.';
  static const String errorCategory = 'Please select a category.';
  static const String warningAspectRatio =
      'Vertical video (9:16) performs best in the feed.';
}

class VideoPublishingScreen extends ConsumerStatefulWidget {
  final File videoFile;
  final String caption;
  final List<String> hashtags;
  final VoidCallback onPublish;
  final VoidCallback onCancel;
  final String? draftId;
  final Map<String, dynamic>? draftData;

  const VideoPublishingScreen({
    super.key,
    required this.videoFile,
    required this.caption,
    required this.hashtags,
    required this.onPublish,
    required this.onCancel,
    this.draftId,
    this.draftData,
  });

  @override
  ConsumerState<VideoPublishingScreen> createState() =>
      _VideoPublishingScreenState();
}

// Category data structure
class VideoCategory {
  final String id;
  final String name;
  final String emoji;
  final IconData icon;
  final Color color;

  const VideoCategory({
    required this.id,
    required this.name,
    required this.emoji,
    required this.icon,
    required this.color,
  });
}

class _VideoPublishingScreenState extends ConsumerState<VideoPublishingScreen> {
  static const Set<String> _bypassStudioUids = {
    'bU0RxyZ2L4ULAv1Co5L4f825yV73',
    'jsmbQMLQjoUyC5cUFvkrRbi9mkp1',
  };

  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  String? _initializationError;
  bool _hasError = false;
  Duration? _videoDuration;
  int _captionCharacterCount = 0;
  final ScrollController _scrollController = ScrollController();
  double _videoFlex = 3.0; // Initial flex value for video preview

  // Available categories
  static const List<VideoCategory> _categories = [
    VideoCategory(
      id: 'gaming',
      name: 'Gaming',
      emoji: '🎮',
      icon: Icons.sports_esports,
      color: Color(0xFF9248D2), // Purple
    ),
    VideoCategory(
      id: 'art',
      name: 'Art',
      emoji: '🎨',
      icon: Icons.palette,
      color: Color(0xFF1670DE), // Blue
    ),
    VideoCategory(
      id: 'music',
      name: 'Music',
      emoji: '🎵',
      icon: Icons.music_note,
      color: Color(0xFFE91E63), // Pink
    ),
    VideoCategory(
      id: 'tech',
      name: 'Tech',
      emoji: '💻',
      icon: Icons.laptop,
      color: Color(0xFF4CAF50), // Green
    ),
    VideoCategory(
      id: 'sports',
      name: 'Sports',
      emoji: '⚽',
      icon: Icons.sports_soccer,
      color: Color(0xFFFF9800), // Orange
    ),
    VideoCategory(
      id: 'food',
      name: 'Food',
      emoji: '🍕',
      icon: Icons.restaurant,
      color: Color(0xFFF44336), // Red
    ),
    VideoCategory(
      id: 'just-chatting',
      name: 'Just Chatting',
      emoji: '💬',
      icon: Icons.chat,
      color: Color(0xFF00BCD4), // Cyan
    ),
    VideoCategory(
      id: 'tutorials',
      name: 'Tutorials',
      emoji: '📚',
      icon: Icons.school,
      color: Color(0xFF3F51B5), // Indigo
    ),
    VideoCategory(
      id: 'fitness',
      name: 'Fitness',
      emoji: '🏃',
      icon: Icons.fitness_center,
      color: Color(0xFF4DB6AC), // Mint
    ),
    VideoCategory(
      id: 'podcasts',
      name: 'Podcasts',
      emoji: '🎤',
      icon: Icons.mic,
      color: Color(0xFF795548), // Brown
    ),
    VideoCategory(
      id: 'fashion',
      name: 'Fashion',
      emoji: '👕',
      icon: Icons.checkroom,
      color: Color(0xFF9C27B0), // Purple
    ),
    VideoCategory(
      id: 'roleplay', // cspell:ignore roleplay
      name: 'Roleplay', // cspell:ignore Roleplay
      emoji: '🎭',
      icon: Icons.theater_comedy,
      color: Color(0xFFFFEB3B), // Yellow
    ),
  ];

  // Publishing state
  String _caption = '';
  List<String> _hashtags = [];
  String _selectedPrivacy = 'Everyone';
  String _selectedCategory = 'gaming'; // has default; user can change
  bool _allowComments = true;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _aspectRatioWarning;
  bool _aspectRatioWarningDismissed = false;

  // Thumbnail state
  double _thumbnailTimeSeconds = 0.0;
  bool _isCustomThumbnail = false;
  File? _customThumbnailFile;
  Uint8List? _frameThumbBytes;
  bool _isGeneratingThumb = false;
  bool _isModerating = false;
  bool _showThumbnailOptions = false;
  bool _showPrivacyOptions = false;
  bool _showCrossPostOptions = false;
  bool _showScheduleOptions = false;
  final Set<String> _selectedPlatforms = <String>{};
  PostSchedule? _schedule;
  String _subscriptionTier = VideoWatermarkService.starterTier;
  bool _isLoadingSubscriptionTier = true;

  // Cross-posting state
  /// Platforms from user's profile (display-linked, shown for cross-posting).
  List<({String name, IconData icon, Color color})> _connectedPlatforms = [];
  /// Which platform toggles are ON (default: all OFF per spec #7).
  final Map<String, bool> _platformEnabled = {};
  /// Per-platform caption (pre-filled from main caption, independently editable).
  final Map<String, String> _platformCaptions = {};

  final VideoModerationService _moderationService = VideoModerationService();
  final EnhancedErrorHandlingService _errorHandler =
      EnhancedErrorHandlingService();
  final VideoWatermarkService _watermarkService = VideoWatermarkService();
  final OptimisticVideoService _optimisticVideoService =
      OptimisticVideoService();
  // Text controllers
  late TextEditingController _captionController;

  @override
  void initState() {
    super.initState();
    _caption = widget.caption;
    _hashtags = List.from(widget.hashtags);
    _hydrateFromDraftData();

    // Initialize text controller with the caption
    _captionController = TextEditingController(text: _caption);
    _captionCharacterCount = _caption.length;
    
    // Listen to caption changes for real-time validation
    _captionController.addListener(_onCaptionChanged);

    // Listen to scroll to adjust video size
    _scrollController.addListener(_onScroll);

    _initializeVideo();
    _loadSubscriptionTier();
    _loadConnectedPlatforms();
  }

  bool get _isEditingDraft => widget.draftId?.isNotEmpty == true;

  void _hydrateFromDraftData() {
    final draft = widget.draftData;
    if (draft == null) return;

    final draftPrivacy = draft['privacy'] as String?;
    if (draftPrivacy != null && draftPrivacy.isNotEmpty) {
      _selectedPrivacy = draftPrivacy;
    }

    final draftCategory = draft['category'] as String?;
    if (draftCategory != null && draftCategory.isNotEmpty) {
      _selectedCategory = draftCategory;
    }

    final draftAllowComments = draft['allowComments'];
    if (draftAllowComments is bool) {
      _allowComments = draftAllowComments;
    }

    final metadata = draft['metadata'];
    if (metadata is Map) {
      final scheduledAtRaw = metadata['scheduled_at_utc']?.toString();
      final timezone = metadata['schedule_timezone']?.toString();
      final scheduledAt =
          scheduledAtRaw == null ? null : DateTime.tryParse(scheduledAtRaw);
      if (scheduledAt != null && timezone != null && timezone.isNotEmpty) {
        _schedule = PostSchedule(
          scheduledAtUtc: scheduledAt.toUtc(),
          timezone: timezone,
          createdAtUtc: scheduledAt.toUtc(),
          updatedAtUtc: DateTime.now().toUtc(),
        );
      }
    }
  }

  Set<String> get _effectiveSelectedPlatforms => _platformEnabled.entries
      .where((entry) => entry.value)
      .map((entry) => entry.key)
      .toSet();

  int get _selectedPlatformCount => _effectiveSelectedPlatforms.length;

  int get _maxCrossPostPlatforms =>
      _watermarkService.maxPlatformsForTier(_subscriptionTier);

  bool get _requiresCrossPostWatermark =>
      _watermarkService.shouldApplyWatermarkForTier(
        _subscriptionTier,
        _effectiveSelectedPlatforms,
      );

  String get _subscriptionPlanLabel =>
      _watermarkService.planLabel(_subscriptionTier);

  void _syncSelectedPlatforms() {
    _selectedPlatforms
      ..clear()
      ..addAll(_effectiveSelectedPlatforms);
  }

  Future<void> _loadSubscriptionTier() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _subscriptionTier = VideoWatermarkService.starterTier;
        _isLoadingSubscriptionTier = false;
      });
      return;
    }

    try {
      if (_bypassStudioUids.contains(user.uid)) {
        if (!mounted) return;
        setState(() {
          _subscriptionTier = VideoWatermarkService.studioTier;
          _isLoadingSubscriptionTier = false;
        });
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data() ?? const <String, dynamic>{};
      final rawTier = (data['subscriptionTier'] as String?)?.toLowerCase();
      final status = (data['subscriptionStatus'] as String?)?.toLowerCase();
      const validTiers = {
        VideoWatermarkService.starterTier,
        VideoWatermarkService.proTier,
        VideoWatermarkService.studioTier,
      };
      const activeStatuses = {'active', 'trialing'};

      final resolvedTier = validTiers.contains(rawTier) &&
              activeStatuses.contains(status)
          ? rawTier!
          : VideoWatermarkService.starterTier;

      if (!mounted) return;
      setState(() {
        _subscriptionTier = resolvedTier;
        _isLoadingSubscriptionTier = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _subscriptionTier = VideoWatermarkService.starterTier;
        _isLoadingSubscriptionTier = false;
      });
    }
  }

  Future<void> _loadConnectedPlatforms() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final raw = doc.data()?['platforms'];
      if (raw is! List || raw.isEmpty) return;
      final loaded = raw
          .whereType<Map<String, dynamic>>()
          .map((p) {
            final typeStr = p['type'] as String? ?? '';
            final icon = _iconForType(typeStr);
            final color = _colorForType(typeStr);
            final name = _displayNameForType(typeStr);
            return (name: name, icon: icon, color: color);
          })
          .where((p) => p.name.isNotEmpty)
          .toList();
      if (!mounted) return;
      setState(() {
        _connectedPlatforms = loaded;
        for (final p in loaded) {
          final draftSelections = widget.draftData?['metadata']
              is Map<String, dynamic>
              ? ((widget.draftData!['metadata']
                          as Map<String, dynamic>)['cross_platform_sharing']
                      as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toSet()
              : null;
          _platformEnabled[p.name] = draftSelections?.contains(p.name) ?? false;
          _platformCaptions[p.name] = _caption;
        }
        _syncSelectedPlatforms();
      });
    } catch (_) {
      // No platforms available — section hidden
    }
  }

  IconData _iconForType(String type) {
    switch (type.toLowerCase()) {
      case 'youtube': return Icons.play_circle;
      case 'tiktok': return Icons.music_note;
      case 'instagram': return Icons.camera_alt;
      case 'twitch': return Icons.live_tv;
      case 'kick': return Icons.sports_esports;
      case 'twitter': return Icons.alternate_email;
      case 'facebook': return Icons.facebook;
      case 'bluesky': return Icons.cloud;
      case 'reddit': return Icons.note;
      default: return Icons.link;
    }
  }

  Color _colorForType(String type) {
    switch (type.toLowerCase()) {
      case 'youtube': return const Color(0xFFFF0000);
      case 'tiktok': return const Color(0xFF69C9D0);
      case 'instagram': return const Color(0xFFE4405F);
      case 'twitch': return const Color(0xFF9146FF);
      case 'kick': return const Color(0xFF53FC18);
      case 'twitter': return const Color(0xFF1DA1F2);
      case 'facebook': return const Color(0xFF1877F2);
      case 'bluesky': return const Color(0xFF00A2FF);
      case 'reddit': return const Color(0xFFFF6B6B);
      default: return Colors.grey;
    }
  }

  String _displayNameForType(String type) {
    switch (type.toLowerCase()) {
      case 'youtube': return 'YouTube';
      case 'tiktok': return 'TikTok';
      case 'instagram': return 'Instagram';
      case 'twitch': return 'Twitch';
      case 'kick': return 'Kick';
      case 'twitter': return 'Twitter';
      case 'facebook': return 'Facebook';
      case 'bluesky': return 'Bluesky';
      case 'reddit': return 'Reddit';
      default: return '';
    }
  }

  void _onCaptionChanged() {
    final newCaption = _captionController.text;
    setState(() {
      _caption = newCaption;
      _captionCharacterCount = newCaption.length;
      // Sync captions for platforms that haven't been manually edited.
      for (final p in _connectedPlatforms) {
        if (!(_platformEnabled[p.name] ?? false)) {
          _platformCaptions[p.name] = newCaption;
        }
      }
    });
  }

  String _crossPostPlanDescription() {
    if (_isLoadingSubscriptionTier) {
      return 'Checking your creator plan...';
    }

    switch (_subscriptionTier) {
      case VideoWatermarkService.proTier:
        return 'Pro includes up to 5 connected destinations with no StreamersTip watermark.';
      case VideoWatermarkService.studioTier:
        return 'Studio includes unlimited connected destinations with no StreamersTip watermark.';
      case VideoWatermarkService.starterTier:
      default:
        return 'Free includes 1 connected destination, and StreamersTip branding stays on the exported post.';
    }
  }

  void _showCrossPostLimitNotice() {
    final message = _subscriptionTier == VideoWatermarkService.starterTier
        ? 'Free includes 1 connected platform with a StreamersTip watermark. Upgrade for more destinations.'
        : '$_subscriptionPlanLabel includes up to $_maxCrossPostPlatforms connected platforms.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF2B1A6B),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _handlePlatformToggle(String platformName, bool enabled) {
    final isCurrentlyEnabled = _platformEnabled[platformName] ?? false;
    if (!enabled) {
      setState(() {
        _platformEnabled[platformName] = false;
        _syncSelectedPlatforms();
      });
      return;
    }

    if (!isCurrentlyEnabled && _selectedPlatformCount >= _maxCrossPostPlatforms) {
      _showCrossPostLimitNotice();
      return;
    }

    setState(() {
      _platformEnabled[platformName] = true;
      _syncSelectedPlatforms();
    });
  }

  CrossPostRequest _buildCrossPostRequestForPlatform(
    String platformName, {
    DateTime? scheduleAt,
    String? videoId,
  }) {
    final requiresWatermark = _watermarkService.shouldApplyWatermarkForTier(
      _subscriptionTier,
      {platformName},
    );

    return CrossPostRequest(
      platformName: platformName,
      caption: _platformCaptions[platformName] ?? _caption,
      videoId: videoId,
      scheduleAt: scheduleAt,
      requiresWatermark: requiresWatermark,
      subscriptionTier: _subscriptionTier,
      watermarkAsset: requiresWatermark
          ? VideoWatermarkService.defaultWatermarkAsset
          : null,
      watermarkConfig: requiresWatermark
          ? _watermarkService.getWatermarkConfig(platformName)
          : null,
    );
  }

  void _onScroll() {
    final scrollOffset = _scrollController.offset;
    // Calculate new flex based on scroll position
    // When scrolled down, reduce video flex (min 1.0, max 3.0)
    final newFlex = (3.0 - (scrollOffset / 200).clamp(0.0, 2.0)).clamp(1.0, 3.0);
    if ((_videoFlex - newFlex).abs() > 0.1) {
      setState(() {
        _videoFlex = newFlex;
      });
    }
  }

  Future<void> _initializeVideo() async {
    try {
      if (!await widget.videoFile.exists()) {
        throw Exception('Video file does not exist');
      }

      // Rule 1: File type
      final extension =
          widget.videoFile.path.split('.').last.toLowerCase();
      if (!_VideoPublishingConstants.allowedExtensions.contains(extension)) {
        if (mounted) {
          setState(() {
            _hasError = true;
            _initializationError =
                _VideoPublishingConstants.errorFileType;
          });
        }
        return;
      }

      // Rule 2: File size
      final fileSize = await widget.videoFile.length();
      if (fileSize < _VideoPublishingConstants.minFileSizeBytes) {
        throw Exception('Video file is too small or corrupted');
      }
      final fileSizeMB = fileSize / (1024 * 1024);
      if (fileSizeMB > _VideoPublishingConstants.maxFileSizeMB) {
        if (mounted) {
          setState(() {
            _hasError = true;
            _initializationError = _VideoPublishingConstants.errorFileSize;
          });
        }
        return;
      }

      _controller = VideoPlayerController.file(widget.videoFile);
      await _controller.initialize();

      // Rule 3: Duration
      _videoDuration = _controller.value.duration;
      final durationSeconds = _videoDuration!.inSeconds.toDouble();
      if (durationSeconds < _VideoPublishingConstants.minVideoDurationSeconds ||
          durationSeconds > _VideoPublishingConstants.maxVideoDurationSeconds) {
        await _controller.dispose();
        if (mounted) {
          setState(() {
            _hasError = true;
            _initializationError = _VideoPublishingConstants.errorDuration;
          });
        }
        return;
      }

      // Rule 4: Resolution minimum (480p = shortest side ≥ 480)
      final videoSize = _controller.value.size;
      final shortSide = videoSize.height < videoSize.width
          ? videoSize.height
          : videoSize.width;
      if (shortSide > 0 &&
          shortSide < _VideoPublishingConstants.minResolutionHeight) {
        await _controller.dispose();
        if (mounted) {
          setState(() {
            _hasError = true;
            _initializationError =
                _VideoPublishingConstants.errorResolution;
          });
        }
        return;
      }

      // Rule 5: Aspect ratio — non-blocking warning
      String? arWarning;
      if (videoSize.height > 0) {
        final ar = videoSize.width / videoSize.height;
        const preferredAr = 9.0 / 16.0; // ~0.5625
        const tolerance = 0.08;
        if ((ar - preferredAr).abs() > tolerance) {
          arWarning = _VideoPublishingConstants.warningAspectRatio;
        }
      }

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _hasError = false;
          _initializationError = null;
          _aspectRatioWarning = arWarning;
          _aspectRatioWarningDismissed = false;
        });
      }
    } catch (e) {
      developer.log('Error initializing video: $e',
          name: 'VideoPublishingScreen');
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _hasError = true;
          _initializationError = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _captionController.removeListener(_onCaptionChanged);
    
    // Safely dispose video controller
    try {
      if (_isInitialized && _controller.value.isInitialized) {
        _controller.pause();
        _controller.dispose();
      }
    } catch (e) {
      developer.log('Error disposing video controller: $e',
          name: 'VideoPublishingScreen');
    }
    
    _captionController.dispose();
    super.dispose();
  }

  /// Add hashtag to caption text
  void _addHashtagToCaption(String hashtag) {
    final currentText = _captionController.text;

    // Check if hashtag is already in the caption
    if (!currentText.contains(hashtag)) {
      String newText;
      if (currentText.isEmpty) {
        newText = hashtag;
      } else if (currentText.endsWith(' ')) {
        newText = currentText + hashtag;
      } else {
        newText = '$currentText $hashtag';
      }

      _captionController.text = newText;
      _caption = newText;

      // Move cursor to end
      _captionController.selection = TextSelection.fromPosition(
        TextPosition(offset: newText.length),
      );
    }
  }

  /// Remove hashtag from caption text
  void _removeHashtagFromCaption(String hashtag) {
    final currentText = _captionController.text;
    String newText = currentText;

    // Remove the hashtag from the text
    newText = newText.replaceAll('$hashtag ', '');
    newText = newText.replaceAll(hashtag, '');
    newText = newText.replaceAll(' $hashtag', '');

    // Clean up any double spaces
    newText = newText.replaceAll('  ', ' ');
    newText = newText.trim();

    _captionController.text = newText;
    _caption = newText;

    // Move cursor to end
    _captionController.selection = TextSelection.fromPosition(
      TextPosition(offset: newText.length),
    );
  }

  void _togglePlayPause() {
    setState(() {
      if (_isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
      }
      _isPlaying = !_isPlaying;
    });
  }

  Future<void> _generateFrameThumb(double timeSeconds) async {
    if (!_isInitialized || _isGeneratingThumb) return;
    setState(() => _isGeneratingThumb = true);
    try {
      await _controller.seekTo(
        Duration(milliseconds: (timeSeconds * 1000).round()),
      );
      await _controller.pause();
      setState(() => _isPlaying = false);
      final bytes = await VideoThumbnail.thumbnailData(
        video: widget.videoFile.path,
        imageFormat: ImageFormat.JPEG,
        timeMs: (timeSeconds * 1000).round(),
        quality: 75,
      );
      if (mounted) {
        setState(() {
          _frameThumbBytes = bytes;
          _thumbnailTimeSeconds = timeSeconds;
          _isCustomThumbnail = false;
          _customThumbnailFile = null;
        });
      }
    } catch (_) {
      // Silently fail — the Mux default thumbnail is still used
    } finally {
      if (mounted) setState(() => _isGeneratingThumb = false);
    }
  }

  String _selectedCategoryName() {
    return _categories
            .firstWhere(
              (category) => category.id == _selectedCategory,
              orElse: () => _categories.first,
            )
            .name;
  }

  String _friendlyUploadStatusMessage() {
    final raw = UploadStatusManager().currentStatusMessage.trim();
    if (raw.isNotEmpty) {
      final lower = raw.toLowerCase();
      if (lower.contains('preparing')) return 'Preparing your post...';
      if (lower.contains('transcod')) return 'Finishing your video...';
      if (lower.contains('processing')) return 'Getting your post ready...';
      if (lower.contains('upload')) {
        return 'Uploading your video ${(_uploadProgress * 100).toInt()}%';
      }
      return raw;
    }

    if (_uploadProgress > 0) {
      return 'Uploading your video ${(_uploadProgress * 100).toInt()}%';
    }

    return 'Getting your post ready...';
  }

  Future<void> _pickThumbnailFromGallery() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;
    setState(() {
      _customThumbnailFile = File(picked.path);
      _isCustomThumbnail = true;
      _frameThumbBytes = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.supportBackground,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          // Header
          _buildHeader(),

          // Video Player Area (collapsible on scroll)
          Expanded(
            flex: _videoFlex.round(),
            child: _buildVideoPreview(),
          ),

          // Content
          Expanded(
            flex: (7 - _videoFlex).round().clamp(3, 6),
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                children: [
                  const SizedBox(height: 16),

                  // Aspect ratio warning (non-blocking)
                  if (_aspectRatioWarning != null &&
                      !_aspectRatioWarningDismissed) ...[
                    _AspectRatioWarningBanner(
                      message: _aspectRatioWarning!,
                      onDismiss: () => setState(
                          () => _aspectRatioWarningDismissed = true),
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (_isEditingDraft) ...[
                    _buildDraftContextBanner(),
                    const SizedBox(height: 12),
                  ],

                  // Caption (most important — first)
                  _buildCaptionSection(),

                  const SizedBox(height: 20),

                  // Category chips
                  _buildCategorySection(),

                  const SizedBox(height: 20),

                  _buildComposerGuidance(),

                  const SizedBox(height: 20),

                  _buildExpandableSection(
                    icon: Icons.image_outlined,
                    title: 'Thumbnail',
                    subtitle: _isCustomThumbnail
                        ? 'Custom image selected'
                        : _thumbnailTimeSeconds > 0
                            ? 'Frame chosen at ${_thumbnailTimeSeconds.toStringAsFixed(1)}s'
                            : 'Optional cover image',
                    isExpanded: _showThumbnailOptions,
                    onToggle: () => setState(
                      () => _showThumbnailOptions = !_showThumbnailOptions,
                    ),
                    child: _buildThumbnailSection(),
                  ),

                  const SizedBox(height: 16),

                  _buildExpandableSection(
                    icon: Icons.lock_outline,
                    title: 'Privacy & comments',
                    subtitle:
                        '$_selectedPrivacy · comments ${_allowComments ? 'on' : 'off'}',
                    isExpanded: _showPrivacyOptions,
                    onToggle: () => setState(
                      () => _showPrivacyOptions = !_showPrivacyOptions,
                    ),
                    child: _buildPrivacySection(),
                  ),

                  const SizedBox(height: 16),

                  _buildExpandableSection(
                    icon: Icons.share_outlined,
                    title: 'Cross-posting',
                    subtitle: _connectedPlatforms.isEmpty
                        ? 'No linked platforms yet'
                        : _selectedPlatformCount > 0
                            ? '$_selectedPlatformCount platform${_selectedPlatformCount == 1 ? '' : 's'} selected'
                            : 'Optional: also share to linked platforms',
                    isExpanded: _showCrossPostOptions,
                    onToggle: () => setState(
                      () => _showCrossPostOptions = !_showCrossPostOptions,
                    ),
                    child: _connectedPlatforms.isNotEmpty
                        ? _buildPlatformSelectorSection()
                        : _buildConnectPlatformsHint(),
                  ),

                  const SizedBox(height: 16),

                  _buildExpandableSection(
                    icon: Icons.schedule_outlined,
                    title: 'Schedule',
                    subtitle: _schedule == null
                        ? 'Optional: publish later'
                        : 'Post scheduled',
                    isExpanded: _showScheduleOptions,
                    onToggle: () => setState(
                      () => _showScheduleOptions = !_showScheduleOptions,
                    ),
                    child: _buildSchedulePostSection(),
                  ),

                  const SizedBox(
                      height: 120), // Space for bottom actions
                ],
              ),
            ),
          ),

          // Bottom Actions
          _buildBottomActions(),
        ],
      ),
    );
  }

  Widget _buildComposerGuidance() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.auto_awesome_outlined,
            color: Color(0xFF9248D2),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Start with the basics: add a caption, pick a category, then publish. Everything below is optional.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.82),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandableSection({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isExpanded,
    required VoidCallback onToggle,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Icon(
                      icon,
                      color: Colors.white.withValues(alpha: 0.9),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.62),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              color: Colors.white.withValues(alpha: 0.06),
            ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: isExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: child,
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 4,
        left: 8,
        right: 8,
        bottom: 8,
      ),
      child: Row(
        children: [
          // Back
          IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              widget.onCancel();
            },
            icon: const Icon(Icons.close, color: Colors.white, size: 22),
          ),
          const Expanded(
            child: SizedBox.shrink(),
          ),
          Text(
            _isEditingDraft ? 'Finish Draft' : 'New Post',
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600),
          ),
          const Expanded(child: SizedBox.shrink()),
          // Draft / status
          if (_isModerating)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const SizedBox(
                  width: 12, height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.orange),
                  ),
                ),
                const SizedBox(width: 6),
                const Text('Checking…',
                    style: TextStyle(
                        color: Colors.orange,
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
              ]),
            )
          else if (_isUploading)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                '${(_uploadProgress * 100).toInt()}%',
                style: const TextStyle(
                    color: Color(0xFF9248D2),
                    fontSize: 14,
                    fontWeight: FontWeight.w700),
              ),
            )
          else
            TextButton(
              onPressed: _hasError ? null : _saveAsDraft,
              child: Text(
                _isEditingDraft ? 'Update Draft' : 'Draft',
                style: TextStyle(
                  color: _hasError
                      ? Colors.white24
                      : Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDraftContextBanner() {
    final updatedAt = DateTime.tryParse(
      widget.draftData?['updatedAt']?.toString() ?? '',
    );
    final hasCrossPostDraft =
        (_effectiveSelectedPlatforms.isNotEmpty) ||
        ((((widget.draftData?['metadata'] as Map?)?['cross_platform_sharing'])
                    as List?)
                ?.isNotEmpty ==
            true);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF9248D2).withValues(alpha: 0.20),
            const Color(0xFF2E8DFF).withValues(alpha: 0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.drafts_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Continuing a saved draft',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  updatedAt == null
                      ? 'Your previous caption and posting settings are loaded and ready to finish.'
                      : 'Last saved ${_formatDraftRelativeTime(updatedAt)}. Caption, privacy, category, and linked destinations are restored.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.80),
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
                if (hasCrossPostDraft) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Cross-post selections from this draft are already waiting below.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDraftRelativeTime(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inMinutes < 1) return 'just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
  }

  Widget _buildVideoPreview() {
    return GestureDetector(
      onTap: _togglePlayPause,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.black,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.10),
              Colors.white.withValues(alpha: 0.02),
            ],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.16),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Video player or error state
              if (_hasError && _initializationError != null)
                Container(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _initializationError!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _hasError = false;
                            _initializationError = null;
                          });
                          _initializeVideo();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF9248D2),
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              else if (_isInitialized && !_hasError)
                AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                )
              else
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),

              // Play/Pause overlay (only show if no error and video is initialized)
              if (!_isPlaying && _isInitialized && !_hasError)
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 40,
                  ),
                ),

              if (_isInitialized && !_hasError)
                Positioned(
                  top: 14,
                  left: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.42),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.play_circle_outline_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _schedule != null
                              ? 'Scheduled preview'
                              : 'Ready to post',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              if (_isInitialized && !_hasError)
                Positioned(
                  bottom: 14,
                  left: 14,
                  right: 14,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.15),
                            Colors.black.withValues(alpha: 0.55),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        _schedule != null
                            ? 'Your video is queued to go out when you are ready.'
                            : 'Tap the preview anytime to pause and double-check your post.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ),
                ),

              // Upload Progress overlay
              if (_isUploading)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 56,
                            height: 56,
                            child: CircularProgressIndicator(
                              value: _uploadProgress > 0 ? _uploadProgress : null,
                              strokeWidth: 4,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFF9248D2)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _friendlyUploadStatusMessage(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'You can stay here while we finish everything safely.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.72),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySection() {
    final selectedCategory = _categories.firstWhere(
      (category) => category.id == _selectedCategory,
      orElse: () => _categories.first,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Category',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 6),
              const Text(
                '(required)',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Pick the one that best fits this post. You can always change it before publishing.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.62),
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              children: [
                Text(
                  selectedCategory.emoji,
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(width: 8),
                Text(
                  'Selected: ${selectedCategory.name}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _categories.map((category) {
              final isSelected = _selectedCategory == category.id;
              return GestureDetector(
                onTap: () =>
                    setState(() => _selectedCategory = category.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? category.color.withValues(alpha: 0.25)
                        : Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? category.color
                          : Colors.white.withValues(alpha: 0.15),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(category.emoji,
                          style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text(
                        category.name,
                        style: TextStyle(
                          color: isSelected
                              ? category.color
                              : Colors.white70,
                          fontSize: 13.5,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCaptionSection() {
    final charCount = _captionCharacterCount;
    final maxLen = _VideoPublishingConstants.maxCaptionLength;
    final counterColor = charCount > maxLen
        ? Colors.red
        : charCount >= (maxLen * 0.9).toInt()
            ? Colors.orange
            : Colors.white38;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                const Text('Caption',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                const SizedBox(width: 6),
                const Text('(required)',
                    style: TextStyle(color: Colors.white38, fontSize: 12)),
              ]),
              Text('$charCount/$maxLen',
                  style: TextStyle(
                      color: counterColor, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Tell people what they are about to watch. A clear first line usually performs best.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.62),
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _captionController,
            maxLength: maxLen,
            maxLines: 4,
            minLines: 2,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.newline,
            keyboardType: TextInputType.multiline,
            style: const TextStyle(
                color: Colors.white, fontSize: 15, height: 1.5),
            decoration: InputDecoration(
              hintText: 'Describe your video…',
              hintStyle:
                  TextStyle(color: Colors.white.withValues(alpha: 0.4)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.15)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.15)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: Color(0xFF9248D2), width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.06),
              counterText: '',
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.tips_and_updates_outlined,
                color: Colors.white.withValues(alpha: 0.42),
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                'Quick hashtags',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.56),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Hashtag quick-add chips
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildHashtagChip('#trending'),
              _buildHashtagChip('#viral'),
              _buildHashtagChip('#fyp'),
              _buildHashtagChip('#streaming'),
              _buildHashtagChip('#${_selectedCategoryName().toLowerCase().replaceAll(' ', '')}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConnectPlatformsHint() {
    return GestureDetector(
      onTap: () {
        AppNavigator.openLinkedPlatforms(context);
      },
      child: Row(
        children: [
          Icon(Icons.add_link,
              color: Colors.white.withValues(alpha: 0.4), size: 16),
          const SizedBox(width: 6),
          Text(
            'Connect platforms to cross-post →',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformSelectorSection() {
    final limitReached = _selectedPlatformCount >= _maxCrossPostPlatforms;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.share_outlined,
                  color: Color(0xFF9248D2), size: 18),
              const SizedBox(width: 8),
              const Text(
                'Also post to',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (_selectedPlatformCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9248D2).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$_selectedPlatformCount on',
                    style: const TextStyle(
                        color: Color(0xFF9248D2), fontSize: 11),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _crossPostPlanDescription(),
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9248D2).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _subscriptionPlanLabel,
                    style: const TextStyle(
                      color: Color(0xFFB98FFF),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _subscriptionTier == VideoWatermarkService.studioTier
                        ? 'Unlimited connected platforms'
                        : 'Up to $_maxCrossPostPlatforms connected platform${_maxCrossPostPlatforms == 1 ? '' : 's'}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_requiresCrossPostWatermark) ...[
            const SizedBox(height: 12),
            _buildWatermarkPreviewCard(),
          ],
          const SizedBox(height: 12),
          ..._connectedPlatforms.map((p) => PlatformRow(
                platformName: p.name,
                platformIcon: p.icon,
                platformColor: p.color,
                isEnabled: _platformEnabled[p.name] ?? false,
                isLocked: !(_platformEnabled[p.name] ?? false) && limitReached,
                initialCaption: _platformCaptions[p.name] ?? _caption,
                characterLimit:
                    PlatformCharacterLimits.limitFor(p.name),
                trailingLabel:
                    _subscriptionTier == VideoWatermarkService.starterTier &&
                            _requiresCrossPostWatermark
                        ? 'Watermark'
                        : null,
                lockedReason: !(_platformEnabled[p.name] ?? false) && limitReached
                    ? _subscriptionTier == VideoWatermarkService.starterTier
                        ? 'Free includes 1 destination. Upgrade to Pro or Studio to unlock more.'
                        : '$_subscriptionPlanLabel includes up to $_maxCrossPostPlatforms destinations.'
                    : null,
                onToggle: (enabled) => _handlePlatformToggle(p.name, enabled),
                onCaptionChanged: (text) =>
                    _platformCaptions[p.name] = text,
              )),
        ],
      ),
    );
  }

  Widget _buildWatermarkPreviewCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF9248D2).withValues(alpha: 0.16),
            const Color(0xFF4E9FD4).withValues(alpha: 0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.branding_watermark_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Floating StreamersTip watermark',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Free cross-posts keep a TikTok-style floating mark using your StreamersTip logo so exports stay branded.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnailSection() {
    final durationSeconds = _videoDuration?.inMilliseconds != null
        ? _videoDuration!.inMilliseconds / 1000.0
        : 0.0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Thumbnail',
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose the frame that appears before your video plays.',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
          ),
          const SizedBox(height: 16),
          // Preview + picker row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail preview
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _buildThumbnailPreview(),
              ),
              const SizedBox(width: 16),
              // Controls
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (durationSeconds > 0) ...[
                      Text(
                        'Scrub to pick frame',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12),
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          thumbColor: const Color(0xFF9248D2),
                          activeTrackColor: const Color(0xFF9248D2),
                          inactiveTrackColor:
                              Colors.white.withValues(alpha: 0.2),
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 8),
                          overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 16),
                          trackHeight: 3,
                        ),
                        child: Slider(
                          value: _thumbnailTimeSeconds.clamp(
                              0.0, durationSeconds),
                          min: 0,
                          max: durationSeconds,
                          onChangeEnd: _generateFrameThumb,
                          onChanged: (value) => setState(
                              () => _thumbnailTimeSeconds = value),
                        ),
                      ),
                      Text(
                        'At ${_thumbnailTimeSeconds.toStringAsFixed(1)}s',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 11),
                      ),
                      const SizedBox(height: 12),
                    ],
                    GestureDetector(
                      onTap: _pickThumbnailFromGallery,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color:
                                  Colors.white.withValues(alpha: 0.3)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.photo_library_outlined,
                                color:
                                    Colors.white.withValues(alpha: 0.8),
                                size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'Upload image',
                              style: TextStyle(
                                  color:
                                      Colors.white.withValues(alpha: 0.8),
                                  fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_isCustomThumbnail)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Custom image selected',
                          style: TextStyle(
                              color: Colors.greenAccent.withValues(
                                  alpha: 0.9),
                              fontSize: 11),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnailPreview() {
    const double w = 72;
    const double h = 96;
    if (_isGeneratingThumb) {
      return Container(
        width: w,
        height: h,
        color: Colors.black54,
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor:
                  AlwaysStoppedAnimation<Color>(Color(0xFF9248D2)),
            ),
          ),
        ),
      );
    }
    if (_isCustomThumbnail && _customThumbnailFile != null) {
      return Image.file(
        _customThumbnailFile!,
        width: w,
        height: h,
        fit: BoxFit.cover,
      );
    }
    if (_frameThumbBytes != null) {
      return Image.memory(
        _frameThumbBytes!,
        width: w,
        height: h,
        fit: BoxFit.cover,
      );
    }
    return Container(
      width: w,
      height: h,
      color: Colors.black54,
      child: Icon(Icons.movie_outlined,
          color: Colors.white.withValues(alpha: 0.4), size: 28),
    );
  }

  Widget _buildPrivacySection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Privacy',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildPrivacyOption('Everyone', 'Anyone can see this video'),
          _buildPrivacyOption('Followers', 'Only your followers can see'),
          _buildPrivacyOption('Private', 'Only you can see this video'),
          const Divider(color: Colors.white12, height: 28),
          Row(
            children: [
              const Icon(Icons.comment_outlined,
                  color: Colors.white70, size: 20),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Allow comments',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w500)),
                    Text('Viewers can comment on your video',
                        style:
                            TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
              Switch(
                value: _allowComments,
                onChanged: (value) =>
                    setState(() => _allowComments = value),
                activeThumbColor: const Color(0xFF9248D2),
                inactiveTrackColor: Colors.white24,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Cross-platform sharing section - hidden for now
  // Widget _buildSharingSection() {
  //   return Container(
  //     margin: const EdgeInsets.symmetric(horizontal: 16),
  //     padding: const EdgeInsets.all(16),
  //     decoration: BoxDecoration(
  //       color: Colors.white.withValues(alpha: 0.05),
  //       borderRadius: BorderRadius.circular(12),
  //     ),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         const Text(
  //           'Cross-Platform Sharing',
  //           style: TextStyle(
  //             color: Colors.white,
  //             fontSize: 18,
  //             fontWeight: FontWeight.bold,
  //           ),
  //         ),
  //         const SizedBox(height: 16),
  //         Row(
  //           children: [
  //             _buildPlatformOption('Instagram', Icons.camera_alt,
  //                 _selectedPlatforms.contains('Instagram')),
  //             const SizedBox(width: 12),
  //             _buildPlatformOption('TikTok', Icons.music_note,
  //                 _selectedPlatforms.contains('TikTok')),
  //             const SizedBox(width: 12),
  //             _buildPlatformOption('YouTube', Icons.play_circle,
  //                 _selectedPlatforms.contains('YouTube')),
  //           ],
  //         ),
  //         if (_selectedPlatforms.isNotEmpty) ...[
  //           const SizedBox(height: 12),
  //           Container(
  //             padding: const EdgeInsets.all(12),
  //             decoration: BoxDecoration(
  //               color: const Color(0xFF9248D2).withValues(alpha: 0.1),
  //               borderRadius: BorderRadius.circular(8),
  //               border: Border.all(
  //                 color: const Color(0xFF9248D2).withValues(alpha: 0.3),
  //               ),
  //             ),
  //             child: Row(
  //               children: [
  //                 const Icon(
  //                   Icons.water_drop,
  //                   color: Color(0xFF9248D2),
  //                   size: 20,
  //                 ),
  //                 const SizedBox(width: 8),
  //                 Expanded(
  //                   child: Text(
  //                     'Watermark will be added to your video for cross-platform sharing',
  //                     style: TextStyle(
  //                       color: Colors.white.withValues(alpha: 0.9),
  //                       fontSize: 12,
  //                       fontWeight: FontWeight.w500,
  //                     ),
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           ),
  //         ],
  //       ],
  //     ),
  //   );
  // }

  Widget _buildSchedulePostSection() {
    // Since cross-platform sharing is hidden, schedule for StreamersTip only
    // Empty list means schedule for main platform only
    final List<PlatformKey> selectedPlatformKeys = <PlatformKey>[];

    // Create media from video file
    final List<PostMedia> media = [
      PostMedia(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: MediaType.video,
        src: widget.videoFile.path,
        aspectRatio: 9.0 / 16.0, // Default aspect ratio for vertical videos
        durationMs:
            30000, // Default 30 seconds, should be calculated from actual video
      ),
    ];

    return SchedulePostWidget(
      selectedPlatforms: selectedPlatformKeys,
      caption: _caption,
      media: media,
      initialSchedule: _schedule,
      onScheduleChanged: (schedule) {
        setState(() {
          _schedule = schedule;
        });
      },
    );
  }

  Widget _buildBottomActions() {
    final isBlocked = _isUploading || _isModerating || _hasError;
    final label = _isModerating
        ? 'Checking your video…'
        : _isUploading
            ? 'Publishing your post…'
            : _schedule != null
                ? 'Schedule Post'
                : 'Publish Now';
    final sublabel = _isModerating
        ? 'Making sure everything is safe and ready.'
        : _isUploading
            ? 'Stay here for a moment while we finish things up.'
            : _schedule != null
                ? 'Your post will go live at the time you selected.'
                : 'Share it to StreamersTip right away.';

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              const Color(0xFF1C135D).withValues(alpha: 0.95),
            ],
          ),
        ),
        child: GestureDetector(
          onTap: isBlocked
              ? null
              : () {
                  HapticFeedback.mediumImpact();
                  _publishVideo();
                },
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              gradient: isBlocked
                  ? null
                  : const LinearGradient(
                      colors: [Color(0xFF9248D2), Color(0xFF4E9FD4)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
              color: isBlocked ? Colors.white12 : null,
              borderRadius: BorderRadius.circular(14),
              boxShadow: isBlocked
                  ? null
                  : [
                      BoxShadow(
                        color:
                            const Color(0xFF9248D2).withValues(alpha: 0.45),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Center(
              child: _isModerating || _isUploading
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(label,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _schedule != null
                                  ? Icons.schedule_send_rounded
                                  : Icons.rocket_launch_outlined,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(label,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          sublabel,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.78),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHashtagChip(String hashtag) {
    return GestureDetector(
      onTap: () async {
        if (_hashtags.contains(hashtag)) {
          // Remove from hashtag list and caption
          setState(() {
            _hashtags.remove(hashtag);
            _removeHashtagFromCaption(hashtag);
          });
        } else {
          // Validate hashtag before adding
          final cleaned = hashtag.replaceAll('#', '');
          final currentUser = FirebaseAuth.instance.currentUser;
          final hashtagService = HashtagLockService();
          final validation =
              await hashtagService.validateHashtag(cleaned, currentUser?.uid);

          if (validation.isValid) {
            setState(() {
              _hashtags.add(hashtag);
              _addHashtagToCaption(hashtag);
            });
          } else {
            // Show error message
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(validation.errorMessage ?? 'Invalid hashtag'),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _hashtags.contains(hashtag)
              ? const Color(0xFF9248D2)
              : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _hashtags.contains(hashtag)
                ? const Color(0xFF9248D2)
                : Colors.white.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          hashtag,
          style: TextStyle(
            color: _hashtags.contains(hashtag) ? Colors.white : Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildPrivacyOption(String title, String subtitle) {
    final isSelected = _selectedPrivacy == title;
    return GestureDetector(
      onTap: () => setState(() => _selectedPrivacy = title),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF9248D2)
                      : Colors.white.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Center(
                      child: Icon(
                        Icons.check,
                        color: Color(0xFF9248D2),
                        size: 12,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Platform option widget - hidden with cross-platform sharing
  // Widget _buildPlatformOption(String platform, IconData icon, bool isSelected) {
  //   return GestureDetector(
  //     onTap: () {
  //       setState(() {
  //         if (_selectedPlatforms.contains(platform)) {
  //           _selectedPlatforms.remove(platform);
  //         } else {
  //           _selectedPlatforms.add(platform);
  //         }
  //       });
  //     },
  //     child: Container(
  //       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  //       decoration: BoxDecoration(
  //         color: isSelected
  //             ? const Color(0xFF9248D2)
  //             : Colors.white.withValues(alpha: 0.1),
  //         borderRadius: BorderRadius.circular(8),
  //         border: Border.all(
  //           color: isSelected
  //               ? const Color(0xFF9248D2)
  //               : Colors.white.withValues(alpha: 0.3),
  //         ),
  //       ),
  //       child: Row(
  //         mainAxisSize: MainAxisSize.min,
  //         children: [
  //           Icon(icon, color: Colors.white, size: 16),
  //           const SizedBox(width: 8),
  //           Text(
  //             platform,
  //             style: const TextStyle(
  //               color: Colors.white,
  //               fontSize: 12,
  //               fontWeight: FontWeight.w600,
  //             ),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  Future<void> _publishVideo() async {
    // Check if Firebase is initialized
    if (!FirebaseIOSService.isInitialized) {
      _showUploadErrorDialog(
          'Firebase is not initialized. Please restart the app and try again.');
      return;
    }

    // Check if user is authenticated
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      debugPrint('❌ VideoPublishingScreen: User not authenticated');
      _showUploadErrorDialog('Please log in to publish videos');
      return;
    }

    debugPrint(
        '✅ VideoPublishingScreen: User authenticated - UID: ${currentUser.uid}');
    debugPrint('✅ VideoPublishingScreen: User email: ${currentUser.email}');
    debugPrint(
        '✅ VideoPublishingScreen: User displayName: ${currentUser.displayName}');

    // Check authentication token and force refresh
    try {
      final idToken = await currentUser.getIdToken(true); // Force refresh
      debugPrint(
          '✅ VideoPublishingScreen: Auth token obtained - Length: ${idToken?.length ?? 0}');
      debugPrint(
          '✅ VideoPublishingScreen: Auth token preview: ${idToken?.substring(0, 20) ?? 'null'}...');
    } catch (e) {
      debugPrint('❌ VideoPublishingScreen: Failed to get auth token: $e');
      _showUploadErrorDialog(
          'Authentication error. Please log out and log back in.');
      return;
    }

    // Validate caption
    if (_caption.trim().isEmpty) {
      _showUploadErrorDialog(_VideoPublishingConstants.errorCaption);
      return;
    }
    if (_caption.length > _VideoPublishingConstants.maxCaptionLength) {
      _showUploadErrorDialog(
          'Caption is too long (maximum ${_VideoPublishingConstants.maxCaptionLength} characters).');
      return;
    }

    // Validate category
    if (_selectedCategory.isEmpty) {
      _showUploadErrorDialog(_VideoPublishingConstants.errorCategory);
      return;
    }

    // Check network connectivity
    final networkService = NetworkConnectivityService();
    final isConnected = await networkService.checkConnectivity();
    if (!isConnected) {
      _showUploadErrorDialog(
          'No internet connection. Please check your network and try again.');
      return;
    }

    // Pause video during upload
    if (_isPlaying && _controller.value.isInitialized) {
      await _controller.pause();
      setState(() {
        _isPlaying = false;
      });
    }

    setState(() {
      _isModerating = true;
    });

    try {
      // 1. Run content moderation
      debugPrint('🔍 VideoPublishingScreen: Running content moderation...');
      final moderationResult = await _moderationService.moderateVideo(
        videoFile: widget.videoFile,
        caption: _caption,
        hashtags: _hashtags,
        metadata: {
          'privacy': _selectedPrivacy,
          'allowComments': _allowComments,
        },
      );
      debugPrint(
          '✅ VideoPublishingScreen: Content moderation completed - approved: ${moderationResult.isApproved}');

      if (!moderationResult.isApproved) {
        setState(() {
          _isModerating = false;
        });

        // Show moderation error dialog
        _showModerationErrorDialog(moderationResult);
        return;
      }

      setState(() {
        _isModerating = false;
      });

      // 2. Generate video ID and create optimistic video
      final videoId = _generateVideoId();
      _syncSelectedPlatforms();
      final selectedPlatforms = _effectiveSelectedPlatforms;
      debugPrint(
          '🎬 VideoPublishingScreen: Creating optimistic video: $videoId');

      // Apply watermark if cross-platform sharing is selected
      File videoFileToUpload = widget.videoFile;
      if (_watermarkService.shouldApplyWatermarkForTier(
        _subscriptionTier,
        selectedPlatforms,
      )) {
        debugPrint(
            '🎬 VideoPublishingScreen: Applying watermark for cross-platform sharing...');
        final watermarkedFile = await _watermarkService.addWatermarkToVideo(
          videoFile: widget.videoFile,
          selectedPlatforms: selectedPlatforms,
          logoPath: VideoWatermarkService.defaultWatermarkAsset,
        );
        if (watermarkedFile != null) {
          videoFileToUpload = watermarkedFile;
          debugPrint('✅ VideoPublishingScreen: Watermark applied successfully');
        }
      }

      // 3. Create optimistic video placeholder
      debugPrint(
          '🎬 VideoPublishingScreen: Creating optimistic video placeholder...');
      await _optimisticVideoService.createOptimisticVideo(
        videoId: videoId,
        caption: _caption,
        categories: [_selectedCategory],
        localThumbnailPath: _customThumbnailFile?.path,
        localVideoPath: videoFileToUpload.path,
        metadata: {
          'privacy': _selectedPrivacy,
          'allowComments': _allowComments,
          'cross_platform_sharing': selectedPlatforms.toList(),
          'watermark_applied': _watermarkService.shouldApplyWatermarkForTier(
            _subscriptionTier,
            selectedPlatforms,
          ),
          'cross_post_subscription_tier': _subscriptionTier,
          'moderation_confidence': moderationResult.confidence,
          'moderation_checked_at': DateTime.now().toIso8601String(),
          'duration': 0, // Will be calculated during processing
          'fileSize': await videoFileToUpload.length(),
        },
      );
      debugPrint(
          '✅ VideoPublishingScreen: Optimistic video created successfully');

      // 4. Check if this is a scheduled post
      if (_schedule != null) {
        // SCHEDULED POST: Upload video and save as scheduled post
        await _scheduleVideo(
          videoFileToUpload: videoFileToUpload,
          videoId: videoId,
          currentUser: currentUser,
          moderationResult: moderationResult,
        );
        return; // Exit early, scheduling is handled
      }

      // IMMEDIATE PUBLISH: Upload video directly to all required feeds
      setState(() {
        _isUploading = true;
        _uploadProgress = 0.0;
      });

      try {
        developer.log('🚀 Starting video upload (immediate publish)...',
            name: 'VideoPublishingScreen');
        developer.log('📁 Video file: ${videoFileToUpload.path}',
            name: 'VideoPublishingScreen');
        developer.log('📝 Caption: $_caption', name: 'VideoPublishingScreen');
        developer.log('🏷️ Hashtags: $_hashtags',
            name: 'VideoPublishingScreen');
        developer.log('🔒 Privacy: $_selectedPrivacy',
            name: 'VideoPublishingScreen');
        developer.log('📂 Category: $_selectedCategory',
            name: 'VideoPublishingScreen');
        developer.log('👤 User ID: ${currentUser.uid}',
            name: 'VideoPublishingScreen');

        final fileSize = await videoFileToUpload.length();
        final canonicalCategory = normalizeCategoryId(_selectedCategory);

        // Build cross-post requests for selected platforms.
        final crossPostRequests = _connectedPlatforms
            .where((p) => _platformEnabled[p.name] == true)
            .map((p) => _buildCrossPostRequestForPlatform(
                  p.name,
                  scheduleAt: _schedule?.scheduledAtUtc,
                ))
            .toList();

        final publishController = ref.read(publishControllerProvider);
        final execution = await publishController.publishNow(
          PublishNowRequest(
            videoFile: videoFileToUpload,
            caption: _caption,
            hashtags: _hashtags,
            privacy: _selectedPrivacy,
            allowComments: _allowComments,
            crossPostRequests: crossPostRequests,
            additionalMetadata: {
              'category': canonicalCategory,
              'cross_platform_sharing': crossPostRequests
                  .map((r) => r.platformName)
                  .toList(),
              'watermark_applied': _watermarkService.shouldApplyWatermarkForTier(
                _subscriptionTier,
                selectedPlatforms,
              ),
              'cross_post_subscription_tier': _subscriptionTier,
              'moderation_confidence': moderationResult.confidence,
              'moderation_checked_at': DateTime.now().toIso8601String(),
              'duration': 0,
              'fileSize': fileSize,
              'thumbnailTimeSeconds': _thumbnailTimeSeconds,
              'isCustomThumbnail': _isCustomThumbnail,
            },
            onProgress: (progress) {
              if (mounted) setState(() => _uploadProgress = progress);
            },
          ),
        );
        final result = execution.publishResult!;

        developer.log(
            '📤 ST result: ${result.streamerstipSuccess}, '
            'crossPost ok: ${result.successfulPlatforms.length}, '
            'failed: ${result.failedPlatforms.length}',
            name: 'VideoPublishingScreen');

        if (!mounted) return;
        setState(() => _isUploading = false);

        if (result.streamerstipSuccess) {
          final uploadedVideoId = execution.uploadedVideoId ?? videoId;
          UploadStatusManager().enterProcessing(uploadedVideoId);

          _showCrossPostResultSheet(
            result: result,
            uploadedVideoId: uploadedVideoId,
            crossPostRequests: crossPostRequests,
          );
        } else {
          // StreamersTip failed — do NOT show cross-post UI.
          final raw = result.streamerstipResult.error ??
              'Failed to publish video';
          _showUploadErrorDialog(_friendlyUploadError(raw));
        }
      } catch (e) {
        developer.log(
            '❌ VideoPublishingScreen: upload error: $e',
            name: 'VideoPublishingScreen');
        if (!mounted) return;
        setState(() => _isUploading = false);
        _showUploadErrorDialog(_friendlyUploadError(e.toString()));
      }
    } catch (e) {
      setState(() {
        _isModerating = false;
      });

      // print('❌ Error publishing video: $e');
      _errorHandler.handleUploadError(
        operation: 'video_publishing',
        error: e,
      );
      _showUploadErrorDialog('Failed to publish video. Please try again.');
    }
  }

  String _friendlyUploadError(String raw) {
    if (raw.contains('PERMISSION_DENIED')) {
      return 'Permission denied. Please check your account and try again.';
    } else if (raw.contains('UNAVAILABLE')) {
      return 'Service unavailable. Please try again in a few minutes.';
    } else if (raw.contains('UNAUTHENTICATED')) {
      return 'Please log in again to publish videos.';
    } else if (raw.contains('thumbnail')) {
      return 'Failed to generate thumbnail. Please try again.';
    } else if (raw.contains('network') || raw.contains('SocketException')) {
      return 'No internet connection. Please check your network.';
    }
    return 'Failed to publish video. Please try again.';
  }

  String _generateVideoId() {
    return 'video_${DateTime.now().millisecondsSinceEpoch}_${_generateRandomString(8)}';
  }

  String _generateRandomString(int length) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(
          length, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
    );
  }

  void _showCrossPostResultSheet({
    required CrossPublishResult result,
    required String uploadedVideoId,
    required List<CrossPostRequest> crossPostRequests,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) => _CrossPostResultSheet(
        uploadedVideoId: uploadedVideoId,
        crossPostRequests: crossPostRequests,
        result: result,
        onOpenManagePosts: () {
          Navigator.of(ctx).pop();
          AppNavigator.openManagePosts(context);
        },
        onOpenLinkedPlatforms: (platforms) {
          Navigator.of(ctx).pop();
          AppNavigator.openLinkedPlatforms(
            context,
            initialPlatforms: platforms,
          );
        },
        onDone: () {
          final currentUserId = FirebaseAuth.instance.currentUser?.uid;
          if (currentUserId != null) {
            ref.invalidate(video_providers.userVideosProvider(currentUserId));
            ref
                .read(video_providers.videoServiceStateProvider.notifier)
                .loadAllVideos();
          }
          ref.read(homeViewReactivateProvider.notifier).triggerReactivation();
          Navigator.of(ctx).pop();
          Navigator.of(context).popUntil((route) => route.isFirst);
        },
      ),
    );
  }

  void _showModerationErrorDialog(VideoModerationResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Row(
          children: [
            Icon(Icons.block, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Text(
              'Content Rejected',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your video cannot be published due to:',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Text(
                result.reason ?? 'Inappropriate content detected',
                style: const TextStyle(color: Colors.red, fontSize: 14),
              ),
            ),
            const SizedBox(height: 12),
            if (result.violations.isNotEmpty) ...[
              const Text(
                'Violations detected:',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 4),
              ...result.violations.map((violation) => Padding(
                    padding: const EdgeInsets.only(left: 8, top: 2),
                    child: Text(
                      '• ${violation.replaceAll('_', ' ').toUpperCase()}',
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  )),
            ],
            const SizedBox(height: 16),
            const Text(
              'Please review your content and try again with appropriate material.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Edit Content',
              style: TextStyle(color: Color(0xFF9248D2)),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _saveAsDraft();
            },
            child: const Text(
              'Save as Draft',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  void _showUploadErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.orange, size: 24),
            SizedBox(width: 8),
            Text(
              'Upload Failed',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          error,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Try Again',
              style: TextStyle(color: Color(0xFF9248D2)),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _saveAsDraft();
            },
            child: const Text(
              'Save as Draft',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAsDraft() async {
    _syncSelectedPlatforms();
    final selectedPlatforms = _effectiveSelectedPlatforms;
    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      // Use LocalDraftService to save draft locally
      final localDraftService = LocalDraftService();
      final success = await localDraftService.saveDraft(
        videoFile: widget.videoFile,
        caption: _caption,
        hashtags: _hashtags,
        privacy: _selectedPrivacy,
        allowComments: _allowComments,
        category: _selectedCategory,
        existingDraftId: widget.draftId,
        additionalMetadata: {
          'cross_platform_sharing': selectedPlatforms.toList(),
          'watermark_applied': _watermarkService.shouldApplyWatermarkForTier(
            _subscriptionTier,
            selectedPlatforms,
          ),
          'cross_post_subscription_tier': _subscriptionTier,
          'scheduled_at_utc': _schedule?.scheduledAtUtc.toIso8601String(),
          'schedule_timezone': _schedule?.timezone,
          'is_scheduled': _schedule != null,
        },
      );

      setState(() {
        _isUploading = false;
      });

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Video saved as draft 📝'),
              backgroundColor: Color(0xFF9248D2),
              duration: Duration(seconds: 3),
            ),
          );
        }
        // Navigate back to HomeView after saving draft
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
          
          // 🚀 REFRESH FEED: Trigger feed refresh after navigation (drafts won't show but refresh for consistency)
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Future.delayed(const Duration(milliseconds: 300), () {
              // Refresh will happen in HomeView when it becomes visible
              developer.log('🔄 VideoPublishingScreen: Draft saved, feed will refresh on return to HomeView');
            });
          });
        }
      } else {
        if (mounted) {
          _showUploadErrorDialog('Failed to save draft');
        }
      }
    } catch (e) {
      await _errorHandler.handleError(
        type: ErrorType.uploadFailed,
        message: 'Failed to save video as draft',
        technicalDetails: e.toString(),
        context: {
          'operation': 'save_draft',
          'caption_length': _caption.length,
          'hashtags_count': _hashtags.length,
          'privacy': _selectedPrivacy,
        },
        isRecoverable: true,
        suggestedActions: [
          'Try again',
          'Check your connection',
          'Restart the app'
        ],
      );

      setState(() {
        _isUploading = false;
      });
      _showUploadErrorDialog('Failed to save draft: ${e.toString()}');
    }
  }

  /// Add uploaded video to centralized VideoService for immediate display
  /// Returns the video ID for use in feed refresh
  /// Schedule a video for future publishing
  Future<void> _scheduleVideo({
    required File videoFileToUpload,
    required String videoId,
    required User currentUser,
    required VideoModerationResult moderationResult,
  }) async {
    _syncSelectedPlatforms();
    final selectedPlatforms = _effectiveSelectedPlatforms;
    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      developer.log('📅 Scheduling video for future publish...',
          name: 'VideoPublishingScreen');
      developer.log(
          '📅 Scheduled time: ${_schedule!.scheduledAtUtc}',
          name: 'VideoPublishingScreen');

      // 1. Upload video to Storage (but don't publish to feeds yet)
      final videoUrl = await _uploadVideoForScheduled(videoFileToUpload, videoId);
      if (videoUrl == null) {
        throw Exception('Failed to upload video file');
      }

      // 2. Generate thumbnail
      final thumbnailUrl = await _generateThumbnailForScheduled(
          videoFileToUpload, videoId);
      if (thumbnailUrl == null) {
        throw Exception('Failed to generate thumbnail');
      }

      // 3. Save video to Firestore with status 'scheduled'
      await _saveScheduledVideoToFirestore(
        videoId: videoId,
        videoUrl: videoUrl,
        thumbnailUrl: thumbnailUrl,
        currentUser: currentUser,
        moderationResult: moderationResult,
      );

      // 4. Save scheduled post to Firestore
      final scheduledExecution =
          await ref.read(publishControllerProvider).saveScheduledPublish(
        SchedulePublishRequest(
          videoId: videoId,
          videoUrl: videoUrl,
          thumbnailUrl: thumbnailUrl,
          caption: _caption,
          hashtags: _hashtags,
          category: normalizeCategoryId(_selectedCategory),
          privacy: _selectedPrivacy,
          allowComments: _allowComments,
          schedule: _schedule!,
          metadata: {
            'moderation_confidence': moderationResult.confidence,
            'moderation_checked_at': DateTime.now().toIso8601String(),
            'duration': _videoDuration?.inSeconds ?? 0,
            'fileSize': await videoFileToUpload.length(),
            'cross_platform_sharing': selectedPlatforms.toList(),
            'watermark_applied': _watermarkService.shouldApplyWatermarkForTier(
              _subscriptionTier,
              selectedPlatforms,
            ),
            'cross_post_subscription_tier': _subscriptionTier,
          },
          crossPostRequests: _connectedPlatforms
              .where((p) => _platformEnabled[p.name] == true)
              .map((p) => _buildCrossPostRequestForPlatform(
                    p.name,
                    scheduleAt: _schedule?.scheduledAtUtc,
                  ))
              .toList(),
        ),
      );
      final scheduledPostId = scheduledExecution.scheduledPostId ?? videoId;

      developer.log('✅ Video scheduled successfully: $scheduledPostId',
          name: 'VideoPublishingScreen');

      setState(() {
        _isUploading = false;
      });

      // Show success message
      if (mounted) {
        final scheduledTime = _schedule!.scheduledAtUtc;
        final timeStr = '${scheduledTime.month}/${scheduledTime.day} at ${scheduledTime.hour}:${scheduledTime.minute.toString().padLeft(2, '0')}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Video scheduled for $timeStr 📅'),
            backgroundColor: const Color(0xFF9248D2),
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // Navigate back to main tab view
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      developer.log('❌ Error scheduling video: $e',
          name: 'VideoPublishingScreen');
      setState(() {
        _isUploading = false;
      });
      if (mounted) {
        _showUploadErrorDialog('Failed to schedule video: ${e.toString()}');
      }
    }
  }

  /// Upload video file for scheduled post (without publishing to feeds)
  Future<String?> _uploadVideoForScheduled(
      File videoFile, String videoId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return null;

      final storage = FirebaseStorage.instance;
      final ref = storage
          .ref()
          .child('videos')
          .child(currentUser.uid)
          .child('$videoId.mp4');

      final uploadTask = ref.putFile(videoFile);

      // Monitor progress
      uploadTask.snapshotEvents.listen((snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        if (mounted) {
          setState(() {
            _uploadProgress = progress;
          });
        }
      });

      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      developer.log('❌ Error uploading video for scheduled post: $e',
          name: 'VideoPublishingScreen');
      return null;
    }
  }

  /// Generate thumbnail for scheduled post
  Future<String?> _generateThumbnailForScheduled(
      File videoFile, String videoId) async {
    try {
      final videoProcessingService = VideoProcessingService();
      final result = await videoProcessingService.processVideo(
        inputFile: videoFile,
        videoId: videoId,
        userId: FirebaseAuth.instance.currentUser?.uid ?? '',
      );
      return result.thumbnailUrl.isEmpty ? null : result.thumbnailUrl;
    } catch (e) {
      developer.log('❌ Error generating thumbnail for scheduled post: $e',
          name: 'VideoPublishingScreen');
      return null;
    }
  }

  /// Save scheduled video to Firestore (with status 'scheduled', not 'published')
  Future<void> _saveScheduledVideoToFirestore({
    required String videoId,
    required String videoUrl,
    required String thumbnailUrl,
    required User currentUser,
    required VideoModerationResult moderationResult,
  }) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final categoryFields = buildCanonicalCategoryFields(_selectedCategory);
      final canonicalCategory = categoryFields['category'] as String;
      final videoData = {
        'id': videoId,
        'userId': currentUser.uid,
        'creatorId': currentUser.uid,
        'creator_id': currentUser.uid,
        'videoUrl': videoUrl,
        'thumbnailUrl': thumbnailUrl,
        'caption': _caption,
        'hashtags': _hashtags,
        'privacy': _selectedPrivacy,
        'allowComments': _allowComments,
        ...categoryFields,
        'status': 'scheduled', // NOT 'published' - will be updated when scheduled time arrives
        'scheduledAtUtc': Timestamp.fromDate(_schedule!.scheduledAtUtc),
        'views': 0,
        'likes': 0,
        'comments': 0,
        'shares': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'moderation': {
          'approved': true,
          'checkedAt': FieldValue.serverTimestamp(),
          'confidence': moderationResult.confidence,
          'violations': [],
        },
        'metadata': {
          'fileSize': await widget.videoFile.length(),
          'duration': _videoDuration?.inSeconds.toDouble() ?? 0.0,
          'resolution': '1080x1920',
          'format': 'mp4',
          'uploadedAt': FieldValue.serverTimestamp(),
          'moderation_confidence': moderationResult.confidence,
          'moderation_checked_at': DateTime.now().toIso8601String(),
          'categoryOriginal': _selectedCategory,
          'categoryCanonical': canonicalCategory,
        },
      };

      await firestore.collection('videos').doc(videoId).set(videoData);

      // Add to user's videos collection
      await firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('videos')
          .doc(videoId)
          .set({
        'status': 'scheduled',
        'createdAt': FieldValue.serverTimestamp(),
      });

      developer.log('✅ Scheduled video saved to Firestore: $videoId',
          name: 'VideoPublishingScreen');
    } catch (e) {
      developer.log('❌ Error saving scheduled video to Firestore: $e',
          name: 'VideoPublishingScreen');
      rethrow;
    }
  }
}

class _CrossPostResultSheet extends ConsumerStatefulWidget {
  final CrossPublishResult result;
  final String uploadedVideoId;
  final List<CrossPostRequest> crossPostRequests;
  final VoidCallback onOpenManagePosts;
  final ValueChanged<List<String>> onOpenLinkedPlatforms;
  final VoidCallback onDone;

  const _CrossPostResultSheet({
    required this.uploadedVideoId,
    required this.crossPostRequests,
    required this.result,
    required this.onOpenManagePosts,
    required this.onOpenLinkedPlatforms,
    required this.onDone,
  });

  @override
  ConsumerState<_CrossPostResultSheet> createState() =>
      _CrossPostResultSheetState();
}

class _CrossPostResultSheetState extends ConsumerState<_CrossPostResultSheet> {
  bool _isRetrying = false;

  @override
  Widget build(BuildContext context) {
    final publishState = ref.watch(publishControllerProvider);
    final overallState = publishState.overallState;
    final failedRequests = widget.crossPostRequests
        .where(
          (request) =>
              publishState.crossPostResults[request.platformName] ==
              CrossPostState.failed,
        )
        .toList();
    final successfulRequests = widget.crossPostRequests
        .where(
          (request) =>
              publishState.crossPostResults[request.platformName] ==
              CrossPostState.success,
        )
        .toList();
    final reconnectPlatforms = failedRequests
        .where(
          (request) => _isReauthError(
            publishState.errorDetails[request.platformName],
          ),
        )
        .map((request) => request.platformName.toLowerCase())
        .toList();

    String title;
    String subtitle;
    switch (overallState) {
      case OverallPublishState.allSuccess:
        title = 'Your video is live everywhere selected';
        subtitle = 'StreamersTip is live, and every selected destination succeeded.';
        break;
      case OverallPublishState.partialSuccess:
        title = 'Your video is live on StreamersTip';
        subtitle = 'Some cross-post destinations succeeded, and some still need attention.';
        break;
      case OverallPublishState.streamerstipOnlySuccess:
        title = 'Your video is live on StreamersTip';
        subtitle = 'Cross-posting did not complete yet, but your StreamersTip upload succeeded.';
        break;
      default:
        title = 'Your video is live on StreamersTip';
        subtitle = 'Cross-post status is still being finalized.';
        break;
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.greenAccent, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            if (widget.crossPostRequests.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Destination status',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ...widget.crossPostRequests.map(
                (request) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildPlatformResultRow(
                    request.platformName,
                    publishState.crossPostResults[request.platformName] ??
                        CrossPostState.idle,
                    publishState.errorDetails[request.platformName],
                  ),
                ),
              ),
            ],
            if (successfulRequests.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Posted successfully to: ${successfulRequests.map((r) => r.platformName).join(', ')}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
            if (failedRequests.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'If you close this now, you can review the same destination states later in Manage Posts.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 24),
            if (failedRequests.isNotEmpty) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isRetrying
                      ? null
                      : () async {
                          setState(() => _isRetrying = true);
                          try {
                            await ref
                                .read(publishControllerProvider)
                                .retryCrossPosts(
                                  videoId: widget.uploadedVideoId,
                                  requests: failedRequests,
                                );
                          } finally {
                            if (mounted) {
                              setState(() => _isRetrying = false);
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9248D2),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    _isRetrying ? 'Retrying failed destinations...' : 'Retry Failed Destinations',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (reconnectPlatforms.isNotEmpty) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () =>
                        widget.onOpenLinkedPlatforms(reconnectPlatforms),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: Colors.orangeAccent.withValues(alpha: 0.45),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Reconnect Platforms',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: widget.onOpenManagePosts,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'Open Manage Posts',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: widget.onDone,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformResultRow(
    String platformName,
    CrossPostState state,
    String? errorMessage,
  ) {
    final (icon, color, label) = switch (state) {
      CrossPostState.success =>
        (Icons.check_circle, Colors.greenAccent, 'Posted'),
      CrossPostState.failed =>
        (Icons.error_outline, Colors.redAccent, 'Failed'),
      CrossPostState.sending =>
        (Icons.schedule_send, Colors.orangeAccent, 'Retrying'),
      CrossPostState.idle =>
        (Icons.radio_button_unchecked, Colors.white54, 'Pending'),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  platformName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  errorMessage?.isNotEmpty == true
                      ? '$label: $errorMessage'
                      : label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isReauthError(String? message) {
    if (message == null) {
      return false;
    }
    final normalized = message.toLowerCase();
    return normalized.contains('401') ||
        normalized.contains('403') ||
        normalized.contains('auth') ||
        normalized.contains('token') ||
        normalized.contains('reauth');
  }
}

class _AspectRatioWarningBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const _AspectRatioWarningBanner({
    required this.message,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF332B00),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.amber, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.amber, fontSize: 13),
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(Icons.close, color: Colors.amber, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}
