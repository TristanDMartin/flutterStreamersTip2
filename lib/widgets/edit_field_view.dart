import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/rate_limiting_service.dart';
import '../services/hashtag_lock_service.dart';
import '../widgets/content_validation_field.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EditFieldView extends ConsumerStatefulWidget {
  final String title;
  final String text;
  final Function(String) onTextChanged;
  final String? helperText;
  final int maxLength;
  final VoidCallback? onSave;
  final VoidCallback? onCancel;
  
  const EditFieldView({
    super.key,
    required this.title,
    required this.text,
    required this.onTextChanged,
    this.helperText,
    required this.maxLength,
    this.onSave,
    this.onCancel,
  });

  @override
  ConsumerState<EditFieldView> createState() => _EditFieldViewState();
}

class _EditFieldViewState extends ConsumerState<EditFieldView> {
  late TextEditingController _textController;
  late TextEditingController _hashtagController;
  late List<String> _selectedHashtags;
  
  static const int maxHashtags = 4;
  bool _isContentValid = true;
  bool _isRateLimited = false;
  String _currentText = '';

  bool get _isValid {
    if (widget.title == "Hashtags") {
      return _selectedHashtags.isNotEmpty && 
             _selectedHashtags.length <= maxHashtags &&
             _selectedHashtags.every((hashtag) => 
               RegExp(r'^[A-Za-z0-9_]{1,20}$').hasMatch(hashtag));
    } else {
      final trimmedText = _currentText.trim();
      final isValid = trimmedText.isNotEmpty && 
             _currentText.length <= widget.maxLength &&
             _isContentValid &&
             !_isRateLimited;
      
    // print('🔍 EditFieldView: _isValid check - text: "$_currentText", length: ${_currentText.length}/${widget.maxLength}, contentValid: $_isContentValid, rateLimited: $_isRateLimited, result: $isValid');
      
      return isValid;
    }
  }

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.text);
    _hashtagController = TextEditingController();
    _currentText = widget.text;
    
    if (widget.title == "Hashtags") {
      final initial = widget.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      _selectedHashtags = initial;
    } else {
      _selectedHashtags = [];
    }
    
    // Check rate limiting on init
    _checkRateLimit();
  }

  @override
  void dispose() {
    _textController.dispose();
    _hashtagController.dispose();
    super.dispose();
  }

  void _addHashtag(String hashtag) async {
    final cleaned = hashtag.trim().replaceAll('#', '');
    if (cleaned.isEmpty || 
        _selectedHashtags.contains(cleaned) || 
        _selectedHashtags.length >= maxHashtags ||
        !RegExp(r'^[A-Za-z0-9_]{1,20}$').hasMatch(cleaned)) {
      return;
    }

    // Check if hashtag is reserved and user is authorized
    final currentUser = FirebaseAuth.instance.currentUser;
    final hashtagService = HashtagLockService();
    final validation = await hashtagService.validateHashtag(cleaned, currentUser?.uid);
    
    if (!validation.isValid) {
      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(validation.errorMessage ?? 'Invalid hashtag'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    setState(() {
      _selectedHashtags.add(cleaned);
      _hashtagController.clear();
    });
  }

  void _removeHashtag(String hashtag) {
    setState(() {
      _selectedHashtags.remove(hashtag);
    });
  }

  Future<void> _checkRateLimit() async {
    final isLimited = await RateLimitingService().isRateLimited();
    if (mounted) {
      setState(() {
        _isRateLimited = isLimited;
      });
    }
  }

  void _handleSave() async {
    // print('🔍 EditFieldView: Save attempted for ${widget.title}');
    // print('🔍 EditFieldView: _isContentValid: $_isContentValid, _isRateLimited: $_isRateLimited');
    
    if (widget.title == "Hashtags") {
      final hashtagText = _selectedHashtags.join(', ');
      widget.onTextChanged(hashtagText);
    } else {
      // For name and bio, validate content before saving
      if (!_isContentValid) {
    // print('🚫 EditFieldView: Content is invalid, blocking save');
        _showContentError();
        return;
      }
      
      if (_isRateLimited) {
    // print('🚫 EditFieldView: User is rate limited, blocking save');
        _showRateLimitError();
        return;
      }
      
    // print('✅ EditFieldView: Content is valid, proceeding with save');
      widget.onTextChanged(_currentText);
    }
    
    if (widget.onSave != null) {
      widget.onSave!();
    }
  }

  void _showContentError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Content violates community guidelines. Please review and edit.'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showRateLimitError() async {
    final remainingTime = await RateLimitingService().getRemainingCooldown();
    final minutes = remainingTime?.inMinutes ?? 0;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Too many violations. Please wait $minutes minutes before trying again.'),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6137EB), Color(0xFF1C135D)],
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            foregroundColor: Colors.white,
        title: Text(
          widget.title,
          style: const TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        leading: IconButton(
          onPressed: widget.onCancel,
          icon: const Text(
            'Cancel',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        actions: [
          IconButton(
            onPressed: _isValid ? _handleSave : null,
            icon: Text(
              'Save',
              style: TextStyle(
                color: _isValid ? Colors.white : Colors.grey,
                fontSize: 16,
              ),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (widget.title == "Hashtags") ...[
              // Hashtag input section
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _hashtagController,
                            decoration: InputDecoration(
                              hintText: 'Add hashtag',
                              hintStyle: const TextStyle(color: Colors.grey),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              enabled: _selectedHashtags.length < maxHashtags,
                            ),
                            style: const TextStyle(color: Colors.white),
                            textCapitalization: TextCapitalization.none,
                            autocorrect: false,
                            onSubmitted: (value) => _addHashtag(value),
                          ),
                        ),
                        if (_hashtagController.text.isNotEmpty)
                          IconButton(
                            onPressed: () => _hashtagController.clear(),
                            icon: const Icon(
                              Icons.cancel,
                              color: Colors.grey,
                              size: 17,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Hashtag chips
                    if (_selectedHashtags.isNotEmpty)
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 3,
                        ),
                        itemCount: _selectedHashtags.length,
                        itemBuilder: (context, index) {
                          final hashtag = _selectedHashtags[index];
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha:0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '#$hashtag',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => _removeHashtag(hashtag),
                                  child: const Icon(
                                    Icons.cancel,
                                    color: Colors.red,
                                    size: 17,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    
                    const SizedBox(height: 12),
                    Text(
                      '${_selectedHashtags.length}/$maxHashtags',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Regular text input section with content moderation
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Use ContentValidationField for name and bio
                    if (widget.title == "Name" || widget.title == "Bio") ...[
                      ContentValidationField(
                        initialValue: _currentText,
                        hintText: widget.title,
                        maxLines: widget.title == "Bio" ? 6 : 1,
                        maxLength: widget.maxLength,
                        onChanged: (value) {
    // print('🔍 EditFieldView: Text changed to "$value"');
                          setState(() {
                            _currentText = value;
                          });
                          widget.onTextChanged(value);
                        },
                        onValidationChanged: (isValid) {
    // print('🔍 EditFieldView: Validation changed to $isValid');
                          setState(() {
                            _isContentValid = isValid;
                          });
    // print('🔍 EditFieldView: _isValid getter now returns: $_isValid');
                        },
                      ),
                    ] else ...[
                      // Regular TextField for other fields
                      TextField(
                        controller: _textController,
                        decoration: InputDecoration(
                          hintText: widget.title,
                          hintStyle: const TextStyle(color: Colors.grey),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        style: const TextStyle(color: Colors.white),
                        maxLines: 6,
                        minLines: 3,
                        onChanged: (value) {
                          setState(() {
                            _currentText = value;
                          });
                          widget.onTextChanged(value);
                        },
                      ),
                    ],
                    if (widget.helperText != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        widget.helperText!,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          '${_currentText.length}/${widget.maxLength}',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        if (_isRateLimited) ...[
                          const Icon(
                            Icons.timer,
                            color: Colors.orange,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Rate Limited',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
            const Spacer(),
          ],
        ),
      ),
    ),
    ),
    );
  }
}
