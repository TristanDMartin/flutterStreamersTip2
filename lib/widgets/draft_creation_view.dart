import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/shared_draft.dart';
import '../models/user_model.dart' as user_model;
import '../services/draft_service.dart';
import '../services/logging_service.dart';
import 'friend_selection_view.dart';

class DraftCreationView extends StatefulWidget {
  final String? receiverId;
  final SharedDraft? existingDraft;

  const DraftCreationView({
    super.key,
    this.receiverId,
    this.existingDraft,
  });

  @override
  State<DraftCreationView> createState() => _DraftCreationViewState();
}

class _DraftCreationViewState extends State<DraftCreationView> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  final _receiverController = TextEditingController();
  final _draftService = DraftService();
  
  bool _isLoading = false;
  String? _thumbnailUrl;
  int _duration = 0;
  user_model.User? _selectedUser;

  @override
  void initState() {
    super.initState();
    if (widget.existingDraft != null) {
      _titleController.text = widget.existingDraft!.draftTitle;
      _messageController.text = widget.existingDraft!.message ?? '';
      _receiverController.text = widget.existingDraft!.receiverId;
      _thumbnailUrl = widget.existingDraft!.draftThumbnailUrl;
      _duration = widget.existingDraft!.draftDuration;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _receiverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close, color: Colors.white),
        ),
        title: Text(
          widget.existingDraft != null ? 'Edit Draft' : 'Create Draft',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9248D2)),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveDraft,
              child: Text(
                widget.existingDraft != null ? 'Update' : 'Create',
                style: const TextStyle(
                  color: Color(0xFF9248D2),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A1A2E),
              Color(0xFF16213E),
              Color(0xFF0F3460),
            ],
          ),
        ),
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title field
                  _buildSectionTitle('Draft Title'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _titleController,
                    hintText: 'Enter draft title',
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Title is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Friend selection field
                  _buildSectionTitle('Send To'),
                  const SizedBox(height: 8),
                  _buildFriendSelectionField(),
                  const SizedBox(height: 24),

                  // Message field
                  _buildSectionTitle('Message'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _messageController,
                    hintText: 'Enter your message',
                    maxLines: 4,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Message is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Thumbnail URL field
                  _buildSectionTitle('Thumbnail URL (Optional)'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: TextEditingController(text: _thumbnailUrl ?? ''),
                    hintText: 'Enter thumbnail URL',
                    onChanged: (value) => _thumbnailUrl = value,
                  ),
                  const SizedBox(height: 24),

                  // Duration field
                  _buildSectionTitle('Duration (seconds)'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: TextEditingController(text: _duration.toString()),
                    hintText: 'Enter duration in seconds',
                    keyboardType: TextInputType.number,
                    onChanged: (value) => _duration = int.tryParse(value) ?? 0,
                  ),
                  const SizedBox(height: 32),

                  // Preview section
                  if (_thumbnailUrl != null && _thumbnailUrl!.isNotEmpty) ...[
                    _buildSectionTitle('Preview'),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          _thumbnailUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[800],
                              child: const Center(
                                child: Icon(
                                  Icons.image_not_supported,
                                  color: Colors.grey,
                                  size: 48,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _saveDraft,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF9248D2),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            widget.existingDraft != null ? 'Update Draft' : 'Create Draft',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      if (widget.existingDraft != null)
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _deleteDraft,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Delete',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    String? Function(String?)? validator,
    int maxLines = 1,
    TextInputType? keyboardType,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.2),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.2),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFF9248D2),
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Colors.red,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Future<void> _saveDraft() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Check if a friend is selected
    if (_selectedUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a friend to share with'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      HapticFeedback.lightImpact();

      if (widget.existingDraft != null) {
        // Update existing draft
        final success = await _draftService.updateDraft(
          widget.existingDraft!.id,
          title: _titleController.text,
          message: _messageController.text,
          thumbnailUrl: _thumbnailUrl,
          duration: _duration,
        );

        if (success && mounted) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Draft updated successfully'),
              backgroundColor: Color(0xFF9248D2),
            ),
          );
        }
      } else {
        // Create new draft
        final draft = await _draftService.createDraft(
          title: _titleController.text,
          message: _messageController.text,
          receiverId: _selectedUser!.id,
          thumbnailUrl: _thumbnailUrl,
          duration: _duration,
        );

        if (draft != null && mounted) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Draft created successfully'),
              backgroundColor: Color(0xFF9248D2),
            ),
          );
        }
      }
    } catch (e) {
      LoggingService.instance.error('Error saving draft: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error saving draft'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildFriendSelectionField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _selectFriend,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.person_add,
                  color: Colors.white.withOpacity(0.6),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _selectedUser != null
                      ? Row(
                          children: [
                            // Selected user avatar
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: _selectedUser!.avatarURL != null 
                                    ? null
                                    : const LinearGradient(
                                        colors: [Color(0xFF9248D2), Color(0xFF7768DF)],
                                      ),
                              ),
                              child: _selectedUser!.avatarURL != null
                                  ? ClipOval(
                                      child: Image.network(
                                        _selectedUser!.avatarURL!,
                                        width: 32,
                                        height: 32,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Center(
                                            child: Text(
                                              _selectedUser!.displayName.isNotEmpty 
                                                  ? _selectedUser!.displayName[0].toUpperCase()
                                                  : 'U',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    )
                                  : Center(
                                      child: Text(
                                        _selectedUser!.displayName.isNotEmpty 
                                            ? _selectedUser!.displayName[0].toUpperCase()
                                            : 'U',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedUser!.displayName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '@${_selectedUser!.username}',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.6),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : Text(
                          'Select a friend to share with',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white.withOpacity(0.4),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _selectFriend() async {
    HapticFeedback.lightImpact();
    
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FriendSelectionView(
          onUserSelected: (user_model.User user) {
            setState(() {
              _selectedUser = user;
              _receiverController.text = user.id;
            });
          },
        ),
      ),
    );
  }

  Future<void> _deleteDraft() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Delete Draft',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to delete this draft? This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        final success = await _draftService.deleteDraft(widget.existingDraft!.id);
        if (success && mounted) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Draft deleted successfully'),
              backgroundColor: Color(0xFF9248D2),
            ),
          );
        }
      } catch (e) {
        LoggingService.instance.error('Error deleting draft: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error deleting draft'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }
}
