import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/playback_owners.dart';
import '../../controllers/home_view_controller.dart';
import '../../providers/feed_state_provider.dart';
import '../../routing/app_routes.dart';
import '../../services/global_playback_manager.dart';
import 'onboarding_models.dart';
import 'onboarding_premium_modal.dart';
import 'onboarding_service.dart';
import 'onboarding_tester_config.dart';
import 'onboarding_view.dart';

/// Single onboarding gate — Firestore is source of truth.
class OnboardingGate extends ConsumerStatefulWidget {
  const OnboardingGate({
    super.key,
    required this.userId,
    required this.child,
    this.email,
    this.username,
    this.displayName,
    this.service,
  });

  final String userId;
  final Widget child;
  final String? email;
  final String? username;
  final String? displayName;
  final OnboardingService? service;

  @override
  ConsumerState<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends ConsumerState<OnboardingGate> {
  final GlobalKey<NavigatorState> _onboardingNavigatorKey =
      GlobalKey<NavigatorState>();
  late OnboardingService _service;
  OnboardingState _state = OnboardingState.initial();
  bool _isReady = false;
  bool _showApp = false;
  bool _pendingPremiumOffer = false;
  bool _checkedTesterReset = false;
  bool _isTesterSession = false;
  bool _onboardingPlaybackBlocked = false;
  StreamSubscription<OnboardingState>? _subscription;

  bool get _isShowingOnboarding => _isReady && !_showApp && !_state.completed;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? OnboardingService();
    unawaited(_bootstrap());
  }

  @override
  void didUpdateWidget(OnboardingGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId ||
        oldWidget.service != widget.service) {
      _subscription?.cancel();
      _service = widget.service ?? OnboardingService();
      _isReady = false;
      _showApp = false;
      _pendingPremiumOffer = false;
      _checkedTesterReset = false;
      _releaseOnboardingPlaybackBlock();
      unawaited(_bootstrap());
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _releaseOnboardingPlaybackBlock();
    super.dispose();
  }

  void _blockPlaybackForOnboarding() {
    if (_onboardingPlaybackBlocked) {
      return;
    }
    _onboardingPlaybackBlocked = true;
    final GlobalPlaybackManager manager = GlobalPlaybackManager.instance;
    manager.block(reason: 'onboarding');
    manager.pauseAll();
  }

  void _releaseOnboardingPlaybackBlock() {
    if (!_onboardingPlaybackBlocked) {
      return;
    }
    GlobalPlaybackManager.instance.unblock();
    _onboardingPlaybackBlocked = false;
  }

  void _syncOnboardingPlaybackState() {
    if (_isShowingOnboarding) {
      _blockPlaybackForOnboarding();
      return;
    }
    _releaseOnboardingPlaybackBlock();
  }

  void _scheduleHomePlaybackRestoreAfterOnboarding() {
    _releaseOnboardingPlaybackBlock();
    final GlobalPlaybackManager manager = GlobalPlaybackManager.instance;
    if (manager.isPlaybackBlocked) {
      manager.forceUnblock();
    }
    manager.setVisibleOwner(PlaybackOwners.home);
    manager.setActiveOwner(PlaybackOwners.home);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        ref
            .read(homeViewControllerProvider.notifier)
            .resumeAfterOnboardingCompleted();
        ref.read(homeViewReactivateProvider.notifier).triggerReactivation();
      });
    });
  }

  Future<void> _bootstrap() async {
    final bool isTester = OnboardingTesterConfig.isTesterUser(
      userId: widget.userId,
      email: widget.email,
      username: widget.username,
      displayName: widget.displayName,
    );
    _isTesterSession = isTester;
    if (isTester) {
      _checkedTesterReset = true;
      await _service.resetForDeveloperTesterInstall(widget.userId);
    } else {
      await _resetTesterIfNeeded();
    }
    final OnboardingState migrated = isTester
        ? await _service.fetchOnboarding(widget.userId)
        : await _service.ensureMigrated(widget.userId);
    if (!mounted) {
      return;
    }
    setState(() {
      _state = migrated;
      _showApp = migrated.completed && !isTester;
      _isReady = true;
    });
    _syncOnboardingPlaybackState();
    _subscription?.cancel();
    _subscription = _service.watchOnboarding(widget.userId).listen(
      (OnboardingState state) {
        if (!mounted) {
          return;
        }
        final bool wasShowingOnboarding = _isShowingOnboarding;
        setState(() {
          _state = state;
          if (state.completed) {
            if (!_isTesterSession) {
              _showApp = true;
            }
          } else {
            _showApp = false;
          }
        });
        if (wasShowingOnboarding && _showApp) {
          _scheduleHomePlaybackRestoreAfterOnboarding();
        } else {
          _syncOnboardingPlaybackState();
        }
      },
    );
  }

  Future<void> _resetTesterIfNeeded() async {
    if (_checkedTesterReset) {
      return;
    }
    _checkedTesterReset = true;
    final bool isTester = OnboardingTesterConfig.isTesterUser(
      userId: widget.userId,
      email: widget.email,
      username: widget.username,
      displayName: widget.displayName,
    );
    if (isTester) {
      _isTesterSession = true;
      await _service.resetForDeveloperTesterInstall(widget.userId);
    }
  }

  void _onOnboardingCompleted() {
    setState(() {
      _showApp = true;
      _pendingPremiumOffer = !_state.premiumOfferDismissed;
    });
    _scheduleHomePlaybackRestoreAfterOnboarding();
    if (_pendingPremiumOffer) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _maybeShowPremiumOffer();
      });
    }
  }

  Future<void> _maybeShowPremiumOffer() async {
    if (!mounted || !_pendingPremiumOffer) {
      return;
    }
    _pendingPremiumOffer = false;
    await showOnboardingPremiumModal(
      context,
      userId: widget.userId,
      onDismissed: () => _service.dismissPremiumOffer(widget.userId),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return const _OnboardingLoadingShell();
    }
    if (!_showApp && !_state.completed) {
      return Navigator(
        key: _onboardingNavigatorKey,
        onGenerateRoute: (RouteSettings settings) {
          return MaterialPageRoute<void>(
            settings: const RouteSettings(name: AppRoutes.onboarding),
            builder: (BuildContext context) {
              return OnboardingView(
                key: ValueKey<String>('onboarding-${widget.userId}'),
                userId: widget.userId,
                initialState: _state,
                service: _service,
                showTesterSkip: _isTesterSession,
                onCompleted: _onOnboardingCompleted,
              );
            },
          );
        },
      );
    }
    return widget.child;
  }
}

class _OnboardingLoadingShell extends StatelessWidget {
  const _OnboardingLoadingShell();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF0F172A),
      child: Center(
        child: CircularProgressIndicator(
          color: Color(0xFF9248D2),
        ),
      ),
    );
  }
}
