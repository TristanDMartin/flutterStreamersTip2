import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/comment.dart';
import '../models/user.dart' as app_user;
import '../services/comments_service.dart';
import '../services/unified_avatar_service.dart';
import 'optimized_comment_tile.dart';

/// CommentsView2 - TikTok-Style Comments Overlay
///
/// Features:
/// - Real-time updates with Firestore streams
/// - Keyboard-aware with isScrollControlled
/// - Full CRUD operations (Create, Read, Update, Delete)
/// - Video continues playing underneath (no pause/reload)
/// - Backdrop blur for readability
/// - Touch-blocking overlay prevents video interaction
///
/// Audio Policy: Video keeps playing at normal volume (TikTok pattern)
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

  // State variables
  bool _isLoading = false;
  String? _errorMessage;
  String? _currentUserAvatarUrl;
  Comment? _replyingTo;
  StreamSubscription<QuerySnapshot>? _commentsSubscription;
  CommentSortOption _sortOption = CommentSortOption.newest;

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

    _commentsSubscription = FirebaseFirestore.instance
        .collection('videos')
        .doc(widget.videoId)
        .collection('comments')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen(
      (snapshot) async {
        try {
          final List<Comment> updatedComments = [];
          final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;

          for (final doc in snapshot.docs) {
            final data = doc.data();
            app_user.User user = app_user.User.fromMap(data['user']);

            // Enrich avatar from Firestore
            user = await _enrichUserAvatar(user);

            // Check if current user liked this comment
            final likedBy =
                (data['likedBy'] as List<dynamic>?)?.cast<String>() ?? [];
            final isLiked =
                currentUser != null && likedBy.contains(currentUser.uid);

            updatedComments.add(Comment(
              id: doc.id,
              user: user,
              text: data['text'] ?? '',
              timestamp: (data['timestamp'] as Timestamp).toDate(),
              likeCount: data['likeCount'] ?? 0,
              isLiked: isLiked,
              replies: (data['replies'] as List<dynamic>?)
                  ?.map((reply) => Comment.fromJson(reply))
                  .toList(),
            ));
          }

          if (mounted) {
            setState(() {
              _comments
                ..clear()
                ..addAll(updatedComments);
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

  Future<app_user.User> _enrichUserAvatar(app_user.User user) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.id)
          .get();
      if (userDoc.exists && userDoc.data() != null) {
        final userData = userDoc.data()!;
        final currentAvatarUrl = userData['avatarURL'] as String?;

        // ✅ Get online status (check multiple fields for compatibility)
        final onlineStatus = userData['status'] as String? ??
            userData['userStatus'] as String? ??
            userData['onlineStatus'] as String? ??
            (userData['isOnline'] == true ? 'online' : 'offline');

        if (currentAvatarUrl != null && currentAvatarUrl.isNotEmpty) {
          return app_user.User(
            id: user.id,
            username: user.username,
            displayName: user.displayName,
            bio: user.bio,
            avatarURL: currentAvatarUrl,
            onlineStatus: onlineStatus, // ✅ Use enriched online status
            hashtags: user.hashtags,
            aiSelf: user.aiSelf,
            postCount: user.postCount,
            followerCount: user.followerCount,
            followingCount: user.followingCount,
            calendarEvents: user.calendarEvents,
          );
        }
      }
    } catch (e) {
      // Silent fail - use original user data
    }
    return user;
  }

  // ============================================================================
  // USER AVATAR MANAGEMENT
  // ============================================================================

  Future<void> _loadCurrentUserAvatar() async {
    final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      if (doc.exists && doc.data() != null && mounted) {
        final data = doc.data()!;
        setState(() {
          _currentUserAvatarUrl = data['avatarURL'] as String?;
        });
      }
    } catch (e) {
      // Silent fail
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

  Future<void> _deleteComment(Comment comment) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Delete Comment',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to delete this comment?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
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
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        return app_user.User(
          id: currentUser.uid,
          username:
              data['username'] as String? ?? currentUser.displayName ?? 'User',
          displayName: data['displayName'] as String? ??
              currentUser.displayName ??
              'User',
          avatarURL: data['avatarURL'] as String?,
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
    final double screenHeight = MediaQuery.of(context).size.height;
    final double keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final double modalHeight =
        screenHeight * 0.5; // Fixed height - keyboard will overlap comments

    print(
        '🎬 CommentsView2: Building modal with height: $modalHeight, keyboard: $keyboardHeight');

    return Stack(
      children: [
        // Block all touches to video beneath - TikTok pattern
        Positioned.fill(
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            behavior: HitTestBehavior.opaque,
            child: Container(color: Colors.transparent),
          ),
        ),
        // Comments modal - the video from HomeView will show through the transparent background
        _buildCommentsModal(modalHeight, keyboardHeight),
      ],
    );
  }

  Widget _buildCommentsModal(double modalHeight, double keyboardHeight) {
    return Positioned(
      bottom:
          keyboardHeight > 0 ? keyboardHeight : 0, // Lift modal above keyboard
      left: 0,
      right: 0,
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2), // Much lighter blur
          child: Container(
            height: modalHeight,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF6633CC)
                      .withValues(alpha: 0.3), // Much more transparent purple
                  Color(0xFF1A1A4D).withValues(
                      alpha: 0.4), // Much more transparent dark purple
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: GestureDetector(
              onTap: () {}, // Prevent tap from propagating to close modal
              child: Column(
                children: [
                  _buildDragIndicator(),
                  _buildHeader(),
                  Expanded(child: _buildCommentList()),
                  _buildEmojiRow(),
                  _buildInputBar(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDragIndicator() {
    return Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[600],
        borderRadius: BorderRadius.circular(2),
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
          border: isSelected ? Border.all(color: Colors.white, width: 1) : null,
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
          child: CircularProgressIndicator(color: Colors.white));
    }
    if (_errorMessage != null) {
      return Center(
        child: Text(
          'Error: $_errorMessage',
          style: const TextStyle(color: Colors.red),
          textAlign: TextAlign.center,
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
          onReply: () => _startReply(comment),
          onDelete:
              _canDeleteComment(comment) ? () => _deleteComment(comment) : null,
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
          const Icon(Icons.reply, color: Colors.blue, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Replying to ${_replyingTo!.user.username}',
              style: const TextStyle(
                color: Colors.blue,
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
            Color(0xFFFF6CAB),
            Color(0xFF8E54E9),
            Color(0xFF3D99F7),
            Color(0xFFFF6CAB),
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
            colors: [Color(0xFF6633CC), Color(0xFF9966FF)],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.send, color: Colors.white, size: 20),
      ),
    );
  }
}
