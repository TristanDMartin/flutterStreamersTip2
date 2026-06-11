import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../routing/app_routes.dart';
import '../../../routing/navigation_context.dart';
import '../../../services/auth_service.dart';
import '../../../services/profile_update_service.dart';
import '../../../utils/category_schema.dart';
import '../../../widgets/edit_field_view.dart';
import '../../../widgets/profile/editable_profile_field.dart';
import '../../../widgets/profile/profile_about_editor_section.dart';
import '../../../widgets/profile/profile_avatar_picker_actions.dart';
import '../../../widgets/profile/profile_avatar_picker_section.dart';
import '../../../widgets/profile/profile_field_update_helper.dart';
import '../../../widgets/profile/profile_platforms_update_helper.dart';
import '../../../widgets/profile/profile_username_utils.dart';
import '../onboarding_style.dart';
import '../onboarding_v1_constants.dart';
import '../widgets/onboarding_progress_header.dart';

class OnboardingCreatorCardScreen extends ConsumerStatefulWidget {
  const OnboardingCreatorCardScreen({
    super.key,
    required this.initialUser,
    required this.onContinue,
    required this.onBack,
  });

  final Map<String, dynamic> initialUser;
  final Future<void> Function(Map<String, dynamic> user) onContinue;
  final VoidCallback onBack;

  @override
  ConsumerState<OnboardingCreatorCardScreen> createState() =>
      _OnboardingCreatorCardScreenState();
}

class _OnboardingCreatorCardScreenState
    extends ConsumerState<OnboardingCreatorCardScreen>
    with AutomaticKeepAliveClientMixin {
  late Map<String, dynamic> _user;
  File? _selectedImage;
  bool _isUploadingAvatar = false;
  String? _uploadError;
  bool _isSaving = false;
  String? _error;
  ProfileUpdateService? _profileUpdateService;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _user = Map<String, dynamic>.from(widget.initialUser);
    if (_user['platforms'] == null) {
      _user['platforms'] = <Map<String, dynamic>>[];
    }
    _profileUpdateService = ProfileUpdateService();
    unawaited(_profileUpdateService!.initialize());
  }

  @override
  void dispose() {
    _profileUpdateService = null;
    super.dispose();
  }

  bool get _isValid {
    final String displayName = (_user['displayName'] as String?)?.trim() ?? '';
    final String bio = (_user['bio'] as String?)?.trim() ?? '';
    final String username = (_user['username'] as String?)?.trim() ?? '';
    return displayName.length >= 2 && bio.isNotEmpty && username.isNotEmpty;
  }

  String? get _avatarUrl {
    final String? url = (_user['avatarURL'] as String?)?.trim();
    if (url != null && url.isNotEmpty) {
      return url;
    }
    return (_user['photoURL'] as String?)?.trim();
  }

  void _showImagePicker() {
    ProfileAvatarPickerActions.showImagePicker(
      context,
      onImageSelected: _handleImageSelected,
    );
  }

  void _handleImageSelected(File imageFile) {
    setState(() {
      _selectedImage = imageFile;
      _uploadError = null;
    });
    unawaited(_uploadAvatar(imageFile));
  }

  Future<void> _uploadAvatar(File imageFile) async {
    final AuthenticationService authService = ref.read(authServiceProvider);
    setState(() {
      _isUploadingAvatar = true;
      _uploadError = null;
    });
    try {
      if (!await imageFile.exists()) {
        throw Exception('Selected image file does not exist');
      }
      final String downloadUrl = await authService.uploadAvatar(imageFile);
      if (!mounted) {
        return;
      }
      setState(() {
        _user['avatarURL'] = downloadUrl;
        _user['photoURL'] = downloadUrl;
        _selectedImage = null;
        _isUploadingAvatar = false;
      });
      _showAvatarSnackBar(
        'Avatar updated successfully!',
        backgroundColor: Colors.green,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('OnboardingCreatorCard: avatar upload failed: $e');
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _isUploadingAvatar = false;
        _uploadError = _formatAvatarUploadError(e);
      });
      _showAvatarSnackBar(
        _uploadError ?? 'Avatar upload failed. Please try again.',
        backgroundColor: Colors.red,
      );
    }
  }

  String _formatAvatarUploadError(Object error) {
    final String message = error.toString().toLowerCase();
    if (message.contains('not authenticated')) {
      return 'Please sign in again and retry.';
    }
    if (message.contains('internet') || message.contains('network')) {
      return 'No internet connection. Check your network and retry.';
    }
    if (message.contains('too large') || message.contains('5mb')) {
      return 'Image is too large. Please choose a photo under 5MB.';
    }
    if (message.contains('403') || message.contains('app attestation')) {
      return 'Upload blocked by security check. Restart the app and retry.';
    }
    return 'Avatar upload failed. Please try again.';
  }

  void _showAvatarSnackBar(
    String message, {
    required Color backgroundColor,
  }) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _updateField(String key, String value) async {
    final ProfileFieldUpdateResult local = ProfileFieldUpdateHelper.applyLocalUpdate(
      user: _user,
      key: key,
      value: value,
      syncUsernameFromDisplayName: true,
      recordNameChangeDate: false,
    );
    if (!local.isSuccess) {
      if (mounted && local.errorMessage != null) {
        ProfileFieldUpdateHelper.showModerationSnackBar(
          context,
          local.errorMessage!,
        );
      }
      return;
    }
    setState(() {
      _user = local.updatedUser!;
    });
    try {
      await _profileUpdateService?.updateUserData(local.firestorePayload!);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('OnboardingCreatorCard: profile field save failed: $e');
      }
    }
  }

  void _showEditField(EditableProfileField field) {
    if (!NavigationContext.canNavigate(context)) {
      return;
    }
    final BuildContext navigatorContext =
        NavigationContext.requireForNavigation(context);
    final String currentValue =
        ProfileFieldUpdateHelper.readFieldValue(_user, field);
    Navigator.push<void>(
      navigatorContext,
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: AppRoutes.editField),
        builder: (BuildContext context) {
          return EditFieldView(
            title: field.title,
            text: currentValue,
            helperText: field == EditableProfileField.name
                ? null
                : field.helperText,
            maxLength: field.maxLength,
            onTextChanged: (String value) {
              unawaited(_updateField(field.key, value));
            },
            onSave: () {
              Navigator.pop(context);
            },
            onCancel: () => Navigator.pop(context),
          );
        },
      ),
    );
  }

  void _showPlatformsEditor() {
    ProfilePlatformsUpdateHelper.openPlatformsEditor(
      context: context,
      user: _user,
      auditView: 'OnboardingCreatorCardScreen',
      profileUpdateService: _profileUpdateService,
      onSaved: (List<Map<String, dynamic>> platforms) {
        if (!mounted) {
          return;
        }
        setState(() {
          _user['platforms'] = platforms;
        });
      },
    );
  }

  Future<void> _submit() async {
    if (!_isValid || _isSaving) {
      return;
    }
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final String displayName = (_user['displayName'] as String?)?.trim() ?? '';
      String username = (_user['username'] as String?)?.trim() ?? '';
      if (username.isEmpty) {
        username = ProfileUsernameUtils.generateUsernameFromDisplayName(
          displayName,
        );
        _user['username'] = username;
      }
      final String bio = (_user['bio'] as String?)?.trim() ?? '';
      final String? avatarUrl = _avatarUrl;
      final String categoryId =
          (_user['categoryId'] as String?)?.trim().isNotEmpty == true
              ? (_user['categoryId'] as String).trim()
              : kDefaultCategoryId;
      final List<Map<String, dynamic>> platforms =
          ProfilePlatformsUpdateHelper.readPlatforms(_user);
      await widget.onContinue(<String, dynamic>{
        'displayName': displayName,
        'username': username,
        'bio': bio,
        'categoryId': categoryId,
        'category': categoryId,
        'avatarURL': avatarUrl,
        'photoURL': avatarUrl,
        'platforms': platforms,
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not save your creator card. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final ColorScheme cs = Theme.of(context).colorScheme;
    return ColoredBox(
      color: cs.surface,
      child: SafeArea(
        child: Column(
          children: <Widget>[
            OnboardingProgressHeader(
              step: 4,
              totalSteps: OnboardingV1Constants.totalSteps,
              showBack: true,
              onBack: widget.onBack,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                      child: Text(
                        'Build your Creator Card',
                        style: OnboardingStyle.titleFor(context),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 6, 24, 0),
                      child: Text(
                        'Complete your card and earn '
                        '+${OnboardingV1Constants.creatorCardRewardXp} XP',
                        style: OnboardingStyle.plainTextStyle(
                          const TextStyle(
                            color: Color(0xFF58CC02),
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ProfileAvatarPickerSection(
                      avatarUrl: _avatarUrl,
                      selectedImage: _selectedImage,
                      isUploading: _isUploadingAvatar,
                      uploadError: _uploadError,
                      onTap: _isUploadingAvatar ? null : _showImagePicker,
                    ),
                    ProfileAboutEditorSection(
                      user: _user,
                      canChangeName: true,
                      showPlatformsRow: true,
                      onEditField: _showEditField,
                      onEditPlatforms: _showPlatformsEditor,
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: cs.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
              child: SizedBox(
                width: double.infinity,
                child: GradientPillButton(
                  label: _isSaving ? 'Saving...' : 'Generate Creator Card',
                  onPressed: _isValid && !_isSaving ? _submit : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
