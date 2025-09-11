import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';

enum Privacy { everyone, friends, onlyMe }

class VideoDetailsFormView extends StatefulWidget {
  final String videoPath;
  final VoidCallback? onPost;
  final VoidCallback? onCancel;
  
  const VideoDetailsFormView({
    super.key,
    required this.videoPath,
    this.onPost,
    this.onCancel,
  });

  @override
  State<VideoDetailsFormView> createState() => _VideoDetailsFormViewState();
}

class _VideoDetailsFormViewState extends State<VideoDetailsFormView> {
  String _selectedCategory = "Gaming";
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  Privacy _privacy = Privacy.everyone;
  bool _isUploading = false;
  String? _uploadError;
  bool _showUploadError = false;

  final List<String> _categories = [
    "Gaming", "Art", "Music", "Tech", "Sports",
    "Food", "Just Chatting", "Tutorials",
    "Fitness", "Podcast", "Fashion", "RolePlaying"
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
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
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: widget.onCancel,
        ),
        title: const Text(
          "Post Details",
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: _canPost() ? _uploadVideo : null,
            child: Text(
              _isUploading ? "Posting..." : "Post",
              style: TextStyle(
                color: _canPost() ? Colors.red : Colors.grey,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Form Content
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category Section
                _buildSectionHeader("Category"),
                _buildCategoryPicker(),
                
                const SizedBox(height: 24),
                
                // Title & Description Section
                _buildSectionHeader("Title & Description"),
                _buildTitleField(),
                const SizedBox(height: 16),
                _buildDescriptionField(),
                
                const SizedBox(height: 24),
                
                // Privacy Section
                _buildSectionHeader("Who can view"),
                _buildPrivacyPicker(),
                
                const SizedBox(height: 40),
              ],
            ),
          ),
          
          // Upload Progress Overlay
          if (_isUploading)
            Container(
              color: Colors.black.withValues(alpha:0.4),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: Colors.pink,
                      strokeWidth: 3,
                    ),
                    SizedBox(height: 16),
                    Text(
                      "Uploading...",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildCategoryPicker() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha:0.3),
          width: 1,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCategory,
          dropdownColor: const Color(0xFF0B0C10),
          style: const TextStyle(color: Colors.white, fontSize: 16),
          items: _categories.map((category) {
            return DropdownMenuItem(
              value: category,
              child: Text(category),
            );
          }).toList(),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() {
                _selectedCategory = newValue;
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildTitleField() {
    return TextField(
      controller: _titleController,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        hintText: "Add a catchy title",
        hintStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: Colors.white.withValues(alpha:0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.white.withValues(alpha:0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.white.withValues(alpha:0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.pink),
        ),
      ),
    );
  }

  Widget _buildDescriptionField() {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha:0.3),
          width: 1,
        ),
      ),
      child: TextField(
        controller: _descriptionController,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        maxLines: null,
        expands: true,
        decoration: const InputDecoration(
          hintText: "Describe your video...",
          hintStyle: TextStyle(color: Colors.white54),
          contentPadding: EdgeInsets.all(16),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildPrivacyPicker() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha:0.3),
          width: 1,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Privacy>(
          value: _privacy,
          dropdownColor: const Color(0xFF0B0C10),
          style: const TextStyle(color: Colors.white, fontSize: 16),
          items: Privacy.values.map((privacy) {
            return DropdownMenuItem(
              value: privacy,
              child: Text(_getPrivacyDisplayName(privacy)),
            );
          }).toList(),
          onChanged: (Privacy? newValue) {
            if (newValue != null) {
              setState(() {
                _privacy = newValue;
              });
            }
          },
        ),
      ),
    );
  }

  String _getPrivacyDisplayName(Privacy privacy) {
    switch (privacy) {
      case Privacy.everyone:
        return "Everyone";
      case Privacy.friends:
        return "Friends";
      case Privacy.onlyMe:
        return "Only Me";
    }
  }

  bool _canPost() {
    return _titleController.text.isNotEmpty &&
           _descriptionController.text.isNotEmpty &&
           !_isUploading;
  }

  Future<void> _uploadVideo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showError("You must be signed in to post.");
      return;
    }

    setState(() {
      _isUploading = true;
      // _uploadError = null;
    });

    try {
      // Upload video to Firebase Storage
      final fileName = "${DateTime.now().millisecondsSinceEpoch}_${user.uid}.mp4";
      final storageRef = FirebaseStorage.instance
          .ref()
          .child("videos/${user.uid}/$fileName");

      final videoFile = File(widget.videoPath);
      final uploadTask = storageRef.putFile(videoFile);

      // Monitor upload progress
      uploadTask.snapshotEvents.listen((snapshot) {
        // final progress = snapshot.bytesTransferred / snapshot.totalBytes;
    // print('Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
      });

      // Wait for upload to complete
      await uploadTask;

      // Get download URL
      final downloadURL = await storageRef.getDownloadURL();

      // Prepare data for Firestore
      final data = {
        "uploaderId": user.uid,
        "videoURL": downloadURL.toString(),
        "title": _titleController.text,
        "description": _descriptionController.text,
        "category": _selectedCategory,
        "privacy": _privacy.name,
        "timestamp": FieldValue.serverTimestamp(),
        "likes": 0,
        "views": 0,
        "comments": 0,
      };

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection("videos")
          .add(data);

      // Success
      setState(() {
        _isUploading = false;
      });

      // Navigate back or show success
      widget.onPost?.call();
      
    } catch (e) {
    // print('Upload error: $e');
      setState(() {
        _isUploading = false;
        // _uploadError = "Upload failed: $e";
        // _showUploadError = true;
      });
    }
  }

  void _showError(String message) {
    setState(() {
      // _uploadError = message;
      // _showUploadError = true;
    });
  }

  @override
  void initState() {
    super.initState();
    // Show error dialog if there's an upload error
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_showUploadError && _uploadError != null) {
        _showErrorDialog();
      }
    });
  }

  void _showErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Upload Failed"),
        content: Text(_uploadError ?? "Unknown error"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                // _uploadError = null;
                _showUploadError = false;
              });
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }
}

// Alternative implementation with more features
class EnhancedVideoDetailsFormView extends StatefulWidget {
  final String videoPath;
  final VoidCallback? onPost;
  final VoidCallback? onCancel;
  
  const EnhancedVideoDetailsFormView({
    super.key,
    required this.videoPath,
    this.onPost,
    this.onCancel,
  });

  @override
  State<EnhancedVideoDetailsFormView> createState() => _EnhancedVideoDetailsFormViewState();
}

class _EnhancedVideoDetailsFormViewState extends State<EnhancedVideoDetailsFormView> {
  String _selectedCategory = "Gaming";
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  Privacy _privacy = Privacy.everyone;
  bool _isUploading = false;
  // String? _uploadError;
  // bool _showUploadError = false;
  final List<String> _tags = [];
  final TextEditingController _tagController = TextEditingController();

  final List<String> _categories = [
    "Gaming", "Art", "Music", "Tech", "Sports",
    "Food", "Just Chatting", "Tutorials",
    "Fitness", "Podcast", "Fashion", "RolePlaying"
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagController.dispose();
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
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: widget.onCancel,
        ),
        title: const Text(
          "Post Details",
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: _canPost() ? _uploadVideo : null,
            child: Text(
              _isUploading ? "Posting..." : "Post",
              style: TextStyle(
                color: _canPost() ? Colors.red : Colors.grey,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader("Category"),
                _buildCategoryPicker(),
                
                const SizedBox(height: 24),
                
                _buildSectionHeader("Title & Description"),
                _buildTitleField(),
                const SizedBox(height: 16),
                _buildDescriptionField(),
                
                const SizedBox(height: 24),
                
                _buildSectionHeader("Tags"),
                _buildTagsSection(),
                
                const SizedBox(height: 24),
                
                _buildSectionHeader("Privacy"),
                _buildPrivacyPicker(),
                
                const SizedBox(height: 40),
              ],
            ),
          ),
          
          if (_isUploading)
            Container(
              color: Colors.black.withValues(alpha:0.4),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.pink),
                    SizedBox(height: 16),
                    Text(
                      "Uploading...",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildCategoryPicker() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha:0.3),
          width: 1,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCategory,
          dropdownColor: const Color(0xFF0B0C10),
          style: const TextStyle(color: Colors.white, fontSize: 16),
          items: _categories.map((category) {
            return DropdownMenuItem(
              value: category,
              child: Text(category),
            );
          }).toList(),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() {
                _selectedCategory = newValue;
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildTitleField() {
    return TextField(
      controller: _titleController,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        hintText: "Add a catchy title",
        hintStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: Colors.white.withValues(alpha:0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.white.withValues(alpha:0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.white.withValues(alpha:0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.pink),
        ),
      ),
    );
  }

  Widget _buildDescriptionField() {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha:0.3),
          width: 1,
        ),
      ),
      child: TextField(
        controller: _descriptionController,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        maxLines: null,
        expands: true,
        decoration: const InputDecoration(
          hintText: "Describe your video...",
          hintStyle: TextStyle(color: Colors.white54),
          contentPadding: EdgeInsets.all(16),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildTagsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tags display
        if (_tags.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _tags.map((tag) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.pink.withValues(alpha:0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.pink),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tag,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _removeTag(tag),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        
        const SizedBox(height: 12),
        
        // Add tag input
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _tagController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Add a tag...",
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha:0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha:0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha:0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.pink),
                  ),
                ),
                onSubmitted: (value) {
                  if (value.isNotEmpty) {
                    _addTag(value);
                    _tagController.clear();
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () {
                if (_tagController.text.isNotEmpty) {
                  _addTag(_tagController.text);
                  _tagController.clear();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text("Add"),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPrivacyPicker() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha:0.3),
          width: 1,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Privacy>(
          value: _privacy,
          dropdownColor: const Color(0xFF0B0C10),
          style: const TextStyle(color: Colors.white, fontSize: 16),
          items: Privacy.values.map((privacy) {
            return DropdownMenuItem(
              value: privacy,
              child: Text(_getPrivacyDisplayName(privacy)),
            );
          }).toList(),
          onChanged: (Privacy? newValue) {
            if (newValue != null) {
              setState(() {
                _privacy = newValue;
              });
            }
          },
        ),
      ),
    );
  }

  void _addTag(String tag) {
    if (!_tags.contains(tag) && _tags.length < 10) {
      setState(() {
        _tags.add(tag);
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  String _getPrivacyDisplayName(Privacy privacy) {
    switch (privacy) {
      case Privacy.everyone:
        return "Everyone";
      case Privacy.friends:
        return "Friends";
      case Privacy.onlyMe:
        return "Only Me";
    }
  }

  bool _canPost() {
    return _titleController.text.isNotEmpty &&
           _descriptionController.text.isNotEmpty &&
           !_isUploading;
  }

  Future<void> _uploadVideo() async {
    // Implementation similar to the basic version
    // but with additional tag handling
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showError("You must be signed in to post.");
      return;
    }

    setState(() {
      _isUploading = true;
      // _uploadError = null;
    });

    try {
      // Upload logic here...
      await Future.delayed(const Duration(seconds: 2)); // Simulate upload
      
      setState(() {
        _isUploading = false;
      });

      widget.onPost?.call();
      
    } catch (e) {
      setState(() {
        _isUploading = false;
        // _uploadError = "Upload failed: $e";
        // _showUploadError = true;
      });
    }
  }

  void _showError(String message) {
    setState(() {
      // _uploadError = message;
      // _showUploadError = true;
    });
  }
}
