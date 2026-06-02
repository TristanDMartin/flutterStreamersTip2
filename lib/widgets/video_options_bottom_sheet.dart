import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../models/home_video.dart';
import '../models/user.dart';
import '../core/feature_flags.dart';
import '../services/video_actions_service.dart';
import '../utils/avatar_url_resolver.dart';
import 'streamer_card_view.dart';
import 'package:streamers_tip/utils/secure_log.dart';

enum VideoOption {
  saveVideo,
  privacy,
  editCaption,
  pinToProfile,
  unpinFromProfile,
  copyLink,
  share,
  delete,
  addToFavorites,
  removeFromFavorites,
  notInterested,
  report,
}

class VideoOptionsBottomSheet extends ConsumerStatefulWidget {
  final HomeVideo video;
  final User currentUser;
  final VoidCallback? onVideoDeleted;
  final VoidCallback? onVideoUpdated;

  const VideoOptionsBottomSheet({
    super.key,
    required this.video,
    required this.currentUser,
    this.onVideoDeleted,
    this.onVideoUpdated,
  });

  @override
  ConsumerState<VideoOptionsBottomSheet> createState() =>
      _VideoOptionsBottomSheetState();
}

class _VideoOptionsBottomSheetState
    extends ConsumerState<VideoOptionsBottomSheet> {
  bool _isProcessing = false;

  bool get _isOwner => widget.currentUser.id == widget.video.creator.id;

  List<VideoOption> _buildMenuOptions() {
    final List<VideoOption> options = [];
    if (_isOwner) {
      if (FeatureFlags.videoDownload) {
        options.add(VideoOption.saveVideo);
      }
      options.add(VideoOption.privacy);
      options.add(VideoOption.editCaption);
      if (widget.video.isPinned) {
        options.add(VideoOption.unpinFromProfile);
      } else {
        options.add(VideoOption.pinToProfile);
      }
      options.add(VideoOption.copyLink);
      options.add(VideoOption.share);
      options.add(VideoOption.delete);
    } else {
      if (FeatureFlags.videoDownload && widget.video.allowSave) {
        options.add(VideoOption.saveVideo);
      }
      if (widget.video.isFavorited) {
        options.add(VideoOption.removeFromFavorites);
      } else {
        options.add(VideoOption.addToFavorites);
      }
      options.add(VideoOption.notInterested);
      options.add(VideoOption.report);
      options.add(VideoOption.copyLink);
      options.add(VideoOption.share);
    }
    return options;
  }

  IconData _getOptionIcon(VideoOption option) {
    switch (option) {
      case VideoOption.saveVideo:
        return Icons.download_outlined;
      case VideoOption.privacy:
        return Icons.visibility_outlined;
      case VideoOption.editCaption:
        return Icons.edit_outlined;
      case VideoOption.pinToProfile:
        return Icons.push_pin_outlined;
      case VideoOption.unpinFromProfile:
        return Icons.push_pin;
      case VideoOption.copyLink:
        return Icons.link_outlined;
      case VideoOption.share:
        return Icons.share_outlined;
      case VideoOption.delete:
        return Icons.delete_outline;
      case VideoOption.addToFavorites:
        return Icons.favorite_border;
      case VideoOption.removeFromFavorites:
        return Icons.favorite;
      case VideoOption.notInterested:
        return Icons.not_interested_outlined;
      case VideoOption.report:
        return Icons.flag_outlined;
    }
  }

  String _getOptionLabel(VideoOption option) {
    switch (option) {
      case VideoOption.saveVideo:
        return 'Save video';
      case VideoOption.privacy:
        return 'Privacy';
      case VideoOption.editCaption:
        return 'Edit caption & tags';
      case VideoOption.pinToProfile:
        return 'Pin to profile';
      case VideoOption.unpinFromProfile:
        return 'Unpin from profile';
      case VideoOption.copyLink:
        return 'Copy link';
      case VideoOption.share:
        return 'Share';
      case VideoOption.delete:
        return 'Delete';
      case VideoOption.addToFavorites:
        return 'Add to Favorites';
      case VideoOption.removeFromFavorites:
        return 'Remove from Favorites';
      case VideoOption.notInterested:
        return 'Not interested';
      case VideoOption.report:
        return 'Report';
    }
  }

  bool _isDestructiveOption(VideoOption option) {
    return option == VideoOption.delete;
  }

  Future<void> _handleOptionTap(VideoOption option) async {
    if (_isProcessing) return;
    switch (option) {
      case VideoOption.saveVideo:
        await _handleSaveVideo();
        break;
      case VideoOption.privacy:
        await _handlePrivacyChange();
        break;
      case VideoOption.editCaption:
        await _handleEditCaption();
        break;
      case VideoOption.pinToProfile:
      case VideoOption.unpinFromProfile:
        await _handlePinToggle();
        break;
      case VideoOption.copyLink:
        await _handleCopyLink();
        break;
      case VideoOption.share:
        await _handleShare();
        break;
      case VideoOption.delete:
        await _handleDelete();
        break;
      case VideoOption.addToFavorites:
      case VideoOption.removeFromFavorites:
        await _handleFavoritesToggle();
        break;
      case VideoOption.notInterested:
        await _handleNotInterested();
        break;
      case VideoOption.report:
        await _handleReport();
        break;
    }
  }

  Future<void> _handleSaveVideo() async {
    setState(() => _isProcessing = true);
    try {
      final videoActionsService = ref.read(videoActionsServiceProvider);
      await videoActionsService.saveVideo(widget.video.id);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video saved to gallery')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save video: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handlePrivacyChange() async {
    final String? newPrivacy = await showDialog<String>(
      context: context,
      builder: (context) => _PrivacyDialog(
        currentPrivacy: widget.video.visibility,
      ),
    );
    if (newPrivacy == null || newPrivacy == widget.video.visibility) return;
    setState(() => _isProcessing = true);
    try {
      final videoActionsService = ref.read(videoActionsServiceProvider);
      await videoActionsService.setPrivacy(widget.video.id, newPrivacy);
      if (mounted) {
        Navigator.of(context).pop();
        widget.onVideoUpdated?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Privacy changed to $newPrivacy')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to change privacy: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleEditCaption() async {
    final String? newCaption = await showDialog<String>(
      context: context,
      builder: (context) => _EditCaptionDialog(
        videoId: widget.video.id,
        currentCaption: widget.video.caption,
        currentTags: widget.video.tags,
      ),
    );
    if (newCaption == null) return;
    setState(() => _isProcessing = true);
    try {
      final videoActionsService = ref.read(videoActionsServiceProvider);
      await videoActionsService.updateCaption(widget.video.id, newCaption);
      if (mounted) {
        Navigator.of(context).pop();
        widget.onVideoUpdated?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Caption updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update caption: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handlePinToggle() async {
    setState(() => _isProcessing = true);
    try {
      final videoActionsService = ref.read(videoActionsServiceProvider);
      if (widget.video.isPinned) {
        await videoActionsService.unpinVideo(widget.video.id);
      } else {
        await videoActionsService.pinVideo(widget.video.id);
      }
      if (mounted) {
        Navigator.of(context).pop();
        widget.onVideoUpdated?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.video.isPinned ? 'Video unpinned' : 'Video pinned',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to toggle pin: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleCopyLink() async {
    try {
      final videoActionsService = ref.read(videoActionsServiceProvider);
      await videoActionsService.copyLink(widget.video.id);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Link copied to clipboard')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to copy link: $e')),
        );
      }
    }
  }

  Future<void> _handleShare() async {
    try {
      final videoActionsService = ref.read(videoActionsServiceProvider);
      await videoActionsService.shareVideo(widget.video.id);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share: $e')),
        );
      }
    }
  }

  Future<void> _handleDelete() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Video'),
        content: const Text(
          'Are you sure you want to delete this video? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _isProcessing = true);
    try {
      final videoActionsService = ref.read(videoActionsServiceProvider);
      await videoActionsService.deleteVideo(widget.video.id);
      if (mounted) {
        Navigator.of(context).pop();
        widget.onVideoDeleted?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete video: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleFavoritesToggle() async {
    setState(() => _isProcessing = true);
    try {
      final videoActionsService = ref.read(videoActionsServiceProvider);
      if (widget.video.isFavorited) {
        await videoActionsService.removeFromFavorites(widget.video.id);
      } else {
        await videoActionsService.addToFavorites(widget.video.id);
      }
      if (mounted) {
        Navigator.of(context).pop();
        widget.onVideoUpdated?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.video.isFavorited
                  ? 'Removed from Favorites'
                  : 'Added to Favorites',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update favorites: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleNotInterested() async {
    setState(() => _isProcessing = true);
    try {
      final String creatorId = widget.video.creator.id;
      await ref.read(videoActionsServiceProvider).markNotInterested(
            videoId: widget.video.id,
            creatorId: creatorId,
          );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Noted. Adjusting recommendations...'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update preferences: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handleReport() async {
    final String? reason = await showDialog<String>(
      context: context,
      builder: (context) => const _ReportDialog(),
    );
    if (reason == null) return;
    setState(() => _isProcessing = true);
    try {
      final videoActionsService = ref.read(videoActionsServiceProvider);
      await videoActionsService.reportVideo(widget.video.id, reason);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted. Thank you.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit report: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = _buildMenuOptions();
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options[index];
                  return ListTile(
                    leading: Icon(
                      _getOptionIcon(option),
                      color: _isDestructiveOption(option)
                          ? Colors.red
                          : Theme.of(context).iconTheme.color,
                    ),
                    title: Text(
                      _getOptionLabel(option),
                      style: TextStyle(
                        color: _isDestructiveOption(option)
                            ? Colors.red
                            : Theme.of(context).textTheme.bodyLarge?.color,
                        fontWeight: _isDestructiveOption(option)
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    enabled: !_isProcessing,
                    onTap: () => _handleOptionTap(option),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _PrivacyDialog extends StatefulWidget {
  final String currentPrivacy;

  const _PrivacyDialog({required this.currentPrivacy});

  @override
  State<_PrivacyDialog> createState() => _PrivacyDialogState();
}

class _PrivacyDialogState extends State<_PrivacyDialog> {
  late String _selectedPrivacy;

  @override
  void initState() {
    super.initState();
    _selectedPrivacy = widget.currentPrivacy;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Privacy'),
      content: RadioGroup<String>(
        groupValue: _selectedPrivacy,
        onChanged: (String? value) {
          if (value != null) {
            setState(() => _selectedPrivacy = value);
          }
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('Public'),
              subtitle: const Text('Anyone can see this video'),
              value: 'public',
            ),
            RadioListTile<String>(
              title: const Text('Followers'),
              subtitle: const Text('Only your followers can see this video'),
              value: 'followers',
            ),
            RadioListTile<String>(
              title: const Text('Private'),
              subtitle: const Text('Only you can see this video'),
              value: 'private',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_selectedPrivacy),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _EditCaptionDialog extends StatefulWidget {
  final String videoId;
  final String currentCaption;
  final List<String> currentTags;

  const _EditCaptionDialog({
    required this.videoId,
    required this.currentCaption,
    required this.currentTags,
  });

  @override
  State<_EditCaptionDialog> createState() => _EditCaptionDialogState();
}

class _EditCaptionDialogState extends State<_EditCaptionDialog> {
  late TextEditingController _captionController;
  List<Map<String, dynamic>> _taggedUsers = [];
  bool _isLoadingTaggedUsers = true;

  @override
  void initState() {
    super.initState();
    _captionController = TextEditingController(text: widget.currentCaption);
    _loadTaggedUsers();
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _loadTaggedUsers() async {
    if (firebase_auth.FirebaseAuth.instance.currentUser == null) {
      if (mounted) {
        setState(() {
          _taggedUsers = [];
          _isLoadingTaggedUsers = false;
        });
      }
      return;
    }
    try {
      final tagsSnapshot = await FirebaseFirestore.instance
          .collection('tags')
          .where('videoId', isEqualTo: widget.videoId)
          .get();

      if (tagsSnapshot.docs.isEmpty) {
        if (mounted) {
          setState(() {
            _taggedUsers = [];
            _isLoadingTaggedUsers = false;
          });
        }
        return;
      }

      final List<Map<String, dynamic>> taggedUsers = [];
      for (final tagDoc in tagsSnapshot.docs) {
        final tagData = tagDoc.data();
        final taggedUserId = tagData['taggedUserId'] as String?;
        if (taggedUserId == null) continue;

        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(taggedUserId)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data()!;
          taggedUsers.add({
            'userId': taggedUserId,
            'username': userData['username'] ?? 'unknown',
            'displayName':
                userData['displayName'] ?? userData['username'] ?? 'Unknown',
            'avatarURL': resolveAvatarUrl(userData) ?? '',
          });
        }
      }

      if (mounted) {
        setState(() {
          _taggedUsers = taggedUsers;
          _isLoadingTaggedUsers = false;
        });
      }
    } catch (e) {
      if (e.toString().contains('permission-denied') ||
          e.toString().contains('PERMISSION_DENIED')) {
        if (mounted) {
          setState(() {
            _taggedUsers = [];
            _isLoadingTaggedUsers = false;
          });
        }
        return;
      }
      debugPrint('❌ Error loading tagged users: $e');
      if (mounted) {
        setState(() {
          _isLoadingTaggedUsers = false;
        });
      }
    }
  }

  void _navigateToTaggedUserProfile(String userId) {
    HapticFeedback.lightImpact();
    secureLog(
        '👤 EditCaptionDialog: Opening StreamerCard for tagged user: $userId');

    // Get current user ID
    final currentUserId = firebase_auth.FirebaseAuth.instance.currentUser?.uid;

    // Navigate to StreamerCardView for tagged user
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => StreamerCardView(
          userId: userId,
          currentUserId: currentUserId,
          onDismiss: () => Navigator.of(context).pop(),
        ),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Caption'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _captionController,
              maxLines: 3,
              maxLength: 500,
              decoration: const InputDecoration(
                hintText: 'Enter caption...',
                border: OutlineInputBorder(),
              ),
            ),
            if (_taggedUsers.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Tagged Users:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _taggedUsers.map((user) {
                  return GestureDetector(
                    onTap: () =>
                        _navigateToTaggedUserProfile(user['userId'] as String),
                    child: Chip(
                      avatar: CircleAvatar(
                        radius: 12,
                        backgroundImage: user['avatarURL'] != null &&
                                user['avatarURL'].toString().isNotEmpty
                            ? NetworkImage(user['avatarURL'].toString())
                            : null,
                        child: user['avatarURL'] == null ||
                                user['avatarURL'].toString().isEmpty
                            ? Text(
                                (user['displayName'] as String? ?? 'U')
                                    .substring(0, 1)
                                    .toUpperCase(),
                                style: const TextStyle(fontSize: 12),
                              )
                            : null,
                      ),
                      label: Text('@${user['username']}'),
                      backgroundColor: Colors.blue.withValues(alpha: 0.1),
                      labelStyle: const TextStyle(fontSize: 12),
                    ),
                  );
                }).toList(),
              ),
            ] else if (_isLoadingTaggedUsers) ...[
              const SizedBox(height: 16),
              const Center(
                child: CircularProgressIndicator(),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_captionController.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _ReportDialog extends StatefulWidget {
  const _ReportDialog();

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  String? _selectedReason;

  final List<String> _reasons = [
    'Spam or misleading',
    'Hate speech or harassment',
    'Violence or harmful content',
    'Adult content',
    'Copyright infringement',
    'Other',
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Report Video'),
      content: RadioGroup<String>(
        groupValue: _selectedReason,
        onChanged: (String? value) {
          setState(() => _selectedReason = value);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _reasons
              .map(
                (reason) => RadioListTile<String>(
                  title: Text(reason),
                  value: reason,
                ),
              )
              .toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _selectedReason == null
              ? null
              : () => Navigator.of(context).pop(_selectedReason),
          child: const Text('Submit'),
        ),
      ],
    );
  }
}
