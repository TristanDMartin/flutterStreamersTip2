import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/scheduled_post.dart';
import '../services/scheduled_post_service.dart';

class EditPostView extends StatefulWidget {
  final ScheduledPost post;

  const EditPostView({
    super.key,
    required this.post,
  });

  @override
  State<EditPostView> createState() => _EditPostViewState();
}

class _EditPostViewState extends State<EditPostView> {
  final ScheduledPostService _postService = ScheduledPostService();
  final _formKey = GlobalKey<FormState>();
  final _captionController = TextEditingController();
  final _tagsController = TextEditingController();
  
  late ScheduledPost _editedPost;
  bool _isLoading = false;
  bool _hasChanges = false;
  PostVisibility _selectedVisibility = PostVisibility.public;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  String _selectedTimezone = 'America/New_York';
  
  final List<String> _availableTimezones = [
    'America/New_York',
    'America/Chicago',
    'America/Denver',
    'America/Los_Angeles',
    'Europe/London',
    'Europe/Paris',
    'Europe/Berlin',
    'Asia/Tokyo',
    'Asia/Shanghai',
    'Australia/Sydney',
  ];

  @override
  void initState() {
    super.initState();
    _editedPost = widget.post;
    _initializeForm();
  }

  void _initializeForm() {
    _captionController.text = _editedPost.caption;
    _tagsController.text = _editedPost.tags.join(', ');
    _selectedVisibility = _editedPost.visibility;
    _selectedDate = _editedPost.schedule?.scheduledAtUtc.toLocal() ?? DateTime.now();
    _selectedTime = TimeOfDay.fromDateTime(_editedPost.schedule?.scheduledAtUtc.toLocal() ?? DateTime.now());
    _selectedTimezone = _editedPost.schedule?.timezone ?? 'UTC';
  }

  @override
  void dispose() {
    _captionController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6137EB), Color(0xFF1C135D)],
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _hasChanges ? _showDiscardDialog : () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit Post',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9248D2)),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _hasChanges ? _saveChanges : null,
              child: Text(
                'Save',
                style: TextStyle(
                  color: _hasChanges ? const Color(0xFF9248D2) : Colors.white30,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
          body: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCaptionSection(),
                  const SizedBox(height: 24),
                  _buildTagsSection(),
                  const SizedBox(height: 24),
                  _buildVisibilitySection(),
                  const SizedBox(height: 24),
                  _buildScheduleSection(),
                  const SizedBox(height: 24),
                  _buildPlatformsSection(),
                  const SizedBox(height: 24),
                  _buildMediaSection(),
                  const SizedBox(height: 100), // Bottom padding
                ],
              ),
            ),
          ),
        ),
      ),
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
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _captionController,
          maxLines: 4,
          maxLength: 2200,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'What\'s on your mind?',
            hintStyle: const TextStyle(color: Colors.white70),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white30),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white30),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF9248D2)),
            ),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            counterStyle: const TextStyle(color: Colors.white70),
          ),
          onChanged: (_) => _markAsChanged(),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Caption is required';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildTagsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tags',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _tagsController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter tags separated by commas',
            hintStyle: const TextStyle(color: Colors.white70),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white30),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white30),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF9248D2)),
            ),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
          ),
          onChanged: (_) => _markAsChanged(),
        ),
        const SizedBox(height: 8),
        Text(
          'Separate multiple tags with commas (e.g., #tech, #flutter, #mobile)',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildVisibilitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Visibility',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white30),
            color: Colors.white.withValues(alpha: 0.05),
          ),
          child: Column(
            children: PostVisibility.values.map((visibility) {
              return RadioListTile<PostVisibility>(
                title: Text(
                  _getVisibilityLabel(visibility),
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  _getVisibilityDescription(visibility),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                value: visibility,
                groupValue: _selectedVisibility,
                onChanged: (value) {
                  setState(() {
                    _selectedVisibility = value!;
                    _markAsChanged();
                  });
                },
                activeColor: const Color(0xFF9248D2),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Schedule',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildDatePicker(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTimePicker(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildTimezonePicker(),
      ],
    );
  }

  Widget _buildDatePicker() {
    return GestureDetector(
      onTap: _selectDate,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white30),
          color: Colors.white.withValues(alpha: 0.05),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: Color(0xFF9248D2), size: 20),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Date',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                Text(
                  '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePicker() {
    return GestureDetector(
      onTap: _selectTime,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white30),
          color: Colors.white.withValues(alpha: 0.05),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time, color: Color(0xFF9248D2), size: 20),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Time',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                Text(
                  _selectedTime.format(context),
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimezonePicker() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white30),
        color: Colors.white.withValues(alpha: 0.05),
      ),
      child: Row(
        children: [
          const Icon(Icons.language, color: Color(0xFF9248D2), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButton<String>(
              value: _selectedTimezone,
              isExpanded: true,
              underline: const SizedBox(),
              style: const TextStyle(color: Colors.white),
              items: _availableTimezones.map((timezone) {
                return DropdownMenuItem<String>(
                  value: timezone,
                  child: Text(timezone),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedTimezone = value!;
                  _markAsChanged();
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformsSection() {
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
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white30),
            color: Colors.white.withValues(alpha: 0.05),
          ),
          child: Column(
            children: _editedPost.platforms.map((platform) {
              return CheckboxListTile(
                title: Text(
                  _getPlatformName(platform.key),
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  _getPlatformStatusText(platform.status ?? PlatformStatus.pending),
                  style: TextStyle(
                    color: _getPlatformStatusColor(platform.status ?? PlatformStatus.pending),
                    fontSize: 12,
                  ),
                ),
                value: platform.enabled,
                onChanged: (value) {
                  setState(() {
                    // Create a new PlatformConfig with updated enabled value
                    final updatedPlatform = platform.copyWith(enabled: value!);
                    final index = _editedPost.platforms.indexOf(platform);
                    _editedPost.platforms[index] = updatedPlatform;
                    _markAsChanged();
                  });
                },
                activeColor: const Color(0xFF9248D2),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildMediaSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Media',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 120,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white30),
            color: Colors.white.withValues(alpha: 0.05),
          ),
          child: _editedPost.media.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _editedPost.media.first.type == MediaType.image
                      ? Image.network(
                          _editedPost.media.first.src,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.image,
                            color: Colors.white30,
                            size: 32,
                          ),
                        )
                      : const Icon(
                          Icons.play_circle_outline,
                          color: Colors.white30,
                          size: 32,
                        ),
                )
              : const Center(
                  child: Icon(
                    Icons.add_photo_alternate,
                    color: Colors.white30,
                    size: 32,
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF9248D2),
              onPrimary: Colors.white,
              surface: Color(0xFF1A1A1A),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      setState(() {
        _selectedDate = date;
        _markAsChanged();
      });
    }
  }

  Future<void> _selectTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF9248D2),
              onPrimary: Colors.white,
              surface: Color(0xFF1A1A1A),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (time != null) {
      setState(() {
        _selectedTime = time;
        _markAsChanged();
      });
    }
  }

  void _markAsChanged() {
    if (!_hasChanges) {
      setState(() {
        _hasChanges = true;
      });
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final tags = _tagsController.text
          .split(',')
          .map((tag) => tag.trim().replaceAll('#', ''))
          .where((tag) => tag.isNotEmpty)
          .toList();

      final scheduledDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      final updatedPost = await _postService.updatePost(
        _editedPost.id,
        caption: _captionController.text.trim(),
        tags: tags,
        visibility: _selectedVisibility,
        schedule: PostSchedule(
          scheduledAtUtc: scheduledDateTime.toUtc(),
          timezone: _selectedTimezone,
          perPlatform: _editedPost.schedule?.perPlatform ?? {},
          createdAtUtc: _editedPost.schedule?.createdAtUtc ?? DateTime.now().toUtc(),
          updatedAtUtc: DateTime.now().toUtc(),
        ),
      );

      HapticFeedback.lightImpact();
      _showSuccessSnackBar('Post updated successfully');
      
      Navigator.pop(context, updatedPost);
    } catch (e) {
      _showErrorSnackBar('Failed to update post: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _showDiscardDialog() async {
    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Discard Changes',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'You have unsaved changes. Are you sure you want to discard them?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    if (shouldDiscard == true) {
      Navigator.pop(context);
    }
  }

  String _getVisibilityLabel(PostVisibility visibility) {
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
        return 'Visible to everyone';
      case PostVisibility.private:
        return 'Only visible to you';
      case PostVisibility.unlisted:
        return 'Visible to anyone with the link';
    }
  }

  String _getPlatformName(String platform) {
    switch (platform) {
      case 'youtube':
        return 'YouTube';
      case 'tiktok':
        return 'TikTok';
      case 'instagram':
        return 'Instagram';
      case 'x':
        return 'X (Twitter)';
      case 'facebook':
        return 'Facebook';
      case 'linkedin':
        return 'LinkedIn';
      default:
        return platform;
    }
  }

  String _getPlatformStatusText(PlatformStatus status) {
    switch (status) {
      case PlatformStatus.pending:
        return 'Pending';
      case PlatformStatus.publishing:
        return 'Publishing';
      case PlatformStatus.published:
        return 'Published';
      case PlatformStatus.failed:
        return 'Failed';
      case PlatformStatus.needsReauth:
        return 'Needs Re-authentication';
      case PlatformStatus.canceled:
        return 'Canceled';
    }
  }

  Color _getPlatformStatusColor(PlatformStatus status) {
    switch (status) {
      case PlatformStatus.pending:
        return Colors.blue;
      case PlatformStatus.publishing:
        return Colors.orange;
      case PlatformStatus.published:
        return Colors.green;
      case PlatformStatus.failed:
        return Colors.red;
      case PlatformStatus.needsReauth:
        return Colors.amber;
      case PlatformStatus.canceled:
        return Colors.grey;
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}
