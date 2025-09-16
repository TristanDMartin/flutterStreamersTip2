import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import 'dart:math';
import '../services/video_upload_service.dart';
import '../services/video_moderation_service.dart';
import '../services/enhanced_error_handling_service.dart';
import '../services/video_watermark_service.dart';
import '../services/upload_status_manager.dart';
import '../services/optimistic_video_service.dart';

class VideoPublishingScreen extends StatefulWidget {
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
  State<VideoPublishingScreen> createState() => _VideoPublishingScreenState();
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

class _VideoPublishingScreenState extends State<VideoPublishingScreen> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;

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
      id: 'roleplay',
      name: 'Roleplay',
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
  final VideoUploadService _uploadService = VideoUploadService();
  final VideoModerationService _moderationService = VideoModerationService();
  final EnhancedErrorHandlingService _errorHandler = EnhancedErrorHandlingService();
  final VideoWatermarkService _watermarkService = VideoWatermarkService();
  final UploadStatusManager _uploadStatusManager = UploadStatusManager();
  final OptimisticVideoService _optimisticVideoService = OptimisticVideoService();

  @override
  void initState() {
    super.initState();
    _caption = widget.caption;
    _hashtags = List.from(widget.hashtags);
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    _controller = VideoPlayerController.file(widget.videoFile);
    await _controller.initialize();
    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
          
          // Content
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Video Preview
                  _buildVideoPreview(),
                  
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
                  
                  // Cross-Platform Sharing
                  _buildSharingSection(),
                  
                  const SizedBox(height: 100), // Space for bottom button
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
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.chevron_left,
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
    return Container(
      height: 200,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.black,
      ),
      child: Stack(
        children: [
          if (_isInitialized)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          
          // Play/Pause Overlay
          Center(
            child: GestureDetector(
              onTap: _togglePlayPause,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha:0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
          
          // Upload Progress
          if (_isUploading)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha:0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: _uploadProgress,
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF9248D2)),
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
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          // Category Dropdown
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
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
        color: Colors.white.withValues(alpha:0.05),
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
          const SizedBox(height: 12),
          TextField(
            onChanged: (value) => setState(() => _caption = value),
            controller: TextEditingController(text: _caption),
            maxLines: 4,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Write a caption...',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha:0.5)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withValues(alpha:0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withValues(alpha:0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF9248D2)),
              ),
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
        color: Colors.white.withValues(alpha:0.05),
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


  Widget _buildSharingSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha:0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cross-Platform Sharing',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildPlatformOption('Instagram', Icons.camera_alt, _selectedPlatforms.contains('Instagram')),
              const SizedBox(width: 12),
              _buildPlatformOption('TikTok', Icons.music_note, _selectedPlatforms.contains('TikTok')),
              const SizedBox(width: 12),
              _buildPlatformOption('YouTube', Icons.play_circle, _selectedPlatforms.contains('YouTube')),
            ],
          ),
          if (_selectedPlatforms.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF9248D2).withValues(alpha:0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF9248D2).withValues(alpha:0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.water_drop,
                    color: Color(0xFF9248D2),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Watermark will be added to your video for cross-platform sharing',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha:0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            const Color(0xFF1C135D).withOpacity(0.8),
          ],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                widget.onCancel();
              },
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
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
              onTap: (_isUploading || _isModerating) ? null : () {
                HapticFeedback.lightImpact();
                _publishVideo();
              },
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  gradient: (_isUploading || _isModerating)
                      ? null
                      : const LinearGradient(
                          colors: [Color(0xFF9248D2), Color(0xFF4897D2)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                  color: (_isUploading || _isModerating) ? Colors.grey.withOpacity(0.3) : null,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: (_isUploading || _isModerating) ? null : [
                    BoxShadow(
                      color: const Color(0xFF9248D2).withOpacity(0.3),
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
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Publish',
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
        ],
      ),
    );
  }

  Widget _buildHashtagChip(String hashtag) {
    return GestureDetector(
      onTap: () {
        setState(() {
          if (_hashtags.contains(hashtag)) {
            _hashtags.remove(hashtag);
          } else {
            _hashtags.add(hashtag);
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _hashtags.contains(hashtag)
              ? const Color(0xFF9248D2)
              : Colors.white.withValues(alpha:0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _hashtags.contains(hashtag)
                ? const Color(0xFF9248D2)
                : Colors.white.withValues(alpha:0.3),
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
                  color: isSelected ? const Color(0xFF9248D2) : Colors.white.withValues(alpha:0.3),
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
                      color: Colors.white.withValues(alpha:0.7),
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


  Widget _buildPlatformOption(String platform, IconData icon, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          if (_selectedPlatforms.contains(platform)) {
            _selectedPlatforms.remove(platform);
          } else {
            _selectedPlatforms.add(platform);
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF9248D2) : Colors.white.withValues(alpha:0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF9248D2) : Colors.white.withValues(alpha:0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(
              platform,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _publishVideo() async {
    if (_caption.trim().isEmpty) {
      _showUploadErrorDialog('Please add a caption to your video');
      return;
    }

    setState(() {
      _isModerating = true;
    });

    try {
      // 1. Run content moderation
    // print('🔍 Running content moderation...');
      final moderationResult = await _moderationService.moderateVideo(
        videoFile: widget.videoFile,
        caption: _caption,
        hashtags: _hashtags,
        metadata: {
          'privacy': _selectedPrivacy,
          'allowComments': _allowComments,
        },
      );

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
    // print('🎬 Creating optimistic video: $videoId');

      // Apply watermark if cross-platform sharing is selected
      File videoFileToUpload = widget.videoFile;
      if (_watermarkService.shouldApplyWatermark(_selectedPlatforms)) {
    // print('🎬 Applying watermark for cross-platform sharing...');
        final watermarkedFile = await _watermarkService.addWatermarkToVideo(
          videoFile: widget.videoFile,
          selectedPlatforms: _selectedPlatforms,
          logoPath: 'assets/logo.png',
        );
        if (watermarkedFile != null) {
          videoFileToUpload = watermarkedFile;
        }
      }

      // 3. Create optimistic video placeholder
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
          'watermark_applied': _watermarkService.shouldApplyWatermark(_selectedPlatforms),
          'moderation_confidence': moderationResult.confidence,
          'moderation_checked_at': DateTime.now().toIso8601String(),
          'duration': 0, // Will be calculated during processing
          'fileSize': await videoFileToUpload.length(),
        },
      );

      // 4. Start background upload
    // print('📤 Starting background upload...');
      await _uploadStatusManager.startUpload(
        fileUri: videoFileToUpload.path,
        title: _caption,
        categories: [_selectedCategory],
        videoId: videoId,
        metadata: {
          'privacy': _selectedPrivacy,
          'allowComments': _allowComments,
          'cross_platform_sharing': _selectedPlatforms.toList(),
          'watermark_applied': _watermarkService.shouldApplyWatermark(_selectedPlatforms),
          'moderation_confidence': moderationResult.confidence,
          'moderation_checked_at': DateTime.now().toIso8601String(),
          'duration': 0,
          'fileSize': await videoFileToUpload.length(),
        },
      );

      // 5. Close composer immediately
      if (mounted) {
        Navigator.of(context).pop();
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
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(length, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
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
                color: Colors.red.withValues(alpha:0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha:0.3)),
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
      final uploadResult = await _uploadService.saveAsDraft(
        videoFile: widget.videoFile,
        caption: _caption,
        hashtags: _hashtags,
        privacy: _selectedPrivacy,
        allowComments: _allowComments,
        additionalMetadata: {
          'category': _selectedCategory,
          'cross_platform_sharing': _selectedPlatforms.toList(),
          'watermark_applied': _watermarkService.shouldApplyWatermark(_selectedPlatforms),
        },
      );

      setState(() {
        _isUploading = false;
      });

      if (uploadResult.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video saved as draft 📝'),
            backgroundColor: Color(0xFF9248D2),
            duration: Duration(seconds: 3),
          ),
        );
        widget.onPublish();
      } else {
        _showUploadErrorDialog(uploadResult.error ?? 'Failed to save draft');
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
        suggestedActions: ['Try again', 'Check your connection', 'Restart the app'],
      );

      setState(() {
        _isUploading = false;
      });
      _showUploadErrorDialog('Failed to save draft: ${e.toString()}');
    }
  }
}
