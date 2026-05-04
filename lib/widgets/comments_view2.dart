import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../models/comment.dart';
import '../models/user.dart' as app_user;
import '../services/comments_service.dart';
import '../services/discussion_author_service.dart';
import '../constants/app_colors.dart';
import '../widgets/threads/create_thread_from_comment_screen.dart';
import '../widgets/threads/thread_detail_screen.dart';
import '../utils/avatar_url_resolver.dart';
import 'optimized_comment_tile.dart';

/// CommentsView2 - StreamersTip Comments Overlay
///
/// Features:
/// - Real-time updates with Firestore streams
/// - Keyboard-aware with isScrollControlled
/// - Full CRUD operations (Create, Read, Update, Delete)
/// - Video continues playing underneath (no pause/reload)
/// - Backdrop blur for readability
/// - Touch-blocking overlay prevents video interaction
///
/// Audio Policy: Video keeps playing at normal volume
class CommentsView2 extends ConsumerStatefulWidget {
  final String videoId;
  final String videoOwnerId;

  const CommentsView2({
    super.key,
    required this.videoId,
    required this.videoOwnerId,
  });

  @override
  ConsumerState<CommentsView2> createState() => _CommentsView2State();
}

enum CommentSortOption {
  newest,
  mostLiked,
}

class _CommentsView2State extends ConsumerState<CommentsView2> {
  // Controllers and state
  final List<Comment> _comments = <Comment>[];
  final TextEditingController _textController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final DiscussionAuthorService _discussionAuthorService =
      DiscussionAuthorService();

  // State variables
  bool _isLoading = false;
  String? _errorMessage;
  String? _currentUserAvatarUrl;
  Comment? _replyingTo;
  StreamSubscription<VideoCommentsSnapshot>? _commentsSubscription;
  CommentSortOption _sortOption = CommentSortOption.newest;
  final Map<String, String> _linkedThreadIds = <String, String>{};

  @override
  void initState() {
    super.initState();
    _setupRealtimeComments();
    _loadCurrentUserAvatar();
  }

  @override
  void dispose() {
    _commentsSubscription?.cancel();
    _textController.dispose();
    _inputFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ============================================================================
  // REAL-TIME COMMENTS SETUP
  // ============================================================================

  void _setupRealtimeComments() {
    setState(() => _isLoading = true);

    _commentsSubscription =
        CommentsService().watchCommentsForVideo(widget.videoId).listen(
      (snapshot) async {
        try {
          final enrichedComments = await Future.wait(
            snapshot.comments.map(_enrichCommentTree),
          );

          if (mounted) {
            setState(() {
              _comments
                ..clear()
                ..addAll(enrichedComments);
              _linkedThreadIds
                ..clear()
                ..addAll(snapshot.linkedThreadIds);
              _applySorting();
              _isLoading = false;
              _errorMessage = null;
            });
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _errorMessage = 'Error loading comments';
              _isLoading = false;
            });
          }
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Failed to load comments';
            _isLoading = false;
          });
        }
      },
    );
  }

  Future<Comment> _enrichCommentTree(Comment comment) async {
    final enrichedUser = await _enrichUserAvatar(comment.user);
    final replies = comment.replies == null
        ? null
        : await Future.wait(comment.replies!.map(_enrichCommentTree));
    return comment.copyWith(
      user: enrichedUser,
      replies: replies,
    );
  }

  Future<app_user.User> _enrichUserAvatar(app_user.User user) async {
    return _discussionAuthorService.enrichCommentUser(user);
  }

  // ============================================================================
  // USER AVATAR MANAGEMENT
  // ============================================================================

  Future<void> _loadCurrentUserAvatar() async {
    final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final avatarUrl =
        await _discussionAuthorService.loadAvatarUrl(currentUser.uid);
    if (avatarUrl != null && mounted) {
      setState(() {
        _currentUserAvatarUrl = avatarUrl;
      });
    }
  }

  // ============================================================================
  // COMMENT ACTIONS
  // ============================================================================

  Future<void> _addComment() async {
    final String text = _textController.text.trim();
    if (text.isEmpty) return;

    final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      setState(() => _errorMessage = 'Please sign in to add comments');
      return;
    }

    _textController.clear();
    _inputFocusNode.unfocus();

    try {
      final commentsService = CommentsService();
      final author = await _getCurrentUserFromFirestore();

      if (_replyingTo != null) {
        await commentsService.addReply(
          videoId: widget.videoId,
          parentId: _replyingTo!.id,
          text: text,
          author: author,
        );
        setState(() => _replyingTo = null);
      } else {
        await commentsService.addComment(
          videoId: widget.videoId,
          text: text,
          author: author,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString());
      }
    }
  }

  void _startReply(Comment comment) {
    setState(() => _replyingTo = comment);
    _inputFocusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() => _replyingTo = null);
  }

  void _openCreateThreadModal(Comment comment) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateThreadFromCommentScreen(
          videoId: widget.videoId,
          comment: comment,
        ),
      ),
    );
  }

  void _openLinkedThread(String threadId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => ThreadDetailScreen(postId: threadId),
      ),
    );
  }

  Future<void> _deleteComment(Comment comment) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        final ColorScheme scheme = Theme.of(context).colorScheme;
        return AlertDialog(
          backgroundColor: scheme.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: scheme.outline.withValues(alpha: 0.35),
            ),
          ),
          title: Text(
            'Delete Comment',
            style: TextStyle(
              color: scheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            'Are you sure you want to delete this comment?',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              style: TextButton.styleFrom(
                foregroundColor: scheme.onSurfaceVariant,
              ),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.error,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    try {
      final success = await CommentsService().deleteComment(
        videoId: widget.videoId,
        commentId: comment.id,
        videoOwnerId: widget.videoOwnerId,
      );

      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete comment'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error deleting comment'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  bool _canDeleteComment(Comment comment) {
    final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (currentUser == null) return false;
    return comment.user.id == currentUser.uid ||
        widget.videoOwnerId == currentUser.uid;
  }

  // ============================================================================
  // SORTING
  // ============================================================================

  void _applySorting() {
    switch (_sortOption) {
      case CommentSortOption.newest:
        _comments.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        break;
      case CommentSortOption.mostLiked:
        _comments.sort((a, b) => b.likeCount.compareTo(a.likeCount));
        break;
    }
  }

  void _changeSortOption(CommentSortOption newOption) {
    if (_sortOption == newOption) return;
    setState(() {
      _sortOption = newOption;
      _applySorting();
    });
  }

  // ============================================================================
  // USER DATA FETCHING
  // ============================================================================

  Future<app_user.User> _getCurrentUserFromFirestore() async {
    final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (currentUser == null) return _fallbackUser();

    try {
      final data = await _discussionAuthorService.loadUserData(currentUser.uid);
      if (data != null) {
        return app_user.User(
          id: currentUser.uid,
          username:
              data['username'] as String? ?? currentUser.displayName ?? 'User',
          displayName: data['displayName'] as String? ??
              currentUser.displayName ??
              'User',
          avatarURL: resolveAvatarUrl(data),
          bio: data['bio'] as String? ?? '',
          followerCount: data['followerCount'] as int? ?? 0,
          followingCount: data['followingCount'] as int? ?? 0,
        );
      }
      return app_user.User(
        id: currentUser.uid,
        username: currentUser.displayName ?? 'User',
        displayName: currentUser.displayName ?? 'User',
        avatarURL: currentUser.photoURL,
        bio: '',
        followerCount: 0,
        followingCount: 0,
      );
    } catch (e) {
      return _fallbackUser();
    }
  }

  app_user.User _fallbackUser() {
    final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
    return app_user.User(
      id: currentUser?.uid ?? 'guest',
      username: currentUser?.displayName ?? 'Guest',
      displayName: currentUser?.displayName ?? 'Guest User',
      avatarURL: currentUser?.photoURL,
      bio: '',
      followerCount: 0,
      followingCount: 0,
    );
  }

  // ============================================================================
  // UI BUILDERS
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    final double modalHeight = MediaQuery.sizeOf(context).height * 0.5;

    return Stack(
      children: [
        // Block all touches to video beneath
        Positioned.fill(
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            behavior: HitTestBehavior.opaque,
            child: Container(color: Colors.transparent),
          ),
        ),
        _CommentsModalWithKeyboardLift(
          modalHeight: modalHeight,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: RepaintBoundary(
              child: Container(
                height: modalHeight,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.34),
                      AppColors.supportBackground.withValues(alpha: 0.58),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: GestureDetector(
                  onTap: () {},
                  child: Column(
                    children: [
                      _buildDragIndicator(),
                      _buildHeader(),
                      Expanded(child: _buildCommentList()),
                      _HideWhenKeyboardOpen(child: _buildEmojiRow()),
                      _buildInputBar(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDragIndicator() {
    return Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.55),
            AppColors.secondary.withValues(alpha: 0.45),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 6,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Comments (${_comments.length})',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          Row(
            children: [
              _buildSortChip(
                  'Newest', CommentSortOption.newest, Icons.access_time),
              const SizedBox(width: 8),
              _buildSortChip(
                  'Most Liked', CommentSortOption.mostLiked, Icons.favorite),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildSortChip(String label, CommentSortOption option, IconData icon) {
    final isSelected = _sortOption == option;
    return GestureDetector(
      onTap: () => _changeSortOption(option),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.85)
                : Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.error.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.error.withValues(alpha: 0.95),
                  size: 22,
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: AppColors.error.withValues(alpha: 0.92),
                      fontSize: 14,
                      height: 1.35,
                    ),
                    textAlign: TextAlign.start,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (_comments.isEmpty) {
      return const Center(
        child: Text(
          'No comments yet.\nBe the first to comment!',
          style: TextStyle(color: Colors.white54),
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _comments.length,
      itemBuilder: (context, index) {
        final comment = _comments[index];
        return OptimizedCommentTile(
          comment: comment,
          videoId: widget.videoId,
          videoOwnerId: widget.videoOwnerId,
          onReply: () => _startReply(comment),
          onDelete:
              _canDeleteComment(comment) ? () => _deleteComment(comment) : null,
          onDeleteReply: _deleteComment,
          onCreateThread: _linkedThreadIds.containsKey(comment.id)
              ? null
              : () => _openCreateThreadModal(comment),
          linkedThreadId: _linkedThreadIds[comment.id],
          onOpenLinkedThread: _linkedThreadIds.containsKey(comment.id)
              ? () => _openLinkedThread(_linkedThreadIds[comment.id]!)
              : null,
        );
      },
    );
  }

  Widget _buildEmojiRow() {
    const List<String> emojiReactions = [
      '❤️',
      '🙌',
      '🔥',
      '😂',
      '😮',
      '😢',
      '👍',
      '💯',
    ];

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: emojiReactions
              .map((emoji) => GestureDetector(
                    onTap: () => _textController.text += emoji,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(emoji, style: const TextStyle(fontSize: 22)),
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPadding + 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white24, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_replyingTo != null) _buildReplyIndicator(),
          _buildInputRow(),
        ],
      ),
    );
  }

  Widget _buildReplyIndicator() {
    return Container(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            Icons.reply,
            color: AppColors.accent.withValues(alpha: 0.9),
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Replying to ${_replyingTo!.user.username}',
              style: TextStyle(
                color: AppColors.accent.withValues(alpha: 0.92),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          GestureDetector(
            onTap: _cancelReply,
            child: const Icon(Icons.close, color: Colors.white54, size: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildInputRow() {
    return Row(
      children: [
        _buildUserAvatar(),
        const SizedBox(width: 12),
        _buildTextField(),
        const SizedBox(width: 8),
        _buildSendButton(),
      ],
    );
  }

  Widget _buildUserAvatar() {
    final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
    final avatarUrl = _currentUserAvatarUrl ?? currentUser?.photoURL;

    // Always show a visible avatar
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          colors: [
            AppColors.primary,
            AppColors.secondary,
            AppColors.tertiary,
            AppColors.primary,
          ],
        ),
      ),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey,
        ),
        child: avatarUrl != null && avatarUrl.isNotEmpty
            ? ClipOval(
                child: Image.network(
                  avatarUrl,
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              )
            : const Icon(
                Icons.person,
                color: Colors.white,
                size: 18,
              ),
      ),
    );
  }

  Widget _buildTextField() {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
        ),
        child: TextField(
          controller: _textController,
          focusNode: _inputFocusNode,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: _replyingTo != null ? 'Reply...' : 'Add a comment...',
            hintStyle: const TextStyle(color: Colors.white60),
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }

  Widget _buildSendButton() {
    return GestureDetector(
      onTap: _addComment,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: AppColors.commentsSendGradient,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.send, color: Colors.white, size: 20),
      ),
    );
  }
}

/// Isolates keyboard inset so [CommentsView2] state does not rebuild each frame.
class _CommentsModalWithKeyboardLift extends StatelessWidget {
  const _CommentsModalWithKeyboardLift({
    required this.modalHeight,
    required this.child,
  });

  final double modalHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            height: modalHeight,
            width: double.infinity,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _HideWhenKeyboardOpen extends StatelessWidget {
  const _HideWhenKeyboardOpen({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.viewInsetsOf(context).bottom > 0) {
      return const SizedBox.shrink();
    }
    return child;
  }
}
