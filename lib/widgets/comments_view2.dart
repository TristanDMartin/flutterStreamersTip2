import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../models/comment.dart';
import '../models/user.dart' as app_user;
import '../services/comments_service.dart';
import '../services/discussion_author_service.dart';
import '../services/global_playback_manager.dart';
import '../services/comment_view_onboarding_service.dart';
import '../services/progression_service.dart';
import '../constants/app_colors.dart';
import '../core/theme/st_theme_tokens.dart';
import '../widgets/comments/comment_threads_onboarding_tooltip.dart';
import '../widgets/threads/create_thread_from_comment_screen.dart';
import '../widgets/threads/thread_detail_screen.dart';
import '../widgets/threads/threads_list_view.dart';
import '../utils/avatar_url_resolver.dart';
import 'optimized_comment_tile.dart';
import 'streamer_card_sections.dart';

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
/// Audio Policy: Video keeps playing underneath with ducked volume
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

class _PendingCommentEntry {
  const _PendingCommentEntry({
    required this.comment,
    this.parentId,
  });

  final Comment comment;
  final String? parentId;
}

class _CommentsView2State extends ConsumerState<CommentsView2> {
  // Controllers and state
  final List<Comment> _comments = <Comment>[];
  final TextEditingController _textController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
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
  int _commentsStreamApplyToken = 0;
  bool _isSubmittingComment = false;
  final Map<String, _PendingCommentEntry> _pendingComments =
      <String, _PendingCommentEntry>{};
  bool _showThreadsTooltip = false;
  final CommentViewOnboardingService _commentOnboardingService =
      CommentViewOnboardingService();

  @override
  void initState() {
    super.initState();
    unawaited(GlobalPlaybackManager.instance.setActiveVideoVolume(0.35));
    _setupRealtimeComments();
    _loadCurrentUserAvatar();
    _inputFocusNode.addListener(_handleInputFocusChanged);
    _textController.addListener(_handleInputTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_maybeShowCommentsOnboarding());
    });
  }

  @override
  void dispose() {
    _commentsSubscription?.cancel();
    _inputFocusNode.removeListener(_handleInputFocusChanged);
    _textController.removeListener(_handleInputTextChanged);
    _textController.dispose();
    _inputFocusNode.dispose();
    unawaited(GlobalPlaybackManager.instance.setActiveVideoVolume(1.0));
    super.dispose();
  }

  void _handleInputFocusChanged() {
    if (mounted) setState(() {});
  }

  void _handleInputTextChanged() {
    if (mounted) setState(() {});
  }

  // ============================================================================
  // REAL-TIME COMMENTS SETUP
  // ============================================================================

  void _setupRealtimeComments() {
    setState(() => _isLoading = true);

    _commentsSubscription =
        CommentsService().watchCommentsForVideo(widget.videoId).listen(
      (VideoCommentsSnapshot snapshot) async {
        final int applyToken = ++_commentsStreamApplyToken;
        try {
          final List<Comment> enrichedComments = await Future.wait(
            snapshot.comments.map(_enrichCommentTree),
          );

          if (!mounted || applyToken != _commentsStreamApplyToken) {
            return;
          }
          setState(() {
            _comments
              ..clear()
              ..addAll(enrichedComments);
            _remergePendingOptimisticComments();
            _linkedThreadIds
              ..clear()
              ..addAll(snapshot.linkedThreadIds);
            _applySorting();
            _isLoading = false;
            _errorMessage = null;
          });
        } catch (e) {
          if (!mounted || applyToken != _commentsStreamApplyToken) {
            return;
          }
          setState(() {
            _errorMessage = 'Error loading comments';
            _isLoading = false;
          });
        }
      },
      onError: (Object error) {
        _commentsStreamApplyToken++;
        if (!mounted) {
          return;
        }
        setState(() {
          _errorMessage = 'Failed to load comments';
          _isLoading = false;
        });
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
    if (text.isEmpty || _isSubmittingComment) {
      return;
    }

    final firebase_auth.User? currentUser =
        firebase_auth.FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      setState(() => _errorMessage = 'Please sign in to add comments');
      return;
    }

    final Comment? replyTarget = _replyingTo;
    final String? parentId = replyTarget?.id;
    final String tempId = 'pending_${DateTime.now().millisecondsSinceEpoch}';
    final app_user.User sessionAuthor = _sessionAuthor(currentUser);
    final Comment optimistic = Comment(
      id: tempId,
      user: sessionAuthor,
      text: text,
      timestamp: DateTime.now(),
      likeCount: 0,
      isLiked: false,
      replies: <Comment>[],
    );

    _textController.clear();
    _inputFocusNode.unfocus();

    setState(() {
      _isSubmittingComment = true;
      _errorMessage = null;
      _replyingTo = null;
      _pendingComments[tempId] = _PendingCommentEntry(
        comment: optimistic,
        parentId: parentId,
      );
      if (parentId == null) {
        _comments.insert(0, optimistic);
      } else {
        _insertOptimisticReply(parentId, optimistic);
      }
      _applySorting();
    });

    try {
      final CommentsService commentsService = CommentsService();
      final app_user.User author = await _getCurrentUserFromFirestore();

      if (parentId != null) {
        await commentsService.addReply(
          videoId: widget.videoId,
          parentId: parentId,
          text: text,
          author: author,
        );
      } else {
        await commentsService.addComment(
          videoId: widget.videoId,
          text: text,
          author: author,
        );
      }

      unawaited(
        ProgressionService.instance.markTaskCompleted(
          currentUser.uid,
          ProgressionTaskIds.firstCommentMade,
          source: 'comments',
        ),
      );
      unawaited(
        ProgressionService.instance.refreshUserProgress(currentUser.uid),
      );

      if (mounted) {
        setState(() {
          _pendingComments.remove(tempId);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _pendingComments.remove(tempId);
          _removeOptimisticComment(tempId, parentId: parentId);
          _textController.text = text;
          _replyingTo = replyTarget;
          _errorMessage = 'Comment failed to send. Tap to retry.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmittingComment = false);
      }
    }
  }

  app_user.User _sessionAuthor(firebase_auth.User currentUser) {
    return app_user.User(
      id: currentUser.uid,
      username: currentUser.displayName ?? 'User',
      displayName: currentUser.displayName ?? 'User',
      avatarURL: _currentUserAvatarUrl ?? currentUser.photoURL,
      bio: '',
      followerCount: 0,
      followingCount: 0,
    );
  }

  void _insertOptimisticReply(String parentId, Comment reply) {
    for (int i = 0; i < _comments.length; i++) {
      final Comment? updated = _insertReplyIntoComment(
        _comments[i],
        parentId,
        reply,
      );
      if (updated != null) {
        _comments[i] = updated;
        return;
      }
    }
  }

  Comment? _insertReplyIntoComment(
    Comment node,
    String parentId,
    Comment reply,
  ) {
    if (node.id == parentId) {
      final List<Comment> replies = List<Comment>.from(node.replies ?? []);
      replies.insert(0, reply);
      return node.copyWith(replies: replies);
    }
    final List<Comment>? children = node.replies;
    if (children == null || children.isEmpty) {
      return null;
    }
    for (int i = 0; i < children.length; i++) {
      final Comment? updated = _insertReplyIntoComment(
        children[i],
        parentId,
        reply,
      );
      if (updated != null) {
        final List<Comment> newReplies = List<Comment>.from(children);
        newReplies[i] = updated;
        return node.copyWith(replies: newReplies);
      }
    }
    return null;
  }

  void _removeOptimisticComment(String tempId, {String? parentId}) {
    if (parentId == null) {
      _comments.removeWhere((Comment c) => c.id == tempId);
      return;
    }
    for (int i = 0; i < _comments.length; i++) {
      final Comment? updated = _removeReplyFromComment(_comments[i], tempId);
      if (updated != null) {
        _comments[i] = updated;
        return;
      }
    }
  }

  Comment? _removeReplyFromComment(Comment node, String tempId) {
    if (node.replies == null || node.replies!.isEmpty) {
      return null;
    }
    final List<Comment> replies = List<Comment>.from(node.replies!);
    final int index = replies.indexWhere((Comment r) => r.id == tempId);
    if (index >= 0) {
      replies.removeAt(index);
      return node.copyWith(replies: replies);
    }
    for (int i = 0; i < replies.length; i++) {
      final Comment? updated = _removeReplyFromComment(replies[i], tempId);
      if (updated != null) {
        replies[i] = updated;
        return node.copyWith(replies: replies);
      }
    }
    return null;
  }

  void _remergePendingOptimisticComments() {
    final List<_PendingCommentEntry> stillPending =
        _pendingComments.values.toList(growable: false);
    for (final _PendingCommentEntry entry in stillPending) {
      if (_isCommentConfirmedInTree(_comments, entry.comment)) {
        _pendingComments.remove(entry.comment.id);
        continue;
      }
      if (entry.parentId == null) {
        if (!_comments.any((Comment c) => c.id == entry.comment.id)) {
          _comments.insert(0, entry.comment);
        }
      } else {
        _insertOptimisticReply(entry.parentId!, entry.comment);
      }
    }
  }

  bool _isCommentConfirmedInTree(List<Comment> tree, Comment pending) {
    for (final Comment comment in tree) {
      if (comment.id != pending.id &&
          !comment.id.startsWith('pending_') &&
          comment.user.id == pending.user.id &&
          comment.text == pending.text) {
        return true;
      }
      final List<Comment>? replies = comment.replies;
      if (replies != null &&
          replies.isNotEmpty &&
          _isCommentConfirmedInTree(replies, pending)) {
        return true;
      }
    }
    return false;
  }

  void _startReply(Comment comment) {
    setState(() => _replyingTo = comment);
    _inputFocusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() => _replyingTo = null);
  }

  void _openCreateThreadModal(Comment comment) {
    final String? userId = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      unawaited(_commentOnboardingService.markCreatedFirstThread(userId));
    }
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

  Future<void> _maybeShowCommentsOnboarding() async {
    final String? userId = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    if (userId == null || !mounted) {
      return;
    }
    unawaited(_commentOnboardingService.markCommentViewOpened(userId));
    final bool shouldShow =
        await _commentOnboardingService.shouldShowThreadsTooltip(userId);
    if (!mounted || !shouldShow) {
      return;
    }
    setState(() => _showThreadsTooltip = true);
  }

  Future<void> _dismissThreadsTooltip() async {
    final String? userId = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      await _commentOnboardingService.markThreadsTooltipShown(userId);
    }
    if (!mounted) {
      return;
    }
    setState(() => _showThreadsTooltip = false);
  }

  Future<void> _onTryThreadsFromTooltip() async {
    await _dismissThreadsTooltip();
    if (!mounted) {
      return;
    }
    final NavigatorState navigator = Navigator.of(context);
    navigator.pop();
    await navigator.push<void>(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/threads'),
        builder: (BuildContext context) =>
            const ThreadsListView(embeddedInHome: false),
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
    final bool isLight = Theme.of(context).brightness == Brightness.light;
    final double keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final Color sheetColor = isLight
        ? Colors.white.withValues(alpha: 0.98)
        : StreamerCardBackStyle.background;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: DraggableScrollableSheet(
        initialChildSize: 0.68,
        minChildSize: 0.42,
        maxChildSize: 0.92,
        expand: false,
        snap: true,
        builder: (context, sheetScrollController) {
          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Material(
                color: sheetColor,
                child: Column(
                  children: [
                    _buildDragIndicator(),
                    _buildHeader(),
                    Expanded(
                      child: _buildCommentList(sheetScrollController),
                    ),
                    _buildComposerFooter(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Color get _primaryTextColor {
    final bool isLight = Theme.of(context).brightness == Brightness.light;
    return isLight
        ? StThemeColors.lightTextPrimary
        : Colors.white;
  }

  Color get _secondaryTextColor {
    final bool isLight = Theme.of(context).brightness == Brightness.light;
    return isLight
        ? StThemeColors.lightTextSecondary
        : StreamerCardBackStyle.softText;
  }

  Color get _mutedTextColor {
    final bool isLight = Theme.of(context).brightness == Brightness.light;
    return isLight
        ? StThemeColors.lightTextMuted
        : StreamerCardBackStyle.muted;
  }

  Color get _accentColor {
    final bool isLight = Theme.of(context).brightness == Brightness.light;
    return isLight ? StThemeColors.brandPurple : StreamerCardBackStyle.accent;
  }

  Color get _accentSoft {
    final bool isLight = Theme.of(context).brightness == Brightness.light;
    return isLight
        ? StThemeColors.brandPurple.withValues(alpha: 0.22)
        : StreamerCardBackStyle.accent.withValues(alpha: 0.2);
  }

  Color get _lavender {
    final bool isLight = Theme.of(context).brightness == Brightness.light;
    return isLight ? StThemeColors.brandPurple : StreamerCardBackStyle.lavender;
  }

  Widget _buildDragIndicator() {
    return Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.only(top: 10, bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        color: _mutedTextColor.withValues(alpha: 0.42),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 12, 12),
      child: Column(
        children: [
          SizedBox(
            height: 44,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Comments',
                      style: TextStyle(
                        color: _primaryTextColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_comments.length}',
                      style: TextStyle(
                        color: _mutedTextColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  width: 40,
                  height: 40,
                  child: IconButton(
                    icon: Icon(
                      Icons.close,
                      color: _mutedTextColor,
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
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
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildSortChip(String label, CommentSortOption option, IconData icon) {
    final bool isSelected = _sortOption == option;
    return Expanded(
      child: GestureDetector(
        onTap: () => _changeSortOption(option),
        child: AnimatedContainer(
          duration: StMotion.fast,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? _accentSoft
                : (Theme.of(context).brightness == Brightness.light
                    ? Colors.transparent
                    : StreamerCardBackStyle.card),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? _accentColor.withValues(alpha: 0.35)
                  : _mutedTextColor.withValues(alpha: 0.16),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? _lavender : _mutedTextColor,
                size: 15,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? _lavender : _secondaryTextColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommentList(ScrollController sheetScrollController) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: StreamerCardBackStyle.lavender),
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
      return Center(
        child: Text(
          'No comments yet.\nBe the first to comment!',
          style: TextStyle(color: _mutedTextColor),
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView.builder(
      controller: sheetScrollController,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
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

  Widget _buildComposerFooter() {
    return SafeArea(
      top: false,
      minimum: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_showThreadsTooltip)
            CommentThreadsOnboardingTooltip(
              onDismiss: _dismissThreadsTooltip,
              onTryThreads: _onTryThreadsFromTooltip,
            ),
          _buildEmojiRow(),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildEmojiRow() {
    if (!_inputFocusNode.hasFocus) return const SizedBox.shrink();
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

    return AnimatedContainer(
      duration: StMotion.fast,
      curve: StMotion.out,
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: emojiReactions
              .map((emoji) => GestureDetector(
                    onTap: () {
                      _textController
                        ..text += emoji
                        ..selection = TextSelection.collapsed(
                          offset: _textController.text.length,
                        );
                    },
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
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: _mutedTextColor.withValues(alpha: 0.12)),
        ),
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
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Comment reply = _replyingTo!;
    final String username = reply.user.username.trim().isNotEmpty
        ? reply.user.username.trim()
        : reply.user.displayName.trim();
    final String preview = reply.text.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        decoration: BoxDecoration(
          color: dark
              ? StreamerCardBackStyle.card
              : _accentSoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _accentColor.withValues(alpha: dark ? 0.3 : 0.24),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.reply_rounded,
              color: _lavender,
              size: 16,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Replying to @$username',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _lavender,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (preview.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _mutedTextColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: 'Cancel reply',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 30, height: 30),
              onPressed: _cancelReply,
              icon: Icon(
                Icons.close_rounded,
                color: _mutedTextColor,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildInputRow() {
    return SizedBox(
      height: 58,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildUserAvatar(),
          const SizedBox(width: 8),
          Expanded(child: _buildTextField()),
          const SizedBox(width: 8),
          _buildSendButton(),
        ],
      ),
    );
  }

  Widget _buildUserAvatar() {
    final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
    final avatarUrl = _currentUserAvatarUrl ?? currentUser?.photoURL;

    return Container(
      width: 36,
      height: 36,
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            StreamerCardBackStyle.ringBlue,
            StreamerCardBackStyle.ringPurple,
          ],
        ),
      ),
      child: ClipOval(
        child: ColoredBox(
          color: StreamerCardBackStyle.avatarFill,
          child: avatarUrl != null && avatarUrl.isNotEmpty
              ? Image.network(
                  avatarUrl,
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.person,
                    color: StreamerCardBackStyle.softText,
                    size: 16,
                  ),
                )
              : const Icon(
                  Icons.person,
                  color: StreamerCardBackStyle.softText,
                  size: 16,
                ),
        ),
      ),
    );
  }

  Widget _buildTextField() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 40, maxHeight: 120),
      child: TextField(
        controller: _textController,
        focusNode: _inputFocusNode,
        keyboardType: TextInputType.text,
        textInputAction: TextInputAction.send,
        minLines: 1,
        maxLines: 4,
        scrollPadding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom + 96,
        ),
        onSubmitted: (_) => _addComment(),
        style: TextStyle(
          color: _primaryTextColor,
          fontSize: 13,
          height: 1.25,
          fontWeight: FontWeight.w400,
        ),
        cursorColor: _lavender,
        decoration: InputDecoration(
          hintText: _replyingTo != null ? 'Reply...' : 'Add a comment...',
          hintStyle: TextStyle(
            color: _mutedTextColor,
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
          filled: true,
          fillColor: isDark
              ? StreamerCardBackStyle.card
              : Colors.black.withValues(alpha: 0.04),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: _mutedTextColor.withValues(alpha: 0.16),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: _mutedTextColor.withValues(alpha: 0.16),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: _accentColor.withValues(alpha: 0.45),
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 10,
          ),
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildSendButton() {
    final bool canSend =
        _textController.text.trim().isNotEmpty && !_isSubmittingComment;
    return GestureDetector(
      onTap: canSend ? _addComment : null,
      child: AnimatedContainer(
        duration: StMotion.fast,
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: canSend
              ? _accentColor.withValues(alpha: 0.22)
              : _mutedTextColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: canSend
                ? _accentColor.withValues(alpha: 0.35)
                : Colors.transparent,
          ),
        ),
        child: Icon(
          Icons.arrow_upward_rounded,
          color: canSend ? _lavender : _mutedTextColor,
          size: 18,
        ),
      ),
    );
  }
}
