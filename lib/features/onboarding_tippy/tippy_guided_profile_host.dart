import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../components/onboarding/onboarding_service.dart';
import '../../constants/app_colors.dart';
import '../../core/app_check_http_headers.dart';
import '../../core/backend/site_api_base.dart';
import '../../services/robust_auth_service.dart';
import '../../services/username_lock_service.dart';
import '../../utils/platform_rules.dart';
import '../../widgets/profile/platform_handle_input_field.dart';
import '../../widgets/profile/profile_avatar_picker_actions.dart';
import '../../widgets/profile/profile_username_availability_controller.dart';
import '../../widgets/profile/profile_username_rules.dart';
import '../tippy/mascot/tippy_mascot.dart';
import '../tippy/mascot/tippy_mascot_types.dart';
import 'tippy_onboarding_contract.dart';
import 'tippy_onboarding_session.dart';
import 'tippy_profile_draft.dart';
import 'tippy_profile_review_preview.dart';

typedef TippyProfileDraftUpdater = Future<void> Function(
  TippyProfileDraft draft,
);

/// Guided Tippy profile setup steps after account creation.
class TippyGuidedProfileHost extends ConsumerStatefulWidget {
  const TippyGuidedProfileHost({
    super.key,
    required this.session,
    required this.onPersist,
    required this.onAdvanceStage,
    required this.busy,
    this.error,
  });

  final TippyOnboardingGuestSession session;
  final TippyProfileDraftUpdater onPersist;
  final Future<void> Function(String stage) onAdvanceStage;
  final bool busy;
  final String? error;

  @override
  TippyGuidedProfileHostState createState() => TippyGuidedProfileHostState();
}

class TippyGuidedProfileHostState
    extends ConsumerState<TippyGuidedProfileHost> {
  late TippyProfileDraft _draft;
  late final TextEditingController _displayNameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _bioController;
  late final TextEditingController _handleController;
  late final TextEditingController _platformUrlController;
  final ProfileUsernameAvailabilityController _usernameAvailability =
      ProfileUsernameAvailabilityController();
  UsernameAvailabilityStatus _usernameStatus = UsernameAvailabilityStatus.idle;
  String? _usernameMessage;
  String? _localError;
  bool _saving = false;
  bool _uploadingAvatar = false;
  String? _activeHandlePlatform;

  /// Closes nested editors (e.g. platform username) without leaving the stage.
  bool consumeBack() {
    if (_activeHandlePlatform == null) {
      return false;
    }
    setState(() {
      _activeHandlePlatform = null;
      _handleController.clear();
      _platformUrlController.clear();
    });
    return true;
  }

  @override
  void initState() {
    super.initState();
    _draft = widget.session.profileDraft;
    _displayNameController =
        TextEditingController(text: _draft.displayName);
    _usernameController = TextEditingController(text: _draft.username);
    _bioController = TextEditingController(text: _draft.bio);
    _handleController = TextEditingController();
    _platformUrlController = TextEditingController();
  }

  @override
  void didUpdateWidget(covariant TippyGuidedProfileHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session.profileDraft != widget.session.profileDraft) {
      _draft = widget.session.profileDraft;
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _handleController.dispose();
    _platformUrlController.dispose();
    _usernameAvailability.dispose();
    super.dispose();
  }

  Future<void> _saveDraft(TippyProfileDraft next) async {
    setState(() => _draft = next);
    await widget.onPersist(next);
  }

  @override
  Widget build(BuildContext context) {
    final String stage = TippyOnboardingStages.normalize(widget.session.stage);
    final String? banner = widget.error ?? _localError;
    return Column(
      children: <Widget>[
        Expanded(child: _buildStageBody(stage)),
        if (banner != null) ...<Widget>[
          const SizedBox(height: 8),
          SelectableText.rich(
            TextSpan(
              text: banner,
              style: const TextStyle(color: Color(0xFFFF6B6B)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStageBody(String stage) {
    switch (stage) {
      case TippyOnboardingStages.accountSecured:
        return _scene(
          TippyOnboardingCopy.accountSecured,
          primary: 'CONTINUE',
          onPrimary: () => widget.onAdvanceStage(TippyOnboardingStages.avatar),
        );
      case TippyOnboardingStages.avatar:
        return _buildAvatar();
      case TippyOnboardingStages.displayName:
        return _buildDisplayName();
      case TippyOnboardingStages.username:
        return _buildUsername();
      case TippyOnboardingStages.bio:
        return _buildBio();
      case TippyOnboardingStages.platforms:
        return _buildPlatforms();
      case TippyOnboardingStages.categories:
        return _buildCategories();
      case TippyOnboardingStages.profileReview:
        return _buildReview();
      default:
        return _scene(
          TippyOnboardingCopy.accountSecured,
          primary: 'CONTINUE',
          onPrimary: () => widget.onAdvanceStage(TippyOnboardingStages.avatar),
        );
    }
  }

  Widget _scene(
    String speech, {
    required String primary,
    required Future<void> Function() onPrimary,
    String? secondary,
    Future<void> Function()? onSecondary,
    Widget? body,
    TippyMascotState mascot = TippyMascotState.speaking,
  }) {
    final Widget speechAndMascot = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _GuidedBubble(text: speech),
        const SizedBox(height: 10),
        TippyMascot(state: mascot, size: 110),
      ],
    );
    return Column(
      children: <Widget>[
        if (body != null) ...<Widget>[
          speechAndMascot,
          const SizedBox(height: 14),
          Expanded(child: body),
        ] else ...<Widget>[
          const Spacer(flex: 2),
          speechAndMascot,
          const Spacer(flex: 3),
        ],
        _GuidedPrimaryButton(
          label: primary,
          busy: widget.busy || _saving,
          onPressed: () => unawaited(onPrimary()),
        ),
        if (secondary != null && onSecondary != null) ...<Widget>[
          const SizedBox(height: 8),
          TextButton(
            onPressed: widget.busy || _saving
                ? null
                : () => unawaited(onSecondary()),
            child: Text(
              secondary,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAvatar() {
    final String? previewUrl = _draft.avatarUrl;
    final File? local = _draft.localAvatarPath == null
        ? null
        : File(_draft.localAvatarPath!);
    final bool hasPhoto =
        local != null || (previewUrl != null && previewUrl.isNotEmpty);
    return _scene(
      TippyOnboardingCopy.avatarPrompt,
      primary: 'CONTINUE',
      onPrimary: () => widget.onAdvanceStage(TippyOnboardingStages.displayName),
      secondary: 'Skip for now',
      onSecondary: () async {
        await _saveDraft(_draft.copyWith(skippedAvatar: true));
        await widget.onAdvanceStage(TippyOnboardingStages.displayName);
      },
      body: Column(
        children: <Widget>[
          const SizedBox(height: 4),
          SizedBox(
            width: 112,
            height: 112,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                ClipOval(
                  child: ColoredBox(
                    color: Colors.white.withValues(alpha: 0.1),
                    child: SizedBox(
                      width: 112,
                      height: 112,
                      child: hasPhoto
                          ? (local != null
                              ? Image.file(
                                  local,
                                  fit: BoxFit.cover,
                                  width: 112,
                                  height: 112,
                                )
                              : Image.network(
                                  previewUrl!,
                                  fit: BoxFit.cover,
                                  width: 112,
                                  height: 112,
                                  errorBuilder: (
                                    BuildContext context,
                                    Object error,
                                    StackTrace? stackTrace,
                                  ) {
                                    return const Icon(
                                      Icons.person,
                                      color: Colors.white70,
                                      size: 40,
                                    );
                                  },
                                ))
                          : const Icon(
                              Icons.person,
                              color: Colors.white70,
                              size: 40,
                            ),
                    ),
                  ),
                ),
                if (_uploadingAvatar)
                  Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.45),
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Opacity(
            opacity: _uploadingAvatar ? 0.55 : 1,
            child: IgnorePointer(
              ignoring: _uploadingAvatar,
              child: _GuidedPrimaryButton(
                label: 'UPLOAD PHOTO',
                onPressed: () {
                  ProfileAvatarPickerActions.showImagePicker(
                    context,
                    hasExistingPhoto: hasPhoto,
                    onImageSelected: (File file) {
                      unawaited(_pickAvatar(file));
                    },
                  );
                },
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Future<void> _pickAvatar(File file) async {
    setState(() {
      _uploadingAvatar = true;
      _localError = null;
    });
    try {
      final firebase_auth.User? user =
          firebase_auth.FirebaseAuth.instance.currentUser;
      String? uploaded;
      if (user != null) {
        uploaded =
            await ref.read(robustAuthServiceProvider).uploadAvatar(file);
      }
      await _saveDraft(
        _draft.copyWith(
          localAvatarPath: file.path,
          avatarUrl: uploaded ?? _draft.avatarUrl,
          skippedAvatar: false,
        ),
      );
    } catch (error) {
      setState(() => _localError = 'Could not upload avatar. Try again.');
    } finally {
      if (mounted) {
        setState(() => _uploadingAvatar = false);
      }
    }
  }

  Widget _buildDisplayName() {
    return _scene(
      TippyOnboardingCopy.displayNamePrompt,
      primary: 'CONTINUE',
      onPrimary: () async {
        final String name = _displayNameController.text.trim();
        if (name.isEmpty) {
          setState(() => _localError = 'Please enter a display name.');
          return;
        }
        setState(() => _localError = null);
        final String suggested = ProfileUsernameRules.normalize(
          name.replaceAll(RegExp(r'\s+'), '_'),
        );
        TippyProfileDraft next = _draft.copyWith(displayName: name);
        if (_draft.username.trim().isEmpty &&
            suggested.length >= TippyGuidedProfileOptions.usernameMinLength) {
          next = next.copyWith(username: suggested);
          _usernameController.text = suggested;
        }
        await _saveDraft(next);
        await widget.onAdvanceStage(TippyOnboardingStages.username);
      },
      body: TextField(
        controller: _displayNameController,
        maxLength: TippyGuidedProfileOptions.displayNameMaxLength,
        style: const TextStyle(color: Colors.white),
        decoration: _fieldDecoration('Display name'),
        onChanged: (_) {
          if (_localError != null) {
            setState(() => _localError = null);
          }
        },
      ),
    );
  }

  Widget _buildUsername() {
    return _scene(
      TippyOnboardingCopy.usernamePrompt,
      primary: 'CONTINUE',
      onPrimary: () async {
        if (_usernameStatus != UsernameAvailabilityStatus.available &&
            _usernameStatus != UsernameAvailabilityStatus.idle) {
          setState(() {
            _localError = _usernameMessage ?? 'Choose an available username.';
          });
          return;
        }
        final String username =
            ProfileUsernameRules.normalize(_usernameController.text);
        if (username.length < TippyGuidedProfileOptions.usernameMinLength) {
          setState(() => _localError = 'Username is too short.');
          return;
        }
        await _saveDraft(_draft.copyWith(username: username));
        await widget.onAdvanceStage(TippyOnboardingStages.bio);
      },
      body: Column(
        children: <Widget>[
          TextField(
            controller: _usernameController,
            maxLength: TippyGuidedProfileOptions.usernameMaxLength,
            style: const TextStyle(color: Colors.white),
            decoration: _fieldDecoration('@username'),
            onChanged: _onUsernameChanged,
          ),
          const SizedBox(height: 6),
          Text(
            'streamerstip.com/streamer/${ProfileUsernameRules.normalize(_usernameController.text).isEmpty ? 'yourname' : ProfileUsernameRules.normalize(_usernameController.text)}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _usernameStatusLabel(),
            style: TextStyle(
              color: _usernameStatus == UsernameAvailabilityStatus.available
                  ? const Color(0xFF66FCF1)
                  : Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _onUsernameChanged(String value) {
    final String? uid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return;
    }
    _usernameAvailability.scheduleCheck(
      username: value,
      userId: uid,
      onStatusChanged: (UsernameAvailabilityStatus status, String? message) {
        if (!mounted) {
          return;
        }
        setState(() {
          _usernameStatus = status;
          _usernameMessage = message;
        });
      },
    );
  }

  String _usernameStatusLabel() {
    switch (_usernameStatus) {
      case UsernameAvailabilityStatus.checking:
        return 'Checking availability…';
      case UsernameAvailabilityStatus.available:
        return 'Username available';
      case UsernameAvailabilityStatus.taken:
        return 'Username already taken';
      case UsernameAvailabilityStatus.invalid:
      case UsernameAvailabilityStatus.tooShort:
        return _usernameMessage ?? 'Username not allowed';
      case UsernameAvailabilityStatus.error:
        return _usernameMessage ?? 'Could not check username';
      case UsernameAvailabilityStatus.idle:
        return 'Letters, numbers, and underscores only';
    }
  }

  Widget _buildBio() {
    return _scene(
      TippyOnboardingCopy.bioPrompt,
      primary: 'CONTINUE',
      onPrimary: () async {
        await _saveDraft(
          _draft.copyWith(
            bio: _bioController.text.trim(),
            skippedBio: _bioController.text.trim().isEmpty,
          ),
        );
        await widget.onAdvanceStage(TippyOnboardingStages.platforms);
      },
      secondary: 'Skip for now',
      onSecondary: () async {
        await _saveDraft(_draft.copyWith(bio: '', skippedBio: true));
        await widget.onAdvanceStage(TippyOnboardingStages.platforms);
      },
      body: TextField(
        controller: _bioController,
        maxLength: TippyGuidedProfileOptions.bioMaxLength,
        maxLines: 4,
        style: const TextStyle(color: Colors.white),
        decoration: _fieldDecoration('Bio'),
      ),
    );
  }

  Widget _buildPlatforms() {
    if (_activeHandlePlatform != null) {
      return _buildPlatformHandleEditor(_activeHandlePlatform!);
    }
    return _scene(
      TippyOnboardingCopy.platformsPrompt,
      primary: 'CONTINUE',
      onPrimary: () => widget.onAdvanceStage(TippyOnboardingStages.categories),
      body: ListView(
        children: TippyGuidedProfileOptions.platforms.map(
          (({String id, String label}) option) {
            final bool selected = _draft.platformIds.contains(option.id);
            final String handle = _draft.platformHandles[option.id] ?? '';
            final String url = _draft.platformUrls[option.id] ?? '';
            final String subtitle = handle.isNotEmpty
                ? (url.isNotEmpty ? '@$handle · $url' : '@$handle')
                : url;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.22)
                    : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () async {
                    final List<String> next =
                        List<String>.from(_draft.platformIds);
                    if (selected) {
                      next.remove(option.id);
                      final Map<String, String> handles =
                          Map<String, String>.from(_draft.platformHandles)
                            ..remove(option.id);
                      final Map<String, String> urls =
                          Map<String, String>.from(_draft.platformUrls)
                            ..remove(option.id);
                      await _saveDraft(
                        _draft.copyWith(
                          platformIds: next,
                          platformHandles: handles,
                          platformUrls: urls,
                        ),
                      );
                    } else {
                      next.add(option.id);
                      await _saveDraft(_draft.copyWith(platformIds: next));
                      setState(() {
                        _activeHandlePlatform = option.id;
                        _handleController.text = _usernameFromStoredHandle(
                          option.id,
                          handle,
                        );
                        _platformUrlController.text = url;
                      });
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                option.label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (subtitle.isNotEmpty)
                                Text(
                                  subtitle,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                        if (selected)
                          IconButton(
                            tooltip: 'Edit link',
                            onPressed: () {
                              setState(() {
                                _activeHandlePlatform = option.id;
                                _handleController.text =
                                    _usernameFromStoredHandle(
                                  option.id,
                                  handle,
                                );
                                _platformUrlController.text = url;
                              });
                            },
                            icon: const Icon(
                              Icons.edit_outlined,
                              color: Colors.white70,
                              size: 20,
                            ),
                          ),
                        Icon(
                          selected
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          color: selected
                              ? const Color(0xFF66FCF1)
                              : Colors.white54,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ).toList(),
      ),
    );
  }

  Widget _buildPlatformHandleEditor(String platformId) {
    final String label = TippyGuidedProfileOptions.platforms
        .firstWhere(
          (({String id, String label}) p) => p.id == platformId,
          orElse: () => (id: platformId, label: platformId),
        )
        .label;
    final String? preview = PlatformRules.previewPlatformUrl(
      platformId,
      _handleController.text.trim().isNotEmpty
          ? _handleController.text
          : _platformUrlController.text,
    );
    return _scene(
      'Add your $label username and profile URL.',
      primary: 'SAVE',
      onPrimary: () async {
        final Map<String, String> handles =
            Map<String, String>.from(_draft.platformHandles);
        final Map<String, String> urls =
            Map<String, String>.from(_draft.platformUrls);
        final Map<String, dynamic> entry =
            PlatformRules.buildEditablePlatformEntry(
          type: platformId,
          username: _handleController.text,
          url: _platformUrlController.text,
          id: 'tippy_$platformId',
        );
        final String username = (entry['username']?.toString() ?? '').trim();
        final String url = (entry['url']?.toString() ?? '').trim();
        if (username.isEmpty) {
          handles.remove(platformId);
        } else {
          handles[platformId] = username;
        }
        if (url.isEmpty) {
          urls.remove(platformId);
        } else {
          urls[platformId] = url;
        }
        await _saveDraft(
          _draft.copyWith(platformHandles: handles, platformUrls: urls),
        );
        setState(() => _activeHandlePlatform = null);
      },
      secondary: 'Skip for now',
      onSecondary: () async {
        setState(() => _activeHandlePlatform = null);
      },
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PlatformHandleInputField(
            platformType: platformId,
            controller: _handleController,
            onChanged: () => setState(() {}),
            onClear: () {
              _handleController.clear();
              setState(() {});
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _platformUrlController,
            onChanged: (_) => setState(() {}),
            keyboardType: TextInputType.url,
            textCapitalization: TextCapitalization.none,
            autocorrect: false,
            enableSuggestions: false,
            style: const TextStyle(color: Colors.white),
            decoration: _fieldDecoration(
              'Full profile URL (optional)',
            ).copyWith(
              hintText: PlatformRules.displayUrlPrefix(platformId).isEmpty
                  ? 'https://…'
                  : PlatformRules.displayUrlPrefix(platformId),
            ),
          ),
          if (preview != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              'Saved as: $preview',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _usernameFromStoredHandle(String platformId, String stored) {
    String value = stored.trim();
    if (value.isEmpty) {
      return '';
    }
    value = value.replaceFirst(RegExp(r'^https?://', caseSensitive: false), '');
    value = value.replaceFirst(RegExp(r'^www\.', caseSensitive: false), '');
    final String prefix = PlatformRules.displayUrlPrefix(platformId)
        .replaceFirst(RegExp(r'^https?://', caseSensitive: false), '')
        .replaceFirst(RegExp(r'^www\.', caseSensitive: false), '');
    if (prefix.isNotEmpty &&
        value.toLowerCase().startsWith(prefix.toLowerCase())) {
      value = value.substring(prefix.length);
    }
    if (value.startsWith('@')) {
      value = value.substring(1);
    }
    return value.trim();
  }

  Widget _buildCategories() {
    return _scene(
      TippyOnboardingCopy.categoriesPrompt,
      primary: 'CONTINUE',
      onPrimary: () =>
          widget.onAdvanceStage(TippyOnboardingStages.profileReview),
      body: ListView(
        children: TippyGuidedProfileOptions.categories.map(
          (({String id, String label}) option) {
            final bool selected = _draft.categoryIds.contains(option.id);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ChipTile(
                label: option.label,
                selected: selected,
                onTap: () async {
                  final List<String> next =
                      List<String>.from(_draft.categoryIds);
                  if (selected) {
                    next.remove(option.id);
                  } else {
                    next.add(option.id);
                  }
                  await _saveDraft(_draft.copyWith(categoryIds: next));
                },
              ),
            );
          },
        ).toList(),
      ),
    );
  }

  Widget _buildReview() {
    return Column(
      children: <Widget>[
        _GuidedBubble(text: TippyOnboardingCopy.profileReviewPrompt),
        const SizedBox(height: 10),
        Expanded(
          child: TippyProfileReviewPreview(draft: _draft),
        ),
        const SizedBox(height: 12),
        _GuidedPrimaryButton(
          label: 'CREATE MY PROFILE',
          busy: widget.busy || _saving,
          onPressed: () => unawaited(_commitProfile()),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: widget.busy || _saving
              ? null
              : () => unawaited(
                    widget.onAdvanceStage(TippyOnboardingStages.username),
                  ),
          child: Text(
            'Edit username',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _commitProfile() async {
    final firebase_auth.User? user =
        firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _localError = 'Please sign in to create your profile.');
      return;
    }
    if (!_draft.hasEssentialIdentity) {
      setState(() {
        _localError = 'Display name and username are required.';
      });
      return;
    }
    setState(() {
      _saving = true;
      _localError = null;
    });
    try {
      final String username =
          ProfileUsernameRules.normalize(_draft.username);
      final bool available =
          await UsernameLockService().isUsernameAvailableForUser(
        username,
        user.uid,
      );
      if (!available) {
        setState(() {
          _localError = 'Username is no longer available.';
          _saving = false;
        });
        await widget.onAdvanceStage(TippyOnboardingStages.username);
        return;
      }
      await UsernameLockService().reserveUsername(
        username: username,
        userId: user.uid,
        previousUsername: (await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get())
            .data()?['username'] as String?,
        allowSoftSkip: true,
      );
      await _persistDisplayNameViaApi(
        user: user,
        displayName: _draft.displayName.trim(),
      );
      try {
        if (_draft.displayName.trim().isNotEmpty) {
          await user.updateDisplayName(_draft.displayName.trim());
        }
      } catch (error) {
        debugPrint('Tippy Auth displayName update skipped: $error');
      }
      await user.reload();
      final firebase_auth.User? refreshed =
          firebase_auth.FirebaseAuth.instance.currentUser;
      if (refreshed == null) {
        throw StateError('unauthenticated: signed out during profile create');
      }
      if (refreshed.emailVerified != true) {
        throw StateError(
          'EMAIL_VERIFICATION: verify your email before creating your profile',
        );
      }
      final List<Map<String, dynamic>> platforms = _draft.platformIds
          .map(
            (String id) {
              return PlatformRules.buildEditablePlatformEntry(
                type: id,
                username: _draft.platformHandles[id] ?? '',
                url: _draft.platformUrls[id] ?? '',
                id: 'tippy_$id',
                isConnected: false,
              );
            },
          )
          .toList();
      final String categoryId = _draft.categoryIds.isNotEmpty
          ? _draft.categoryIds.first
          : 'gaming';
      await OnboardingService().saveGuidedTippyProfile(
        userId: refreshed.uid,
        displayName: _draft.displayName.trim(),
        username: username,
        bio: _draft.bio.trim(),
        categoryId: categoryId,
        categoryIds: _draft.categoryIds,
        platforms: platforms,
        avatarUrl: _draft.avatarUrl,
      );
      await widget.onAdvanceStage(TippyOnboardingStages.findFriends);
    } catch (error, stackTrace) {
      debugPrint('Tippy create profile failed: $error');
      debugPrint('$stackTrace');
      setState(() {
        _localError = _friendlyCommitError(error);
      });
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _persistDisplayNameViaApi({
    required firebase_auth.User user,
    required String displayName,
  }) async {
    final String trimmed = displayName.trim();
    if (trimmed.isEmpty) {
      return;
    }
    try {
      final String? idToken = await user.getIdToken(true);
      if (idToken == null || idToken.isEmpty) {
        debugPrint('Tippy displayName API soft-skip: missing id token');
        return;
      }
      final Map<String, String> headers =
          await buildAuthenticatedHttpHeaders(
        idToken: idToken,
        extra: const <String, String>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );
      final http.Response response = await http
          .post(
            Uri.parse(siteProfileDisplayNameUrl()),
            headers: headers,
            body: jsonEncode(<String, dynamic>{'displayName': trimmed}),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return;
      }
      debugPrint(
        'Tippy displayName API soft-skip: status=${response.statusCode} '
        'body=${response.body}',
      );
    } catch (error) {
      debugPrint('Tippy displayName API soft-skip: $error');
    }
  }

  String _friendlyCommitError(Object error) {
    if (error is UsernameTakenException) {
      return 'That username was just taken. Pick another.';
    }
    if (error is UsernameClaimException) {
      return error.message;
    }
    final String raw = error.toString();
    final String lower = raw.toLowerCase();
    if (lower.contains('email_verification') ||
        lower.contains('verify your email') ||
        (lower.contains('email') && lower.contains('verif'))) {
      return 'Verify your email before creating your profile.';
    }
    if (lower.contains('permission-denied') ||
        lower.contains('permission_denied')) {
      return 'Could not save profile. Verify your email if needed, then try again.';
    }
    if (lower.contains('unauthenticated') ||
        lower.contains('not signed in') ||
        lower.contains('session expired')) {
      return 'Your session expired. Sign in again, then create your profile.';
    }
    if (raw.contains('network') || raw.contains('SocketException')) {
      return 'Network issue — check connection and try again.';
    }
    if (raw.contains('Invalid username') || raw.contains('already taken')) {
      return 'Username issue — go back and choose another.';
    }
    return 'Could not create profile. Your answers are saved — try again.';
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.08),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    );
  }
}

class _GuidedBubble extends StatelessWidget {
  const _GuidedBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          height: 1.35,
        ),
      ),
    );
  }
}

class _GuidedPrimaryButton extends StatelessWidget {
  const _GuidedPrimaryButton({
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: busy ? 0.85 : 1,
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              colors: <Color>[
                AppColors.primary,
                Color(0xFF7768DF),
                Color(0xFF4897D2),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.38),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: const Color(0xFF4897D2).withValues(alpha: 0.28),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: busy ? null : onPressed,
              borderRadius: BorderRadius.circular(18),
              child: Center(
                child: busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChipTile extends StatelessWidget {
  const _ChipTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.28)
          : Colors.white.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
