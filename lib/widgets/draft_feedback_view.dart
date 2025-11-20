import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import '../models/chat.dart' as app_chat;
import '../models/message.dart' as app_message;
import '../services/draft_sharing_service.dart';
import '../providers/chat_provider.dart';
import '../constants/app_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Draft Feedback View - Chat-like interface for viewing draft feedback
/// 
/// Features:
/// - Display draft video at the top
/// - Show feedback messages below
/// - Allow sending feedback messages
/// - Real-time message updates
class DraftFeedbackView extends ConsumerStatefulWidget {
  final Map<String, dynamic> sharedDraft;
  final app_chat.Chat chat;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserAvatarURL;

  const DraftFeedbackView({
    super.key,
    required this.sharedDraft,
    required this.chat,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserAvatarURL,
  });

  @override
  ConsumerState<DraftFeedbackView> createState() => _DraftFeedbackViewState();
}

class _DraftFeedbackViewState extends ConsumerState<DraftFeedbackView> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  final DraftSharingService _draftSharingService = DraftSharingService();
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _isVideoPlaying = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
    _scrollToBottom();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _textController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _initializeVideo() async {
    try {
      final videoPath = widget.sharedDraft['videoPath'] as String?;
      if (videoPath == null || videoPath.isEmpty) {
        final originalDraftId = widget.sharedDraft['originalDraftId'] as String?;
        if (originalDraftId != null && originalDraftId.isNotEmpty) {
          final drafts = await _draftSharingService.getSharedDraftsWithMe();
          final draft = drafts.firstWhere(
            (d) => d['originalDraftId'] == originalDraftId,
            orElse: () => <String, dynamic>{},
          );
          if (draft.isNotEmpty) {
            final draftVideoPath = draft['videoPath'] as String?;
            if (draftVideoPath != null && draftVideoPath.isNotEmpty) {
              await _loadVideo(draftVideoPath);
              return;
            }
          }
        }
        debugPrint('⚠️ No valid video path found for draft');
        return;
      }
      await _loadVideo(videoPath);
    } catch (e) {
      debugPrint('❌ Error initializing video: $e');
    }
  }

  Future<void> _loadVideo(String videoPath) async {
    try {
      if (videoPath.isEmpty) {
        debugPrint('⚠️ Video path is empty');
        return;
      }

      final file = File(videoPath);
      if (!file.existsSync()) {
        debugPrint('⚠️ Video file does not exist: $videoPath');
        return;
      }

      _videoController = VideoPlayerController.file(file);
      await _videoController!.initialize();
      setState(() {
        _isVideoInitialized = true;
      });
    } catch (e) {
      debugPrint('❌ Error loading video: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendFeedback() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    // Validate chat ID
    if (widget.chat.id == null || widget.chat.id!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid chat. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      final chatNotifier = ref.read(chatProvider(widget.chat).notifier);
      await chatNotifier.send();
      _textController.clear();
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending feedback: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _toggleVideoPlayback() {
    if (_videoController == null || !_isVideoInitialized) return;

    setState(() {
      if (_isVideoPlaying) {
        _videoController!.pause();
      } else {
        _videoController!.play();
      }
      _isVideoPlaying = !_isVideoPlaying;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Validate chat before building
    if (widget.chat.id == null || widget.chat.id!.isEmpty) {
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
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.white,
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Invalid chat',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Go back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF6137EB), Color(0xFF1C135D)],
            ),
          ),
          child: Column(
            children: [
              _buildHeader(),
              _buildDraftPreview(),
              Expanded(
                child: Consumer(
                  builder: (context, ref, child) {
                    final chatState = ref.watch(chatProvider(widget.chat));
                    if (chatState.isLoading) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                        ),
                      );
                    }
                    if (chatState.error != null) {
                      return Center(
                        child: Text(
                          'Error: ${chatState.error}',
                          style: const TextStyle(color: AppColors.error),
                        ),
                      );
                    }
                    if (chatState.messages.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.feedback_outlined,
                              color: Colors.white.withValues(alpha: 0.5),
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No feedback yet',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Share your thoughts on this draft!',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 16,
                        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
                      ),
                      itemCount: chatState.messages.length,
                      itemBuilder: (context, index) {
                        final message = chatState.messages[index];
                        final chatNotifier =
                            ref.read(chatProvider(widget.chat).notifier);
                        final isFromCurrentUser =
                            chatNotifier.isFromCurrentUser(message);
                        return _buildMessageBubble(
                          message,
                          isFromCurrentUser,
                        );
                      },
                    );
                  },
                ),
              ),
              _buildInputArea(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Icon(
              Icons.arrow_back,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.otherUserName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Draft Feedback',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (widget.otherUserAvatarURL != null)
            CircleAvatar(
              radius: 16,
              backgroundImage: CachedNetworkImageProvider(
                widget.otherUserAvatarURL!,
              ),
              onBackgroundImageError: (_, __) {},
            ),
        ],
      ),
    );
  }

  Widget _buildDraftPreview() {
    final caption = widget.sharedDraft['caption'] ?? '';
    final hashtags = widget.sharedDraft['hashtags'] as List<dynamic>? ?? [];
    final thumbnailPath = widget.sharedDraft['thumbnailPath'] as String?;

    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_isVideoInitialized && _videoController != null)
                  GestureDetector(
                    onTap: _toggleVideoPlayback,
                    child: AspectRatio(
                      aspectRatio: _videoController!.value.aspectRatio,
                      child: VideoPlayer(_videoController!),
                    ),
                  )
                else if (thumbnailPath != null)
                  Image.file(
                    File(thumbnailPath),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: AppColors.card,
                        child: const Icon(
                          Icons.video_library,
                          color: AppColors.textTertiary,
                          size: 48,
                        ),
                      );
                    },
                  )
                else
                  Container(
                    color: AppColors.card,
                    child: const Icon(
                      Icons.video_library,
                      color: AppColors.textTertiary,
                      size: 48,
                    ),
                  ),
                if (_isVideoInitialized)
                  GestureDetector(
                    onTap: _toggleVideoPlayback,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Icon(
                        _isVideoPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.card.withValues(alpha: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (caption.isNotEmpty)
                  Text(
                    caption,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (hashtags.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    children: hashtags.map<Widget>((tag) {
                      return Text(
                        '#$tag',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
    app_message.Message message,
    bool isFromCurrentUser,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isFromCurrentUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isFromCurrentUser) ...[
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8),
              child: widget.otherUserAvatarURL != null
                  ? CircleAvatar(
                      radius: 16,
                      backgroundImage: CachedNetworkImageProvider(
                        widget.otherUserAvatarURL!,
                      ),
                      onBackgroundImageError: (_, __) {},
                    )
                  : const CircleAvatar(
                      radius: 16,
                      child: Icon(
                        Icons.person,
                        size: 16,
                        color: Colors.white70,
                      ),
                    ),
            ),
            Flexible(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.15),
                      Colors.white.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                    bottomLeft: Radius.circular(8),
                    bottomRight: Radius.circular(24),
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  message.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                  softWrap: true,
                  overflow: TextOverflow.visible,
                  textAlign: TextAlign.start,
                ),
              ),
            ),
          ],
          if (isFromCurrentUser) ...[
            const Spacer(),
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary,
                    AppColors.secondary,
                    AppColors.tertiary,
                    Color(0xFF3C8BD6),
                    Color(0xFF4897D2),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(8),
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: AppColors.tertiary.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                message.text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
                softWrap: true,
                overflow: TextOverflow.visible,
                textAlign: TextAlign.start,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              child: FirebaseAuth.instance.currentUser?.photoURL != null
                  ? CircleAvatar(
                      radius: 16,
                      backgroundImage: CachedNetworkImageProvider(
                        FirebaseAuth.instance.currentUser!.photoURL!,
                      ),
                      onBackgroundImageError: (_, __) {},
                    )
                  : const CircleAvatar(
                      radius: 16,
                      child: Icon(
                        Icons.person,
                        size: 16,
                        color: Colors.white70,
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: keyboardHeight + bottomPadding + 12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(
                minHeight: 40,
                maxHeight: 120,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: TextField(
                controller: _textController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Add feedback...',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendFeedback(),
                textCapitalization: TextCapitalization.sentences,
                keyboardType: TextInputType.multiline,
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _sendFeedback,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.secondary,
                    AppColors.tertiary,
                    Color(0xFF3C8BD6),
                    Color(0xFF4897D2),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.send,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

