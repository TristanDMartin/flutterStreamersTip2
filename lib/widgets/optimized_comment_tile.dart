import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../models/comment.dart';
import '../services/comments_service.dart';
import '../constants/app_colors.dart';
import '../services/report_service.dart';
import 'status_aware_avatar.dart';

class OptimizedCommentTile extends ConsumerStatefulWidget {
  final Comment comment;
  final String videoId;
  final String? videoOwnerId;
  final VoidCallback? onReply;
  final VoidCallback? onDelete;
  final ValueChanged<Comment>? onDeleteReply;
  final VoidCallback? onCreateThread;
  final VoidCallback? onOpenLinkedThread;
  final String? linkedThreadId;
  final bool showReplies;
  final bool highlightThreadAction;

  const OptimizedCommentTile({
    super.key,
    required this.comment,
    required this.videoId,
    this.videoOwnerId,
    this.onReply,
    this.onDelete,
    this.onDeleteReply,
    this.onCreateThread,
    this.onOpenLinkedThread,
    this.linkedThreadId,
    this.showReplies = true,
    this.highlightThreadAction = false,
  });

  @override
  ConsumerState<OptimizedCommentTile> createState() =>
      _OptimizedCommentTileState();
}

class _OptimizedCommentTileState extends ConsumerState<OptimizedCommentTile>
    with SingleTickerProviderStateMixin {
  bool _isLiked = false;
  int _likeCount = 0;
  bool _isLoading = false;
  AnimationController? _threadPulseController;
  Animation<double>? _threadPulseScale;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.comment.isLiked;
    _likeCount = widget.comment.likeCount;
    _syncThreadPulseAnimation();
  }

  @override
  void didUpdateWidget(OptimizedCommentTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.comment.isLiked != widget.comment.isLiked) {
      _isLiked = widget.comment.isLiked;
    }
    if (oldWidget.comment.likeCount != widget.comment.likeCount) {
      _likeCount = widget.comment.likeCount;
    }
    if (oldWidget.highlightThreadAction != widget.highlightThreadAction) {
      _syncThreadPulseAnimation();
    }
  }

  @override
  void dispose() {
    _threadPulseController?.dispose();
    super.dispose();
  }

  void _syncThreadPulseAnimation() {
    if (widget.highlightThreadAction) {
      _threadPulseController ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 900),
      )..repeat(reverse: true);
      _threadPulseScale ??= Tween<double>(begin: 1, end: 1.1).animate(
        CurvedAnimation(
          parent: _threadPulseController!,
          curve: Curves.easeInOut,
        ),
      );
      if (!_threadPulseController!.isAnimating) {
        _threadPulseController!.repeat(reverse: true);
      }
      return;
    }
    _threadPulseController?.stop();
  }

  Widget _wrapThreadHighlight(Widget child) {
    if (!widget.highlightThreadAction ||
        _threadPulseController == null ||
        _threadPulseScale == null) {
      return child;
    }
    return ScaleTransition(scale: _threadPulseScale!, child: child);
  }

  bool _isVideoOwner() {
    final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (currentUser == null || widget.videoOwnerId == null) return false;
    return widget.videoOwnerId == currentUser.uid;
  }

  bool get _hasLinkedThread =>
      widget.linkedThreadId != null && widget.linkedThreadId!.isNotEmpty;

  bool get _isDeletedComment => widget.comment.text.trim() == '[deleted]';

  Future<void> _reportComment() async {
    final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    if (currentUser.uid == widget.comment.user.id) return;

    final reportService = ReportService();
    final alreadyReported = await reportService.hasUserReportedComment(
      videoId: widget.videoId,
      commentId: widget.comment.id,
    );
    if (!mounted) return;
    if (alreadyReported) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('You have already reported this comment.')),
      );
      return;
    }

    final selectedReason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) {
        final reasons = reportService.getReportReasons();
        return SafeArea(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: reasons.length,
            itemBuilder: (context, index) {
              final reason = reasons[index];
              return ListTile(
                leading: const Icon(Icons.flag_outlined, color: Colors.white70),
                title:
                    Text(reason, style: const TextStyle(color: Colors.white)),
                onTap: () => Navigator.of(context).pop(reason),
              );
            },
          ),
        );
      },
    );

    if (selectedReason == null) return;

    try {
      await reportService.reportComment(
        videoId: widget.videoId,
        commentId: widget.comment.id,
        commentAuthorId: widget.comment.user.id,
        reason: selectedReason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Comment reported. Thanks for letting us know.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to report comment: $e')),
      );
    }
  }

  Future<void> _toggleLike() async {
    if (_isLoading) return;

    // Immediate UI feedback
    HapticFeedback.lightImpact();
    setState(() {
      _isLoading = true;
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });

    try {
      final success = await CommentsService().toggleLike(
        videoId: widget.videoId,
        commentId: widget.comment.id,
      );

      if (!success) {
        // Revert on failure
        setState(() {
          _isLiked = !_isLiked;
          _likeCount += _isLiked ? 1 : -1;
        });
      }
    } catch (e) {
      // Revert on error
      setState(() {
        _isLiked = !_isLiked;
        _likeCount += _isLiked ? 1 : -1;
      });
      // appLog('Error toggling like: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isLight = Theme.of(context).brightness == Brightness.light;
    final Color primaryText = isLight ? const Color(0xFF0F172A) : Colors.white;
    final Color secondaryText =
        isLight ? const Color(0xFF334155) : Colors.white70;
    final Color mutedText = isLight ? const Color(0xFF64748B) : Colors.white54;
    final Color chipBg = isLight
        ? const Color(0xFFF1F5F9).withValues(alpha: 0.9)
        : Colors.white.withValues(alpha: 0.1);
    final Color chipBorder = isLight
        ? const Color(0xFF0F172A).withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.2);
    final showActionRow = !_isDeletedComment &&
        (widget.onReply != null ||
            widget.onDelete != null ||
            (_hasLinkedThread && widget.onOpenLinkedThread != null) ||
            (!_hasLinkedThread &&
                _isVideoOwner() &&
                widget.onCreateThread != null));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar with online status
              StatusAwareAvatar(
                userId: widget.comment.user.id,
                avatarURL: widget.comment.user.avatarURL,
                radius: 18,
                showOnlineIndicator: true,
                backgroundColor: AppColors.primary,
                placeholder: Text(
                  widget.comment.user.username.isNotEmpty
                      ? widget.comment.user.username[0].toUpperCase()
                      : 'U',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
              const SizedBox(width: 12),

              // Comment content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Username and timestamp
                    Row(
                      children: [
                        Text(
                          widget.comment.user.username,
                          style: TextStyle(
                            color: primaryText,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.comment.relativeTimestamp,
                          style: TextStyle(
                            color: mutedText,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Comment text
                    Text(
                      widget.comment.text,
                      style: TextStyle(
                        color: primaryText,
                        fontSize: 14,
                      ),
                    ),
                    if (showActionRow) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (widget.onReply != null)
                            GestureDetector(
                              onTap: widget.onReply,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: chipBg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: chipBorder),
                                ),
                                child: Text(
                                  'Reply',
                                  style: TextStyle(
                                    color: secondaryText,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          if (widget.onDelete != null) ...[
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: widget.onDelete,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.error.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.error.withValues(
                                      alpha: 0.45,
                                    ),
                                  ),
                                ),
                                child: const Text(
                                  'Delete',
                                  style: TextStyle(
                                    color: AppColors.error,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          if (_hasLinkedThread &&
                              widget.onOpenLinkedThread != null) ...[
                            const SizedBox(width: 12),
                            _wrapThreadHighlight(
                              GestureDetector(
                                onTap: widget.onOpenLinkedThread,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.tertiary.withValues(
                                      alpha: 0.16,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.tertiary.withValues(
                                        alpha: 0.4,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    'View Thread',
                                    style: TextStyle(
                                      color: AppColors.accent.withValues(
                                        alpha: 0.95,
                                      ),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                          if (!_hasLinkedThread &&
                              _isVideoOwner() &&
                              widget.onCreateThread != null) ...[
                            const SizedBox(width: 12),
                            _wrapThreadHighlight(
                              GestureDetector(
                                onTap: widget.onCreateThread,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.secondary.withValues(
                                      alpha: 0.22,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.35,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    'Thread',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              if (!_isDeletedComment)
                Column(
                  children: [
                    if (firebase_auth.FirebaseAuth.instance.currentUser !=
                            null &&
                        firebase_auth.FirebaseAuth.instance.currentUser!.uid !=
                            widget.comment.user.id)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: GestureDetector(
                          onTap: _reportComment,
                          child: Icon(
                            Icons.flag_outlined,
                            color: mutedText,
                            size: 18,
                          ),
                        ),
                      ),
                    GestureDetector(
                      onTap: _toggleLike,
                      child: Stack(
                        children: [
                          Icon(
                            _isLiked ? Icons.favorite : Icons.favorite_border,
                            color: _isLiked ? AppColors.primary : secondaryText,
                            size: 20,
                          ),
                          if (_isLoading)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Center(
                                  child: SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _likeCount.toString(),
                      style: TextStyle(
                        color: secondaryText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // Replies
          if (widget.showReplies && (widget.comment.replies?.length ?? 0) > 0)
            Padding(
              padding: const EdgeInsets.only(left: 48, top: 8),
              child: Column(
                children: widget.comment.replies!
                    .map((reply) => OptimizedReplyTile(
                          reply: reply,
                          videoId: widget.videoId,
                          videoOwnerId: widget.videoOwnerId,
                          onDelete: (widget.onDeleteReply != null &&
                                  !_isDeletedComment)
                              ? () => widget.onDeleteReply!(reply)
                              : null,
                        ))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class OptimizedReplyTile extends StatefulWidget {
  final Comment reply;
  final String videoId;
  final String? videoOwnerId;
  final VoidCallback? onDelete;

  const OptimizedReplyTile({
    super.key,
    required this.reply,
    required this.videoId,
    this.videoOwnerId,
    this.onDelete,
  });

  @override
  State<OptimizedReplyTile> createState() => _OptimizedReplyTileState();
}

class _OptimizedReplyTileState extends State<OptimizedReplyTile> {
  bool _isLiked = false;
  int _likeCount = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.reply.isLiked;
    _likeCount = widget.reply.likeCount;
  }

  bool get _isDeletedReply => widget.reply.text.trim() == '[deleted]';

  bool get _canDeleteReply {
    final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (currentUser == null) return false;
    return widget.reply.user.id == currentUser.uid ||
        widget.videoOwnerId == currentUser.uid;
  }

  Future<void> _toggleLike() async {
    if (_isLoading) return;

    // Immediate UI feedback
    HapticFeedback.lightImpact();
    setState(() {
      _isLoading = true;
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });

    try {
      final success = await CommentsService().toggleLike(
        videoId: widget.videoId,
        commentId: widget.reply.id,
      );

      if (!success) {
        // Revert on failure
        setState(() {
          _isLiked = !_isLiked;
          _likeCount += _isLiked ? 1 : -1;
        });
      }
    } catch (e) {
      // Revert on error
      setState(() {
        _isLiked = !_isLiked;
        _likeCount += _isLiked ? 1 : -1;
      });
      // appLog('Error toggling like: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.primary,
            backgroundImage: widget.reply.user.avatarURL != null
                ? NetworkImage(widget.reply.user.avatarURL!)
                : null,
            child: widget.reply.user.avatarURL == null
                ? Text(
                    widget.reply.user.username.isNotEmpty
                        ? widget.reply.user.username[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      widget.reply.user.username,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.reply.relativeTimestamp,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  widget.reply.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              if (_canDeleteReply && widget.onDelete != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: GestureDetector(
                    onTap: widget.onDelete,
                    child: Icon(
                      Icons.delete_outline,
                      color: Colors.white.withValues(alpha: 0.75),
                      size: 16,
                    ),
                  ),
                ),
              GestureDetector(
                onTap: _isDeletedReply ? null : _toggleLike,
                child: Stack(
                  children: [
                    Icon(
                      _isLiked ? Icons.favorite : Icons.favorite_border,
                      color: _isLiked
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      size: 16,
                    ),
                    if (_isLoading)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 8,
                              height: 8,
                              child: CircularProgressIndicator(
                                strokeWidth: 1,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _likeCount.toString(),
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
