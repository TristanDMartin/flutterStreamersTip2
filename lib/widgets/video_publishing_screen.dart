import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import 'dart:math';
import '../services/video_upload_service.dart';
import '../services/video_service.dart';
import '../services/local_draft_service.dart';
import '../models/user.dart' as user_model;
import '../models/home_video.dart';
import '../providers/home_provider.dart';
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
import '../services/firestore_scheduled_post_service.dart';
import '../services/video_processing_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:developer' as developer;

// Constants for video publishing validation
class _VideoPublishingConstants {
  static const int maxCaptionLength = 500;
  static const int maxFileSizeMB = 500;
  static const int minFileSizeBytes = 1024; // 1KB minimum
  static const double minVideoDurationSeconds = 1.0;
  static const double maxVideoDurationSeconds = 300.0; // 5 minutes
}

class VideoPublishingScreen extends ConsumerStatefulWidget {
  final File videoFile;
  final String caption;
  final List<String> hashtags;
  final VoidCallback onPublish;
  final VoidCallback onCancel;

  const VideoPublishingScreen({
    super.key,
    required this.videoFile,
    required this.caption,
    required this.hashtags,
    required this.onPublish,
    required this.onCancel,
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
  String _selectedCategory = 'gaming'; // Default to gaming
  final bool _allowComments = true;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  bool _isModerating = false;
  final Set<String> _selectedPlatforms = <String>{};
  PostSchedule? _schedule;
  final VideoUploadService _uploadService = VideoUploadService();
  final VideoModerationService _moderationService = VideoModerationService();
  final EnhancedErrorHandlingService _errorHandler =
      EnhancedErrorHandlingService();
  final VideoWatermarkService _watermarkService = VideoWatermarkService();
  final OptimisticVideoService _optimisticVideoService =
      OptimisticVideoService();
  final FirestoreScheduledPostService _scheduledPostService =
      FirestoreScheduledPostService();

  // Text controllers
  late TextEditingController _captionController;

  @override
  void initState() {
    super.initState();
    _caption = widget.caption;
    _hashtags = List.from(widget.hashtags);

    // Initialize text controller with the caption
    _captionController = TextEditingController(text: _caption);
    _captionCharacterCount = _caption.length;
    
    // Listen to caption changes for real-time validation
    _captionController.addListener(_onCaptionChanged);

    // Listen to scroll to adjust video size
    _scrollController.addListener(_onScroll);

    _initializeVideo();
  }

  void _onCaptionChanged() {
    setState(() {
      _caption = _captionController.text;
      _captionCharacterCount = _caption.length;
    });
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
      // Validate file exists and is readable
      if (!await widget.videoFile.exists()) {
        throw Exception('Video file does not exist');
      }

      final fileSize = await widget.videoFile.length();
      if (fileSize < _VideoPublishingConstants.minFileSizeBytes) {
        throw Exception('Video file is too small or corrupted');
      }

      final fileSizeMB = fileSize / (1024 * 1024);
      if (fileSizeMB > _VideoPublishingConstants.maxFileSizeMB) {
        if (mounted) {
          setState(() {
            _hasError = true;
            _initializationError =
                'Video file is too large (${fileSizeMB.toStringAsFixed(1)}MB). Maximum size is ${_VideoPublishingConstants.maxFileSizeMB}MB.';
          });
        }
        return;
      }

      _controller = VideoPlayerController.file(widget.videoFile);
      await _controller.initialize();

      // Validate video duration
      _videoDuration = _controller.value.duration;
      final durationSeconds = _videoDuration!.inSeconds.toDouble();
      
      if (durationSeconds < _VideoPublishingConstants.minVideoDurationSeconds) {
        await _controller.dispose();
        throw Exception('Video is too short (minimum 1 second)');
      }
      
      if (durationSeconds > _VideoPublishingConstants.maxVideoDurationSeconds) {
        await _controller.dispose();
        throw Exception('Video is too long (maximum 5 minutes)');
      }

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _hasError = false;
          _initializationError = null;
        });
      }
    } catch (e) {
      developer.log('Error initializing video: $e',
          name: 'VideoPublishingScreen');
      if (mounted) {
        setState(() {
          _isInitialized = true; // Set to true to show error UI
          _hasError = true;
          _initializationError = e.toString().replaceAll('Exception: ', '');
        });
      }
      // Don't dispose controller here as it might not be initialized
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6137EB), Color(0xFF1C135D)],
          ),
        ),
        child: Column(
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
                    const SizedBox(height: 20),

                    // Category Selection
                    _buildCategorySection(),

                    const SizedBox(height: 20),

                    // Caption Section
                    _buildCaptionSection(),

                    const SizedBox(height: 20),

                    // Privacy Settings
                    _buildPrivacySection(),

                    const SizedBox(height: 20),

                    // Schedule Post
                    _buildSchedulePostSection(),

                    // Cross-Platform Sharing - Hidden for now
                    // _buildSharingSection(),

                    const SizedBox(
                        height: 120), // Space for bottom buttons with safe area
                  ],
                ),
              ),
            ),

            // Bottom Actions
            _buildBottomActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onCancel();
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Text(
            'Publish Video',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          if (_isModerating)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Moderating...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          else if (_isUploading)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF9248D2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${(_uploadProgress * 100).toInt()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVideoPreview() {
    return GestureDetector(
      onTap: _togglePlayPause,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.black,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
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

              // Upload Progress
              if (_isUploading)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: _uploadProgress,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFF9248D2)),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Uploading... ${(_uploadProgress * 100).toInt()}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Category',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Choose the category that best fits your video',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          // Category Dropdown
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCategory,
                isExpanded: true,
                dropdownColor: const Color(0xFF1A1A1A),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
                icon: const Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.white,
                ),
                items: _categories.map((category) {
                  return DropdownMenuItem<String>(
                    value: category.id,
                    child: Row(
                      children: [
                        Text(
                          category.emoji,
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          category.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedCategory = newValue;
                    });
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaptionSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Caption',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Caption',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${_captionCharacterCount}/${_VideoPublishingConstants.maxCaptionLength}',
                style: TextStyle(
                  color: _captionCharacterCount >
                          _VideoPublishingConstants.maxCaptionLength
                      ? Colors.red
                      : _captionCharacterCount >=
                              _VideoPublishingConstants.maxCaptionLength * 0.9
                          ? Colors.orange
                          : Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _captionController,
            maxLength: _VideoPublishingConstants.maxCaptionLength,
            maxLines: 4,
            minLines: 1,
            textInputAction: TextInputAction.newline,
            keyboardType: TextInputType.multiline,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              height: 1.4,
            ),
            decoration: InputDecoration(
              hintText: 'Write a caption...',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                    color: _caption.trim().isEmpty
                        ? Colors.red.withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                    color: _caption.trim().isEmpty
                        ? Colors.red.withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                    color: _caption.trim().isEmpty
                        ? Colors.red
                        : const Color(0xFF9248D2)),
              ),
              contentPadding: const EdgeInsets.all(16),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.03),
              counterText: '', // Hide default counter, we show our own
            ),
          ),
          if (_caption.trim().isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Caption is required',
                style: TextStyle(
                  color: Colors.red.withValues(alpha: 0.9),
                  fontSize: 12,
                ),
              ),
            ),
          const SizedBox(height: 12),
          // Tag users hint
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tip: Tag users in your caption by typing "tagged: @username"',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Hashtag suggestions
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildHashtagChip('#trending'),
              _buildHashtagChip('#viral'),
              _buildHashtagChip('#fyp'),
              _buildHashtagChip('#streaming'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacySection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
          _buildPrivacyOption('Connections', 'Only your connections can see'),
          _buildPrivacyOption('Private', 'Only you can see this video'),
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
      onScheduleChanged: (schedule) {
        setState(() {
          _schedule = schedule;
        });
      },
    );
  }

  Widget _buildBottomActions() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              const Color(0xFF1C135D).withValues(alpha: 0.9),
            ],
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _saveAsDraft();
                },
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      'Save as Draft',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: GestureDetector(
                onTap: (_isUploading ||
                        _isModerating ||
                        _caption.trim().isEmpty ||
                        _hasError)
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        _publishVideo();
                      },
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: (_isUploading ||
                            _isModerating ||
                            _caption.trim().isEmpty ||
                            _hasError)
                        ? null
                        : const LinearGradient(
                            colors: [Color(0xFF9248D2), Color(0xFF4897D2)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                    color: (_isUploading ||
                            _isModerating ||
                            _caption.trim().isEmpty ||
                            _hasError)
                        ? Colors.grey.withValues(alpha: 0.3)
                        : null,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: (_isUploading || _isModerating)
                        ? null
                        : [
                            BoxShadow(
                              color: const Color(0xFF9248D2)
                                  .withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                  child: Center(
                    child: _isModerating
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Moderating...',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          )
                        : _isUploading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : Text(
                                _schedule != null ? 'Schedule' : 'Publish',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                  ),
                ),
              ),
            ),
          ],
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
      _showUploadErrorDialog('Please add a caption to your video');
      return;
    }

    if (_caption.length > _VideoPublishingConstants.maxCaptionLength) {
      _showUploadErrorDialog(
          'Caption is too long (maximum ${_VideoPublishingConstants.maxCaptionLength} characters)');
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
      debugPrint(
          '🎬 VideoPublishingScreen: Creating optimistic video: $videoId');

      // Apply watermark if cross-platform sharing is selected
      File videoFileToUpload = widget.videoFile;
      if (_watermarkService.shouldApplyWatermark(_selectedPlatforms)) {
        debugPrint(
            '🎬 VideoPublishingScreen: Applying watermark for cross-platform sharing...');
        final watermarkedFile = await _watermarkService.addWatermarkToVideo(
          videoFile: widget.videoFile,
          selectedPlatforms: _selectedPlatforms,
          logoPath: 'assets/logo.png',
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
        localThumbnailPath: null, // Will be generated during upload
        localVideoPath: videoFileToUpload.path,
        metadata: {
          'privacy': _selectedPrivacy,
          'allowComments': _allowComments,
          'cross_platform_sharing': _selectedPlatforms.toList(),
          'watermark_applied':
              _watermarkService.shouldApplyWatermark(_selectedPlatforms),
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

        final uploadResult = await _uploadService.uploadVideo(
          videoFile: videoFileToUpload,
          caption: _caption,
          hashtags: _hashtags,
          privacy: _selectedPrivacy,
          allowComments: _allowComments,
          additionalMetadata: {
            'category': _selectedCategory,
            'cross_platform_sharing': _selectedPlatforms.toList(),
            'watermark_applied':
                _watermarkService.shouldApplyWatermark(_selectedPlatforms),
            'moderation_confidence': moderationResult.confidence,
            'moderation_checked_at': DateTime.now().toIso8601String(),
            'duration': 0,
            'fileSize': await videoFileToUpload.length(),
          },
        );

        developer.log(
            '📤 Upload result: success=${uploadResult.success}, error=${uploadResult.error}',
            name: 'VideoPublishingScreen');

        setState(() {
          _isUploading = false;
        });

        if (uploadResult.success) {
          // Add video to centralized VideoService for immediate display
          final newVideoId = await _addVideoToService(uploadResult);

          // Show success message
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Video published successfully! 🎉'),
                backgroundColor: Color(0xFF9248D2),
                duration: Duration(seconds: 3),
              ),
            );
          }
          
          // Navigate back to main tab view (which shows HomeView by default)
          if (mounted) {
            Navigator.of(context).popUntil((route) => route.isFirst);
            // Feed refresh will happen automatically when HomeView becomes visible via _reactivateFeed()
            developer.log('✅ VideoPublishingScreen: Navigated back to HomeView, feed will refresh for video: $newVideoId');
          }
        } else {
          if (mounted) {
            String errorMessage =
                uploadResult.error ?? 'Failed to publish video';

            // Provide more specific error messages
            if (errorMessage.contains('PERMISSION_DENIED')) {
              errorMessage =
                  'Permission denied. Please check your account status and try again.';
            } else if (errorMessage.contains('UNAVAILABLE')) {
              errorMessage =
                  'Service temporarily unavailable. Please try again in a few minutes.';
            } else if (errorMessage.contains('UNAUTHENTICATED')) {
              errorMessage = 'Please log in again to publish videos.';
            } else if (errorMessage.contains('thumbnail')) {
              errorMessage =
                  'Failed to generate video thumbnail. Please try again.';
            }

            _showUploadErrorDialog(errorMessage);
          }
        }
      } catch (e) {
        debugPrint(
            '❌ VideoPublishingScreen: Error during video upload process: $e');
        debugPrint('❌ VideoPublishingScreen: Error type: ${e.runtimeType}');
        debugPrint(
            '❌ VideoPublishingScreen: Stack trace: ${StackTrace.current}');

        setState(() {
          _isUploading = false;
        });
        if (mounted) {
          String errorMessage = 'Failed to publish video: ${e.toString()}';

          // Provide more specific error messages
          if (e.toString().contains('PERMISSION_DENIED')) {
            errorMessage =
                'Permission denied. Please check your account status and try again.';
          } else if (e.toString().contains('UNAVAILABLE')) {
            errorMessage =
                'Service temporarily unavailable. Please try again in a few minutes.';
          } else if (e.toString().contains('UNAUTHENTICATED')) {
            errorMessage = 'Please log in again to publish videos.';
          } else if (e.toString().contains('thumbnail')) {
            errorMessage =
                'Failed to generate video thumbnail. Please try again.';
          }

          _showUploadErrorDialog(errorMessage);
        }
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
        additionalMetadata: {
          'cross_platform_sharing': _selectedPlatforms.toList(),
          'watermark_applied':
              _watermarkService.shouldApplyWatermark(_selectedPlatforms),
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
  Future<String?> _addVideoToService(VideoUploadResult uploadResult) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return null;

      // Create a HomeVideo object from the upload result
      final video = HomeVideo(
        id: uploadResult.metadata?['videoId'] as String? ?? '',
        creator: user_model.User(
          id: currentUser.uid,
          username: currentUser.displayName ?? 'User',
          displayName: currentUser.displayName ?? 'User',
          bio: '',
          avatarURL: currentUser.photoURL ?? '',
          followerCount: 0,
          followingCount: 0,
        ),
        videoURL: uploadResult.videoUrl ?? '',
        thumbnailURL: uploadResult.thumbnailUrl ?? '',
        caption: _caption.isNotEmpty ? _caption : 'Untitled',
        categoryId: _selectedCategory,
        isDraft: false,
      );

      // Add to VideoService for immediate display (at the top - newest first)
      final videoService = ref.read(videoServiceProvider.notifier);
      videoService.addVideo(video);

      // 🚀 REFRESH FEED: Refresh HomeView to show the new video immediately
      final homeProviderNotifier = ref.read(homeProvider.notifier);
      await homeProviderNotifier.refreshAfterUpload(newVideoId: video.id);

      debugPrint(
          '✅ Video added to VideoService and HomeView refreshed: ${video.caption}');
      
      return video.id;
    } catch (e) {
      debugPrint('❌ Error adding video to VideoService: $e');
      return null;
    }
  }

  /// Schedule a video for future publishing
  Future<void> _scheduleVideo({
    required File videoFileToUpload,
    required String videoId,
    required User currentUser,
    required VideoModerationResult moderationResult,
  }) async {
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
      final scheduledPostId = await _scheduledPostService.saveScheduledPost(
        videoId: videoId,
        videoUrl: videoUrl,
        thumbnailUrl: thumbnailUrl,
        caption: _caption,
        hashtags: _hashtags,
        category: _selectedCategory,
        privacy: _selectedPrivacy,
        allowComments: _allowComments,
        schedule: _schedule!,
        metadata: {
          'moderation_confidence': moderationResult.confidence,
          'moderation_checked_at': DateTime.now().toIso8601String(),
          'duration': _videoDuration?.inSeconds ?? 0,
          'fileSize': await videoFileToUpload.length(),
          'cross_platform_sharing': _selectedPlatforms.toList(),
          'watermark_applied':
              _watermarkService.shouldApplyWatermark(_selectedPlatforms),
        },
      );

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
      final videoData = {
        'id': videoId,
        'userId': currentUser.uid,
        'creatorId': currentUser.uid,
        'videoUrl': videoUrl,
        'thumbnailUrl': thumbnailUrl,
        'caption': _caption,
        'hashtags': _hashtags,
        'privacy': _selectedPrivacy,
        'allowComments': _allowComments,
        'category': _selectedCategory,
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
