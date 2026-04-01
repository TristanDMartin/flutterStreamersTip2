import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../../services/forum_service.dart';
import '../../services/comments_service.dart';
import '../../models/comment.dart';
import '../../models/forum_author.dart';
import '../../models/forum_category.dart';
import 'thread_detail_screen.dart';

/// Screen for creating a thread from a comment
class CreateThreadFromCommentScreen extends StatefulWidget {
  final String videoId;
  final Comment comment;

  const CreateThreadFromCommentScreen({
    super.key,
    required this.videoId,
    required this.comment,
  });

  @override
  State<CreateThreadFromCommentScreen> createState() =>
      _CreateThreadFromCommentScreenState();
}

class _CreateThreadFromCommentScreenState
    extends State<CreateThreadFromCommentScreen> {
  final ForumService _forumService = ForumService();
  final CommentsService _commentsService = CommentsService();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  String? _selectedCategory;
  List<ForumCategory> _categories = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    // Pre-fill content with comment text
    _contentController.text = widget.comment.text;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _forumService.getCategories();
      setState(() {
        _categories = categories;
        if (categories.isNotEmpty && _selectedCategory == null) {
          _selectedCategory = categories[0].id;
        }
      });
    } catch (e) {
      debugPrint('❌ Error loading categories: $e');
    }
  }

  Future<void> _createThread() async {
    if (_isLoading) return;

    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty || content.isEmpty || _selectedCategory == null) {
      setState(() {
        _errorMessage = 'Please fill all fields and select a category.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = firebase_auth.FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw 'User not authenticated.';
      }

      final threadAuthor = ForumAuthor(
        uid: user.uid,
        username: user.displayName ?? 'user',
        displayName: user.displayName ?? 'User',
        avatarUrl: user.photoURL,
      );

      final commentAuthor = {
        'id': widget.comment.user.id,
        'username': widget.comment.user.username,
        'displayName': widget.comment.user.displayName,
        'name': widget.comment.user.displayName,
      };

      final threadId = await _forumService.createThreadFromComment(
        threadTitle: title,
        commentText: content,
        commentAuthor: commentAuthor,
        threadAuthor: threadAuthor,
        videoId: widget.videoId,
        commentId: widget.comment.id,
        categoryId: _selectedCategory!,
        tags: [],
      );

      // Link comment to thread
      await _commentsService.linkCommentToThread(
        videoId: widget.videoId,
        commentId: widget.comment.id,
        threadId: threadId,
      );

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (context) => ThreadDetailScreen(postId: threadId),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Create Thread from Comment',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _createThread,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Create',
                    style: TextStyle(
                      color: Color(0xFF9248D2),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            // Original comment preview
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Original Comment',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.comment.text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            // Title field
            TextField(
              controller: _titleController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Thread Title',
                hintStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Content field
            TextField(
              controller: _contentController,
              style: const TextStyle(color: Colors.white),
              maxLines: 10,
              decoration: InputDecoration(
                hintText: 'Thread Content',
                hintStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Category dropdown
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: InputDecoration(
                hintText: 'Select Category',
                hintStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              dropdownColor: Colors.grey[850],
              style: const TextStyle(color: Colors.white),
              items: _categories.map((category) {
                return DropdownMenuItem(
                  value: category.id,
                  child: Text(category.name),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}
