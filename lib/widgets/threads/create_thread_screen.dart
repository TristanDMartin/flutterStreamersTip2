import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/forum_service.dart';
import '../../utils/user_facing_error.dart';
import '../../models/forum_author.dart';
import '../../models/forum_category.dart';
import '../../constants/app_colors.dart';
import '../../core/theme/support_shell_style.dart';
import '../../features/threads/thread_visibility.dart';
import 'thread_visibility_picker.dart';

/// Screen for creating a new thread
class CreateThreadScreen extends StatefulWidget {
  const CreateThreadScreen({
    super.key,
    this.attachedVideoId,
    this.initialTitle,
    this.initialContent,
  });

  final String? attachedVideoId;
  final String? initialTitle;
  final String? initialContent;

  @override
  State<CreateThreadScreen> createState() => _CreateThreadScreenState();
}

class _CreateThreadScreenState extends State<CreateThreadScreen> {
  final ForumService _forumService = ForumService();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  String? _selectedCategory;
  List<ForumCategory> _categories = [];
  String _visibility = kThreadVisibilityPublic;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.initialTitle ?? '';
    _contentController.text = widget.initialContent ?? '';
    _loadCategories();
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
        throw 'You must be signed in to create a thread.';
      }

      // Verify email is verified
      await user.reload();
      final refreshedUser = firebase_auth.FirebaseAuth.instance.currentUser;
      if (refreshedUser != null && !refreshedUser.emailVerified) {
        throw 'Please verify your email before creating threads. Check your inbox for a verification link.';
      }

      // Ensure user has required profile fields
      final displayName = user.displayName?.trim() ?? '';
      final username = user.displayName?.trim().toLowerCase().replaceAll(' ', '_') ?? 'user_${user.uid.substring(0, 8)}';
      
      if (displayName.isEmpty) {
        throw 'Please complete your profile setup before creating threads. Go to Profile > Edit Profile to set your display name.';
      }

      final author = ForumAuthor(
        uid: user.uid,
        username: username,
        displayName: displayName,
        avatarUrl: user.photoURL,
      );

      debugPrint('📝 Creating thread: title="$title", category=$_selectedCategory, author=${author.uid}');

      await _forumService.createPost(
        title: title,
        content: content,
        categoryId: _selectedCategory!,
        tags: widget.attachedVideoId == null
            ? <String>[]
            : <String>['video-discussion'],
        author: author,
        visibility: _visibility,
        linkedVideoId: widget.attachedVideoId,
      );

      debugPrint('✅ Thread created successfully');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thread created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } on firebase_auth.FirebaseAuthException catch (e) {
      debugPrint('❌ Auth error creating thread: ${e.code} - ${e.message}');
      setState(() {
        _errorMessage = switch (e.code) {
          'requires-recent-login' => 'Please sign in again to create threads.',
          'user-disabled' => 'Your account has been disabled.',
          'user-not-found' => 'Your account was not found. Please sign in again.',
          _ => 'Authentication error: ${e.message ?? e.code}',
        };
        _isLoading = false;
      });
    } on FirebaseException catch (e) {
      debugPrint('❌ Firestore error creating thread: ${e.code} - ${e.message}');
      setState(() {
        _errorMessage = switch (e.code) {
          'permission-denied' => 'You don\'t have permission to create threads. Please complete your account setup or verify your email.',
          'unavailable' => 'Server is temporarily unavailable. Please try again in a moment.',
          'deadline-exceeded' => 'Request timed out. Check your connection and try again.',
          _ => 'Error creating thread: ${e.message ?? e.code}',
        };
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Unexpected error creating thread: $e');
      setState(() {
        _errorMessage = e is String ? e : UserFacingError.message(e);
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Scaffold(
      backgroundColor: shell.scaffold,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create Thread',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Start a conversation worth jumping into.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _isLoading ? null : _createThread,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Post',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.10),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'Threads',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Share a strong title, give people context, and pick the best category so the right crowd finds it.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.74),
                              fontSize: 14,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.28),
                          ),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    _buildInputCard(
                      label: 'Title',
                      helper: 'Keep it clear and easy to scan.',
                      child: TextField(
                        controller: _titleController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _buildInputDecoration('Thread title'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildInputCard(
                      label: 'Conversation',
                      helper: 'Add the context people need to reply well.',
                      child: TextField(
                        controller: _contentController,
                        style: const TextStyle(color: Colors.white),
                        maxLines: 10,
                        decoration: _buildInputDecoration(
                            'What do you want to talk about?'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildInputCard(
                      label: 'Category',
                      helper:
                          'This helps your thread reach the right audience.',
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedCategory,
                        decoration: _buildInputDecoration('Select category'),
                        dropdownColor: shell.panelSurface,
                        style: TextStyle(color: shell.onChrome),
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
                    ),
                    const SizedBox(height: 16),
                    ThreadVisibilityPicker(
                      value: _visibility,
                      enabled: !_isLoading,
                      onChanged: (String next) {
                        setState(() => _visibility = next);
                      },
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

  Widget _buildInputCard({
    required String label,
    required String helper,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            helper,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hintText) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        color: Colors.white.withValues(alpha: 0.55),
      ),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.06),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: Colors.white.withValues(alpha: 0.10),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: Colors.white.withValues(alpha: 0.10),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: AppColors.primary.withValues(alpha: 0.7),
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
    );
  }
}
