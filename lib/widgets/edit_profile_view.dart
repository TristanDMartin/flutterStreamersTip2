import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'edit_field_view.dart';
import 'links_edit_view.dart';
import 'status_button.dart';
import '../services/auth_service.dart';
import '../services/profile_update_service.dart';
import '../services/content_moderation_service.dart';
import '../services/storage_diagnostic_service.dart';
import '../utils/user_facing_error.dart';
import '../services/admin_service.dart';
import '../models/user_status.dart';
import '../providers/status_provider.dart';
import '../providers/support_tickets_provider.dart';
import '../views/settings_view.dart';
import '../features/admin/widgets/admin_shield_button.dart';
import '../features/admin/views/admin_control_center_view.dart';
import '../constants/app_colors.dart';
import '../core/theme/st_theme_tokens.dart';
import '../utils/platform_rules.dart';
import '../utils/user_profile_firestore.dart';
import '../utils/playback_route_suppression.dart';
import '../routing/app_routes.dart';
import 'profile/editable_profile_field.dart';
import 'profile/profile_avatar_picker_actions.dart';
import 'profile/profile_username_utils.dart';

class EditProfileView extends ConsumerStatefulWidget {
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
  ConsumerState<EditProfileView> createState() => _EditProfileViewState();
}
class _EditProfileViewState extends ConsumerState<EditProfileView> {
  late Map<String, dynamic> _user;
  bool _isUploadingAvatar = false;
  File? _selectedImage;
  String? _uploadError;
  DateTime? _lastNameChangeDate;
  bool _canChangeName = true;
  ProfileUpdateService? _profileUpdateService;
  bool _isAdmin = false;
  bool _rulesAlignedAdmin = false;
  bool _isResolvingAdminAccess = false;

  @override
  void initState() {
    super.initState();
    PlaybackRouteSuppression.suppress(reason: 'edit_profile');
    _user = Map.from(widget.user);
    final User? authUser = FirebaseAuth.instance.currentUser;
    if (authUser != null) {
      _user.putIfAbsent('id', () => authUser.uid);
      _user.putIfAbsent('uid', () => authUser.uid);
      if (authUser.email != null) {
        _user.putIfAbsent('email', () => authUser.email);
      }
    }
    _profileUpdateService = ProfileUpdateService();
    _profileUpdateService!.addProfileViewListener(
      _onProfileUpdateServiceChanged,
    );
    unawaited(
      _profileUpdateService!.initialize().then((_) {
        if (mounted) {
          _onProfileUpdateServiceChanged();
        }
      }),
    );
    _checkNameChangeEligibility();
    _isAdmin = AdminService.hasImmediateAdminAccess(cachedUserMap: _user);
    _rulesAlignedAdmin = _isAdmin;
    unawaited(_checkAdminStatus());
  }

  void _onProfileUpdateServiceChanged() {
    final Map<String, dynamic>? d = _profileUpdateService?.userData;
    if (d == null || !mounted) {
      return;
    }
    for (final String k in const <String>[
      'role',
      'isAdmin',
      'admin',
      'username',
      UserProfileFirestore.platformsField,
      UserProfileFirestore.calendarEventsField,
    ]) {
      if (d.containsKey(k)) {
        _user[k] = d[k];
      }
    }
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    final bool granted = await AdminService.instance.resolveAdminAccess(
      cachedUserMap: _user,
    );
    if (mounted) {
      setState(() {
        _isAdmin = granted;
        _rulesAlignedAdmin = granted;
      });
    }
  }

  void _showAdminAccessRequiredMessage() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Admin access required'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleAdminButtonTap() async {
    debugPrint('ADMIN_BUTTON_TAPPED');
    AdminService.userDocGrantsAdminAccess(
      _user,
      authUser: FirebaseAuth.instance.currentUser,
      logSource: 'button_tap',
    );
    if (AdminService.hasImmediateAdminAccess(cachedUserMap: _user)) {
      await AdminService.instance.ensureOwnerAdminActivation(
        cachedUserMap: _user,
      );
      _openAdminControlCenter();
      return;
    }
    if (_isResolvingAdminAccess) {
      return;
    }
    setState(() {
      _isResolvingAdminAccess = true;
    });
    try {
      final bool granted = await AdminService.instance.resolveAdminAccess(
        cachedUserMap: _user,
      );
      if (!mounted) {
        return;
      }
      if (granted) {
        setState(() {
          _isAdmin = true;
          _rulesAlignedAdmin = true;
        });
        _openAdminControlCenter();
        return;
      }
      _showAdminAccessRequiredMessage();
    } finally {
      if (mounted) {
        setState(() {
          _isResolvingAdminAccess = false;
        });
      }
    }
  }

  void _openAdminControlCenter() {
    if (!mounted) return;
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/admin_control'),
        builder: (_) => const AdminControlCenterView(),
      ),
    );
  }

  @override
  void dispose() {
    _profileUpdateService?.removeProfileViewListener(
      _onProfileUpdateServiceChanged,
    );
    _profileUpdateService = null;
    super.dispose();
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
        final username = ProfileUsernameUtils.generateUsernameFromDisplayName(
          value.toString(),
        );
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
        // appLog('ProfileUpdateService error: $e');
      }
      // Fallback to direct Firestore update
      _saveToFirestore(updateData);
    }
  }

  Future<void> _saveToFirestore(Map<String, dynamic> data) async {
    try {
      final authService =
          ProviderScope.containerOf(context).read(authServiceProvider);
      await authService.updateUserProfile(data);
    } catch (e) {
      // Error saving to Firestore - silent fail to avoid user spam
      if (kDebugMode) {
        // appLog('Firestore save error: $e');
      }
    }
  }

  void _showImagePicker() {
    if (kDebugMode) {
      debugPrint('🖼️ EditProfileView: Opening image picker modal');
    }
    ProfileAvatarPickerActions.showImagePicker(
      context,
      onImageSelected: _handleImageSelected,
    );
  }

  void _handleImageSelected(File imageFile) {
    if (kDebugMode) {
      debugPrint('📸 EditProfileView: Image selected: ${imageFile.path}');
    }
    setState(() {
      _selectedImage = imageFile;
      _uploadError = null;
    });
    _uploadAvatar(imageFile);
  }

  Future<void> _uploadAvatar(File imageFile) async {
    if (kDebugMode) {
      // ✅ FIX #2: Wrap in kDebugMode
      debugPrint('🔄 EditProfileView: Starting avatar upload process');
    }

    final ProviderContainer container = ProviderScope.containerOf(context);
    final AuthenticationService authService =
        container.read(authServiceProvider);
    final ScaffoldMessengerState scaffoldMessenger =
        ScaffoldMessenger.of(context);

    setState(() {
      _isUploadingAvatar = true;
      _uploadError = null;
    });

    try {
      // Validate file before upload
      if (!await imageFile.exists()) {
        throw Exception('Selected image file does not exist');
      }

      if (kDebugMode) {
        // ✅ FIX #2: Wrap in kDebugMode
        final int fileSize = await imageFile.length();
        debugPrint('📁 EditProfileView: File size: $fileSize bytes');
      }

      if (!mounted) {
        return;
      }

      if (kDebugMode) {
        // ✅ FIX #2: Wrap in kDebugMode
        debugPrint(
            '🔐 EditProfileView: AuthService obtained, starting upload...');
      }

      final downloadUrl = await authService.uploadAvatar(imageFile);

      if (!mounted) return; // ✅ FIX #4: Check mounted after await

      if (kDebugMode) {
        // ✅ FIX #2: Wrap in kDebugMode
        debugPrint('✅ EditProfileView: Upload completed, URL: $downloadUrl');
      }

      setState(() {
        _user['avatarURL'] = downloadUrl;
        _selectedImage = null;
        _isUploadingAvatar = false;
      });

      // Update local callback
      widget.onUserUpdated(_user);

      if (kDebugMode) {
        // ✅ FIX #2: Wrap in kDebugMode
        debugPrint('📱 EditProfileView: Local user data updated');
      }

      // Update all profile views through ProfileUpdateService
      try {
        final profileUpdateService = ProfileUpdateService();
        await profileUpdateService.updateUserData({
          'avatarURL': downloadUrl,
          'photoURL': downloadUrl,
        });

        if (!mounted) return; // ✅ FIX #4: Check mounted after await

        if (kDebugMode) {
          // ✅ FIX #2: Wrap in kDebugMode
          debugPrint('✅ EditProfileView: Avatar updated in all profile views');
        }
      } catch (e) {
        if (kDebugMode) {
          // ✅ FIX #2: Wrap in kDebugMode
          debugPrint(
              '❌ EditProfileView: Error updating avatar in profile views: $e');
        }
        // Don't show error to user for this secondary update
      }

      // ✅ FIX #4: Use captured scaffold messenger instead of context
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Avatar updated successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }

      if (kDebugMode) {
        // ✅ FIX #2: Wrap in kDebugMode
        debugPrint('🎉 EditProfileView: Success message shown to user');
      }
    } catch (e) {
      if (kDebugMode) {
        // ✅ FIX #2: Wrap in kDebugMode
        debugPrint('❌ EditProfileView: Avatar upload failed: $e');
      }

      if (!mounted) return; // ✅ FIX #4: Check mounted before setState

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
          errorMessage = UserFacingError.message(e);
        }

        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: _selectedImage != null
                  ? 'Retry'
                  : (kDebugMode ? 'Diagnose' : 'OK'),
              textColor: Colors.white,
              onPressed: () {
                if (_selectedImage != null) {
                  _uploadAvatar(_selectedImage!); // ✅ FIX #5: Retry upload
                } else if (kDebugMode) {
                  _runStorageDiagnostics();
                }
              },
            ),
          ),
        );
      }
    }
  }

  Future<void> _runStorageDiagnostics() async {
    if (!kDebugMode) {
      return;
    }
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
            content: Text(UserFacingError.message(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showEditField(EditableProfileField field) {
    if (field == EditableProfileField.name && !_canChangeName) {
      _showNameChangeCooldownDialog(); // cspell:ignore cooldown
      return;
    }

    final currentValue = _getFieldValue(field);

    Navigator.push(
      context,
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: AppRoutes.editField),
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
      builder: (BuildContext dialogContext) {
        final ColorScheme cs = Theme.of(dialogContext).colorScheme;
        final Color on = cs.onSurface;
        return AlertDialog(
          title: const Text('Name Change Cooldown'), // cspell:ignore cooldown
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You can only change your display name once every 7 days.',
                style: TextStyle(fontSize: 16, color: on),
              ),
              const SizedBox(height: 16),
              Text(
                'Last changed: ${_formatDate(_lastNameChangeDate!)}',
                style: TextStyle(
                  fontSize: 14,
                  color: on.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Next change available: ${_formatDate(nextChangeDate)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: on,
                ),
              ),
              if (daysRemaining > 0) ...[
                const SizedBox(height: 8),
                Text(
                  'Days remaining: $daysRemaining',
                  style: TextStyle(
                    fontSize: 14,
                    color: StThemeColors.warningAmber,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  /// Format date for display
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _getFieldValue(EditableProfileField field) {
    switch (field) {
      case EditableProfileField.name:
        return _user['displayName'] ?? '';
      case EditableProfileField.bio:
        return _user['bio'] ?? '';
      case EditableProfileField.hashtags:
        final hashtags = _user['hashtags'] as List<dynamic>? ?? [];
        return hashtags.join(', ');
    }
  }

  void _showStatusPicker() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        final double bottomInset = MediaQuery.viewInsetsOf(sheetContext).bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Consumer(
            builder: (BuildContext context, WidgetRef ref, Widget? child) {
              final statusAsync = ref.watch(statusNotifierProvider);
              final updateStatus = ref.read(updateStatusProvider);

              return statusAsync.when(
                data: (presence) => StatusPickerModal(
                  currentStatus: presence.status,
                  onStatusSelected: (UserStatus status) async {
                    final NavigatorState navigator =
                        Navigator.of(sheetContext);
                    StatusUpdateOutcome outcome;
                    try {
                      outcome = await updateStatus(status);
                    } on PlatformException catch (e) {
                      debugPrint(
                        'STATUS_PLATFORM_EXCEPTION code=${e.code} '
                        'message=${e.message}',
                      );
                      outcome = StatusUpdateOutcome.failed(
                        userMessage: 'Status could not sync. Try again.',
                        pendingRetry: true,
                      );
                    } catch (e) {
                      debugPrint('STATUS_UPDATE_FAILED ui_error=$e');
                      outcome = StatusUpdateOutcome.failed(
                        userMessage: 'Status could not sync. Try again.',
                        pendingRetry: true,
                      );
                    }
                    if (!outcome.success && sheetContext.mounted) {
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        SnackBar(
                          content: Text(
                            outcome.userMessage ??
                                'Status could not sync. Try again.',
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                    try {
                      await _profileUpdateService?.updateUserData(
                        <String, dynamic>{'status': status.value},
                      );
                    } catch (e) {
                      debugPrint('STATUS_UPDATE_FAILED profile_cache=$e');
                    }
                    if (mounted) {
                      navigator.pop();
                    }
                  },
                ),
                loading: () => Center(
                  child: CircularProgressIndicator(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                error: (Object error, StackTrace stack) => Center(
                  child: Text(
                    'Error loading status',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showLinksEditor() {
    final List<Map<String, dynamic>> currentPlatforms =
        UserProfileFirestore.parsePlatformsFromUserData(_user);

    Navigator.push(
      context,
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: AppRoutes.editLinks),
        builder: (context) => LinksEditView(
          platforms: currentPlatforms,
          onPlatformsUpdated: (updatedPlatforms) async {
            // Capture context and scaffold messenger before async operations
            final scaffoldMessenger = ScaffoldMessenger.of(context);

            final String? platformRulesError =
                PlatformRules.validatePlatformsList(updatedPlatforms);
            if (platformRulesError != null) {
              if (mounted) {
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text(platformRulesError),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 4),
                  ),
                );
              }
              return;
            }

            final List<Map<String, dynamic>> normalizedPlatforms =
                UserProfileFirestore.normalizePlatformsForFirestore(
              updatedPlatforms,
            );
            final String? uid = (_user['id'] ?? _user['uid'])?.toString();
            if (uid != null && uid.isNotEmpty) {
              UserProfileFirestore.logPlatformSave(
                uid: uid,
                view: 'EditProfileView',
                count: normalizedPlatforms.length,
              );
            }

            // Content moderation validation for platforms
            final moderationResult = ContentModerationService.validatePlatforms(
              normalizedPlatforms,
            );

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
              _user['platforms'] = normalizedPlatforms;
            });

            // Update local callback
            widget.onUserUpdated(_user);

            // Update all profile views through ProfileUpdateService
            try {
              final profileUpdateService = ProfileUpdateService();
              await profileUpdateService.updateUserData(
                <String, dynamic>{'platforms': normalizedPlatforms},
              );
              if (kDebugMode) {
                // ✅ FIX #2: Wrap in kDebugMode
                debugPrint(
                    '✅ EditProfileView: Platforms updated in all profile views');
              }
            } catch (e) {
              if (kDebugMode) {
                // ✅ FIX #2: Wrap in kDebugMode
                debugPrint(
                    '❌ EditProfileView: Error updating platforms in profile views: $e');
              }
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
    final double bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: bottomInset + 24),
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
    );
  }

  Widget _buildAppBar() {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color on = cs.onSurface;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: on.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: cs.outline.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: widget.onBack ?? () => Navigator.pop(context),
              icon: Icon(
                Icons.arrow_back,
                color: on,
                size: 22,
              ),
            ),
            Expanded(
              child: Text(
                'Edit profile',
                style: TextStyle(
                  color: on,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (_isAdmin || _isResolvingAdminAccess) ...[
              Consumer(
                builder: (context, ref, child) {
                  final SupportTicketsState supportTickets = _rulesAlignedAdmin
                      ? ref.watch(supportTicketsProvider)
                      : const SupportTicketsState();
                  final bool hasPendingTickets =
                      supportTickets.pendingTickets > 0;
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: _isResolvingAdminAccess
                        ? const SizedBox(
                            width: 28,
                            height: 28,
                            child: Padding(
                              padding: EdgeInsets.all(4),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : AdminShieldButton(
                            showTicketBadge: hasPendingTickets,
                            onPressed: _handleAdminButtonTap,
                          ),
                  );
                },
              ),
            ],
            IconButton(
              tooltip: 'Privacy & settings',
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    settings: const RouteSettings(name: AppRoutes.settings),
                    builder: (context) => const SettingsView(
                      initialSearchQuery: 'Privacy',
                    ),
                  ),
                );
              },
              icon: Icon(
                Icons.privacy_tip_outlined,
                color: on,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarSection() {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color on = cs.onSurface;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: on.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: cs.outline.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: GestureDetector(
        onTap: _isUploadingAvatar
            ? null
            : () {
                if (kDebugMode) {
                  // ✅ FIX #2: Wrap in kDebugMode
                  debugPrint('👆 EditProfileView: Avatar button tapped');
                }
                _showImagePicker();
              },
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 124,
                  height: 124,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: AppColors.supportAccentGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(3),
                  child: _buildAvatarContent(),
                ),
                if (!_isUploadingAvatar)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.supportAccent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: on.withValues(alpha: 0.28),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                AppColors.supportAccent.withValues(alpha: 0.28),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
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
            const SizedBox(height: 14),
            _buildAvatarText(),
            const SizedBox(height: 6),
            Text(
              _isUploadingAvatar
                  ? 'We are updating your profile image now.'
                  : 'Choose a photo or avatar that represents your profile.',
              style: TextStyle(
                color: on.withValues(alpha: 0.66),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
              textAlign: TextAlign.center,
            ),
            if (_uploadError != null) ...[
              const SizedBox(height: 8),
              Text(
                'Upload failed. Tap to try again.',
                style: TextStyle(
                  color: cs.error,
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
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color fill = cs.surfaceContainerHighest;
    if (_isUploadingAvatar) {
      return Container(
        decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: CircularProgressIndicator(
            color: cs.primary,
            strokeWidth: 3,
          ),
        ),
      );
    }

    if (_selectedImage != null) {
      return Container(
        decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
        ),
        child: ClipOval(
          child: Image.file(
            _selectedImage!,
            width: 120,
            height: 120,
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    if (_user['avatarURL'] != null &&
        _user['avatarURL'].toString().isNotEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
        ),
        child: ClipOval(
          child: Image.network(
            _user['avatarURL'],
            width: 120,
            height: 120,
            fit: BoxFit.cover,
            errorBuilder:
                (BuildContext context, Object error, StackTrace? stackTrace) =>
                    Icon(
              Icons.person,
              size: 40,
              color: cs.onSurface.withValues(alpha: 0.45),
            ),
            loadingBuilder:
                (BuildContext context, Widget? child, ImageChunkEvent? p) {
              if (p == null) {
                return child!;
              }
              return Center(
                child: CircularProgressIndicator(
                  color: cs.primary,
                  strokeWidth: 2,
                ),
              );
            },
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          Icons.person,
          size: 40,
          color: cs.onSurface.withValues(alpha: 0.45),
        ),
      ),
    );
  }

  Widget _buildAvatarText() {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color on = cs.onSurface;
    if (_isUploadingAvatar) {
      return Text(
        'Uploading...',
        style: TextStyle(
          color: on,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      );
    }

    if (_uploadError != null) {
      return Text(
        'Upload failed',
        style: TextStyle(
          color: cs.error,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      );
    }

    return Text(
      'Edit photo or avatar',
      style: TextStyle(
        color: on,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildAboutYouSection() {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color on = cs.onSurface;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
            child: Text(
              'About',
              style: TextStyle(
                color: on,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: on.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: cs.outline.withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                _buildEditProfileRow(
                    EditableProfileField.name, _user['displayName'] ?? ''),
                _buildDivider(),
                _buildUsernameRow(),
                _buildDivider(),
                _buildEditProfileRow(
                    EditableProfileField.bio, _user['bio'] ?? ''),
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

  Widget _buildEditProfileRow(EditableProfileField field, String value) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color on = cs.onSurface;
    final Color muted = on.withValues(alpha: 0.45);
    final isNameField = field == EditableProfileField.name;
    final isLocked = isNameField && !_canChangeName;

    return GestureDetector(
      onTap: () => _showEditField(field),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: isLocked
              ? on.withValues(alpha: 0.06)
              : on.withValues(alpha: 0.03),
        ),
        child: Row(
          children: [
            Text(
              field.title,
              style: TextStyle(
                color: isLocked ? muted : on,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (value.isNotEmpty)
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    color: isLocked ? muted : on.withValues(alpha: 0.72),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (isLocked) ...[
              Icon(
                Icons.lock,
                color: muted,
                size: 16,
              ),
              const SizedBox(width: 8),
            ],
            Icon(
              isLocked ? Icons.info_outline : Icons.chevron_right,
              color: muted,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsernameRow() {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color on = cs.onSurface;
    final Color muted = on.withValues(alpha: 0.45);
    final String atHandle = ProfileUsernameUtils.formatAtHandle(_user);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: on.withValues(alpha: 0.03),
      ),
      child: Row(
        children: [
          Text(
            'Username',
            style: TextStyle(
              color: on,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            atHandle.isNotEmpty ? atHandle : 'Not set',
            style: TextStyle(
              color: on.withValues(alpha: 0.72),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.lock,
            color: muted,
            size: 16,
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformsRow() {
    final List<Map<String, dynamic>> platforms =
        UserProfileFirestore.parsePlatformsFromUserData(_user);
    final int platformCount = platforms.length;

    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color on = cs.onSurface;
    final Color muted = on.withValues(alpha: 0.45);
    return GestureDetector(
      onTap: _showLinksEditor,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: on.withValues(alpha: 0.03),
        ),
        child: Row(
          children: [
            Text(
              'Platforms',
              style: TextStyle(
                color: on,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (platformCount > 0)
              Text(
                '$platformCount platform${platformCount == 1 ? '' : 's'}',
                style: TextStyle(
                  color: on.withValues(alpha: 0.72),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              color: muted,
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

    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color on = cs.onSurface;
    final Color muted = on.withValues(alpha: 0.45);
    return GestureDetector(
      onTap: () => _showEditField(EditableProfileField.hashtags),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: on.withValues(alpha: 0.03),
        ),
        child: Row(
          children: [
            Text(
              'Hashtags',
              style: TextStyle(
                color: on,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (hashtags.isNotEmpty)
              Expanded(
                child: Text(
                  hashtags.join(', '),
                  style: TextStyle(
                    color: on.withValues(alpha: 0.72),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            Icon(
              Icons.chevron_right,
              color: muted,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    final Color on = Theme.of(context).colorScheme.onSurface;
    return Container(
      margin: const EdgeInsets.only(left: 18),
      height: 1,
      color: on.withValues(alpha: 0.1),
    );
  }

  Widget _buildFavoritesVisibilityRow() {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color on = cs.onSurface;
    final privacy = _user['privacy'] as Map<String, dynamic>? ?? {};
    final showFavoritesOnCard = privacy['showFavoritesOnCard'] ?? false;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: on.withValues(alpha: 0.03),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Show Favorites on your Streamer Card',
                  style: TextStyle(
                    color: on,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Toggles visibility on your public Streamer Card only. Your Profile still shows Favorites to you.',
                  style: TextStyle(
                    color: on.withValues(alpha: 0.68),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: showFavoritesOnCard,
            onChanged: (bool value) async {
              await _updateFavoritesVisibility(value);
            },
            activeThumbColor: cs.primary,
            activeTrackColor: cs.primary.withValues(alpha: 0.45),
            inactiveTrackColor: on.withValues(alpha: 0.2),
            inactiveThumbColor: on.withValues(alpha: 0.65),
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
            backgroundColor: Theme.of(context).colorScheme.primary,
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
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Widget _buildPreferencesSection() {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color on = cs.onSurface;
    final Color muted = on.withValues(alpha: 0.45);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
            child: Text(
              'Preferences',
              style: TextStyle(
                color: on,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: on.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: cs.outline.withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            child: GestureDetector(
              onTap: _showStatusPicker,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: on.withValues(alpha: 0.03),
                ),
                child: Consumer(
                  builder:
                      (BuildContext context, WidgetRef ref, Widget? child) {
                    final statusAsync = ref.watch(statusNotifierProvider);

                    return statusAsync.when(
                      data: (presence) => Row(
                        children: [
                          Text(
                            'Online Status',
                            style: TextStyle(
                              color: on,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: _getStatusColor(presence.status),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: _getStatusColor(presence.status)
                                      .withValues(alpha: 0.35),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            presence.status.displayName,
                            style: TextStyle(
                              color: on.withValues(alpha: 0.72),
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.chevron_right,
                            color: muted,
                            size: 16,
                          ),
                        ],
                      ),
                      loading: () => Row(
                        children: [
                          Text(
                            'Online Status',
                            style: TextStyle(
                              color: on,
                              fontSize: 16,
                            ),
                          ),
                          const Spacer(),
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: cs.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.chevron_right,
                            color: muted,
                            size: 16,
                          ),
                        ],
                      ),
                      error: (Object error, StackTrace stack) => Row(
                        children: [
                          Text(
                            'Online Status',
                            style: TextStyle(
                              color: on,
                              fontSize: 16,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.error_outline,
                            color: cs.error,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Error',
                            style: TextStyle(
                              color: cs.error,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.chevron_right,
                            color: muted,
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
      case UserStatus.away:
        return const Color(0xFFF44336); // Red
      case UserStatus.streaming:
        return const Color(0xFF9C27B0); // Purple
    }
  }
}
