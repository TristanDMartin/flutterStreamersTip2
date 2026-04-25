import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../../models/forum_post.dart';
import '../../models/forum_comment.dart';
import '../../models/forum_author.dart';
import '../../services/forum_service.dart';
import '../../services/discussion_author_service.dart';
import '../../services/report_service.dart';
import '../../services/unified_avatar_service.dart';
import '../../constants/app_colors.dart';
import '../../routing/app_navigator.dart';
import 'discussion_author_row.dart';
import 'thread_comment_item.dart';

/// Thread detail screen showing thread content and comments
/// Simplified version without video embedding to avoid build_runner issues
class ThreadDetailScreen extends ConsumerStatefulWidget {
  final String postId;

  const ThreadDetailScreen({
    super.key,
    required this.postId,
  });

  @override
  ConsumerState<ThreadDetailScreen> createState() => _ThreadDetailScreenState();
}

class _ThreadDetailScreenState extends ConsumerState<ThreadDetailScreen> {
  final ForumService _forumService = ForumService();
  final ReportService _reportService = ReportService();
  final DiscussionAuthorService _discussionAuthorService =
      DiscussionAuthorService();
  final FocusNode _composerFocusNode = FocusNode();
  ForumPost? _post;
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _commentController = TextEditingController();
  String? _replyingToCommentId;
  String? _replyingToDisplayName;
  final Set<String> _expandedReplies = {};
  bool _isSubmittingReply = false;

  @override
  void initState() {
    super.initState();
    _loadThread();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _composerFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadThread() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final post = await _forumService.getPost(widget.postId);
      if (post == null) {
        setState(() {
          _errorMessage = 'Thread not found';
          _isLoading = false;
        });
        return;
      }

      // Enrich post with current user avatar data
      final enrichedPost = await _enrichPostWithAvatar(post);

      if (mounted) {
        setState(() {
          _post = enrichedPost;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'We couldn\'t load this thread right now. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  /// Enrich post with current user avatar from users collection
  Future<ForumPost> _enrichPostWithAvatar(ForumPost post) async {
    try {
      final updatedAuthor =
          await _discussionAuthorService.loadForumAuthor(post.author.uid);
      return ForumPost(
        id: post.id,
        title: post.title,
        content: post.content,
        category: post.category,
        categoryDisplayName: post.categoryDisplayName,
        tags: post.tags,
        author: updatedAuthor,
        visibility: post.visibility,
        likes: post.likes,
        commentCount: post.commentCount,
        likedBy: post.likedBy,
        bookmarkedBy: post.bookmarkedBy,
        followedBy: post.followedBy,
        linkedVideoId: post.linkedVideoId,
        linkedCommentId: post.linkedCommentId,
        sourceComment: post.sourceComment,
        createdAt: post.createdAt,
        updatedAt: post.updatedAt,
        deleted: post.deleted,
      );
    } catch (e) {
      debugPrint('❌ Error enriching post avatar: $e');
      return post;
    }
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _post == null) return;

    try {
      final user = firebase_auth.FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please sign in to comment')),
          );
        }
        return;
      }

      final author = await _forumService.getUserProfile(user.uid);
      await _forumService.addComment(widget.postId, text, author);
      if (mounted) {
        _commentController.clear();
        unawaited(_loadThread());
      }
    } catch (e) {
      final message = e.toString().contains('permission-denied')
          ? 'Comments are blocked by Firestore rules right now. The app-side fix is in; if this still appears after reinstall/redeploy, we should re-publish rules.'
          : 'Error: ${e.toString()}';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    }
  }

  void _handleReply(ForumComment comment) {
    setState(() {
      _replyingToCommentId = comment.id;
      _replyingToDisplayName = comment.author.displayName;
      if (!_expandedReplies.contains(comment.id)) {
        _expandedReplies.add(comment.id);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _composerFocusNode.requestFocus();
    });
  }

  void _handleCancelReply() {
    setState(() {
      _replyingToCommentId = null;
      _replyingToDisplayName = null;
    });
  }

  Future<void> _handleSubmitReply() async {
    final commentId = _replyingToCommentId;
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    if (commentId == null) return;

    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isSubmittingReply = true;
    });

    try {
      final author = await _forumService.getUserProfile(user.uid);
      await _forumService.addComment(
        widget.postId,
        text,
        author,
        parentCommentId: commentId,
      );

      if (mounted) {
        setState(() {
          _replyingToCommentId = null;
          _replyingToDisplayName = null;
          _commentController.clear();
          if (!_expandedReplies.contains(commentId)) {
            _expandedReplies.add(commentId);
          }
        });
        unawaited(_loadThread());
      }
    } catch (e) {
      final message = e.toString().contains('permission-denied')
          ? 'Replies are blocked by Firestore rules right now. The app-side fix is in; if this still appears after reinstall/redeploy, we should re-publish rules.'
          : 'Error: ${e.toString()}';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingReply = false;
        });
      }
    }
  }

  Future<void> _handleLike(String commentId) async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await _forumService.toggleCommentLike(
        widget.postId,
        commentId,
        user.uid,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _handleDislike(String commentId) async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await _forumService.toggleCommentDislike(
        widget.postId,
        commentId,
        user.uid,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _handleDelete(String commentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text('Are you sure you want to delete this comment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _forumService.deleteComment(widget.postId, commentId);
      if (mounted) {
        unawaited(_loadThread());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _handleComposerSubmit() async {
    if (_replyingToCommentId != null) {
      await _handleSubmitReply();
      return;
    }
    await _addComment();
  }

  void _toggleReplies(String commentId) {
    setState(() {
      if (_expandedReplies.contains(commentId)) {
        _expandedReplies.remove(commentId);
      } else {
        _expandedReplies.add(commentId);
      }
    });
  }

  Future<void> _toggleLike() async {
    if (_post == null) return;

    try {
      final user = firebase_auth.FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final author = ForumAuthor(
        uid: user.uid,
        username: user.displayName ?? 'user',
        displayName: user.displayName ?? 'User',
        avatarUrl: user.photoURL,
      );

      await _forumService.togglePostLike(widget.postId, user.uid, author);
      _loadThread(); // Refresh to update like count
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _reportThread() async {
    final post = _post;
    final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (post == null ||
        currentUser == null ||
        currentUser.uid == post.author.uid) {
      return;
    }

    final alreadyReported = await _reportService.hasUserReportedThread(post.id);
    if (!mounted) return;
    if (alreadyReported) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have already reported this thread.')),
      );
      return;
    }

    final selectedReason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (context) {
        final reasons = _reportService.getReportReasons();
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
      await _reportService.reportThread(
        postId: post.id,
        authorId: post.author.uid,
        reason: selectedReason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Thread reported. Thanks for the report.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to report thread: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.supportBackground,
        body: Container(
          color: AppColors.supportBackground,
          child: Column(
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: _buildTopBarShell(
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    title: 'Thread',
                    subtitle: 'Loading conversation...',
                    actions: const SizedBox.shrink(),
                  ),
                ),
              ),
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null || _post == null) {
      return Scaffold(
        backgroundColor: AppColors.supportBackground,
        body: Container(
          color: AppColors.supportBackground,
          child: Column(
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: _buildTopBarShell(
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    title: 'Thread',
                    subtitle: 'We hit a snag opening this one.',
                    actions: const SizedBox.shrink(),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.10),
                      ),
                    ),
                    child: Text(
                      _errorMessage ?? 'Thread not found',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.supportBackground,
      resizeToAvoidBottomInset: true,
      body: Container(
        color: AppColors.supportBackground,
        child: Column(
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: _buildTopBarShell(
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  title: 'Thread',
                  subtitle: 'Jump into the conversation',
                  actions: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (firebase_auth
                              .FirebaseAuth.instance.currentUser?.uid !=
                          _post!.author.uid)
                        _buildHeaderIconButton(
                          icon: Icons.flag_outlined,
                          onPressed: _reportThread,
                        ),
                      const SizedBox(width: 8),
                      _buildHeaderIconButton(
                        icon: _post!.likedBy.contains(firebase_auth
                                .FirebaseAuth.instance.currentUser?.uid)
                            ? Icons.favorite
                            : Icons.favorite_border,
                        onPressed: _toggleLike,
                        isActive: _post!.likedBy.contains(firebase_auth
                            .FirebaseAuth.instance.currentUser?.uid),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  _replyingToCommentId != null ? 164 : 132,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildThreadHeroCard(),
                    const SizedBox(height: 18),
                    _buildCommentsSection(),
                  ],
                ),
              ),
            ),
            // Comment input - Fixed at bottom, outside scrollable area
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: AppColors.supportSurfaceGradient,
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_replyingToCommentId != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.10),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.reply_rounded,
                              size: 16,
                              color: AppColors.supportAccent,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Replying to ${_replyingToDisplayName ?? 'comment'}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _handleCancelReply,
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white70,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('Cancel'),
                            ),
                          ],
                        ),
                      ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildComposerAvatar(),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            focusNode: _composerFocusNode,
                            textInputAction: TextInputAction.send,
                            style: const TextStyle(color: Colors.white),
                            minLines: 1,
                            maxLines: 4,
                            onSubmitted: (_) => _handleComposerSubmit(),
                            decoration: InputDecoration(
                              hintText: _replyingToCommentId != null
                                  ? 'Write a reply...'
                                  : 'Jump into the conversation...',
                              hintStyle: const TextStyle(color: Colors.white70),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.08),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(22),
                                borderSide: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(22),
                                borderSide: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(22),
                                borderSide: BorderSide(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.75),
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed:
                              _isSubmittingReply ? null : _handleComposerSubmit,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: const CircleBorder(),
                            padding: const EdgeInsets.all(14),
                          ),
                          child: _isSubmittingReply
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : const Icon(Icons.send_rounded, size: 20),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBarShell({
    required Widget leading,
    required String title,
    required String subtitle,
    required Widget actions,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.supportSurfaceGradient,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
        ),
      ),
      child: Row(
        children: [
          leading,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          actions,
        ],
      ),
    );
  }

  Widget _buildHeaderIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    bool isActive = false,
  }) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.primary.withValues(alpha: 0.16)
            : Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.55)
              : Colors.white.withValues(alpha: 0.10),
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.18),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(
          icon,
          color: isActive ? AppColors.primary : Colors.white,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildThreadHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((_post!.categoryDisplayName ?? '').isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _post!.categoryDisplayName!.toUpperCase(),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            _post!.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 14),
          DiscussionAuthorRow(
            displayName: _post!.author.displayName,
            username: _post!.author.username,
            avatarUrl: _post!.author.avatarUrl,
            userId: _post!.author.uid,
            avatarRadius: 22,
            trailingText: _formatDate(_post!.createdAt),
            onTap: () => _openStreamerCard(_post!.author.uid),
          ),
          const SizedBox(height: 18),
          Text(
            _post!.content,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 16,
              height: 1.45,
            ),
          ),
          if (_post!.sourceComment != null) ...[
            const SizedBox(height: 16),
            _buildSourceCommentCard(),
          ],
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildStatPill(
                icon: Icons.favorite_rounded,
                label: '${_post!.likes} likes',
              ),
              _buildStatPill(
                icon: Icons.chat_bubble_outline_rounded,
                label: '${_post!.commentCount} replies',
              ),
              _buildStatPill(
                icon: Icons.access_time_rounded,
                label: _formatDate(_post!.createdAt),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.95),
                      AppColors.secondary.withValues(alpha: 0.9),
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.forum_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Discussion',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Reply, react, and keep the thread moving.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.68),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          StreamBuilder<List<ForumComment>>(
            stream: _forumService.watchComments(widget.postId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return _buildCommentsFeedbackCard(
                  icon: Icons.cloud_off_outlined,
                  title: 'Comments Need A Retry',
                  message:
                      'We hit a snag loading this conversation. Give it another try in a moment.',
                );
              }

              final comments = snapshot.data ?? [];
              if (comments.isEmpty) {
                return _buildCommentsFeedbackCard(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'Be The First To Reply',
                  message:
                      'Kick things off with the first comment and set the tone for this thread.',
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: comments.length,
                itemBuilder: (context, index) {
                  final comment = comments[index];

                  return ThreadCommentItem(
                    comment: comment,
                    postId: widget.postId,
                    onReply: _handleReply,
                    onLike: () => _handleLike(comment.id),
                    onDislike: () => _handleDislike(comment.id),
                    onDelete: () => _handleDelete(comment.id),
                    onToggleReplies: () => _toggleReplies(comment.id),
                    isExpanded: _expandedReplies.contains(comment.id),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsFeedbackCard({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: Colors.white.withValues(alpha: 0.84)),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              fontSize: 14,
              height: 1.35,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.86)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposerAvatar() {
    final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return _buildComposerAvatarShell(const Icon(
        Icons.person,
        color: Colors.white,
        size: 18,
      ));
    }

    return StreamBuilder(
      stream: _discussionAuthorService.watchForumAuthor(currentUser.uid),
      builder: (context, snapshot) {
        final liveAvatarUrl = snapshot.data?.avatarUrl ?? currentUser.photoURL;
        if (liveAvatarUrl != null && liveAvatarUrl.isNotEmpty) {
          return _buildComposerAvatarShell(
            UnifiedAvatarService().getAvatar(
              imageUrl: liveAvatarUrl,
              radius: 18,
              useProfileViewStyling: false,
              showLoadingIndicator: false,
              errorWidget: const Icon(
                Icons.person,
                color: Colors.white,
                size: 18,
              ),
            ),
          );
        }
        return _buildComposerAvatarShell(const Icon(
          Icons.person,
          color: Colors.white,
          size: 18,
        ));
      },
    );
  }

  Widget _buildComposerAvatarShell(Widget child) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.85),
            AppColors.secondary.withValues(alpha: 0.75),
          ],
        ),
      ),
      child: ClipOval(child: child),
    );
  }

  Widget _buildSourceCommentCard() {
    final sourceComment = _post!.sourceComment!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.forum_outlined,
                size: 16,
                color: Colors.amber[200],
              ),
              const SizedBox(width: 8),
              const Text(
                'Started from a video comment',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            sourceComment.text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 14,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: () => _openStreamerCard(sourceComment.authorId),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                'Original comment by ${sourceComment.authorName} (@${sourceComment.authorUsername})',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openStreamerCard(String userId) {
    if (userId.isEmpty) return;

    AppNavigator.openStreamerCard(
      context,
      userId: userId,
      currentUserId: firebase_auth.FirebaseAuth.instance.currentUser?.uid,
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
  }
}
