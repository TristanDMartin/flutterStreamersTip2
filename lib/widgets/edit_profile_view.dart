import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'edit_field_view.dart';
import 'links_edit_view.dart';
import 'image_picker_widget.dart';
import 'status_button.dart';
import '../services/auth_service.dart';
import '../services/profile_update_service.dart';
import '../services/content_moderation_service.dart';
import '../services/storage_diagnostic_service.dart';
import '../models/user_status.dart';
import '../providers/status_provider.dart';

class EditProfileView extends StatefulWidget {
  final Map<String, dynamic> user;
  final Function(Map<String, dynamic>) onUserUpdated;
  final VoidCallback? onBack;

  const EditProfileView({
    super.key,
    required this.user,
    required this.onUserUpdated,
    this.onBack,
  });

  @override
  State<EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends State<EditProfileView> {
  late Map<String, dynamic> _user;
  bool _isUploadingAvatar = false;
  File? _selectedImage;
  String? _uploadError;
  DateTime? _lastNameChangeDate;
  bool _canChangeName = true;
  ProfileUpdateService? _profileUpdateService;

  // Gradient colors matching your design system
  static const List<Color> _gradientColors = [
    Color(0xFF9248D2), // Purple
    Color(0xFF7768DF), // Another purple
    Color(0xFF1670DE), // Blue
    Color(0xFF3C8BD6), // Lighter blue
    Color(0xFF4897D2), // Lightest blue
  ];

  @override
  void initState() {
    super.initState();
    _user = Map.from(widget.user);
    _profileUpdateService = ProfileUpdateService();
    _checkNameChangeEligibility();
  }

  /// Check if user can change their name (7-day cooldown) // cspell:ignore cooldown
  void _checkNameChangeEligibility() {
    final lastChange = _user['lastNameChangeDate'];
    if (lastChange != null) {
      _lastNameChangeDate = DateTime.tryParse(lastChange.toString());
      if (_lastNameChangeDate != null) {
        final daysSinceLastChange =
            DateTime.now().difference(_lastNameChangeDate!).inDays;
        _canChangeName = daysSinceLastChange >= 7;

        // Debug logging removed for production
      }
    }
  }

  void _updateUser(String key, dynamic value) async {
    // Content moderation validation
    ModerationResult? moderationResult;

    if (key == 'displayName') {
      moderationResult =
          ContentModerationService.validateDisplayName(value.toString());
    } else if (key == 'bio') {
      moderationResult = ContentModerationService.validateBio(value.toString());
    } else if (key == 'hashtags') {
      final hashtagsString = value.toString().trim();
      if (hashtagsString.isNotEmpty) {
        final hashtags = hashtagsString
            .split(',')
            .map((tag) => tag.trim().replaceFirst('#', ''))
            .where((tag) => tag.isNotEmpty)
            .toList();
        moderationResult = ContentModerationService.validateHashtags(hashtags);
      }
    }

    // Check if content moderation failed
    if (moderationResult != null && !moderationResult.isAllowed) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(moderationResult.reason ??
                'Content contains inappropriate language'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return; // Don't update if content is inappropriate
    }

    setState(() {
      // Handle hashtags conversion from string to List
      if (key == 'hashtags') {
        final hashtagsString = value.toString().trim();
        if (hashtagsString.isEmpty) {
          _user[key] = [];
        } else {
          // Split by comma, trim whitespace, remove empty strings, and remove # prefix
          final hashtags = hashtagsString
              .split(',')
              .map((tag) => tag.trim().replaceFirst('#', ''))
              .where((tag) => tag.isNotEmpty)
              .toList();
          _user[key] = hashtags;
        }
      } else {
        _user[key] = value;
      }

      // If display name is updated, also update the username to match
      if (key == 'displayName') {
        // Convert display name to username format (lowercase, no spaces, special chars)
        final username = _generateUsernameFromDisplayName(value.toString());
        _user['username'] = username;

        // Record the name change date
        _user['lastNameChangeDate'] = DateTime.now().toIso8601String();
        _lastNameChangeDate = DateTime.now();
        _canChangeName = false;

        // Username and date updated successfully
      }
    });

    // Update local callback
    widget.onUserUpdated(_user);

    // Prepare update data for ProfileUpdateService
    Map<String, dynamic> updateData;
    if (key == 'displayName') {
      updateData = {
        'displayName': value,
        'username': _user['username'],
        'lastNameChangeDate': _user['lastNameChangeDate'],
      };
    } else if (key == 'hashtags') {
      updateData = {key: _user[key]}; // Use the processed hashtags List
    } else {
      updateData = {key: value};
    }

    // Update all profile views through ProfileUpdateService
    try {
      await _profileUpdateService?.updateUserData(updateData);
    } catch (e) {
      // Error updating profile views, using fallback
      if (kDebugMode) {
        // print('ProfileUpdateService error: $e');
      }
      // Fallback to direct Firestore update
      _saveToFirestore(updateData);
    }
  }

  /// Generate a username from display name
  String _generateUsernameFromDisplayName(String displayName) {
    if (displayName.isEmpty) return '';

    // Convert to lowercase and replace spaces with underscores
    String username = displayName.toLowerCase();

    // Remove special characters except underscores and keep only alphanumeric and underscores
    username = username.replaceAll(RegExp(r'[^a-z0-9_]'), '');

    // Remove multiple consecutive underscores
    username = username.replaceAll(RegExp(r'_+'), '_');

    // Remove leading/trailing underscores
    username = username.replaceAll(RegExp(r'^_+|_+$'), '');

    // Ensure it's not empty and add a number if needed to make it unique
    if (username.isEmpty) {
      username = 'user';
    }

    // Limit length to 20 characters (common username limit)
    if (username.length > 20) {
      username = username.substring(0, 20);
    }

    return username;
  }

  Future<void> _saveToFirestore(Map<String, dynamic> data) async {
    try {
      final authService =
          ProviderScope.containerOf(context).read(authServiceProvider);
      await authService.updateUserProfile(data);
    } catch (e) {
      // Error saving to Firestore - silent fail to avoid user spam
      if (kDebugMode) {
        // print('Firestore save error: $e');
      }
    }
  }

  void _showImagePicker() {
    debugPrint('🖼️ EditProfileView: Opening image picker modal');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ImagePickerWidget(
        onImageSelected: _handleImageSelected,
        onCancel: () {
          debugPrint('❌ EditProfileView: Image picker cancelled');
          Navigator.pop(context);
        },
      ),
    );
  }

  void _handleImageSelected(File imageFile) {
    debugPrint('📸 EditProfileView: Image selected: ${imageFile.path}');
    setState(() {
      _selectedImage = imageFile;
      _uploadError = null;
    });
    Navigator.pop(context); // Close the image picker
    _uploadAvatar(imageFile);
  }

  Future<void> _uploadAvatar(File imageFile) async {
    debugPrint('🔄 EditProfileView: Starting avatar upload process');

    setState(() {
      _isUploadingAvatar = true;
      _uploadError = null;
    });

    try {
      // Validate file before upload
      if (!await imageFile.exists()) {
        throw Exception('Selected image file does not exist');
      }

      final fileSize = await imageFile.length();
      debugPrint('📁 EditProfileView: File size: $fileSize bytes');

      if (!mounted) return;
      final authService =
          ProviderScope.containerOf(context).read(authServiceProvider);
      debugPrint(
          '🔐 EditProfileView: AuthService obtained, starting upload...');

      final downloadUrl = await authService.uploadAvatar(imageFile);
      debugPrint('✅ EditProfileView: Upload completed, URL: $downloadUrl');

      setState(() {
        _user['avatarURL'] = downloadUrl;
        _selectedImage = null;
        _isUploadingAvatar = false;
      });

      // Update local callback
      widget.onUserUpdated(_user);
      debugPrint('📱 EditProfileView: Local user data updated');

      // Update all profile views through ProfileUpdateService
      try {
        final profileUpdateService = ProfileUpdateService();
        await profileUpdateService.updateUserData({'avatarURL': downloadUrl});
        debugPrint('✅ EditProfileView: Avatar updated in all profile views');
      } catch (e) {
        debugPrint(
            '❌ EditProfileView: Error updating avatar in profile views: $e');
        // Don't show error to user for this secondary update
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Avatar updated successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        debugPrint('🎉 EditProfileView: Success message shown to user');
      }
    } catch (e) {
      debugPrint('❌ EditProfileView: Avatar upload failed: $e');

      setState(() {
        _isUploadingAvatar = false;
        _uploadError = e.toString();
      });

      if (mounted) {
        String errorMessage = 'Failed to upload avatar';

        // Extract user-friendly error message
        if (e.toString().contains('Storage access denied')) {
          errorMessage =
              'Storage access denied. Please check your permissions.';
        } else if (e.toString().contains('Network error')) {
          errorMessage =
              'Network error. Please check your internet connection.';
        } else if (e.toString().contains('too large')) {
          errorMessage =
              'Image file is too large. Please choose a smaller image.';
        } else if (e.toString().contains('does not exist')) {
          errorMessage = 'Selected image file not found. Please try again.';
        } else if (e.toString().contains('User not authenticated')) {
          errorMessage = 'Please sign in again to upload your avatar.';
        } else {
          errorMessage = e.toString().replaceAll('Exception: ', '');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Diagnose',
              textColor: Colors.white,
              onPressed: () {
                _runStorageDiagnostics();
              },
            ),
          ),
        );
      }
    }
  }

  Future<void> _runStorageDiagnostics() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Running Firebase Storage diagnostics...'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 2),
        ),
      );

      final results = await StorageDiagnosticService.runDiagnostics();
      final recommendations =
          StorageDiagnosticService.getRecommendations(results);

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Firebase Storage Diagnostics'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Status: ${results['overall_status']}'),
                  const SizedBox(height: 8),
                  Text('Storage Instance: ${results['storage_instance']}'),
                  Text('Storage Bucket: ${results['storage_bucket']}'),
                  Text('User Authenticated: ${results['user_authenticated']}'),
                  Text('Storage Access: ${results['storage_access']}'),
                  Text('Storage Write: ${results['storage_write']}'),
                  const SizedBox(height: 16),
                  const Text('Recommendations:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(recommendations),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Diagnostics failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showEditField(EditableField field) {
    // Check if user can change their name
    if (field == EditableField.name && !_canChangeName) {
      _showNameChangeCooldownDialog(); // cspell:ignore cooldown
      return;
    }

    final currentValue = _getFieldValue(field);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditFieldView(
          title: field.title,
          text: currentValue,
          onTextChanged: (value) {
            _updateUser(field.key, value);
          },
          helperText: field.helperText,
          maxLength: field.maxLength,
          onSave: () => Navigator.pop(context),
          onCancel: () => Navigator.pop(context),
        ),
      ),
    );
  }

  /// Show dialog explaining name change cooldown // cspell:ignore cooldown
  void _showNameChangeCooldownDialog() {
    if (_lastNameChangeDate == null) return;

    final daysRemaining =
        7 - DateTime.now().difference(_lastNameChangeDate!).inDays;
    final nextChangeDate = _lastNameChangeDate!.add(const Duration(days: 7));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Name Change Cooldown'), // cspell:ignore cooldown
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'You can only change your display name once every 7 days.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Text(
              'Last changed: ${_formatDate(_lastNameChangeDate!)}',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              'Next change available: ${_formatDate(nextChangeDate)}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            if (daysRemaining > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Days remaining: $daysRemaining',
                style: const TextStyle(fontSize: 14, color: Colors.orange),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Format date for display
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _getFieldValue(EditableField field) {
    switch (field) {
      case EditableField.name:
        return _user['displayName'] ?? '';
      case EditableField.bio:
        return _user['bio'] ?? '';
      case EditableField.hashtags:
        final hashtags = _user['hashtags'] as List<dynamic>? ?? [];
        return hashtags.join(', ');
    }
  }

  void _showStatusPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          final statusAsync = ref.watch(statusNotifierProvider);
          final updateStatus = ref.read(updateStatusProvider);

          return statusAsync.when(
            data: (presence) => StatusPickerModal(
              currentStatus: presence.status,
              onStatusSelected: (status) async {
                final navigator = Navigator.of(context);
                await updateStatus(status);

                // Update ProfileUpdateService to notify all views
                try {
                  await _profileUpdateService
                      ?.updateUserData({'status': status.name});
                  // Status updated successfully
                } catch (e) {
                  // Error updating status, using fallback
                  if (kDebugMode) {
                    // print('Status update error: $e');
                  }
                }

                if (mounted) {
                  navigator.pop();
                }
              },
            ),
            loading: () => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
            error: (error, stack) => const Center(
              child: Text(
                'Error loading status',
                style: TextStyle(color: Colors.white),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showLinksEditor() {
    final currentPlatforms = List<Map<String, dynamic>>.from(
      _user['platforms'] ?? [],
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LinksEditView(
          platforms: currentPlatforms,
          onPlatformsUpdated: (updatedPlatforms) async {
            // Capture context and scaffold messenger before async operations
            final scaffoldMessenger = ScaffoldMessenger.of(context);

            // Content moderation validation for platforms
            final moderationResult =
                ContentModerationService.validatePlatforms(updatedPlatforms);

            if (!moderationResult.isAllowed) {
              if (mounted) {
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text(moderationResult.reason ??
                        'Platform contains inappropriate content'),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 4),
                  ),
                );
              }
              return; // Don't update if content is inappropriate
            }

            // Update local state
            setState(() {
              _user['platforms'] = updatedPlatforms;
            });

            // Update local callback
            widget.onUserUpdated(_user);

            // Update all profile views through ProfileUpdateService
            try {
              final profileUpdateService = ProfileUpdateService();
              await profileUpdateService
                  .updateUserData({'platforms': updatedPlatforms});
              debugPrint(
                  '✅ EditProfileView: Platforms updated in all profile views');
            } catch (e) {
              debugPrint(
                  '❌ EditProfileView: Error updating platforms in profile views: $e');
            }

            // Show success message
            if (mounted) {
              scaffoldMessenger.showSnackBar(
                const SnackBar(
                  content: Text('Platforms updated successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          },
        ),
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
            colors: _gradientColors,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom AppBar
              _buildAppBar(),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildAvatarSection(),
                      _buildAboutYouSection(),
                      _buildPreferencesSection(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: widget.onBack ?? () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back,
              color: Colors.white,
              size: 24,
            ),
          ),
          const Expanded(
            child: Text(
              'Edit profile',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 48), // Balance the back button
        ],
      ),
    );
  }

  Widget _buildAvatarSection() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: GestureDetector(
        onTap: _isUploadingAvatar
            ? null
            : () {
                debugPrint('👆 EditProfileView: Avatar button tapped');
                _showImagePicker();
              },
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2C2C2E),
                    shape: BoxShape.circle,
                  ),
                  child: _buildAvatarContent(),
                ),
                if (!_isUploadingAvatar)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: Color(0xFF9248D2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _buildAvatarText(),
            if (_uploadError != null) ...[
              const SizedBox(height: 8),
              Text(
                'Upload failed. Tap to try again.',
                style: TextStyle(
                  color: Colors.red[300],
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarContent() {
    // Show loading spinner during upload
    if (_isUploadingAvatar) {
      return const Center(
        child: CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 3,
        ),
      );
    }

    // Show selected image preview
    if (_selectedImage != null) {
      return ClipOval(
        child: Image.file(
          _selectedImage!,
          width: 120,
          height: 120,
          fit: BoxFit.cover,
        ),
      );
    }

    // Show current avatar from URL
    if (_user['avatarURL'] != null &&
        _user['avatarURL'].toString().isNotEmpty) {
      return ClipOval(
        child: Image.network(
          _user['avatarURL'],
          width: 120,
          height: 120,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => const Icon(
            Icons.person,
            size: 40,
            color: Colors.grey,
          ),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            );
          },
        ),
      );
    }

    // Show default person icon
    return const Icon(
      Icons.person,
      size: 40,
      color: Colors.grey,
    );
  }

  Widget _buildAvatarText() {
    if (_isUploadingAvatar) {
      return const Text(
        'Uploading...',
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      );
    }

    if (_uploadError != null) {
      return const Text(
        'Upload failed',
        style: TextStyle(
          color: Colors.red,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      );
    }

    return const Text(
      'Edit photo or avatar',
      style: TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildAboutYouSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: const Text(
              'About',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // Fields Container
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                _buildEditProfileRow(
                    EditableField.name, _user['displayName'] ?? ''),
                _buildDivider(),
                _buildUsernameRow(),
                _buildDivider(),
                _buildEditProfileRow(EditableField.bio, _user['bio'] ?? ''),
                _buildDivider(),
                _buildPlatformsRow(),
                _buildDivider(),
                _buildHashtagsRow(),
                _buildDivider(),
                _buildFavoritesVisibilityRow(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditProfileRow(EditableField field, String value) {
    final isNameField = field == EditableField.name;
    final isLocked = isNameField && !_canChangeName;

    return GestureDetector(
      onTap: () => _showEditField(field),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isLocked
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.white.withValues(alpha: 0.1),
        ),
        child: Row(
          children: [
            Text(
              field.title,
              style: TextStyle(
                color: isLocked ? Colors.grey : Colors.white,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            if (value.isNotEmpty)
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    color: isLocked ? Colors.grey : Colors.grey,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (isLocked) ...[
              const Icon(
                Icons.lock,
                color: Colors.grey,
                size: 16,
              ),
              const SizedBox(width: 8),
            ],
            Icon(
              isLocked ? Icons.info_outline : Icons.chevron_right,
              color: Colors.grey,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsernameRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
      ),
      child: Row(
        children: [
          const Text(
            'Username',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
          const Spacer(),
          Text(
            '@${_user['username'] ?? ''}',
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.lock,
            color: Colors.grey,
            size: 16,
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformsRow() {
    final platforms = _user['platforms'] as List<dynamic>? ?? [];
    final platformCount = platforms.length;

    return GestureDetector(
      onTap: _showLinksEditor,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
        ),
        child: Row(
          children: [
            const Text(
              'Platforms',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            if (platformCount > 0)
              Text(
                '$platformCount platform${platformCount == 1 ? '' : 's'}',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
              ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right,
              color: Colors.grey,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHashtagsRow() {
    final hashtagsData = _user['hashtags'];
    List<dynamic> hashtags = [];

    // Handle both List and String cases
    if (hashtagsData is List) {
      hashtags = hashtagsData;
    } else if (hashtagsData is String) {
      hashtags = hashtagsData.split(',').map((e) => e.trim()).toList();
    }

    return GestureDetector(
      onTap: () => _showEditField(EditableField.hashtags),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
        ),
        child: Row(
          children: [
            const Text(
              'Hashtags',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            if (hashtags.isNotEmpty)
              Expanded(
                child: Text(
                  hashtags.join(', '),
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const Icon(
              Icons.chevron_right,
              color: Colors.grey,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      margin: const EdgeInsets.only(left: 16),
      height: 1,
      color: Colors.white.withValues(alpha: 0.1),
    );
  }

  Widget _buildFavoritesVisibilityRow() {
    final privacy = _user['privacy'] as Map<String, dynamic>? ?? {};
    final showFavoritesOnCard = privacy['showFavoritesOnCard'] ?? false;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Show Favorites on your Streamer Card',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Toggles visibility on your public Streamer Card only. Your Profile still shows Favorites to you.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: showFavoritesOnCard,
            onChanged: (value) async {
              await _updateFavoritesVisibility(value);
            },
            activeColor: const Color(0xFF9248D2),
            inactiveThumbColor: Colors.white.withValues(alpha: 0.3),
            inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
          ),
        ],
      ),
    );
  }

  Future<void> _updateFavoritesVisibility(bool showFavorites) async {
    try {
      // Update local state immediately for optimistic UI
      setState(() {
        _user['privacy'] = {
          ...(_user['privacy'] as Map<String, dynamic>? ?? {}),
          'showFavoritesOnCard': showFavorites,
        };
      });

      // Update Firestore using ProfileUpdateService for nested fields
      await _profileUpdateService?.updateUserData({
        'privacy': {
          ...(_user['privacy'] as Map<String, dynamic>? ?? {}),
          'showFavoritesOnCard': showFavorites,
        },
      });

      // Show confirmation
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              showFavorites
                  ? 'Favorites are now visible on your Streamer Card'
                  : 'Favorites are now hidden on your Streamer Card',
            ),
            backgroundColor: const Color(0xFF9248D2),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Revert on error
      setState(() {
        _user['privacy'] = {
          ...(_user['privacy'] as Map<String, dynamic>? ?? {}),
          'showFavoritesOnCard': !showFavorites,
        };
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update setting: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildPreferencesSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: GestureDetector(
              onTap: _showStatusPicker,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
                child: Consumer(
                  builder: (context, ref, child) {
                    final statusAsync = ref.watch(statusNotifierProvider);

                    return statusAsync.when(
                      data: (presence) => Row(
                        children: [
                          const Text(
                            'Online Status',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _getStatusColor(presence.status),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            presence.status.displayName,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.chevron_right,
                            color: Colors.grey,
                            size: 16,
                          ),
                        ],
                      ),
                      loading: () => const Row(
                        children: [
                          Text(
                            'Online Status',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                          Spacer(),
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.grey),
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(
                            Icons.chevron_right,
                            color: Colors.grey,
                            size: 16,
                          ),
                        ],
                      ),
                      error: (error, stack) => const Row(
                        children: [
                          Text(
                            'Online Status',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                          Spacer(),
                          Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 16,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Error',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(
                            Icons.chevron_right,
                            color: Colors.grey,
                            size: 16,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // Debug widget removed for production
        ],
      ),
    );
  }

  Color _getStatusColor(UserStatus status) {
    switch (status) {
      case UserStatus.online:
        return const Color(0xFF4CAF50); // Green
      case UserStatus.offline:
        return const Color(0xFF9E9E9E); // Grey
      case UserStatus.busy:
        return const Color(0xFFFF9800); // Orange
      case UserStatus.dnd:
        return const Color(0xFFF44336); // Red
      case UserStatus.streaming:
        return const Color(0xFF9C27B0); // Purple
    }
  }
}

enum EditableField {
  name,
  bio,
  hashtags;

  String get title {
    switch (this) {
      case EditableField.name:
        return 'Name';
      case EditableField.bio:
        return 'Bio';
      case EditableField.hashtags:
        return 'Hashtags';
    }
  }

  String get key {
    switch (this) {
      case EditableField.name:
        return 'displayName';
      case EditableField.bio:
        return 'bio';
      case EditableField.hashtags:
        return 'hashtags';
    }
  }

  int get maxLength {
    switch (this) {
      case EditableField.name:
        return 30;
      case EditableField.bio:
        return 200;
      case EditableField.hashtags:
        return 100;
    }
  }

  String? get helperText {
    switch (this) {
      case EditableField.name:
        return 'Your nickname can only be changed once every 7 days.';
      case EditableField.bio:
        return 'You can include your pronouns here if you\'d like (e.g., \'He/him\', \'They/them\', \'She/her\').';
      case EditableField.hashtags:
        return null;
    }
  }
}
