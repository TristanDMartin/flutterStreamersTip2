import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import '../services/upload_manager.dart';
import 'instant_response_button.dart';

class PostSettingsScreen extends ConsumerStatefulWidget {
  final String videoPath;
  final VoidCallback? onCancel;

  const PostSettingsScreen({
    super.key,
    required this.videoPath,
    this.onCancel,
  });

  @override
  ConsumerState<PostSettingsScreen> createState() => _PostSettingsScreenState();
}

class _PostSettingsScreenState extends ConsumerState<PostSettingsScreen> {
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _hashtagController = TextEditingController();
  final TextEditingController _mentionController = TextEditingController();
  
  PrivacyLevel _privacyLevel = PrivacyLevel.everyone;
  bool _allowComments = true;
  bool _allowDuet = true;
  bool _allowStitch = true;
  bool _crossShareToInstagram = false;
  bool _crossShareToTikTok = false;
  bool _crossShareToYouTube = false;
  
  String? _selectedThumbnail;
  bool _isUploading = false;

  @override
  void dispose() {
    _captionController.dispose();
    _hashtagController.dispose();
    _mentionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uploadState = ref.watch(uploadManagerProvider);
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),
            
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Video thumbnail preview
                    _buildThumbnailPreview(),
                    
                    const SizedBox(height: 24),
                    
                    // Caption section
                    _buildCaptionSection(),
                    
                    const SizedBox(height: 24),
                    
                    // Hashtags section
                    _buildHashtagsSection(),
                    
                    const SizedBox(height: 24),
                    
                    // Mentions section
                    _buildMentionsSection(),
                    
                    const SizedBox(height: 24),
                    
                    // Privacy settings
                    _buildPrivacySection(),
                    
                    const SizedBox(height: 24),
                    
                    // Interaction settings
                    _buildInteractionSection(),
                    
                    const SizedBox(height: 24),
                    
                    // Cross-platform sharing
                    _buildCrossShareSection(),
                  ],
                ),
              ),
            ),
            
            // Bottom actions
            _buildBottomActions(),
            
            // Upload banner
            if (uploadState.isUploading) _buildUploadBanner(uploadState),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          InstantIconButton(
            onPressed: widget.onCancel ?? () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.arrow_back,
              color: Colors.white,
              size: 28,
            ),
            hapticType: HapticFeedbackType.selectionClick,
          ),
          const Spacer(),
          const Text(
            'Post Settings',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 48), // Balance the back button
        ],
      ),
    );
  }

  Widget _buildThumbnailPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Cover Thumbnail',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _selectedThumbnail != null
                ? Image.file(
                    File(_selectedThumbnail!),
                    fit: BoxFit.cover,
                  )
                : Container(
                    color: Colors.grey[900],
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.video_library,
                            color: Colors.white,
                            size: 48,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Video Thumbnail',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        InstantElevatedButton(
          onPressed: _selectThumbnail,
          hapticType: HapticFeedbackType.lightImpact,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF9248D2),
            foregroundColor: Colors.white,
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.photo_camera),
              SizedBox(width: 8),
              Text('Change Thumbnail'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCaptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Caption',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: TextField(
            controller: _captionController,
            maxLines: 4,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Write a caption...',
              hintStyle: TextStyle(color: Colors.white54),
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHashtagsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Hashtags',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: TextField(
            controller: _hashtagController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: '#hashtag1 #hashtag2 #hashtag3',
              hintStyle: TextStyle(color: Colors.white54),
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(16),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Add hashtags to help people discover your video',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildMentionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mentions',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: TextField(
            controller: _mentionController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: '@username1 @username2',
              hintStyle: TextStyle(color: Colors.white54),
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(16),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Mention other users in your video',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildPrivacySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Privacy',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...PrivacyLevel.values.map((privacy) {
          return _buildPrivacyOption(privacy);
        }),
      ],
    );
  }

  Widget _buildPrivacyOption(PrivacyLevel privacy) {
    final isSelected = _privacyLevel == privacy;
    return InstantResponseButton(
      onPressed: () {
        setState(() {
          _privacyLevel = privacy;
        });
      },
      hapticType: HapticFeedbackType.selectionClick,
      scaleOnPress: 0.98,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected 
              ? const Color(0xFF9248D2).withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
                ? const Color(0xFF9248D2)
                : Colors.white.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? const Color(0xFF9248D2) : Colors.white54,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    privacy.title,
                    style: TextStyle(
                      color: isSelected ? const Color(0xFF9248D2) : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    privacy.description,
                    style: const TextStyle(
                      color: Colors.white54,
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

  Widget _buildInteractionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Interaction Settings',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        _buildInteractionToggle(
          'Allow Comments',
          'Let others comment on your video',
          _allowComments,
          (value) => setState(() => _allowComments = value),
        ),
        _buildInteractionToggle(
          'Allow Duet',
          'Let others create duets with your video',
          _allowDuet,
          (value) => setState(() => _allowDuet = value),
        ),
        _buildInteractionToggle(
          'Allow Stitch',
          'Let others stitch your video',
          _allowStitch,
          (value) => setState(() => _allowStitch = value),
        ),
      ],
    );
  }

  Widget _buildInteractionToggle(
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
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
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFF9248D2),
          ),
        ],
      ),
    );
  }

  Widget _buildCrossShareSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Cross-Platform Sharing',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        _buildCrossShareToggle(
          'Instagram',
          Icons.camera_alt,
          _crossShareToInstagram,
          (value) => setState(() => _crossShareToInstagram = value),
        ),
        _buildCrossShareToggle(
          'TikTok',
          Icons.music_note,
          _crossShareToTikTok,
          (value) => setState(() => _crossShareToTikTok = value),
        ),
        _buildCrossShareToggle(
          'YouTube',
          Icons.play_circle,
          _crossShareToYouTube,
          (value) => setState(() => _crossShareToYouTube = value),
        ),
      ],
    );
  }

  Widget _buildCrossShareToggle(
    String platform,
    IconData icon,
    bool value,
    Function(bool) onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              platform,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFF9248D2),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Draft button
          Expanded(
            child: InstantOutlinedButton(
              onPressed: _saveAsDraft,
              hapticType: HapticFeedbackType.lightImpact,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white, width: 2),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Save as Draft',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Post button
          Expanded(
            child: InstantElevatedButton(
              onPressed: _canPost() ? _postVideo : null,
              enabled: _canPost(),
              hapticType: HapticFeedbackType.mediumImpact,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9248D2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Post',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadBanner(UploadManagerState uploadState) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.9),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Color(0xFF9248D2),
                  strokeWidth: 2,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  uploadState.tipText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: uploadState.progress,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF9248D2)),
          ),
        ],
      ),
    );
  }

  void _selectThumbnail() {
    // TODO: Implement thumbnail selection from video frames
    setState(() {
      _selectedThumbnail = widget.videoPath; // Placeholder
    });
  }

  bool _canPost() {
    return _captionController.text.isNotEmpty && !_isUploading;
  }

  void _saveAsDraft() {
    // TODO: Implement draft saving
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Draft saved successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _postVideo() {
    setState(() {
      _isUploading = true;
    });

    final uploadManager = ref.read(uploadManagerProvider.notifier);
    uploadManager.startUpload(_captionController.text);

    // TODO: Implement actual video upload
    // This is a placeholder implementation
    Future.delayed(const Duration(seconds: 3), () {
      uploadManager.finishUpload();
      setState(() {
        _isUploading = false;
      });
      
      // Navigate back to home or show success
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
  }
}

enum PrivacyLevel {
  everyone('Everyone', 'Anyone can see your video'),
  connections('Connections', 'Only people you follow can see your video'),
  private('Private', 'Only you can see your video');

  const PrivacyLevel(this.title, this.description);
  final String title;
  final String description;
}
