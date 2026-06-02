import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../models/comment.dart';
import '../models/user.dart' as app_user;
import '../services/comments_service.dart';
import '../utils/user_facing_error.dart';
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
    if (text.isEmpty || _isSubmittingComment) return;

    final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      setState(() => _errorMessage = 'Please sign in to add comments');
      return;
    }

    setState(() {
      _isSubmittingComment = true;
      _errorMessage = null;
    });

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
      await ProgressionService.instance.markTaskCompleted(
        currentUser.uid,
        ProgressionTaskIds.firstCommentMade,
        source: 'comments',
      );
      unawaited(
        ProgressionService.instance.refreshUserProgress(currentUser.uid),
      );
      if (mounted) {
        _textController.clear();
        _inputFocusNode.unfocus();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = UserFacingError.message(e));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmittingComment = false);
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
        : const Color(0xFF070A16).withValues(alpha: 0.96);

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
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
    final isLight = Theme.of(context).brightness == Brightness.light;
    return isLight ? StThemeColors.lightTextPrimary : Colors.white;
  }

  Color get _secondaryTextColor {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return isLight
        ? StThemeColors.lightTextSecondary
        : StThemeColors.darkTextSecondary;
  }

  Color get _mutedTextColor {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return isLight ? StThemeColors.lightTextMuted : StThemeColors.darkTextMuted;
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
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Column(
        children: [
          SizedBox(
            height: 52,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Comments',
                      style: TextStyle(
                        color: _primaryTextColor,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${_comments.length}',
                      style: TextStyle(
                        color: _mutedTextColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  width: 44,
                  height: 44,
                  child: IconButton(
                    icon: Icon(Icons.close, color: _secondaryTextColor),
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
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildSortChip(String label, CommentSortOption option, IconData icon) {
    final isSelected = _sortOption == option;
    return Expanded(
      child: GestureDetector(
        onTap: () => _changeSortOption(option),
        child: AnimatedContainer(
          duration: StMotion.fast,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? StThemeColors.brandPurple.withValues(alpha: 0.22)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(21),
            border: Border.all(
              color: isSelected
                  ? StThemeColors.brandPurple
                  : _mutedTextColor.withValues(alpha: 0.16),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? StThemeColors.brandPurple : _mutedTextColor,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? _primaryTextColor : _secondaryTextColor,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
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
        child: CircularProgressIndicator(color: StThemeColors.brandPurple),
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
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
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
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool dark = theme.brightness == Brightness.dark;
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
              ? scheme.surfaceContainerHighest.withValues(alpha: 0.84)
              : scheme.primaryContainer.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: scheme.primary.withValues(alpha: dark ? 0.38 : 0.24),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.reply_rounded,
              color: scheme.primary,
              size: 18,
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
                      color: scheme.onSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    preview.isEmpty ? 'Original comment' : '“$preview”',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurface.withValues(alpha: 0.72),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
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
                color: scheme.onSurface.withValues(alpha: 0.62),
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
          color: StThemeColors.darkSurface,
        ),
        child: avatarUrl != null && avatarUrl.isNotEmpty
            ? ClipOval(
                child: Image.network(
                  avatarUrl,
                  width: 28,
                  height: 28,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              )
            : const Icon(
                Icons.person,
                color: Colors.white,
                size: 16,
              ),
      ),
    );
  }

  Widget _buildTextField() {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: ConstrainedBox(
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
            color: scheme.onSurface,
            fontSize: 15,
            height: 1.25,
          ),
          cursorColor: scheme.primary,
          decoration: InputDecoration(
            hintText: _replyingTo != null ? 'Reply...' : 'Add a comment...',
            hintStyle: TextStyle(
              color: scheme.onSurface.withValues(alpha: 0.50),
            ),
            filled: true,
            fillColor: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : scheme.surfaceContainerHighest.withValues(alpha: 0.78),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide(
                color: scheme.outline.withValues(alpha: 0.22),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide(
                color: scheme.outline.withValues(alpha: 0.22),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide(
                color: scheme.primary.withValues(alpha: 0.72),
              ),
            ),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSendButton() {
    final canSend =
        _textController.text.trim().isNotEmpty && !_isSubmittingComment;
    return GestureDetector(
      onTap: canSend ? _addComment : null,
      child: AnimatedContainer(
        duration: StMotion.fast,
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          gradient: canSend ? StThemeColors.gradient : null,
          color: canSend ? null : _mutedTextColor.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            if (canSend)
              BoxShadow(
                color: StThemeColors.brandPurple.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Icon(
          Icons.arrow_upward_rounded,
          color: canSend ? Colors.white : _mutedTextColor,
          size: 20,
        ),
      ),
    );
  }
}
