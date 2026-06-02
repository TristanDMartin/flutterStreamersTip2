import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import '../models/chat.dart' as app_chat;
import '../models/message.dart' as app_message;
import '../services/draft_sharing_service.dart';
import '../providers/chat_provider.dart';
import '../constants/app_colors.dart';
import '../core/theme/support_shell_style.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/video_preview_letterbox.dart';

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
  static final List<({IconData icon, String label, String prompt})>
      _defaultFeedbackPrompts = [
    (
      icon: Icons.flash_on_outlined,
      label: 'Hook',
      prompt:
          'The opening could be stronger. I would try a clearer first-second hook so viewers know why to keep watching.',
    ),
    (
      icon: Icons.content_cut_outlined,
      label: 'Pacing',
      prompt:
          'The pacing feels a little slow in the middle. I would tighten a few cuts so the energy stays up.',
    ),
    (
      icon: Icons.record_voice_over_outlined,
      label: 'Voiceover',
      prompt:
          'The message is strong. I would make the voiceover a bit clearer or punchier so the main point lands faster.',
    ),
    (
      icon: Icons.auto_awesome_outlined,
      label: 'Highlight',
      prompt:
          'This draft already has a strong moment. I would lean into that highlight earlier because it is the most memorable part.',
    ),
  ];

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  final DraftSharingService _draftSharingService = DraftSharingService();
  VideoPlayerController? _videoController;
  bool _isInitializingVideo = true;
  bool _isVideoInitialized = false;
  bool _isVideoPlaying = false;
  Duration _videoPosition = Duration.zero;
  Duration _videoDuration = Duration.zero;
  String? _videoErrorMessage;

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
    _videoController?.removeListener(_handleVideoUpdate);
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _initializeVideo() async {
    if (mounted) {
      setState(() {
        _isInitializingVideo = true;
        _videoErrorMessage = null;
      });
    }

    try {
      final videoUrl = widget.sharedDraft['videoUrl'] as String?;
      if (videoUrl != null && videoUrl.isNotEmpty) {
        await _loadVideo(videoUrl, isRemote: true);
        return;
      }

      final videoPath = widget.sharedDraft['videoPath'] as String?;
      if (videoPath == null || videoPath.isEmpty) {
        final originalDraftId =
            widget.sharedDraft['originalDraftId'] as String?;
        if (originalDraftId != null && originalDraftId.isNotEmpty) {
          final drafts = [
            ...await _draftSharingService.getSharedDraftsWithMe(),
            ...await _draftSharingService.getDraftsSharedByMe(),
          ];
          final draft = drafts.firstWhere(
            (d) => d['originalDraftId'] == originalDraftId,
            orElse: () => <String, dynamic>{},
          );
          if (draft.isNotEmpty) {
            final draftVideoUrl = draft['videoUrl'] as String?;
            if (draftVideoUrl != null && draftVideoUrl.isNotEmpty) {
              await _loadVideo(draftVideoUrl, isRemote: true);
              return;
            }

            final draftVideoPath = draft['videoPath'] as String?;
            if (draftVideoPath != null && draftVideoPath.isNotEmpty) {
              await _loadVideo(draftVideoPath);
              return;
            }
          }
        }
        debugPrint('⚠️ No valid video path found for draft');
        if (mounted) {
          setState(() {
            _isInitializingVideo = false;
            _videoErrorMessage =
                'Preview unavailable. The shared draft is missing a playable video source.';
          });
        }
        return;
      }
      await _loadVideo(videoPath);
    } catch (e) {
      debugPrint('❌ Error initializing video: $e');
      if (mounted) {
        setState(() {
          _isInitializingVideo = false;
          _videoErrorMessage =
              'We couldn\'t prepare the draft preview right now.';
        });
      }
    }
  }

  Future<void> _loadVideo(String videoSource, {bool isRemote = false}) async {
    try {
      if (videoSource.isEmpty) {
        debugPrint('⚠️ Video path is empty');
        return;
      }

      if (isRemote) {
        _videoController =
            VideoPlayerController.networkUrl(Uri.parse(videoSource));
      } else {
        final file = File(videoSource);
        if (!file.existsSync()) {
          debugPrint('⚠️ Video file does not exist: $videoSource');
          return;
        }
        _videoController = VideoPlayerController.file(file);
      }
      await _videoController!.initialize();
      _videoController!.addListener(_handleVideoUpdate);
      if (mounted) {
        setState(() {
          _isInitializingVideo = false;
          _isVideoInitialized = true;
          _videoErrorMessage = null;
          _videoDuration = _videoController!.value.duration;
          _videoPosition = _videoController!.value.position;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading video: $e');
      if (mounted) {
        setState(() {
          _isInitializingVideo = false;
          _isVideoInitialized = false;
          _videoErrorMessage = isRemote
              ? 'We couldn\'t load the remote draft preview.'
              : 'We couldn\'t open the local draft preview.';
        });
      }
    }
  }

  void _handleVideoUpdate() {
    final controller = _videoController;
    if (controller == null || !mounted) return;

    final value = controller.value;
    if (!value.isInitialized) return;

    final nextPosition = value.position;
    final nextDuration = value.duration;
    final nextPlaying = value.isPlaying;

    if (nextPosition != _videoPosition ||
        nextDuration != _videoDuration ||
        nextPlaying != _isVideoPlaying) {
      setState(() {
        _videoPosition = nextPosition;
        _videoDuration = nextDuration;
        _isVideoPlaying = nextPlaying;
      });
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
      chatNotifier.updateComposedText(text);
      await chatNotifier.send();
      _textController.clear();
      chatNotifier.updateComposedText('');
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

    if (_isVideoPlaying) {
      _videoController!.pause();
    } else {
      _videoController!.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    // Validate chat before building
    if (widget.chat.id == null || widget.chat.id!.isEmpty) {
      return Scaffold(
        backgroundColor: shell.scaffold,
        body: Center(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 30),
            decoration: BoxDecoration(
              color: shell.surfaceCard,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: shell.surfaceCardBorder,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  color: shell.onChrome,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'Invalid chat',
                  style: TextStyle(
                    color: shell.onChrome,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
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
      backgroundColor: shell.scaffold,
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Column(
          children: [
            _buildHeader(),
            _buildDraftPreview(),
            Expanded(
              child: Consumer(
                builder: (context, ref, child) {
                  final chatState = ref.watch(chatProvider(widget.chat));
                  if (chatState.isLoading && chatState.messages.isEmpty) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                      ),
                    );
                  }
                  if (chatState.error != null) {
                    return Center(
                      child: Container(
                        margin: const EdgeInsets.all(24),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 24),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.10),
                          ),
                        ),
                        child: Text(
                          'Error: ${chatState.error}',
                          style: const TextStyle(color: AppColors.error),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  if (chatState.messages.isEmpty) {
                    return Center(
                      child: Container(
                        margin: const EdgeInsets.all(24),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 30),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.10),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 88,
                              height: 88,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: AppColors.supportAccentGradient,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.feedback_outlined,
                                color: Colors.white,
                                size: 38,
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'No feedback yet',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Start the conversation and share what works, what could improve, or what stands out.',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.62),
                                fontSize: 14,
                                height: 1.45,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: ListView.builder(
                      key: ValueKey('messages-${chatState.messages.length}'),
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
                    ),
                  );
                },
              ),
            ),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 20,
        right: 20,
        bottom: 12,
      ),
      padding: EdgeInsets.only(
        top: 18,
        left: 18,
        right: 18,
        bottom: 18,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.supportSurfaceGradient,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
        ),
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
          _buildUserAvatar(
            imageUrl: widget.otherUserAvatarURL,
            name: widget.otherUserName,
            radius: 16,
          ),
        ],
      ),
    );
  }

  Widget _buildDraftPreview() {
    final caption = widget.sharedDraft['caption'] ?? '';
    final hashtags = widget.sharedDraft['hashtags'] as List<dynamic>? ?? [];
    final thumbnailPath = widget.sharedDraft['thumbnailPath'] as String?;
    final thumbnailUrl =
        (widget.sharedDraft['thumbnailUrl'] as String?)?.isNotEmpty == true
            ? widget.sharedDraft['thumbnailUrl'] as String
            : widget.sharedDraft['draftThumbnailUrl'] as String?;
    final durationMs = _videoDuration.inMilliseconds;
    final positionMs = _videoPosition.inMilliseconds.clamp(
      0,
      durationMs > 0 ? durationMs : 0,
    );
    final progressValue = durationMs > 0 ? positionMs / durationMs : 0.0;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      height: 316,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              alignment: Alignment.center,
              children: [
                if (_isInitializingVideo)
                  _buildPreviewLoadingState()
                else if (_isVideoInitialized && _videoController != null)
                  GestureDetector(
                    onTap: _toggleVideoPlayback,
                    child: ColoredBox(
                      color: Colors.black,
                      child: FittedBox(
                        fit: shouldLetterboxNonVerticalAspectRatio(
                          _videoController!.value.aspectRatio,
                        )
                            ? BoxFit.contain
                            : BoxFit.cover,
                        alignment: Alignment.center,
                        clipBehavior: Clip.hardEdge,
                        child: SizedBox(
                          width: _videoController!.value.size.width,
                          height: _videoController!.value.size.height,
                          child: VideoPlayer(_videoController!),
                        ),
                      ),
                    ),
                  )
                else if (thumbnailUrl != null && thumbnailUrl.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: thumbnailUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorWidget: (context, url, error) {
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
                  _buildPreviewFallbackState(),
                Positioned(
                  top: 14,
                  left: 14,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.34),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.14),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.rate_review_outlined,
                          color: Colors.white,
                          size: 14,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Draft Review',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_isVideoInitialized)
                  GestureDetector(
                    onTap: _toggleVideoPlayback,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.30),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      padding: const EdgeInsets.all(18),
                      child: Icon(
                        _isVideoPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                  ),
                Positioned(
                  right: 14,
                  bottom: 14,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.34),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.14),
                      ),
                    ),
                    child: Text(
                      _isVideoInitialized
                          ? (_isVideoPlaying ? 'Pause preview' : 'Play preview')
                          : 'Preview',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isVideoInitialized) ...[
                  Row(
                    children: [
                      Text(
                        _formatDuration(_videoPosition),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 5),
                            overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 10),
                            inactiveTrackColor:
                                Colors.white.withValues(alpha: 0.14),
                            activeTrackColor: Colors.white,
                            thumbColor: Colors.white,
                            overlayColor: Colors.white.withValues(alpha: 0.14),
                          ),
                          child: Slider(
                            value: progressValue.clamp(0.0, 1.0),
                            onChanged: durationMs > 0
                                ? (value) {
                                    final next = Duration(
                                      milliseconds:
                                          (durationMs * value).round(),
                                    );
                                    _videoController?.seekTo(next);
                                  }
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _formatDuration(_videoDuration),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.56),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
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
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: hashtags.map<Widget>((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.22),
                          ),
                        ),
                        child: Text(
                          '#$tag',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
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
    final timestampLabel = _formatMessageTime(message.timestamp);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isFromCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isFromCurrentUser) ...[
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildUserAvatar(
                imageUrl: widget.otherUserAvatarURL,
                name: widget.otherUserName,
                radius: 16,
              ),
            ),
            Flexible(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.09),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                    bottomLeft: Radius.circular(10),
                    bottomRight: Radius.circular(24),
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                      softWrap: true,
                      overflow: TextOverflow.visible,
                      textAlign: TextAlign.start,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      timestampLabel,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.46),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: AppColors.supportAccentGradient,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(10),
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.16),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.26),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                    softWrap: true,
                    overflow: TextOverflow.visible,
                    textAlign: TextAlign.start,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    timestampLabel,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.68),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 32,
              height: 32,
              child: _buildUserAvatar(
                imageUrl: FirebaseAuth.instance.currentUser?.photoURL,
                name: FirebaseAuth.instance.currentUser?.displayName ??
                    FirebaseAuth.instance.currentUser?.email ??
                    'You',
                radius: 16,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    final chatState = ref.watch(chatProvider(widget.chat));
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final isSending = chatState.isLoading && chatState.messages.isNotEmpty;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: keyboardHeight + bottomPadding + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
        ),
      ),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: _textController,
        builder: (context, value, child) {
          final hasText = value.text.trim().isNotEmpty;

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.22),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.mode_comment_outlined,
                          color: Colors.white,
                          size: 13,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Feedback',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    isSending
                        ? 'Sending...'
                        : hasText
                            ? 'Ready to send'
                            : 'Add a note or suggestion',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.56),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildPromptChips(
                hasText: hasText,
                isSending: isSending,
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(
                        minHeight: 44,
                        maxHeight: 120,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: hasText
                              ? Colors.white.withValues(alpha: 0.26)
                              : Colors.white.withValues(alpha: 0.14),
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: _textController,
                        enabled: !isSending,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText:
                              'What works well? What would you change before posting?',
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.54),
                            height: 1.35,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                        ),
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        onChanged: (text) => ref
                            .read(chatProvider(widget.chat).notifier)
                            .updateComposedText(text),
                        onSubmitted: (_) => isSending ? null : _sendFeedback(),
                        textCapitalization: TextCapitalization.sentences,
                        keyboardType: TextInputType.multiline,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: hasText && !isSending ? _sendFeedback : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: hasText && !isSending
                            ? const LinearGradient(
                                colors: AppColors.supportAccentGradient,
                              )
                            : null,
                        color: hasText && !isSending
                            ? null
                            : Colors.white.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: hasText && !isSending
                              ? Colors.white.withValues(alpha: 0.18)
                              : Colors.white.withValues(alpha: 0.12),
                        ),
                        boxShadow: hasText && !isSending
                            ? [
                                BoxShadow(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.30),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                                ),
                              ]
                            : null,
                      ),
                      child: isSending
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Icon(
                              Icons.send_rounded,
                              color: hasText
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.38),
                              size: 20,
                            ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPromptChips({
    required bool hasText,
    required bool isSending,
  }) {
    final prompts = _contextAwarePrompts();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          hasText
              ? 'Quick prompts to reshape your note'
              : 'Tap a prompt to start with polished feedback',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.58),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: prompts.map((prompt) {
            return InkWell(
              onTap: isSending ? null : () => _applyPrompt(prompt.prompt),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      prompt.icon,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.82),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      prompt.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  void _applyPrompt(String prompt) {
    final existing = _textController.text.trim();
    final nextText = existing.isEmpty ? prompt : '$existing\n\n$prompt';
    _textController.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextText.length),
    );
    ref.read(chatProvider(widget.chat).notifier).updateComposedText(nextText);
  }

  List<({IconData icon, String label, String prompt})> _contextAwarePrompts() {
    final caption = (widget.sharedDraft['caption'] as String?)?.trim() ?? '';
    final hashtags = (widget.sharedDraft['hashtags'] as List<dynamic>? ?? [])
        .whereType<Object>()
        .map((tag) => tag.toString().trim())
        .where((tag) => tag.isNotEmpty)
        .toList();

    final videoSourceDurationMs =
        (widget.sharedDraft['durationMs'] as num?)?.toInt() ??
            (widget.sharedDraft['duration'] as num?)?.toInt();
    final effectiveDurationMs = _videoDuration.inMilliseconds > 0
        ? _videoDuration.inMilliseconds
        : videoSourceDurationMs;

    final prompts = <({IconData icon, String label, String prompt})>[];

    if (caption.isEmpty) {
      prompts.add((
        icon: Icons.closed_caption_off_outlined,
        label: 'Caption',
        prompt:
            'I would add a clearer caption so the takeaway lands even if someone watches without sound.',
      ));
    } else if (caption.length < 35) {
      prompts.add((
        icon: Icons.short_text_outlined,
        label: 'Clarity',
        prompt:
            'The caption is concise, but I would make the promise a little clearer so viewers instantly understand the payoff.',
      ));
    }

    if (hashtags.isEmpty) {
      prompts.add((
        icon: Icons.tag_outlined,
        label: 'Hashtags',
        prompt:
            'I would add a few targeted hashtags so the draft has better context for discovery once it is posted.',
      ));
    } else if (hashtags.length < 3) {
      prompts.add((
        icon: Icons.sell_outlined,
        label: 'Discovery',
        prompt:
            'The hashtag set feels light. I would test a few more specific tags that match the niche and the audience intent.',
      ));
    }

    if (effectiveDurationMs != null && effectiveDurationMs > 0) {
      final durationSeconds = effectiveDurationMs / 1000;
      if (durationSeconds < 8) {
        prompts.add((
          icon: Icons.timer_outlined,
          label: 'Length',
          prompt:
              'This draft is very short, so every second matters. I would make sure the opening frame and closing payoff are both crystal clear.',
        ));
      } else if (durationSeconds > 45) {
        prompts.add((
          icon: Icons.compress_outlined,
          label: 'Trim',
          prompt:
              'This draft runs a bit long for a quick-scroll format. I would tighten the middle and get to the payoff faster.',
        ));
      }
    }

    prompts.addAll(_defaultFeedbackPrompts);

    final seenLabels = <String>{};
    return prompts
        .where((prompt) => seenLabels.add(prompt.label))
        .take(5)
        .toList();
  }

  Widget _buildPreviewLoadingState() {
    return Container(
      color: AppColors.card,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            SizedBox(height: 16),
            Text(
              'Preparing draft preview...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewFallbackState() {
    return Container(
      color: AppColors.card,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.video_library_outlined,
                  color: Colors.white70,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Preview unavailable',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _videoErrorMessage ??
                    'This draft was shared without a playable preview.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.68),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserAvatar({
    required String? imageUrl,
    required String name,
    required double radius,
  }) {
    final initials = _initialsFor(name);

    if (imageUrl != null && imageUrl.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: CachedNetworkImageProvider(imageUrl),
        onBackgroundImageError: (_, __) {},
        backgroundColor: Colors.white.withValues(alpha: 0.10),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.white.withValues(alpha: 0.10),
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _initialsFor(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return '?';
    }
    if (parts.length == 1) {
      return parts.first.characters.first.toUpperCase();
    }
    return '${parts.first.characters.first}${parts.last.characters.first}'
        .toUpperCase();
  }

  String _formatMessageTime(DateTime? timestamp) {
    if (timestamp == null) return 'Just now';
    final hour = timestamp.hour % 12 == 0 ? 12 : timestamp.hour % 12;
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final period = timestamp.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final minutes = (totalSeconds ~/ 60).toString();
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
