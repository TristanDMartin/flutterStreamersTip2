import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../models/comment.dart';
import '../models/user.dart' as app_user;
import '../services/auth_service.dart';

class CommentsView extends ConsumerStatefulWidget {
  final String videoId;

  const CommentsView({super.key, required this.videoId});

  @override
  ConsumerState<CommentsView> createState() => _CommentsViewState();
}

class _CommentsViewState extends ConsumerState<CommentsView> {
  final List<Comment> _comments = <Comment>[];
  final TextEditingController _textController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  String? _errorMessage;

  String _searchQuery = '';

  // Updated emoji reactions as specified
  static const List<String> _emojiReactions = <String>[
    '❤️', '🙌', '🔥', '👏', '😢', '😍', '😮', '😂',
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
    // Check if user is authenticated using Firebase Auth directly
    final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      setState(() {
        _errorMessage = 'Please sign in to view comments';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final List<Comment> fetched = _CommentService.shared
          .fetchCommentsForVideo(widget.videoId);
      setState(() {
        _comments
          ..clear()
          ..addAll(fetched);
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addComment() async {
    final String text = _textController.text.trim();
    if (text.isEmpty) return;

    // Check if user is authenticated using Firebase Auth directly
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
      await _CommentService.shared.addComment(
        videoId: widget.videoId,
        text: text,
        author: me,
      );
    } catch (e) {
      setState(() {
        _comments.removeWhere((c) => c.id == optimistic.id);
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendReply(Comment parent, String text) async {
    final String replyText = text.trim();
    if (replyText.isEmpty) return;

    final app_user.User me = _currentUserOrSample();
    final Comment optimistic = Comment(
      id: 'r-${DateTime.now().microsecondsSinceEpoch}',
      user: me,
      text: replyText,
      timestamp: DateTime.now(),
      likeCount: 0,
      isLiked: false,
      replies: <Comment>[],
    );

    setState(() {
      final int idx = _comments.indexWhere((c) => c.id == parent.id);
      if (idx != -1) {
        final List<Comment> updatedReplies =
            List<Comment>.from(_comments[idx].replies ?? <Comment>[]);
        updatedReplies.insert(0, optimistic);
        _comments[idx] = _comments[idx].copyWith(replies: updatedReplies);
      }
    });

    try {
      await _CommentService.shared.addReply(
        videoId: widget.videoId,
        parentId: parent.id,
        text: replyText,
        author: me,
      );
    } catch (e) {
      setState(() {
        final int idx = _comments.indexWhere((c) => c.id == parent.id);
        if (idx != -1) {
          final List<Comment> updatedReplies =
              List<Comment>.from(_comments[idx].replies ?? <Comment>[])
                ..removeWhere((r) => r.id == optimistic.id);
          _comments[idx] = _comments[idx].copyWith(replies: updatedReplies);
        }
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _toggleLike(String commentId) async {
    // Optimistic toggle on main comments
    int idx = _comments.indexWhere((c) => c.id == commentId);
    if (idx != -1) {
      final bool nowLiked = !_comments[idx].isLiked;
      final int newCount = _comments[idx].likeCount + (nowLiked ? 1 : -1);
      setState(() {
        _comments[idx] = _comments[idx]
            .copyWith(isLiked: nowLiked, likeCount: newCount);
      });
    } else {
      // Search in replies
      for (int i = 0; i < _comments.length; i++) {
        final List<Comment> replies =
            List<Comment>.from(_comments[i].replies ?? <Comment>[]);
        final int rIdx = replies.indexWhere((r) => r.id == commentId);
        if (rIdx != -1) {
          final bool nowLiked = !replies[rIdx].isLiked;
          final int newCount = replies[rIdx].likeCount + (nowLiked ? 1 : -1);
          replies[rIdx] = replies[rIdx]
              .copyWith(isLiked: nowLiked, likeCount: newCount);
          setState(() {
            _comments[i] = _comments[i].copyWith(replies: replies);
          });
          break;
        }
      }
    }

    try {
      await _CommentService.shared.toggleLike(commentId: commentId);
    } catch (e) {
      // Revert on error
      idx = _comments.indexWhere((c) => c.id == commentId);
      if (idx != -1) {
        final bool nowLiked = !_comments[idx].isLiked;
        final int newCount = _comments[idx].likeCount + (nowLiked ? 1 : -1);
        setState(() {
          _comments[idx] = _comments[idx]
              .copyWith(isLiked: nowLiked, likeCount: newCount);
        });
      } else {
        for (int i = 0; i < _comments.length; i++) {
          final List<Comment> replies =
              List<Comment>.from(_comments[i].replies ?? <Comment>[]);
          final int rIdx = replies.indexWhere((r) => r.id == commentId);
          if (rIdx != -1) {
            final bool nowLiked = !replies[rIdx].isLiked;
            final int newCount =
                replies[rIdx].likeCount + (nowLiked ? 1 : -1);
            replies[rIdx] = replies[rIdx]
                .copyWith(isLiked: nowLiked, likeCount: newCount);
            setState(() {
              _comments[i] = _comments[i].copyWith(replies: replies);
            });
            break;
          }
        }
      }
      setState(() => _errorMessage = e.toString());
    }
  }

  Future<void> _deleteComment(String commentId) async {
    try {
      await _CommentService.shared.deleteComment(
        videoId: widget.videoId,
        commentId: commentId,
      );
      setState(() {
        _comments.removeWhere((c) => c.id == commentId);
        for (int i = 0; i < _comments.length; i++) {
          final List<Comment> replies =
              List<Comment>.from(_comments[i].replies ?? <Comment>[])
                ..removeWhere((r) => r.id == commentId);
          _comments[i] = _comments[i].copyWith(replies: replies);
        }
      });
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    }
  }



  List<Comment> get _filteredComments {
    if (_searchQuery.isEmpty) return _comments;
    return _comments.where((comment) {
      return comment.text.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          comment.user.username.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag indicator bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          _buildHeader(),
          
          // Comments List
          Expanded(child: _buildCommentList()),
          
          // Reactions Row (Above Input)
          _buildEmojiRow(),
          
          // Input Bar
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // Centered "Comments" title
          const Text(
            'Comments',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          // Search/action row
          Row(
            children: [
              // Magnifying glass icon
              Icon(
                Icons.search,
                color: Colors.grey[400],
                size: 20,
              ),
              const SizedBox(width: 8),
              
              // Quick search link
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _searchQuery = 'Lemonade recipes for pregnant women';
                    });
                  },
                  child: Text(
                    '· Lemonade recipes for pregnant women',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommentList() {
    if (_isLoading && _comments.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    if (_filteredComments.isEmpty && !_isLoading && _errorMessage == null) {
      return const Center(
        child: Text(
          'No comments yet',
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SelectableText.rich(
            TextSpan(
              children: <InlineSpan>[
                const TextSpan(
                  text: 'Error: ',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
                ),
                TextSpan(
                  text: _errorMessage!,
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _filteredComments.length,
      itemBuilder: (BuildContext context, int index) {
        final Comment c = _filteredComments[index];
        return _CommentTile(
          comment: c,
          onReply: () => _showReplySheet(c),
          onDelete: () => _showDeleteSheet(c),
          onToggleLike: () => _toggleLike(c.id),
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
              _textController.text = _textController.text + emoji;
              _inputFocusNode.requestFocus();
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  emoji,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
        ),
      ),
      child: Row(
        children: [
          // User avatar
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.purple,
            backgroundImage: _currentUserOrSample().avatarURL != null
                ? NetworkImage(_currentUserOrSample().avatarURL!)
                : null,
            child: _currentUserOrSample().avatarURL == null
                ? Text(
                    _currentUserOrSample().username.isNotEmpty
                        ? _currentUserOrSample().username[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          
          // Text field
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: _textController,
                focusNode: _inputFocusNode,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'What do you think of this?',
                  hintStyle: const TextStyle(color: Colors.white54),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  suffixIcon: IconButton(
                    onPressed: () {
                      // Emoji/sticker button - focus to show native keyboard
                      _inputFocusNode.requestFocus();
                    },
                    icon: const Icon(
                      Icons.emoji_emotions_outlined,
                      color: Colors.white54,
                      size: 20,
                    ),
                  ),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _addComment(),
              ),
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
      backgroundColor: Colors.black,
      builder: (BuildContext context) {
        final TextEditingController replyController = TextEditingController();
        return Padding(
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  parent.text,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: replyController,
                maxLines: 5,
                minLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Write your reply...',
                  hintStyle: TextStyle(color: Colors.white54),
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
        );
      },
    );
  }

  void _showDeleteSheet(Comment c) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.black,
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Delete Comment',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'Are you sure you want to delete this comment?',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(c.text, style: const TextStyle(color: Colors.white)),
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
        );
      },
    );
  }

  app_user.User _currentUserOrSample() {
    final AuthenticationService auth = ref.read(authServiceProvider);
    final Map<String, dynamic>? profile = auth.currentUserProfile;
    if (profile != null) {
      return app_user.User(
        id: profile['uid']?.toString() ?? 'me',
        username: (profile['username'] ?? 'you').toString(),
        displayName: (profile['displayName'] ?? 'You').toString(),
        bio: null,
        avatarURL: profile['photoURL'] as String?,
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

class _CommentTile extends StatelessWidget {
  final Comment comment;
  final VoidCallback onReply;
  final VoidCallback onDelete;
  final VoidCallback onToggleLike;

  const _CommentTile({
    required this.comment,
    required this.onReply,
    required this.onDelete,
    required this.onToggleLike,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.purple,
                backgroundImage: comment.user.avatarURL != null
                    ? NetworkImage(comment.user.avatarURL!)
                    : null,
                child: comment.user.avatarURL == null
                    ? Text(
                        comment.user.username.isNotEmpty
                            ? comment.user.username[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(color: Colors.white),
                      )
                    : null,
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
                          comment.user.username,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          comment.relativeTimestamp,
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
                      comment.text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Reply button
                    GestureDetector(
                      onTap: onReply,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                  ],
                ),
              ),
              
              // Like button and count
              Column(
                children: [
                  GestureDetector(
                    onTap: onToggleLike,
                    child: Icon(
                      comment.isLiked ? Icons.favorite : Icons.favorite_border,
                      color: comment.isLiked ? Colors.red : Colors.white70,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    comment.likeCount.toString(),
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
          if ((comment.replies?.length ?? 0) > 0)
            Padding(
              padding: const EdgeInsets.only(left: 48, top: 8),
              child: Column(
                children: comment.replies!
                    .map((Comment r) => _ReplyTile(
                          reply: r,
                          onToggleLike: () => onToggleLike(),
                          onDelete: onDelete,
                        ))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReplyTile extends StatelessWidget {
  final Comment reply;
  final VoidCallback onToggleLike;
  final VoidCallback onDelete;

  const _ReplyTile({
    required this.reply,
    required this.onToggleLike,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: Colors.purple,
            backgroundImage: reply.user.avatarURL != null
                ? NetworkImage(reply.user.avatarURL!)
                : null,
            child: reply.user.avatarURL == null
                ? Text(
                    reply.user.username.isNotEmpty
                        ? reply.user.username[0].toUpperCase()
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
                      reply.user.username,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      reply.relativeTimestamp,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  reply.text,
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
                onTap: onToggleLike,
                child: Icon(
                  reply.isLiked ? Icons.favorite : Icons.favorite_border,
                  color: reply.isLiked ? Colors.red : Colors.white70,
                  size: 16,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                reply.likeCount.toString(),
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

// Simple in-memory comment service stub. Replace with Firestore integration.
class _CommentService {
  static final _CommentService shared = _CommentService._();
  _CommentService._();

  final Map<String, List<Comment>> _store = <String, List<Comment>>{};

  List<Comment> fetchCommentsForVideo(String videoId) {
    return List<Comment>.from(
      _store[videoId] ?? CommentMockData.mockData(),
    );
  }

  Future<void> addComment({
    required String videoId,
    required String text,
    required app_user.User author,
  }) async {
    final Comment comment = Comment(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      user: author,
      text: text,
      timestamp: DateTime.now(),
      likeCount: 0,
      isLiked: false,
      replies: <Comment>[],
    );
    final List<Comment> list = List<Comment>.from(_store[videoId] ?? <Comment>[])
      ..insert(0, comment);
    _store[videoId] = list;
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }

  Future<void> addReply({
    required String videoId,
    required String parentId,
    required String text,
    required app_user.User author,
  }) async {
    final List<Comment> list = List<Comment>.from(_store[videoId] ?? <Comment>[]);
    final int idx = list.indexWhere((c) => c.id == parentId);
    if (idx != -1) {
      final Comment reply = Comment(
        id: 'r-${DateTime.now().microsecondsSinceEpoch}',
        user: author,
        text: text,
        timestamp: DateTime.now(),
        likeCount: 0,
        isLiked: false,
        replies: <Comment>[],
      );
      final List<Comment> replies = List<Comment>.from(list[idx].replies ?? <Comment>[])
        ..insert(0, reply);
      list[idx] = list[idx].copyWith(replies: replies);
      _store[videoId] = list;
    }
    await Future<void>.delayed(const Duration(milliseconds: 120));
  }

  Future<void> toggleLike({required String commentId}) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
  }

  Future<void> deleteComment({
    required String videoId,
    required String commentId,
  }) async {
    final List<Comment> list = List<Comment>.from(_store[videoId] ?? <Comment>[])
      ..removeWhere((c) => c.id == commentId);
    for (int i = 0; i < list.length; i++) {
      final List<Comment> replies =
          List<Comment>.from(list[i].replies ?? <Comment>[])
            ..removeWhere((r) => r.id == commentId);
      list[i] = list[i].copyWith(replies: replies);
    }
    _store[videoId] = list;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}