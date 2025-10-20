import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/comment.dart';
import '../services/comments_service.dart';
import 'status_aware_avatar.dart';

class OptimizedCommentTile extends ConsumerStatefulWidget {
  final Comment comment;
  final String videoId;
  final VoidCallback? onReply;
  final VoidCallback? onDelete;
  final bool showReplies;

  const OptimizedCommentTile({
    super.key,
    required this.comment,
    required this.videoId,
    this.onReply,
    this.onDelete,
    this.showReplies = true,
  });

  @override
  ConsumerState<OptimizedCommentTile> createState() =>
      _OptimizedCommentTileState();
}

class _OptimizedCommentTileState extends ConsumerState<OptimizedCommentTile> {
  bool _isLiked = false;
  int _likeCount = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.comment.isLiked;
    _likeCount = widget.comment.likeCount;
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
      // print('Error toggling like: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                backgroundColor: const Color(0xFF9248D2),
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
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.comment.relativeTimestamp,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Comment text
                    Text(
                      widget.comment.text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Action buttons
                    Row(
                      children: [
                        if (widget.onReply != null)
                          GestureDetector(
                            onTap: widget.onReply,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey[800],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Reply',
                                style: TextStyle(
                                  color: Colors.white70,
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
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Delete',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Like button and count
              Column(
                children: [
                  GestureDetector(
                    onTap: _toggleLike,
                    child: Stack(
                      children: [
                        Icon(
                          _isLiked ? Icons.favorite : Icons.favorite_border,
                          color: _isLiked ? Colors.red : Colors.white70,
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
                                        Colors.red),
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
                    style: const TextStyle(
                      color: Colors.white70,
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

  const OptimizedReplyTile({
    super.key,
    required this.reply,
    required this.videoId,
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
      // print('Error toggling like: $e');
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
            backgroundColor: const Color(0xFF9248D2),
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
              GestureDetector(
                onTap: _toggleLike,
                child: Stack(
                  children: [
                    Icon(
                      _isLiked ? Icons.favorite : Icons.favorite_border,
                      color: _isLiked ? Colors.red : Colors.white70,
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
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.red),
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
                style: const TextStyle(
                  color: Colors.white70,
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
