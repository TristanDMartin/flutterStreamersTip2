import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../models/comment.dart';
import '../models/user.dart' as app_user;
import '../services/comments_service.dart';
import '../services/auth_service.dart';
import '../utils/user_facing_error.dart';
import 'optimized_comment_tile.dart';

class CommentsViewOptimized extends ConsumerStatefulWidget {
  final String videoId;
  final String? videoOwnerId; // Add video owner ID for permission checking

  const CommentsViewOptimized({
    super.key,
    required this.videoId,
    this.videoOwnerId,
  });

  @override
  ConsumerState<CommentsViewOptimized> createState() =>
      _CommentsViewOptimizedState();
}

class _CommentsViewOptimizedState extends ConsumerState<CommentsViewOptimized> {
  final List<Comment> _comments = <Comment>[];
  final TextEditingController _textController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  String? _errorMessage;

  // Simplified emoji reactions
  static const List<String> _emojiReactions = <String>[
    '❤️',
    '🙌',
    '🔥',
    '👏',
    '😢',
    '😍',
    '😮',
    '😂',
  ];

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _textController.dispose();
    _inputFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final List<Comment> fetched =
          await CommentsService().fetchCommentsForVideo(widget.videoId);
      if (mounted) {
        setState(() {
          _comments
            ..clear()
            ..addAll(fetched);
        });
      }
    } catch (e) {
      if (mounted) {
        String errorMessage =
            'Unable to load comments. Showing sample comments.';

        // Provide more specific error messages
        if (e.toString().contains('permission-denied')) {
          errorMessage = 'Permission denied. Please sign in to view comments.';
        } else if (e.toString().contains('network')) {
          errorMessage = 'Network error. Please check your connection.';
        }

        setState(() {
          _errorMessage = errorMessage;
        });

        // Still try to show mock data for better UX
        final List<Comment> mockData = CommentMockData.mockData();
        setState(() {
          _comments
            ..clear()
            ..addAll(mockData);
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addComment() async {
    final String text = _textController.text.trim();
    if (text.isEmpty) return;

    final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      setState(() => _errorMessage = 'Please sign in to add comments');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final app_user.User me = _currentUserOrSample();
    final Comment optimistic = Comment(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      user: me,
      text: text,
      timestamp: DateTime.now(),
      likeCount: 0,
      isLiked: false,
      replies: <Comment>[],
    );

    setState(() {
      _comments.insert(0, optimistic);
      _textController.clear();
    });

    try {
      await CommentsService().addComment(
        videoId: widget.videoId,
        text: text,
        author: me,
      );
      // Success - optimistic update stays
    } catch (e) {
      // Revert optimistic update on failure
      if (mounted) {
        String errorMessage = 'Failed to add comment. Please try again.';

        // Provide more specific error messages
        if (e.toString().contains('permission-denied')) {
          errorMessage = 'Permission denied. Please sign in to add comments.';
        } else if (e.toString().contains('network')) {
          errorMessage = 'Network error. Please check your connection.';
        } else if (e.toString().contains('User not authenticated')) {
          errorMessage = 'Please sign in to add comments.';
        }

        setState(() {
          _comments.removeWhere((c) => c.id == optimistic.id);
          _errorMessage = errorMessage;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendReply(Comment parent, String text) async {
    final String replyText = text.trim();
    if (replyText.isEmpty) return;

    final app_user.User me = _currentUserOrSample();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await CommentsService().addReply(
        videoId: widget.videoId,
        parentId: parent.id,
        text: replyText,
        author: me,
      );
      await _loadComments();
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = UserFacingError.message(e));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Check if current user can delete a comment
  bool _canDeleteComment(Comment comment) {
    final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (currentUser == null) return false;

    // Comment author can delete their own comment
    if (comment.user.id == currentUser.uid) return true;

    // Video owner can delete any comment on their video
    if (widget.videoOwnerId != null && widget.videoOwnerId == currentUser.uid) {
      return true;
    }

    return false;
  }

  Future<void> _deleteComment(String commentId) async {
    try {
      // Check if user has permission to delete this comment
      final comment = _comments.firstWhere((c) => c.id == commentId);
      if (!_canDeleteComment(comment)) {
        setState(
          () => _errorMessage = 'You are not authorized to delete this comment',
        );
        return;
      }

      final success = await CommentsService().deleteComment(
        videoId: widget.videoId,
        commentId: commentId,
        videoOwnerId: widget.videoOwnerId,
      );

      if (success) {
        await _loadComments();
      }
    } catch (e) {
      setState(() => _errorMessage = UserFacingError.message(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isLight = theme.brightness == Brightness.light;
    final List<Color> sheetGradient = isLight
        ? <Color>[
            scheme.surface,
            scheme.surfaceContainerLow,
          ]
        : <Color>[
            scheme.primary.withValues(alpha: 0.92),
            scheme.surfaceContainerHighest,
          ];
    final Color dragColor = isLight ? scheme.outlineVariant : Colors.grey[600]!;
    final double containerHeight = MediaQuery.sizeOf(context).height * 0.75;

    return Material(
      color: Colors.transparent,
      child: Container(
        // FIXED HEIGHT: Never changes to prevent bounce
        height: containerHeight,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: sheetGradient,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Drag indicator bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: dragColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            _buildHeader(),

            // Comments List
            Expanded(child: _buildCommentList()),

            Builder(
              builder: (BuildContext footerContext) {
                final double keyboardInset =
                    MediaQuery.viewInsetsOf(footerContext).bottom;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (keyboardInset == 0) _buildEmojiRow(),
                    _buildInputBar(keyboardInset),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // Centered "Comments" title
          Text(
            'Comments',
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          // Comment count
          Text(
            '${_comments.length} comments',
            style: TextStyle(
              color: scheme.onSurface.withValues(alpha: 0.65),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentList() {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    if (_isLoading && _comments.isEmpty) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
        ),
      );
    }

    if (_comments.isEmpty && !_isLoading && _errorMessage == null) {
      return Center(
        child: Text(
          'No comments yet',
          style: TextStyle(
            color: scheme.onSurface.withValues(alpha: 0.72),
            fontSize: 16,
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.info_outline, color: Colors.orange, size: 48),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: 0.72),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadComments,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _comments.length,
      itemBuilder: (BuildContext context, int index) {
        final Comment c = _comments[index];
        return OptimizedCommentTile(
          comment: c,
          videoId: widget.videoId,
          videoOwnerId: widget.videoOwnerId,
          onReply: () => _showReplySheet(c),
          onDelete: _canDeleteComment(c) ? () => _showDeleteSheet(c) : null,
          onDeleteReply: _showDeleteSheet,
        );
      },
    );
  }

  Widget _buildEmojiRow() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _emojiReactions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (BuildContext context, int index) {
          final String emoji = _emojiReactions[index];
          return GestureDetector(
            onTap: () {
              final String currentText = _textController.text;
              _textController.text = currentText + emoji;
              _textController.selection = TextSelection.fromPosition(
                TextPosition(offset: _textController.text.length),
              );
            },
            child: SizedBox(
              width: 40,
              height: 40,
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 24)),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputBar(double keyboardInset) {
    final double bottomPadding = MediaQuery.paddingOf(context).bottom;
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isLight = theme.brightness == Brightness.light;
    final List<Color> barGradient = isLight
        ? <Color>[
            scheme.surfaceContainerLow,
            scheme.surface,
          ]
        : <Color>[
            scheme.primary.withValues(alpha: 0.88),
            scheme.surfaceContainerHighest,
          ];

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        keyboardInset > 0 ? 8 : bottomPadding + 8,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: barGradient,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border(
          top: BorderSide(
            color: scheme.outline.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // User avatar
          CircleAvatar(
            radius: 16,
            backgroundColor: scheme.primary,
            backgroundImage: _currentUserOrSample().avatarURL != null
                ? NetworkImage(_currentUserOrSample().avatarURL!)
                : null,
            child: _currentUserOrSample().avatarURL == null
                ? Text(
                    _currentUserOrSample().username.isNotEmpty
                        ? _currentUserOrSample().username[0].toUpperCase()
                        : 'U',
                    style: TextStyle(
                      color: scheme.onPrimary,
                      fontSize: 12,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),

          // Text field
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: scheme.outline.withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              child: TextField(
                controller: _textController,
                focusNode: _inputFocusNode,
                style: TextStyle(color: scheme.onSurface),
                decoration: InputDecoration(
                  hintText: 'What do you think of this?',
                  hintStyle: TextStyle(
                    color: scheme.onSurface.withValues(alpha: 0.55),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                textInputAction: TextInputAction.send,
                keyboardType: TextInputType.text,
                enableInteractiveSelection: true,
                onSubmitted: (_) => _addComment(),
                onTapOutside: (_) => _inputFocusNode.unfocus(),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Send button
          GestureDetector(
            onTap: _addComment,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[
                    scheme.primary,
                    scheme.secondary,
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.send, color: scheme.onPrimary, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  void _showReplySheet(Comment parent) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: false,
      isDismissible: true,
      enableDrag: true,
      builder: (BuildContext context) {
        final TextEditingController replyController = TextEditingController();
        final ThemeData theme = Theme.of(context);
        final ColorScheme scheme = theme.colorScheme;
        final bool isLight = theme.brightness == Brightness.light;
        return Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isLight
                    ? <Color>[scheme.surface, scheme.surfaceContainerLow]
                    : <Color>[
                        scheme.primary.withValues(alpha: 0.92),
                        scheme.surfaceContainerHighest,
                      ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Reply to @${parent.user.username}',
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.close,
                          color: scheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      parent.text,
                      style: TextStyle(
                        color: scheme.onSurface.withValues(alpha: 0.72),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: replyController,
                    maxLines: 5,
                    minLines: 3,
                    style: TextStyle(color: scheme.onSurface),
                    decoration: InputDecoration(
                      hintText: 'Write your reply...',
                      hintStyle: TextStyle(
                        color: scheme.onSurface.withValues(alpha: 0.55),
                      ),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          final String text = replyController.text.trim();
                          if (text.isEmpty) return;
                          Navigator.pop(context);
                          await _sendReply(parent, text);
                        },
                        child: const Text('Send'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showDeleteSheet(Comment c) {
    // Only show delete sheet if user can delete the comment
    if (!_canDeleteComment(c)) {
      setState(
        () => _errorMessage = 'You are not authorized to delete this comment',
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        final ThemeData theme = Theme.of(context);
        final ColorScheme scheme = theme.colorScheme;
        final bool isLight = theme.brightness == Brightness.light;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isLight
                  ? <Color>[scheme.surface, scheme.surfaceContainerLow]
                  : <Color>[
                      scheme.primary.withValues(alpha: 0.92),
                      scheme.surfaceContainerHighest,
                    ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Delete Comment',
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Are you sure you want to delete this comment?',
                  style: TextStyle(
                    color: scheme.onSurface.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    c.text,
                    style: TextStyle(color: scheme.onSurface),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _deleteComment(c.id);
                      },
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  app_user.User _currentUserOrSample() {
    final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final AuthenticationService auth = ref.read(authServiceProvider);
      final Map<String, dynamic>? profile = auth.currentUserProfile;

      return app_user.User(
        id: currentUser.uid, // Use Firebase Auth UID directly
        username: (profile?['username'] ?? currentUser.displayName ?? 'you')
            .toString(),
        displayName:
            (profile?['displayName'] ?? currentUser.displayName ?? 'You')
                .toString(),
        bio: null,
        avatarURL: profile?['photoURL'] ?? currentUser.photoURL,
        onlineStatus: 'online',
        hashtags: const <String>[],
        postCount: 0,
        followerCount: 0,
        followingCount: 0,
      );
    }
    return app_user.UserSamples.samples.first;
  }
}
