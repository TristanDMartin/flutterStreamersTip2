import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/onboarding/account_status_client.dart';
import '../../components/onboarding/complete_onboarding_client.dart';
import '../../components/onboarding/complete_verified_activation.dart';
import '../../components/onboarding/onboarding_service.dart';
import '../../constants/app_colors.dart';
import '../../services/product_event_tracking_service.dart';
import '../../services/robust_auth_service.dart';
import '../../services/username_lock_service.dart';
import '../../utils/platform_rules.dart';
import '../../widgets/profile/platform_handle_input_field.dart';
import '../../widgets/profile/profile_avatar_picker_actions.dart';
import '../../widgets/profile/profile_username_availability_controller.dart';
import '../../widgets/profile/profile_username_rules.dart';
import '../../widgets/profile/profile_username_utils.dart';
import '../tippy/mascot/tippy_mascot.dart';
import '../tippy/mascot/tippy_mascot_types.dart';
import 'tippy_onboarding_contract.dart';
import 'tippy_onboarding_debug_log.dart';
import 'tippy_onboarding_feedback.dart';
import 'tippy_onboarding_session.dart';
import 'tippy_profile_draft.dart';
import 'tippy_profile_review_preview.dart';

const List<Color> _webOnboardingPrimaryGradient = <Color>[
  Color(0xFF6B3AA0),
  Color(0xFF4A2570),
];

typedef TippyProfileDraftUpdater = Future<void> Function(
  TippyProfileDraft draft,
);
typedef TippyGuidedProfileBackConsumer = bool Function();

/// Guided Tippy profile setup steps after account creation.
class TippyGuidedProfileHost extends ConsumerStatefulWidget {
  const TippyGuidedProfileHost({
    super.key,
    required this.session,
    required this.onPersist,
    required this.onAdvanceStage,
    required this.busy,
    this.error,
    this.onBackConsumerChanged,
  });

  final TippyOnboardingGuestSession session;
  final TippyProfileDraftUpdater onPersist;
  final Future<void> Function(String stage) onAdvanceStage;
  final bool busy;
  final String? error;
  final ValueChanged<TippyGuidedProfileBackConsumer?>? onBackConsumerChanged;

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
  String? _ownedUsername;
  String? _preferredUsername;
  /// Confirmed by successful username-change response; blocks stale status overwrite.
  String? _usernameMutationConfirmed;
  /// Blocks background identity/bio hydrate from overwriting a remixed bio.
  bool _bioDirty = false;
  String? _localError;
  bool _saving = false;
  bool _dnaSeedPersistScheduled = false;
  bool _uploadingAvatar = false;
  bool _avatarSuccessFlash = false;
  bool _stageMotionForward = true;
  bool _canonicalUsernameReady = false;
  bool _accountProvisioned = false;
  bool _waitingForCanonical = false;
  bool _activationReconcileBlocked = false;
  String? _activeHandlePlatform;
  bool _changingUsername = false;
  int _identityPollAttempt = 0;

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
    final String seededHandle =
        tippyIdentityFromUsername(_draft.username).username;
    if (seededHandle.isNotEmpty) {
      _ownedUsername = seededHandle;
      _preferredUsername = seededHandle;
    }
    final String authName =
        (firebase_auth.FirebaseAuth.instance.currentUser?.displayName ?? '')
            .trim();
    _displayNameController = TextEditingController(
      text: seedCreatorCallName(
        ownedUsername: _draft.username,
        draftDisplayName: _draft.displayName,
        authDisplayName: authName,
      ),
    );
    _usernameController = TextEditingController(text: _draft.username);
    _bioController = TextEditingController(text: _draft.bio);
    _handleController = TextEditingController();
    _platformUrlController = TextEditingController();
    widget.onBackConsumerChanged?.call(consumeBack);
    _seedDnaDraftIfNeeded();
    unawaited(_seedIdentityFromSignedInAccount());
  }

  @override
  void didUpdateWidget(covariant TippyGuidedProfileHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String oldStage =
        TippyOnboardingStages.normalize(oldWidget.session.stage);
    final String newStage =
        TippyOnboardingStages.normalize(widget.session.stage);
    if (oldStage != newStage) {
      _stageMotionForward = TippyOnboardingStages.isAtOrAfter(
        newStage,
        oldStage,
      );
    }
    if (oldWidget.session.profileDraft != widget.session.profileDraft) {
      final TippyProfileDraft incoming = widget.session.profileDraft;
      final String localBio = _bioController.text.trim();
      if (_bioDirty && localBio.isNotEmpty) {
        _draft = incoming.copyWith(
          bio: localBio,
          bioRemixCount: _draft.bioRemixCount,
          bioRemixHistory: _draft.bioRemixHistory,
        );
      } else {
        _draft = localBio.isNotEmpty && incoming.bio.trim().isEmpty
            ? incoming.copyWith(bio: localBio)
            : incoming;
        if (_bioController.text.trim().isEmpty &&
            _draft.bio.trim().isNotEmpty) {
          _bioController.text = _draft.bio;
        }
      }
      if (_displayNameController.text.trim().isEmpty &&
          _draft.displayName.trim().isNotEmpty) {
        _displayNameController.text = _draft.displayName;
      }
    }
    final String stage = TippyOnboardingStages.normalize(widget.session.stage);
    if (stage == TippyOnboardingStages.username &&
        oldStage != TippyOnboardingStages.username) {
      unawaited(
        _seedIdentityFromSignedInAccount(
          forceActivation: !_accountProvisioned && !_activationReconcileBlocked,
        ),
      );
    }
    if (stage == TippyOnboardingStages.bio ||
        stage == TippyOnboardingStages.platformHandles) {
      _seedDnaDraftIfNeeded();
    }
  }

  void _seedDnaDraftIfNeeded() {
    final TippyProfileDraft seeded = _bioDirty
        ? applyCheckupProfilesToProfileDraft(
            draft: _draft,
            checkupProfiles: widget.session.checkupProfiles,
          )
        : applyDnaAnswersToProfileDraft(
            draft: _draft,
            answers: widget.session.answers,
            checkupProfiles: widget.session.checkupProfiles,
          );
    if (_bioController.text.trim().isEmpty && seeded.bio.isNotEmpty) {
      _bioController.text = seeded.bio;
    }
    final bool unchanged = seeded.bio == _draft.bio &&
        seeded.platformIds.join(',') == _draft.platformIds.join(',') &&
        seeded.categoryIds.join(',') == _draft.categoryIds.join(',') &&
        seeded.platformHandles.toString() ==
            _draft.platformHandles.toString();
    if (unchanged) {
      return;
    }
    _draft = seeded;
    logTippyActivationProof(
      '[ACTIVATION_PROOF] event=bio_seeded answers=${widget.session.answers.length} '
      'bioLen=${seeded.bio.length}',
    );
    if (_dnaSeedPersistScheduled) {
      return;
    }
    _dnaSeedPersistScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _dnaSeedPersistScheduled = false;
      if (!mounted) {
        return;
      }
      unawaited(_saveDraft(seeded));
    });
  }

  bool _isUsernameStepReady() {
    if ((_ownedUsername ?? '').trim().isNotEmpty) {
      return true;
    }
    return resolveCreatorUsernameScreen(
          statusLoaded: _canonicalUsernameReady,
          canonicalUsername: _ownedUsername,
          preferredUsername: _preferredUsername,
          provisioned: _accountProvisioned,
        ) ==
        CreatorUsernameScreenState.select;
  }

  String _ownedUsernameFromStatus(AccountStatusSnapshot status) {
    final String preferred = (status.preferredUsername ?? '').trim().isNotEmpty
        ? status.preferredUsername!.trim()
        : widget.session.profileDraft.username;
    return ownedUsernameFromAccountStatus(
      canonicalUsername: status.canonicalUsername,
      username: status.username,
      preferredUsername: preferred,
      draftUsername: widget.session.profileDraft.username,
      email: firebase_auth.FirebaseAuth.instance.currentUser?.email,
    );
  }

  Future<void> _fillCreatorCallNameFromAuth(
    firebase_auth.User user,
  ) async {
    final String next = seedCreatorCallName(
      ownedUsername: _ownedUsername,
      draftDisplayName: _displayNameController.text,
      authDisplayName: user.displayName,
    );
    if (next.isEmpty) {
      return;
    }
    _displayNameController.text = next;
    final String derived = tippyIdentityFromUsername(next).username;
    final String emailLocal = emailLocalPartUsername(user.email);
    await _saveDraft(
      _draft.copyWith(
        displayName: next,
        username: derived == emailLocal ? _draft.username : derived,
      ),
    );
  }

  Future<bool> _ensureCanonicalIdentity() async {
    if (_isUsernameStepReady()) {
      return true;
    }
    for (int attempt = 0; attempt < 8; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
        if (!mounted) {
          return false;
        }
      }
      await _seedIdentityFromSignedInAccount(
        forceActivation: attempt > 0 && !_activationReconcileBlocked,
      );
      if (_isUsernameStepReady()) {
        return true;
      }
      if (_activationReconcileBlocked) {
        return false;
      }
    }
    return _isUsernameStepReady();
  }

  /// Prefill username from status claim or the signup reservation.
  Future<void> _seedIdentityFromSignedInAccount({
    bool forceActivation = false,
  }) async {
    final firebase_auth.User? user =
        firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }
    try {
      AccountStatusSnapshot status = await fetchAccountStatus();
      String owned = _ownedUsernameFromStatus(status);
      if (owned.isEmpty) {
        owned = tippyIdentityFromUsername(
          (await TippyOnboardingSessionStore().peekSignupUsername(
                uid: user.uid,
              )) ??
              widget.session.profileDraft.username,
        ).username;
      }
      logTippyActivationProof(
        '[ACTIVATION_PROOF] event=status_returned t=${DateTime.now().toUtc().toIso8601String()} canonicalUsername=$owned username=${status.username} preferredUsername=${status.preferredUsername} provisioned=${status.provisioned}',
      );
      final String stage =
          TippyOnboardingStages.normalize(widget.session.stage);
      final bool shouldReconcile = !_activationReconcileBlocked &&
          !status.provisioned &&
          (forceActivation || stage == TippyOnboardingStages.username) &&
          (status.preferredUsername ?? '').trim().isNotEmpty;
      if (shouldReconcile) {
        try {
          status = await completeVerifiedActivation(intendedUid: user.uid);
          owned = _ownedUsernameFromStatus(status);
        } on VerifiedActivationException catch (error) {
          logTippyActivationProof(
        '[ACTIVATION_PROOF] event=activation_reconcile_stopped code=${error.code} httpStatus=${error.status}',
          );
          if (!isRetryableVerifiedActivationFailure(
            code: error.code,
            status: error.status,
          )) {
            _activationReconcileBlocked = true;
          } else {
            rethrow;
          }
        }
      }
      if (!mounted) {
        return;
      }
      if (_changingUsername) {
        setState(() {
          _canonicalUsernameReady = true;
          _accountProvisioned = status.provisioned;
        });
        return;
      }
      if (owned.isEmpty) {
        owned = tippyIdentityFromUsername(
          widget.session.profileDraft.username,
        ).username;
      }
      final String mutation = (_usernameMutationConfirmed ?? '').trim();
      if (mutation.isNotEmpty &&
          owned.isNotEmpty &&
          owned != mutation) {
        owned = mutation;
      }
      final String statusPreferred =
          tippyIdentityFromUsername(status.preferredUsername ?? '').username;
      _preferredUsername = statusPreferred.isNotEmpty
          ? statusPreferred
          : (owned.isNotEmpty ? owned : null);
      if (mutation.isNotEmpty) {
        _preferredUsername = mutation;
      }
      _ownedUsername = owned.isEmpty ? null : owned;
      setState(() {
        _canonicalUsernameReady = true;
        _accountProvisioned = status.provisioned;
      });
      if (owned.isEmpty) {
        final String emailLocal = emailLocalPartUsername(user.email);
        if (emailLocal.isNotEmpty && _draft.username == emailLocal) {
          await _saveDraft(_draft.copyWith(username: ''));
        }
        await _fillCreatorCallNameFromAuth(user);
        if (mounted &&
            TippyOnboardingStages.normalize(widget.session.stage) ==
                TippyOnboardingStages.username &&
            !_isUsernameStepReady() &&
            !_activationReconcileBlocked &&
            _identityPollAttempt < 8) {
          _identityPollAttempt += 1;
          Future<void>.delayed(const Duration(milliseconds: 400), () {
            if (mounted &&
                !_isUsernameStepReady() &&
                !_activationReconcileBlocked) {
              unawaited(
                _seedIdentityFromSignedInAccount(forceActivation: true),
              );
            }
          });
        }
        return;
      }
      _identityPollAttempt = 0;
      final ({String username, String displayName}) identity =
          tippyIdentityFromUsername(owned);
      final TippyProfileDraft next = _draft.copyWith(
        displayName: _draft.displayName.trim().isNotEmpty
            ? _draft.displayName
            : identity.username,
        username: identity.username,
      );
      _usernameController.text = next.username;
      if (_displayNameController.text.trim().isEmpty) {
        _displayNameController.text = next.displayName;
      }
      if (_ownsUsername(identity.username)) {
        _usernameStatus = UsernameAvailabilityStatus.available;
        _usernameMessage = 'Username available';
      }
      await _saveDraft(next);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _canonicalUsernameReady =
            _accountProvisioned || _canonicalUsernameReady;
      });
      if (TippyOnboardingStages.normalize(widget.session.stage) ==
              TippyOnboardingStages.username &&
          !_activationReconcileBlocked &&
          !_isUsernameStepReady() &&
          _identityPollAttempt < 8) {
        _identityPollAttempt += 1;
        Future<void>.delayed(const Duration(milliseconds: 400), () {
          if (mounted &&
              !_isUsernameStepReady() &&
              !_activationReconcileBlocked) {
            unawaited(_seedIdentityFromSignedInAccount(forceActivation: true));
          }
        });
      }
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
    widget.onBackConsumerChanged?.call(null);
    super.dispose();
  }

  Future<void> _saveDraft(TippyProfileDraft next) async {
    if (!mounted) {
      return;
    }
    setState(() => _draft = next);
    await widget.onPersist(next);
  }

  bool _ownsUsername(String candidate) {
    return isOwnedTippyUsername(candidate, _ownedUsername) ||
        isOwnedTippyUsername(candidate, _preferredUsername);
  }

  List<Map<String, String?>> _platformsPayload() {
    return _draft.platformIds.map((String id) {
      final String handle = (_draft.platformHandles[id] ?? '')
          .trim()
          .replaceFirst(RegExp(r'^@+'), '');
      final String url = (_draft.platformUrls[id] ?? '').trim();
      return <String, String?>{
        'type': id,
        'username': handle.isEmpty ? null : handle,
        'url': url.isEmpty ? null : url,
      };
    }).toList();
  }

  Future<CompleteOnboardingResult?> _persistProgress({
    String? username,
    String? bio,
    List<Map<String, String?>>? platforms,
    List<String>? platformIds,
    bool? allowUsernameChange,
    required bool hardFail,
  }) async {
    try {
      return await completeOnboarding(
        username: username,
        bio: bio,
        platforms: platforms,
        platformIds: platformIds ?? _draft.platformIds,
        answers: widget.session.answers,
        sessionId: widget.session.sessionId,
        allowUsernameChange: allowUsernameChange ?? _changingUsername,
        finalize: false,
      );
    } catch (error) {
      if (hardFail) {
        rethrow;
      }
      return null;
    }
  }

  void _hydrateCanonicalUsername(String username) {
    final String owned = tippyIdentityFromUsername(username).username;
    if (owned.isEmpty) {
      return;
    }
    _usernameMutationConfirmed = owned;
    _ownedUsername = owned;
    _preferredUsername = owned;
    _usernameController.text = owned;
  }

  @override
  Widget build(BuildContext context) {
    final String stage = TippyOnboardingStages.normalize(widget.session.stage);
    final String? banner = widget.error ?? _localError;
    return Column(
      children: <Widget>[
        Expanded(
          child: AnimatedSwitcher(
            duration: tippyStageTransitionDuration(context),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            layoutBuilder: (
              Widget? currentChild,
              List<Widget> previousChildren,
            ) {
              return SizedBox.expand(
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    ...previousChildren,
                    if (currentChild != null) currentChild,
                  ],
                ),
              );
            },
            transitionBuilder: (Widget child, Animation<double> animation) {
              final Offset begin = _stageMotionForward
                  ? const Offset(0.06, 0)
                  : const Offset(-0.06, 0);
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: begin,
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: KeyedSubtree(
              key: ValueKey<String>(stage),
              child: _buildStageBody(stage),
            ),
          ),
        ),
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
          secondarySpeech: TippyOnboardingCopy.accountSecuredNext,
          primary: 'CONTINUE',
          onPrimary: () async {
            unawaited(widget.onAdvanceStage(TippyOnboardingStages.avatar));
          },
        );
      case TippyOnboardingStages.avatar:
        return _buildAvatar();
      case TippyOnboardingStages.displayName:
      case TippyOnboardingStages.username:
        return _buildDisplayName();
      case TippyOnboardingStages.bio:
        return _buildBio();
      case TippyOnboardingStages.platformHandles:
        return _buildPlatforms();
      case TippyOnboardingStages.profileReview:
        return _buildReview();
      default:
        return _scene(
          TippyOnboardingCopy.accountSecured,
          secondarySpeech: TippyOnboardingCopy.accountSecuredNext,
          primary: 'CONTINUE',
          onPrimary: () async {
            unawaited(widget.onAdvanceStage(TippyOnboardingStages.avatar));
          },
        );
    }
  }

  Widget _scene(
    String speech, {
    required String primary,
    required Future<void> Function() onPrimary,
    String? secondarySpeech,
    String? secondary,
    Future<void> Function()? onSecondary,
    Widget? body,
    TippyMascotState mascot = TippyMascotState.speaking,
  }) {
    final Widget speechAndMascot = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _GuidedBubble(text: speech),
        if (secondarySpeech != null) ...<Widget>[
          const SizedBox(height: 10),
          Text(
            secondarySpeech,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              height: 1.35,
            ),
          ),
        ],
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
          busy: widget.busy || _saving || _waitingForCanonical,
          onPressed: () => unawaited(onPrimary()),
        ),
        if (secondary != null && onSecondary != null) ...<Widget>[
          const SizedBox(height: 8),
          TextButton(
            onPressed: widget.busy || _saving || _waitingForCanonical
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
    final File? local =
        _draft.localAvatarPath == null ? null : File(_draft.localAvatarPath!);
    final bool hasPhoto =
        local != null || (previewUrl != null && previewUrl.isNotEmpty);
    final firebase_auth.User? authUser =
        firebase_auth.FirebaseAuth.instance.currentUser;
    final String initialLetter =
        ProfileUsernameUtils.resolveAvatarInitialLetter(
      <String, dynamic>{
        'displayName': _draft.displayName,
        'username': _draft.username,
        'email': authUser?.email,
      },
      fallbacks: <String?>[authUser?.displayName],
    );
    return _scene(
      TippyOnboardingCopy.avatarPrompt,
      primary: _waitingForCanonical ? 'FINISHING ACCOUNT' : 'CONTINUE',
      onPrimary: () => _continueFromAvatar(skipped: false, hasPhoto: hasPhoto),
      secondary: 'Skip for now',
      onSecondary: () => _continueFromAvatar(skipped: true, hasPhoto: hasPhoto),
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
                                    return Center(
                                      child: Text(
                                        initialLetter,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 40,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    );
                                  },
                                ))
                          : Center(
                              child: Text(
                                initialLetter,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 40,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
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
            opacity: 1,
            child: _GuidedPrimaryButton(
              label: _uploadingAvatar ? 'PHOTO SELECTED' : 'UPLOAD PHOTO',
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
          if (_avatarSuccessFlash) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              'Looking good',
              style: TextStyle(
                color: const Color(0xFF6EE7B7),
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
          const Spacer(),
        ],
      ),
    );
  }

  Future<void> _continueFromAvatar({
    required bool skipped,
    required bool hasPhoto,
  }) async {
    if (_waitingForCanonical || _uploadingAvatar) {
      return;
    }
    if (!skipped && hasPhoto) {
      tippyConfirmHaptic(context);
    }
    if (skipped) {
      await _saveDraft(_draft.copyWith(skippedAvatar: true));
    }
    final String uid =
        firebase_auth.FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isNotEmpty && (skipped || hasPhoto)) {
      await OnboardingService().markPhotoStatus(
        userId: uid,
        status: skipped ? 'skipped' : 'uploaded',
      );
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _waitingForCanonical = true;
      _localError = null;
    });
    final bool ready = await _ensureCanonicalIdentity();
    if (!mounted) {
      return;
    }
    setState(() => _waitingForCanonical = false);
    if (!ready) {
      logTippyActivationProof(
        '[ACTIVATION_PROOF] event=username_wait_canonical t=${DateTime.now().toUtc().toIso8601String()} provisioned=$_accountProvisioned canonicalUsername=${_ownedUsername ?? ''}',
      );
      setState(() {
        _localError = _activationReconcileBlocked
            ? 'Could not finish creating your account. Try again later.'
            : null;
      });
      return;
    }
    await widget.onAdvanceStage(TippyOnboardingStages.username);
  }

  Future<void> _pickAvatar(File file) async {
    logTippyActivationProof(
        '[ACTIVATION_PROOF] event=avatar_selected t=${DateTime.now().toUtc().toIso8601String()}',
    );
    try {
      await _saveDraft(
        _draft.copyWith(
          localAvatarPath: file.path,
          skippedAvatar: false,
        ),
      );
    } catch (error) {
      logTippyActivationProof(
        '[ACTIVATION_PROOF] event=avatar_preview_persist_failed t=${DateTime.now().toUtc().toIso8601String()} error=$error',
      );
    }
    logTippyActivationProof(
        '[ACTIVATION_PROOF] event=avatar_preview_visible t=${DateTime.now().toUtc().toIso8601String()}',
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _uploadingAvatar = true;
      _localError = null;
    });
    final RobustAuthenticationService auth;
    try {
      auth = ref.read(robustAuthServiceProvider);
    } catch (error) {
      logTippyActivationProof(
        '[ACTIVATION_PROOF] event=avatar_lifecycle_blocked t=${DateTime.now().toUtc().toIso8601String()} error=$error',
      );
      if (mounted) {
        setState(() => _uploadingAvatar = false);
      }
      return;
    }
    String? uploadedUrl;
    try {
      uploadedUrl = await auth.uploadAvatar(file);
      if (uploadedUrl.trim().isEmpty) {
        throw StateError('Avatar upload returned an empty URL.');
      }
    } catch (error) {
      logTippyActivationProof(
        '[ACTIVATION_PROOF] event=avatar_upload_failed t=${DateTime.now().toUtc().toIso8601String()} error=$error',
      );
      if (mounted) {
        setState(() {
          _uploadingAvatar = false;
          _localError = 'Could not upload avatar. Try again.';
        });
      }
      return;
    }
    logTippyActivationProof(
        '[ACTIVATION_PROOF] event=avatar_upload_completed t=${DateTime.now().toUtc().toIso8601String()}',
    );
    if (mounted) {
      tippySuccessHaptic(context);
      setState(() => _avatarSuccessFlash = true);
      Future<void>.delayed(const Duration(milliseconds: 900), () {
        if (mounted) {
          setState(() => _avatarSuccessFlash = false);
        }
      });
    }
    try {
      await _saveDraft(
        _draft.copyWith(
          localAvatarPath: file.path,
          avatarUrl: uploadedUrl,
          skippedAvatar: false,
        ),
      );
    } catch (error) {
      logTippyActivationProof(
        '[ACTIVATION_PROOF] event=avatar_persist_failed t=${DateTime.now().toUtc().toIso8601String()} error=$error',
      );
    }
    if (mounted) {
      setState(() => _uploadingAvatar = false);
    }
  }

  Widget _buildDisplayName() {
    final String canonicalUsername = (_ownedUsername ?? '').trim();
    final String lockedHandle = tippyIdentityFromUsername(
      canonicalUsername.isNotEmpty
          ? canonicalUsername
          : (_preferredUsername ?? ''),
    ).username;
    final bool locked = !_changingUsername && lockedHandle.isNotEmpty;
    if (locked) {
      return _scene(
        TippyOnboardingCopy.usernameLockedTitle,
        primary: 'CONTINUE',
        onPrimary: () async {
          if (_saving) {
            return;
          }
          setState(() {
            _saving = true;
            _localError = null;
          });
          // Phase 1J.1: advance immediately; persist in background.
          unawaited(widget.onAdvanceStage(TippyOnboardingStages.bio));
          try {
            await _persistProgress(
              username: lockedHandle,
              hardFail: true,
            );
          } catch (error) {
            if (mounted) {
              setState(() => _localError = _friendlyCommitError(error));
            }
          } finally {
            if (mounted) {
              setState(() => _saving = false);
            }
          }
        },
        secondary: TippyOnboardingCopy.usernameChange,
        onSecondary: () async {
          setState(() => _changingUsername = true);
        },
        body: Column(
          children: <Widget>[
            Text(
              TippyOnboardingCopy.usernameLockedBody,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '@$lockedHandle',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'streamerstip.com/streamer/$lockedHandle',
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            ),
          ],
        ),
      );
    }
    final String previewHandle = tippyIdentityFromUsername(
      _changingUsername
          ? _usernameController.text
          : _displayNameController.text,
    ).username;
    return _scene(
      _changingUsername
          ? TippyOnboardingCopy.usernamePrompt
          : TippyOnboardingCopy.displayNamePrompt,
      primary: 'CONTINUE',
      onPrimary: () async {
        final String? uid =
            firebase_auth.FirebaseAuth.instance.currentUser?.uid;
        if (uid == null) {
          setState(() => _localError = 'Please sign in to continue.');
          return;
        }
        final String callName = _changingUsername
            ? _usernameController.text
            : _displayNameController.text.trim();
        final ({String username, String displayName}) identity =
            tippyIdentityFromUsername(
          callName.isEmpty ? _usernameController.text : callName,
        );
        if (identity.username.length <
            TippyGuidedProfileOptions.usernameMinLength) {
          setState(() => _localError = 'Username is too short.');
          return;
        }
        setState(() => _localError = null);
        _usernameController.text = identity.username;
        if (!_changingUsername && _displayNameController.text.trim().isEmpty) {
          _displayNameController.text = callName;
        }
        await _saveDraft(
          _draft.copyWith(
            username: identity.username,
            displayName: _changingUsername
                ? identity.username
                : (_displayNameController.text.trim().isEmpty
                    ? identity.username
                    : _displayNameController.text.trim()),
          ),
        );
        await _usernameAvailability.checkNow(
          username: identity.username,
          userId: uid,
          onStatusChanged:
              (UsernameAvailabilityStatus status, String? message) {
            if (!mounted) {
              return;
            }
            setState(() {
              _usernameStatus = status;
              _usernameMessage = message;
            });
          },
        );
        if (_ownsUsername(identity.username)) {
          _usernameStatus = UsernameAvailabilityStatus.available;
        }
        if (_usernameStatus != UsernameAvailabilityStatus.available) {
          setState(() {
            _localError = _usernameMessage ??
                'That username is unavailable. Pick another.';
          });
          return;
        }
        final bool wasChangingUsername = _changingUsername;
        setState(() {
          _saving = true;
          _localError = null;
        });
        try {
          logTippyActivationProof(
            '[USERNAME_RUNTIME_TRACE] event=save_request username=${identity.username} allowUsernameChange=$wasChangingUsername',
          );
          final CompleteOnboardingResult? saved = await _persistProgress(
            username: identity.username,
            allowUsernameChange: wasChangingUsername,
            hardFail: true,
          );
          final String confirmed = tippyIdentityFromUsername(
            saved?.username ?? '',
          ).username;
          logTippyActivationProof(
            '[USERNAME_RUNTIME_TRACE] event=save_response username=$confirmed requested=${identity.username}',
          );
          if (wasChangingUsername &&
              confirmed.isNotEmpty &&
              confirmed != identity.username) {
            setState(() {
              _localError =
                  'Username did not update on the server. Still @$confirmed.';
            });
            return;
          }
          if (confirmed.isNotEmpty) {
            _hydrateCanonicalUsername(confirmed);
            await _saveDraft(
              _draft.copyWith(
                username: confirmed,
                displayName: confirmed,
              ),
            );
          }
          setState(() => _changingUsername = false);
          await widget.onAdvanceStage(TippyOnboardingStages.bio);
        } catch (error) {
          setState(() => _localError = _friendlyCommitError(error));
        } finally {
          if (mounted) {
            setState(() => _saving = false);
          }
        }
      },
      body: Column(
        children: <Widget>[
          TextField(
            controller: _changingUsername
                ? _usernameController
                : _displayNameController,
            maxLength: _changingUsername
                ? TippyGuidedProfileOptions.usernameMaxLength
                : TippyGuidedProfileOptions.displayNameMaxLength,
            textCapitalization: _changingUsername
                ? TextCapitalization.none
                : TextCapitalization.words,
            style: const TextStyle(color: Colors.white),
            decoration: _fieldDecoration(
              '',
              hintText: _changingUsername ? 'yourname' : 'Your name',
            ),
            onChanged: (String value) {
              final ({String username, String displayName}) identity =
                  tippyIdentityFromUsername(value);
              unawaited(
                _saveDraft(
                  _draft.copyWith(
                    username: identity.username,
                    displayName:
                        _changingUsername ? identity.username : value.trim(),
                  ),
                ),
              );
              if (_localError != null) {
                setState(() => _localError = null);
              }
            },
          ),
          Text(
            'streamerstip.com/streamer/${previewHandle.isEmpty ? 'yourname' : previewHandle}',
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildUsername() {
    return _scene(
      TippyOnboardingCopy.usernamePrompt,
      primary: 'CONTINUE',
      onPrimary: () async {
        final String? uid =
            firebase_auth.FirebaseAuth.instance.currentUser?.uid;
        if (uid == null) {
          setState(() => _localError = 'Please sign in to continue.');
          return;
        }
        final String username =
            ProfileUsernameRules.normalize(_usernameController.text);
        if (username.length < TippyGuidedProfileOptions.usernameMinLength) {
          setState(() => _localError = 'Username is too short.');
          return;
        }
        await _usernameAvailability.checkNow(
          username: username,
          userId: uid,
          onStatusChanged:
              (UsernameAvailabilityStatus status, String? message) {
            if (!mounted) {
              return;
            }
            setState(() {
              _usernameStatus = status;
              _usernameMessage = message;
            });
          },
        );
        if (_ownsUsername(username)) {
          _usernameStatus = UsernameAvailabilityStatus.available;
        }
        if (_usernameStatus != UsernameAvailabilityStatus.available) {
          setState(() {
            _localError = _usernameMessage ??
                'That username is unavailable. Pick another.';
          });
          return;
        }
        setState(() => _localError = null);
        await _saveDraft(
          _draft.copyWith(
            username: username,
            displayName: username,
          ),
        );
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
    if (_ownsUsername(value)) {
      setState(() {
        _usernameStatus = UsernameAvailabilityStatus.available;
        _usernameMessage = 'Username available';
      });
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

  void _remixBio() {
    final String beforeBio = _bioController.text.trim();
    final List<String> previousBios = <String>[
      beforeBio,
      ..._draft.bioRemixHistory,
    ].where((String b) => b.isNotEmpty).toList(growable: false);
    final ({String bio, int remixCount})? next = nextTippyRemixedBio(
      answers: widget.session.answers,
      remixCount: _draft.bioRemixCount,
      previousBios: previousBios,
    );
    if (next == null) {
      return;
    }
    _bioDirty = true;
    final double similarity = tippyBioSimilarity(beforeBio, next.bio);
    logTippyActivationProof(
      '[BIO_REMIX_RUNTIME_TRACE] phase=generate beforeBio=$beforeBio '
      'generatedCandidate=${next.bio} similarityToBefore=$similarity '
      'remixCount=${_draft.bioRemixCount}',
    );
    final List<String> history = <String>[
      ...previousBios,
      next.bio,
    ].take(4).toList(growable: false);
    setState(() {
      _bioController.text = next.bio;
      _draft = _draft.copyWith(
        bio: next.bio,
        skippedBio: false,
        bioRemixCount: next.remixCount,
        bioRemixHistory: history,
      );
    });
    logTippyActivationProof(
      '[BIO_REMIX_RUNTIME_TRACE] phase=editor_replace '
      'editorValueImmediatelyAfterReplace=${_bioController.text}',
    );
    unawaited(_saveDraft(_draft));
  }

  Widget _buildBio() {
    final bool canRemix = _draft.bioRemixCount < kTippyBioMaxRemixes;
    return _scene(
      TippyOnboardingCopy.bioPrompt,
      primary: 'CONTINUE',
      onPrimary: () async {
        if (_saving) {
          return;
        }
        final String bio = _bioController.text.trim();
        setState(() {
          _saving = true;
          _localError = null;
        });
        _bioDirty = false;
        await _saveDraft(
          _draft.copyWith(
            bio: bio,
            skippedBio: bio.isEmpty,
          ),
        );
        // Phase 1J.1: advance immediately; persist in background.
        unawaited(widget.onAdvanceStage(TippyOnboardingStages.platformHandles));
        try {
          await _persistProgress(
            bio: bio,
            hardFail: false,
          );
          logTippyActivationProof(
            '[BIO_REMIX_RUNTIME_TRACE] phase=after_save persistedDraftBio=$bio '
            'finalDisplayedBio=${_bioController.text.trim()}',
          );
        } catch (error) {
          if (mounted) {
            setState(() => _localError = _friendlyCommitError(error));
          }
        } finally {
          if (mounted) {
            setState(() => _saving = false);
          }
        }
      },
      secondary: 'Skip for now',
      onSecondary: () async {
        _bioDirty = false;
        await _saveDraft(_draft.copyWith(bio: '', skippedBio: true));
        await widget.onAdvanceStage(TippyOnboardingStages.platformHandles);
      },
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextField(
            controller: _bioController,
            maxLength: TippyGuidedProfileOptions.bioMaxLength,
            maxLines: 4,
            style: const TextStyle(color: Colors.white),
            decoration: _fieldDecoration(
              '',
              hintText:
                  'Horror and story-driven streamer building a community…',
            ),
            onChanged: (_) {
              _bioDirty = true;
            },
          ),
          if (canRemix)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _remixBio,
                icon: const Icon(Icons.auto_awesome, size: 16),
                label: const Text('Remix'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFC89BFF),
                  textStyle: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
        ],
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
      onPrimary: () async {
        await _persistProgress(
          platforms: _platformsPayload(),
          platformIds: _draft.platformIds,
          hardFail: false,
        );
        await widget.onAdvanceStage(TippyOnboardingStages.profileReview);
      },
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
                      final String nextHandle = handle.isNotEmpty
                          ? handle
                          : tippyIdentityFromUsername(_draft.username).username;
                      await _saveDraft(
                        _draft.copyWith(
                          platformIds: next,
                          platformHandles: nextHandle.isEmpty
                              ? _draft.platformHandles
                              : <String, String>{
                                  ..._draft.platformHandles,
                                  option.id: nextHandle,
                                },
                        ),
                      );
                      setState(() {
                        _activeHandlePlatform = option.id;
                        _handleController.text = _usernameFromStoredHandle(
                          option.id,
                          nextHandle,
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
                          selected ? Icons.check_circle : Icons.circle_outlined,
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
        _localError = 'Username is required.';
      });
      return;
    }
    if (kDebugMode) {
      logTippyActivationProof(
        '[CREATE_PROFILE_TAPPED] uid=${user.uid} canonicalUsername=${_draft.username} '
        'displayName=${_draft.displayName} avatar=${_draft.avatarUrl} '
        'platforms=${_draft.platformIds.join(',')} '
        'creatorDNAAttached=${widget.session.sessionId.isNotEmpty}',
      );
      logTippyActivationProof('[PROFILE_FINALIZE_START] uid=${user.uid}');
    }
    final DateTime uploadWaitDeadline =
        DateTime.now().add(const Duration(milliseconds: 1500));
    while (_uploadingAvatar && DateTime.now().isBefore(uploadWaitDeadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
    if (_saving) {
      return;
    }
    setState(() {
      _saving = true;
      _localError = null;
    });
    final String localNext = TippyOnboardingStages.stageAfterCreatorCard(
      answers: widget.session.answers,
      twitchConnectionStatus: widget.session.twitchConnectionStatus,
    );
    // Phase 1J.1: leave profile review immediately; finalize in background.
    if (mounted) {
      tippySuccessHaptic(context);
    }
    unawaited(widget.onAdvanceStage(localNext));
    try {
      final String username = ProfileUsernameRules.normalize(_draft.username);
      final List<Map<String, String?>> platforms = _platformsPayload();
      final CompleteOnboardingResult result = await completeOnboarding(
        username: username,
        displayName: _draft.displayName.trim().isEmpty
            ? username
            : _draft.displayName.trim(),
        bio: _draft.bio.trim(),
        avatarUrl: _draft.avatarUrl,
        skippedAvatar: _draft.skippedAvatar,
        platforms: platforms,
        platformIds: _draft.platformIds,
        categoryIds: _draft.categoryIds,
        answers: widget.session.answers,
        sessionId: widget.session.sessionId,
        allowUsernameChange: _changingUsername,
        finalize: true,
      );
      await _saveDraft(
        _draft.copyWith(
          username: result.username,
          displayName: result.displayName,
        ),
      );
      if (kDebugMode) {
        logTippyActivationProof(
          '[PROFILE_FINALIZE_SUCCESS] uid=${user.uid} username=${result.username} '
          'activationState=${result.activationState} nextStage=${result.nextStage}',
        );
      }
      unawaited(
        ProductEventTrackingService.instance.creatorProfileCompleted(
          surface: 'tippy_onboarding',
        ),
      );
      final String resolvedNext = TippyOnboardingStages.resolvePostCreatorCardStage(
        localStage: localNext,
        serverStage: result.nextStage,
      );
      if (resolvedNext != localNext) {
        await widget.onAdvanceStage(resolvedNext);
      }
    } catch (error, stackTrace) {
      debugPrint('Tippy create profile failed: $error');
      debugPrint('$stackTrace');
      // Soft: user already advanced; attach/status recover later.
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  String _friendlyCommitError(Object error) {
    if (error is CompleteOnboardingException) {
      return '${error.message} (${error.stage})';
    }
    if (error is VerifiedActivationException) {
      return error.message;
    }
    if (error is UsernameTakenException) {
      return 'That username was just taken. Pick another.';
    }
    if (error is UsernameClaimException) {
      final String code = (error.code ?? '').toLowerCase();
      if (code == 'already_claimed' ||
          error.message.toLowerCase().contains('already claimed') ||
          error.message.toLowerCase().contains('changeusername')) {
        return 'That username is unavailable. Pick another.';
      }
      return error.message;
    }
    final String raw = error.toString();
    final String lower = raw.toLowerCase();
    if (lower.contains('account_not_provisioned') ||
        lower.contains('activation failed') ||
        lower.contains('provision')) {
      return kVerifiedActivationPersistentError;
    }
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

  InputDecoration _fieldDecoration(String label, {String? hintText}) {
    return InputDecoration(
      labelText: label.isEmpty ? null : label,
      hintText: hintText,
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
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
              colors: _webOnboardingPrimaryGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: const Color(0xFF6B3AA0).withValues(alpha: 0.38),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: const Color(0xFF4A2570).withValues(alpha: 0.30),
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
