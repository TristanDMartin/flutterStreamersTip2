import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/scheduled_post.dart';
import '../widgets/schedule_post_widget.dart';

class PostComposerIntegration extends StatefulWidget {
  final List<PostMedia> media;
  final String initialCaption;
  final List<PlatformKey> selectedPlatforms;

  const PostComposerIntegration({
    super.key,
    required this.media,
    required this.initialCaption,
    required this.selectedPlatforms,
  });

  @override
  State<PostComposerIntegration> createState() => _PostComposerIntegrationState();
}

class _PostComposerIntegrationState extends State<PostComposerIntegration> {
  String _caption = '';
  PostSchedule? _schedule;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _caption = widget.initialCaption;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Post Composer',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _publishPost,
            child: Text(
              _schedule != null ? 'Schedule' : 'Publish',
              style: TextStyle(
                color: _isSubmitting ? Colors.white30 : const Color(0xFF9248D2),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Media Preview
            _buildMediaPreview(),
            
            const SizedBox(height: 24),
            
            // Caption Input
            _buildCaptionInput(),
            
            const SizedBox(height: 24),
            
            // Platform Selection
            _buildPlatformSelection(),
            
            const SizedBox(height: 24),
            
            // Schedule Post Widget
            SchedulePostWidget(
              selectedPlatforms: widget.selectedPlatforms,
              caption: _caption,
              media: widget.media,
              onScheduleChanged: (schedule) {
                setState(() {
                  _schedule = schedule;
                });
              },
            ),
            
            const SizedBox(height: 24),
            
            // Additional Options
            _buildAdditionalOptions(),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaPreview() {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withValues(alpha: 0.1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: widget.media.isNotEmpty
            ? widget.media.first.type == MediaType.image
                ? Image.network(
                    widget.media.first.src,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.image,
                      color: Colors.white30,
                      size: 48,
                    ),
                  )
                : const Icon(
                    Icons.play_circle_outline,
                    color: Colors.white30,
                    size: 48,
                  )
            : const Icon(
                Icons.add_photo_alternate,
                color: Colors.white30,
                size: 48,
              ),
      ),
    );
  }

  Widget _buildCaptionInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Caption',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          style: const TextStyle(color: Colors.white),
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Write a caption...',
            hintStyle: const TextStyle(color: Colors.white70),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.2),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.2),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: Color(0xFF9248D2),
                width: 2,
              ),
            ),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
          ),
          onChanged: (value) {
            setState(() {
              _caption = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildPlatformSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Platforms',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: widget.selectedPlatforms.map((platform) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF9248D2).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF9248D2),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getPlatformIcon(platform),
                  size: 16,
                  color: const Color(0xFF9248D2),
                ),
                const SizedBox(width: 4),
                Text(
                  _getPlatformName(platform),
                  style: const TextStyle(
                    color: Color(0xFF9248D2),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildAdditionalOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Additional Options',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildOptionButton(
                icon: Icons.visibility,
                label: 'Visibility',
                onTap: () => _showVisibilityDialog(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildOptionButton(
                icon: Icons.tag,
                label: 'Tags',
                onTap: () => _showTagsDialog(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOptionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white70, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getPlatformName(PlatformKey platform) {
    switch (platform) {
      case PlatformKey.youtube:
        return 'YouTube';
      case PlatformKey.tiktok:
        return 'TikTok';
      case PlatformKey.instagram:
        return 'Instagram';
      case PlatformKey.x:
        return 'X (Twitter)';
      case PlatformKey.facebook:
        return 'Facebook';
      case PlatformKey.linkedin:
        return 'LinkedIn';
    }
  }

  IconData _getPlatformIcon(PlatformKey platform) {
    switch (platform) {
      case PlatformKey.youtube:
        return Icons.play_circle_filled;
      case PlatformKey.tiktok:
        return Icons.music_note;
      case PlatformKey.instagram:
        return Icons.camera_alt;
      case PlatformKey.x:
        return Icons.alternate_email;
      case PlatformKey.facebook:
        return Icons.facebook;
      case PlatformKey.linkedin:
        return Icons.business;
    }
  }

  void _showVisibilityDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Post Visibility',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ...PostVisibility.values.map((visibility) => ListTile(
              title: Text(
                _getVisibilityName(visibility),
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                _getVisibilityDescription(visibility),
                style: const TextStyle(color: Colors.white70),
              ),
              onTap: () {
                Navigator.pop(context);
                // Handle visibility selection
              },
            )),
          ],
        ),
      ),
    );
  }

  void _showTagsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Add Tags',
          style: TextStyle(color: Colors.white),
        ),
        content: const TextField(
          style: TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter tags separated by commas...',
            hintStyle: TextStyle(color: Colors.white70),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  String _getVisibilityName(PostVisibility visibility) {
    switch (visibility) {
      case PostVisibility.public:
        return 'Public';
      case PostVisibility.private:
        return 'Private';
      case PostVisibility.unlisted:
        return 'Unlisted';
    }
  }

  String _getVisibilityDescription(PostVisibility visibility) {
    switch (visibility) {
      case PostVisibility.public:
        return 'Anyone can see this post';
      case PostVisibility.private:
        return 'Only you can see this post';
      case PostVisibility.unlisted:
        return 'Only people with the link can see this post';
    }
  }

  Future<void> _publishPost() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      HapticFeedback.mediumImpact();
      
      // Simulate API call
      await Future.delayed(const Duration(seconds: 2));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _schedule != null 
                  ? 'Post scheduled successfully!'
                  : 'Post published successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to ${_schedule != null ? 'schedule' : 'publish'} post: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}
