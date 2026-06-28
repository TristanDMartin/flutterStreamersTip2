import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../routing/app_routes.dart';
import '../../../routing/navigation_context.dart';
import '../../../services/robust_auth_service.dart';
import '../../../services/profile_update_service.dart';
import '../../../services/username_lock_service.dart';
import '../../../utils/category_schema.dart';
import '../../../widgets/edit_field_view.dart';
import '../../../widgets/profile/editable_profile_field.dart';
import '../../../widgets/profile/profile_about_editor_section.dart';
import '../../../widgets/profile/profile_avatar_picker_actions.dart';
import '../../../widgets/profile/profile_avatar_picker_section.dart';
import '../../../widgets/profile/profile_creator_identity_fields.dart';
import '../../../widgets/profile/profile_field_update_helper.dart';
import '../../../widgets/profile/profile_platforms_update_helper.dart';
import '../../../widgets/profile/profile_username_availability_controller.dart';
import '../../../widgets/profile/profile_username_rules.dart';
import '../../../widgets/profile/profile_username_utils.dart';
import '../onboarding_style.dart';
import '../onboarding_v1_constants.dart';
import '../widgets/onboarding_full_screen_shell.dart';
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
  late String _initialUsername;
  File? _selectedImage;
  bool _isUploadingAvatar = false;
  String? _uploadError;
  bool _isSaving = false;
  String? _error;
  bool _usernameManuallyEdited = false;
  ProfileUpdateService? _profileUpdateService;
  final ProfileUsernameAvailabilityController _usernameAvailability =
      ProfileUsernameAvailabilityController();
  UsernameAvailabilityStatus _usernameStatus = UsernameAvailabilityStatus.idle;
  String? _usernameStatusMessage;

  @override
  bool get wantKeepAlive => true;

  String get _userId =>
      widget.initialUser['uid'] as String? ??
      widget.initialUser['id'] as String? ??
      fa.FirebaseAuth.instance.currentUser?.uid ??
      '';

  @override
  void initState() {
    super.initState();
    _user = Map<String, dynamic>.from(widget.initialUser);
    if (_user['platforms'] == null) {
      _user['platforms'] = <Map<String, dynamic>>[];
    }
    _initialUsername = (_user['username'] as String?)?.trim() ?? '';
    if (_initialUsername.isNotEmpty) {
      _usernameManuallyEdited = true;
    }
    _profileUpdateService = ProfileUpdateService();
    unawaited(_profileUpdateService!.initialize());
    _scheduleUsernameAvailabilityCheck();
  }

  @override
  void dispose() {
    _usernameAvailability.dispose();
    _profileUpdateService = null;
    super.dispose();
  }

  bool get _hasAvatar {
    if (_selectedImage != null) {
      return true;
    }
    final String? url = _avatarUrl;
    return url != null && url.isNotEmpty;
  }

  bool get _canContinue {
    final String displayName = (_user['displayName'] as String?)?.trim() ?? '';
    final String bio = (_user['bio'] as String?)?.trim() ?? '';
    final String username =
        ProfileUsernameRules.normalize((_user['username'] as String?) ?? '');
    if (displayName.length < 2 || bio.isEmpty || username.isEmpty) {
      return false;
    }
    if (!ProfileUsernameRules.isFormatValid(username)) {
      return false;
    }
    if (_isUploadingAvatar || _isSaving) {
      return false;
    }
    if (_usernameStatus == UsernameAvailabilityStatus.checking) {
      return false;
    }
    if (_usernameStatus == UsernameAvailabilityStatus.taken ||
        _usernameStatus == UsernameAvailabilityStatus.invalid ||
        _usernameStatus == UsernameAvailabilityStatus.tooShort ||
        _usernameStatus == UsernameAvailabilityStatus.error) {
      return false;
    }
    return _usernameStatus == UsernameAvailabilityStatus.available;
  }

  String? get _avatarUrl {
    final String? url = (_user['avatarURL'] as String?)?.trim();
    if (url != null && url.isNotEmpty) {
      return url;
    }
    return (_user['photoURL'] as String?)?.trim();
  }

  void _scheduleUsernameAvailabilityCheck() {
    final String username = (_user['username'] as String?) ?? '';
    _usernameAvailability.scheduleCheck(
      username: username,
      userId: _userId,
      onStatusChanged: (UsernameAvailabilityStatus status, String? message) {
        if (!mounted) {
          return;
        }
        setState(() {
          _usernameStatus = status;
          _usernameStatusMessage = message;
        });
      },
    );
  }

  void _onDisplayNameChanged(String value) {
    final ProfileFieldUpdateResult local = ProfileFieldUpdateHelper.applyLocalUpdate(
      user: _user,
      key: EditableProfileField.name.key,
      value: value,
      syncUsernameFromDisplayName: !_usernameManuallyEdited,
    );
    if (!local.isSuccess || local.updatedUser == null) {
      return;
    }
    setState(() {
      _user = local.updatedUser!;
    });
    _scheduleUsernameAvailabilityCheck();
  }

  void _onUsernameChanged(String value) {
    _usernameManuallyEdited = true;
    final String normalized = ProfileUsernameUtils.normalizeUsername(value);
    setState(() {
      _user['username'] = normalized;
    });
    _scheduleUsernameAvailabilityCheck();
  }

  void _showImagePicker() {
    ProfileAvatarPickerActions.showImagePicker(
      context,
      hasExistingPhoto: _hasAvatar,
      onRemovePhoto: _removeAvatar,
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

  Future<void> _removeAvatar() async {
    setState(() {
      _selectedImage = null;
      _uploadError = null;
      _user['avatarURL'] = null;
      _user['photoURL'] = null;
    });
    try {
      await _profileUpdateService?.updateUserData(<String, dynamic>{
        'avatarURL': null,
        'photoURL': null,
        'avatarUrl': null,
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('OnboardingCreatorCard: avatar remove failed: $e');
      }
    }
  }

  Future<void> _uploadAvatar(File imageFile) async {
    final RobustAuthenticationService authService =
        ref.read(robustAuthServiceProvider);
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
      await _profileUpdateService?.updateUserData(<String, dynamic>{
        'avatarURL': downloadUrl,
        'photoURL': downloadUrl,
        'avatarUrl': downloadUrl,
      });
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

  Future<void> _updateField(String key, String value) async {
    final ProfileFieldUpdateResult local = ProfileFieldUpdateHelper.applyLocalUpdate(
      user: _user,
      key: key,
      value: value,
      syncUsernameFromDisplayName: false,
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
    if (!_canContinue || _isSaving) {
      return;
    }
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final String displayName = (_user['displayName'] as String?)?.trim() ?? '';
      final String username = ProfileUsernameRules.normalize(
        (_user['username'] as String?)?.trim() ?? '',
      );
      await _usernameAvailability.checkNow(
        username: username,
        userId: _userId,
        onStatusChanged: (UsernameAvailabilityStatus status, String? message) {
          if (!mounted) {
            return;
          }
          setState(() {
            _usernameStatus = status;
            _usernameStatusMessage = message;
          });
        },
      );
      if (_usernameAvailability.status !=
          UsernameAvailabilityStatus.available) {
        throw Exception(_usernameStatusMessage ?? 'Username unavailable');
      }
      await UsernameLockService().reserveUsername(
        username: username,
        userId: _userId,
        previousUsername: _initialUsername,
      );
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
    } on UsernameTakenException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _usernameStatus = UsernameAvailabilityStatus.taken;
          _usernameStatusMessage = 'Username already taken';
        });
      }
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
    return OnboardingScreenLayout(
      child: Column(
        children: <Widget>[
          OnboardingProgressHeader(
            step: 3,
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
                      'STEP 3 OF 4',
                      style: OnboardingStyle.plainTextStyle(
                        TextStyle(
                          color: const Color(0xFF9248D2).withValues(alpha: 0.95),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
                    child: Text(
                      'Build your creator identity',
                      style: OnboardingStyle.titleFor(context, fontSize: 30),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                    child: Text(
                      'This is how other streamers find and know you.',
                      style: OnboardingStyle.bodyFor(context, fontSize: 15),
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
                  ProfileCreatorIdentityFields(
                    displayName: (_user['displayName'] as String?) ?? '',
                    username: (_user['username'] as String?) ?? '',
                    onDisplayNameChanged: _onDisplayNameChanged,
                    onUsernameChanged: _onUsernameChanged,
                    usernameStatus: _usernameStatus,
                    usernameStatusMessage: _usernameStatusMessage,
                  ),
                  ProfileAboutEditorSection(
                    user: _user,
                    canChangeName: false,
                    showNameRow: false,
                    showUsernameRow: false,
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
                          color: Theme.of(context).colorScheme.error,
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
                useSolidPurple: true,
                label: _isSaving
                    ? 'Saving...'
                    : 'Create My Card → '
                        '+${OnboardingV1Constants.creatorCardRewardXp} XP',
                onPressed: _canContinue && !_isSaving ? _submit : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
