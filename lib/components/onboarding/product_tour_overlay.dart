import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/playback_owners.dart';
import '../../providers/discover_provider.dart';
import '../../providers/home_provider.dart' as hp;
import '../../providers/product_tour_ui_provider.dart';
import '../../routing/app_navigator.dart';
import '../../routing/app_routes.dart';
import '../../models/trending_creator.dart';
import '../../models/user.dart';
import '../../services/global_playback_manager.dart';
import '../../services/robust_auth_service.dart';
import '../../services/unified_avatar_service.dart' as nav_overlay;
import 'coach_mark.dart';
import 'product_tour_target_keys.dart';

class ProductTourStep {
  const ProductTourStep({
    required this.id,
    required this.key,
    required this.title,
    required this.body,
    required this.placement,
    required this.fallbackRectBuilder,
    this.tooltipVerticalBias = 0,
    this.spotlightInset = 6,
    this.showSpotlight = true,
    this.tooltipAlignEnd = false,
  });

  final String id;
  final Key key;
  final String title;
  final String body;
  final CoachMarkPlacement placement;
  final Rect Function(Size size, EdgeInsets padding) fallbackRectBuilder;
  final double tooltipVerticalBias;
  final double spotlightInset;
  final bool showSpotlight;
  final bool tooltipAlignEnd;
}

class ProductTourOverlay extends ConsumerStatefulWidget {
  const ProductTourOverlay({
    super.key,
    required this.onFinish,
    required this.onSkip,
    this.onStepChanged,
    this.initialStep = 0,
    this.waitForFeedVideo = false,
  });

  final int initialStep;
  final VoidCallback onFinish;
  final ValueChanged<int> onSkip;
  final ValueChanged<String>? onStepChanged;
  final bool waitForFeedVideo;

  @override
  ConsumerState<ProductTourOverlay> createState() => _ProductTourOverlayState();
}

class _ProductTourOverlayState extends ConsumerState<ProductTourOverlay> {
  late int _index;
  Timer? _discoverPeekTimer;
  int _lastMainTabRequest = -1;
  bool _blockedPlaybackForPrimer = false;
  bool _tourOpenedInbox = false;
  bool _tourOpenedProfile = false;
  OverlayEntry? _creatorCardCoachOverlayEntry;
  bool _creatorCardTourUsesNavigatorOverlay = false;
  bool _tourPushedStreamerCardRoute = false;

  static List<ProductTourStep> get _steps => <ProductTourStep>[
        ProductTourStep(
          id: 'home_feed',
          key: const Key('coachmark-home-feed'),
          title: 'Swipe up for more',
          body: 'Swipe through creator clips and discover new streamers.',
          placement: CoachMarkPlacement.top,
          tooltipVerticalBias: 58,
          fallbackRectBuilder: (Size size, EdgeInsets padding) => Rect.fromLTWH(
            18,
            padding.top + 72,
            size.width - 36,
            220,
          ),
        ),
        ProductTourStep(
          id: 'upload_button',
          key: const Key('coachmark-upload-button'),
          title: 'Upload',
          body: 'Post clips, schedule content, and start building consistency.',
          placement: CoachMarkPlacement.top,
          fallbackRectBuilder: (Size size, EdgeInsets padding) => Rect.fromLTWH(
            size.width - 92,
            size.height - padding.bottom - 108,
            74,
            74,
          ),
        ),
        ProductTourStep(
          id: 'discover_categories',
          key: const Key('coachmark-discover-categories'),
          title: 'Discover',
          body: 'Jump into gaming, tech, music, and other creator communities.',
          placement: CoachMarkPlacement.bottom,
          tooltipVerticalBias: 16,
          spotlightInset: 10,
          fallbackRectBuilder: (Size size, EdgeInsets padding) => Rect.fromLTWH(
            16,
            padding.top + 126,
            size.width - 32,
            176,
          ),
        ),
        ProductTourStep(
          id: 'creator_card',
          key: const Key('coachmark-creator-card'),
          title: 'Creator Card',
          body:
              'Your networking card helps other creators understand who you are.',
          placement: CoachMarkPlacement.bottom,
          tooltipVerticalBias: 12,
          tooltipAlignEnd: true,
          fallbackRectBuilder: (Size size, EdgeInsets padding) => Rect.fromLTWH(
            18,
            size.height - padding.bottom - 250,
            size.width - 36,
            128,
          ),
        ),
        ProductTourStep(
          id: 'tippy_ai',
          key: const Key('coachmark-tippy-ai'),
          title: 'Tippy AI',
          body: 'Use Tippy to plan content, improve posts, and grow faster.',
          placement: CoachMarkPlacement.top,
          tooltipVerticalBias: -6,
          spotlightInset: 4,
          fallbackRectBuilder: (Size size, EdgeInsets padding) => Rect.fromLTWH(
            size.width - 88,
            padding.top + 74,
            70,
            70,
          ),
        ),
        ProductTourStep(
          id: 'network',
          key: const Key('coachmark-network'),
          title: 'Network',
          body: 'Find collaborators, follow creators, and build your circle.',
          placement: CoachMarkPlacement.top,
          fallbackRectBuilder: (Size size, EdgeInsets padding) => Rect.fromLTWH(
            16,
            padding.top + 52,
            size.width - 32,
            (size.height - padding.top - padding.bottom - 132).clamp(120, 520),
          ),
        ),
        ProductTourStep(
          id: 'inbox',
          key: const Key('coachmark-inbox'),
          title: 'Inbox',
          body:
              'Keep replies, opportunities, and creator messages in one place.',
          placement: CoachMarkPlacement.top,
          showSpotlight: false,
          fallbackRectBuilder: (Size size, EdgeInsets padding) => Rect.fromLTWH(
            size.width * 0.64,
            size.height - padding.bottom - 96,
            74,
            64,
          ),
        ),
        ProductTourStep(
          id: 'profile',
          key: const Key('coachmark-profile'),
          title: 'Profile',
          body:
              'Track your growth, polish your profile, and show your best work.',
          placement: CoachMarkPlacement.top,
          showSpotlight: false,
          fallbackRectBuilder: (Size size, EdgeInsets padding) => Rect.fromLTWH(
            size.width - 88,
            size.height - padding.bottom - 96,
            74,
            64,
          ),
        ),
      ];

  @override
  void initState() {
    super.initState();
    _index = widget.initialStep.clamp(0, _steps.length - 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      widget.onStepChanged?.call(_steps[_index].id);
      _afterStepChanged();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _discoverPeekTimer?.cancel();
    _releasePrimerPlaybackBlock();
    _tearDownCreatorCardTourOverlay(popStreamer: true);
    _tearDownTourShellRoutes();
    try {
      ref.read(productTourUiPhaseProvider.notifier).state =
          ProductTourUiPhase.idle;
      ref.read(productTourMainTabIndexRequestProvider.notifier).state = null;
    } catch (_) {
      // Some widget tests mount this overlay without a live ProviderScope.
    }
    super.dispose();
  }

  NavigatorState? _tourRootNavigatorOrNull() {
    final BuildContext? c =
        nav_overlay.NavigationService.navigatorKey.currentContext;
    if (c == null) {
      return null;
    }
    return Navigator.of(c, rootNavigator: true);
  }

  void _tearDownTourShellRoutes() {
    final NavigatorState? nav = _tourRootNavigatorOrNull();
    if (nav == null) {
      return;
    }
    if (_tourOpenedProfile) {
      if (nav.canPop()) {
        nav.pop();
      }
      _tourOpenedProfile = false;
    }
    if (_tourOpenedInbox) {
      if (nav.canPop()) {
        nav.pop();
      }
      _tourOpenedInbox = false;
    }
  }

  void _syncTourShellRoutes() {
    final NavigatorState? nav = _tourRootNavigatorOrNull();
    if (nav == null) {
      return;
    }
    final String id = _steps[_index].id;
    if (id == 'inbox') {
      if (_tourOpenedProfile) {
        if (nav.canPop()) {
          nav.pop();
        }
        _tourOpenedProfile = false;
      }
      if (!_tourOpenedInbox) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _steps[_index].id != 'inbox') {
            return;
          }
          final NavigatorState? n = _tourRootNavigatorOrNull();
          if (n == null) {
            return;
          }
          n.pushNamed(AppRoutes.inbox);
          _tourOpenedInbox = true;
        });
      }
      return;
    }
    if (id == 'profile') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _steps[_index].id != 'profile') {
          return;
        }
        final NavigatorState? n = _tourRootNavigatorOrNull();
        if (n == null) {
          return;
        }
        final User? user = ref.read(robustAuthServiceProvider).currentUser;
        if (user == null) {
          return;
        }
        if (_tourOpenedInbox) {
          if (n.canPop()) {
            n.pop();
          }
          _tourOpenedInbox = false;
        }
        if (!_tourOpenedProfile) {
          n.pushNamed(
            AppRoutes.profile,
            arguments: ProfileRouteArgs(
              user: user,
              isCurrentUser: true,
            ),
          );
          _tourOpenedProfile = true;
        }
      });
      return;
    }
    _tearDownTourShellRoutes();
  }

  void _afterStepChanged() {
    if (!mounted) {
      return;
    }
    _syncTourUiPhase();
    _syncMainTabForStep(_steps[_index].id);
    _dismissDiscoverAndStreamerRoutesForTippyTour();
    _scheduleDiscoverPeekIfNeeded();
    _ensureDiscoverOpenForExplore();
    _scrollDiscoverCategoriesIntoView();
    _scrollCreatorCardTourTargetIntoView();
    _relayoutCoachMarkAfterCommandCenterOpens();
    _relayoutCoachMarkAfterProgressionTab();
    _relayoutCoachMarkAfterNetworkTab();
    _scrollProgressionHeroIntoView();
    _syncTourShellRoutes();
    _bumpDiscoverPrepIfCreatorCardStep();
    _syncCreatorCardTourStep();
    _relayoutCoachMarkAfterDiscoverTargets();
    _creatorCardCoachOverlayEntry?.markNeedsBuild();
  }

  /// Tippy spotlight targets [ProductTourTargetKeys.tippyAi] on the home shell.
  /// After the creator-card step we may still have Discover and/or StreamerCard
  /// on the root navigator; pop those so step 5 matches the original behavior.
  void _dismissDiscoverAndStreamerRoutesForTippyTour() {
    if (_steps[_index].id != 'tippy_ai') {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _steps[_index].id != 'tippy_ai') {
        return;
      }
      final NavigatorState? nav = _tourRootNavigatorOrNull();
      if (nav == null) {
        return;
      }
      const int maxPops = 2;
      int pops = 0;
      while (nav.canPop() && pops < maxPops) {
        nav.pop();
        pops++;
      }
      if (pops > 0 && mounted) {
        setState(() {});
      }
    });
  }

  void _tearDownCreatorCardTourOverlay({required bool popStreamer}) {
    _creatorCardCoachOverlayEntry?.remove();
    _creatorCardCoachOverlayEntry = null;
    _creatorCardTourUsesNavigatorOverlay = false;
    if (popStreamer && _tourPushedStreamerCardRoute) {
      _tourPushedStreamerCardRoute = false;
      final NavigatorState? nav = _tourRootNavigatorOrNull();
      if (nav != null && nav.canPop()) {
        nav.pop();
      }
    } else {
      _tourPushedStreamerCardRoute = false;
    }
  }

  void _syncCreatorCardTourStep() {
    if (_steps[_index].id != 'creator_card') {
      _tearDownCreatorCardTourOverlay(popStreamer: true);
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _steps[_index].id != 'creator_card') {
        return;
      }
      _maybeStartCreatorCardNavigatorTour();
    });
  }

  bool _isTourSampleCreatorId(String id) {
    return const <String>{'1', '2', '3', '4', '5', '6'}.contains(id);
  }

  String? _firstTourEligibleTrendingUserId() {
    try {
      final List<TrendingCreator> creators =
          ref.read(discoverProvider).trendingCreators;
      for (final TrendingCreator c in creators) {
        if (_isTourSampleCreatorId(c.id)) {
          continue;
        }
        if (c.id.length < 20) {
          continue;
        }
        return c.id;
      }
    } catch (_) {
      // Tests may omit Firebase; [discoverProvider] can throw.
    }
    return null;
  }

  void _insertCreatorCardCoachOverlayIfNeeded() {
    if (!mounted ||
        _steps[_index].id != 'creator_card' ||
        !_creatorCardTourUsesNavigatorOverlay) {
      return;
    }
    final NavigatorState? nav = _tourRootNavigatorOrNull();
    final OverlayState? overlay = nav?.overlay;
    if (overlay == null) {
      return;
    }
    if (_creatorCardCoachOverlayEntry != null) {
      _creatorCardCoachOverlayEntry!.markNeedsBuild();
      return;
    }
    final ProviderContainer container = ProviderScope.containerOf(context);
    _creatorCardCoachOverlayEntry = OverlayEntry(
      builder: (BuildContext overlayContext) {
        return UncontrolledProviderScope(
          container: container,
          child: Material(
            color: Colors.transparent,
            child: SizedBox.expand(
              child: _buildTourCoachMark(overlayContext),
            ),
          ),
        );
      },
    );
    overlay.insert(_creatorCardCoachOverlayEntry!);
  }

  void _maybeStartCreatorCardNavigatorTour() {
    if (_steps[_index].id != 'creator_card') {
      return;
    }
    final String? userId = _firstTourEligibleTrendingUserId();
    final BuildContext? navCtx =
        nav_overlay.NavigationService.navigatorKey.currentContext;
    if (userId == null || navCtx == null) {
      return;
    }
    if (_tourPushedStreamerCardRoute) {
      _insertCreatorCardCoachOverlayIfNeeded();
      return;
    }
    _tourPushedStreamerCardRoute = true;
    _creatorCardTourUsesNavigatorOverlay = true;
    AppNavigator.openStreamerCard(
      navCtx,
      userId: userId,
      currentUserId: fa.FirebaseAuth.instance.currentUser?.uid,
      tourAnchorKey: ProductTourTargetKeys.creatorCard,
      onDismiss: () {
        _tourPushedStreamerCardRoute = false;
        Navigator.of(navCtx, rootNavigator: true).pop();
      },
      onMessage: (_) {},
      onNavigateToTab: (_) {},
      onShare: (_) {},
    ).then((_) {
      _tourPushedStreamerCardRoute = false;
      if (!mounted) {
        return;
      }
      _creatorCardCoachOverlayEntry?.remove();
      _creatorCardCoachOverlayEntry = null;
      _creatorCardTourUsesNavigatorOverlay = false;
      if (_steps[_index].id == 'creator_card') {
        setState(() {});
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _steps[_index].id != 'creator_card') {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _steps[_index].id != 'creator_card') {
          return;
        }
        _insertCreatorCardCoachOverlayIfNeeded();
      });
    });
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 320), () {
        if (!mounted || _steps[_index].id != 'creator_card') {
          return;
        }
        _creatorCardCoachOverlayEntry?.markNeedsBuild();
        setState(() {});
      }),
    );
  }

  void _relayoutCoachMarkAfterDiscoverTargets() {
    final String id = _steps[_index].id;
    if (id != 'discover_categories' && id != 'creator_card') {
      return;
    }
    for (final int delayMs in const <int>[60, 200, 480, 900]) {
      unawaited(
        Future<void>.delayed(Duration(milliseconds: delayMs), () {
          if (!mounted) {
            return;
          }
          if (_steps[_index].id != 'discover_categories' &&
              _steps[_index].id != 'creator_card') {
            return;
          }
          _creatorCardCoachOverlayEntry?.markNeedsBuild();
          setState(() {});
        }),
      );
    }
  }

  void _bumpDiscoverPrepIfCreatorCardStep() {
    if (_steps[_index].id != 'creator_card') {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _steps[_index].id != 'creator_card') {
        return;
      }
      try {
        ref.read(productTourDiscoverCreatorsPrepProvider.notifier).state++;
      } catch (_) {
        // Tests may omit ProviderScope.
      }
    });
  }

  void _syncPrimerPlaybackBlock() {
    if (_steps[_index].id != 'home_feed' || _blockedPlaybackForPrimer) {
      return;
    }
    _blockedPlaybackForPrimer = true;
    GlobalPlaybackManager.instance.block(reason: 'onboardingSwipePrimer');
  }

  void _releasePrimerPlaybackBlock() {
    if (!_blockedPlaybackForPrimer) {
      return;
    }
    _blockedPlaybackForPrimer = false;
    GlobalPlaybackManager.instance.unblock();
    GlobalPlaybackManager.instance.setActiveOwner(PlaybackOwners.home);
  }

  void _relayoutCoachMarkAfterCommandCenterOpens() {
    if (_steps[_index].id != 'tippy_ai') {
      return;
    }
    for (final int delayMs in const <int>[200, 420, 900, 1400]) {
      unawaited(
        Future<void>.delayed(Duration(milliseconds: delayMs), () {
          if (!mounted || _steps[_index].id != 'tippy_ai') {
            return;
          }
          setState(() {});
        }),
      );
    }
  }

  void _relayoutCoachMarkAfterProgressionTab() {
    if (_steps[_index].id != 'progression') {
      return;
    }
    for (final int delayMs in const <int>[120, 380, 800]) {
      unawaited(
        Future<void>.delayed(Duration(milliseconds: delayMs), () {
          if (!mounted || _steps[_index].id != 'progression') {
            return;
          }
          setState(() {});
        }),
      );
    }
  }

  void _relayoutCoachMarkAfterNetworkTab() {
    if (_steps[_index].id != 'network') {
      return;
    }
    for (final int delayMs in const <int>[120, 360, 620]) {
      unawaited(
        Future<void>.delayed(Duration(milliseconds: delayMs), () {
          if (!mounted || _steps[_index].id != 'network') {
            return;
          }
          setState(() {});
        }),
      );
    }
  }

  void _scrollProgressionHeroIntoView() {
    if (_steps[_index].id != 'progression') {
      return;
    }
    void attemptScroll() {
      if (!mounted || _steps[_index].id != 'progression') {
        return;
      }
      final BuildContext? ctx =
          ProductTourTargetKeys.progressionPanel.currentContext;
      if (ctx == null) {
        return;
      }
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.05,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      attemptScroll();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        attemptScroll();
      });
    });
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 450), attemptScroll),
    );
  }

  static const double _categoriesScrollAlignment = 0.18;

  void _scrollDiscoverCategoriesIntoView() {
    if (_steps[_index].id != 'discover_categories') {
      return;
    }
    void attemptScroll() {
      if (!mounted || _steps[_index].id != 'discover_categories') {
        return;
      }
      final BuildContext? targetContext =
          ProductTourTargetKeys.discoverCategories.currentContext;
      if (targetContext == null) {
        return;
      }
      Scrollable.ensureVisible(
        targetContext,
        alignment: _categoriesScrollAlignment,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      attemptScroll();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        attemptScroll();
      });
    });
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 480), attemptScroll),
    );
  }

  void _scrollCreatorCardTourTargetIntoView() {
    if (_steps[_index].id != 'creator_card') {
      return;
    }
    void attemptScroll() {
      if (!mounted || _steps[_index].id != 'creator_card') {
        return;
      }
      final BuildContext? targetContext =
          ProductTourTargetKeys.discoverTrending.currentContext;
      if (targetContext == null) {
        return;
      }
      Scrollable.ensureVisible(
        targetContext,
        alignment: 0.08,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      attemptScroll();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        attemptScroll();
      });
    });
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 520), attemptScroll),
    );
  }

  void _ensureDiscoverOpenForExplore() {
    final String id = _steps[_index].id;
    if (id != 'discover_activity' &&
        id != 'discover_categories' &&
        id != 'creator_card') {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final String currentId = _steps[_index].id;
      if (currentId != 'discover_activity' &&
          currentId != 'discover_categories' &&
          currentId != 'creator_card') {
        return;
      }
      final GlobalKey targetKey = currentId == 'discover_activity'
          ? ProductTourTargetKeys.discoverActivity
          : currentId == 'creator_card'
              ? ProductTourTargetKeys.discoverTrending
              : ProductTourTargetKeys.discoverCategories;
      final Rect? rect = CoachMark.targetRectForKey(targetKey);
      if (rect != null) {
        return;
      }
      final NavigatorState? navState =
          nav_overlay.NavigationService.navigatorKey.currentState;
      navState?.pushNamed(AppRoutes.discover);
    });
  }

  void _syncMainTabForStep(String stepId) {
    final int tab = stepId == 'network' ? 1 : 0;
    if (tab == _lastMainTabRequest) {
      return;
    }
    _lastMainTabRequest = tab;
    try {
      ref.read(productTourMainTabIndexRequestProvider.notifier).state = tab;
    } catch (_) {
      // Some widget tests mount this overlay without a live ProviderScope.
    }
  }

  void _scheduleDiscoverPeekIfNeeded() {
    _discoverPeekTimer?.cancel();
    if (_steps[_index].id != 'discover') {
      return;
    }
    _discoverPeekTimer = Timer(const Duration(milliseconds: 2600), () {
      if (!mounted) {
        return;
      }
      if (_steps[_index].id != 'discover') {
        return;
      }
      final NavigatorState? navState =
          nav_overlay.NavigationService.navigatorKey.currentState;
      navState?.pushNamed(AppRoutes.discover);
    });
  }

  void _syncTourUiPhase() {
    if (!mounted) {
      return;
    }
    final ProductTourUiPhase next = _phaseForStep(_steps[_index].id);
    try {
      ref.read(productTourUiPhaseProvider.notifier).state = next;
    } catch (_) {
      // Some widget tests mount this overlay without a live ProviderScope.
    }
  }

  Rect _targetRectForContext(
    BuildContext mediaContext,
    ProductTourStep step,
  ) {
    final Size size = MediaQuery.sizeOf(mediaContext);
    final EdgeInsets padding = MediaQuery.paddingOf(mediaContext);
    if (step.id == 'creator_card') {
      final Rect? cardRect =
          CoachMark.targetRectForKey(ProductTourTargetKeys.creatorCard);
      if (cardRect != null) {
        return cardRect;
      }
      final Rect? trendingRect =
          CoachMark.targetRectForKey(ProductTourTargetKeys.discoverTrending);
      if (trendingRect != null) {
        return trendingRect;
      }
    } else {
      final GlobalKey? targetKey = ProductTourTargetKeys.keyForStepId(step.id);
      if (targetKey != null) {
        final Rect? fromKey = CoachMark.targetRectForKey(targetKey);
        if (fromKey != null) {
          return fromKey;
        }
      }
    }
    return step.fallbackRectBuilder(size, padding);
  }

  void _handleTourPrimaryPressed() {
    if (_index == _steps.length - 1) {
      _discoverPeekTimer?.cancel();
      _tearDownCreatorCardTourOverlay(popStreamer: true);
      _syncTourUiPhaseToIdle();
      _releasePrimerPlaybackBlock();
      _tearDownTourShellRoutes();
      widget.onFinish();
      return;
    }
    if (_steps[_index].id == 'creator_card') {
      _tearDownCreatorCardTourOverlay(popStreamer: true);
    }
    _discoverPeekTimer?.cancel();
    setState(() => _index += 1);
    widget.onStepChanged?.call(_steps[_index].id);
    _afterStepChanged();
    WidgetsBinding.instance.addPostFrameCallback((_) => setState(() {}));
  }

  void _handleTourBackPressed() {
    _discoverPeekTimer?.cancel();
    final int nextIndex = _index - 1;
    final String priorId = _steps[nextIndex].id;
    final String leavingId = _steps[_index].id;
    final NavigatorState? navState = _tourRootNavigatorOrNull();
    if (leavingId == 'creator_card') {
      _tearDownCreatorCardTourOverlay(popStreamer: true);
    }
    if (priorId == 'home_feed' || priorId == 'discover') {
      if (navState != null && navState.canPop()) {
        navState.pop();
      }
    } else if (leavingId == 'discover_categories') {
      if (navState != null && navState.canPop()) {
        navState.pop();
      }
    }
    setState(() => _index = nextIndex);
    widget.onStepChanged?.call(_steps[_index].id);
    _afterStepChanged();
    WidgetsBinding.instance.addPostFrameCallback((_) => setState(() {}));
  }

  void _handleTourSkipPressed() {
    _discoverPeekTimer?.cancel();
    _tearDownCreatorCardTourOverlay(popStreamer: true);
    _tearDownTourShellRoutes();
    _syncTourUiPhaseToIdle();
    _releasePrimerPlaybackBlock();
    widget.onSkip(_index);
  }

  Widget _buildTourCoachMark(BuildContext mediaContext) {
    final ProductTourStep step = _steps[_index];
    return CoachMark(
      key: step.key,
      title: step.title,
      body: step.body,
      targetRect: _targetRectForContext(mediaContext, step),
      placement: step.placement,
      tooltipVerticalBias: step.tooltipVerticalBias,
      spotlightInset: step.spotlightInset,
      showSpotlight: step.showSpotlight,
      tooltipAlignEnd: step.tooltipAlignEnd,
      stepLabel: 'Step ${_index + 1} of ${_steps.length}',
      primaryLabel: _index == _steps.length - 1 ? 'Finish Tour' : 'Next',
      onPrimary: _handleTourPrimaryPressed,
      onBack: _index == 0 ? null : _handleTourBackPressed,
      onSkip: _handleTourSkipPressed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ProductTourStep step = _steps[_index];
    if (step.id == 'home_feed') {
      if (widget.waitForFeedVideo) {
        final bool hasFeedVideo = ref.watch(
          hp.homeProvider.select(
            (hp.HomeState state) => state.forYouVideos.isNotEmpty,
          ),
        );
        if (!hasFeedVideo) {
          return const SizedBox.shrink();
        }
      }
      _syncPrimerPlaybackBlock();
      return KeyedSubtree(
        key: step.key,
        child: _SwipePrimerOverlay(
          onStart: () {
            _discoverPeekTimer?.cancel();
            _releasePrimerPlaybackBlock();
            setState(() => _index = (_index + 1).clamp(0, _steps.length - 1));
            widget.onStepChanged?.call(_steps[_index].id);
            _afterStepChanged();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() {});
            });
          },
          onSkip: () {
            _discoverPeekTimer?.cancel();
            _tearDownCreatorCardTourOverlay(popStreamer: true);
            _tearDownTourShellRoutes();
            _syncTourUiPhaseToIdle();
            _releasePrimerPlaybackBlock();
            widget.onSkip(_index);
          },
        ),
      );
    }
    if (step.id == 'creator_card' &&
        _creatorCardTourUsesNavigatorOverlay) {
      return const SizedBox.shrink();
    }
    return Material(
      key: const Key('product-tour-overlay'),
      color: Colors.transparent,
      child: SizedBox.expand(
        child: _buildTourCoachMark(context),
      ),
    );
  }

  void _syncTourUiPhaseToIdle() {
    _lastMainTabRequest = -1;
    try {
      ref.read(productTourUiPhaseProvider.notifier).state =
          ProductTourUiPhase.idle;
      ref.read(productTourMainTabIndexRequestProvider.notifier).state = null;
    } catch (_) {
      // Some widget tests mount this overlay without a live ProviderScope.
    }
  }

  ProductTourUiPhase _phaseForStep(String id) {
    switch (id) {
      case 'progression':
        return ProductTourUiPhase.progressionView;
      case 'threads':
        return ProductTourUiPhase.threadsView;
      case 'tippy_ai':
        return ProductTourUiPhase.tippyCommandCenter;
      default:
        return ProductTourUiPhase.idle;
    }
  }
}

class _SwipePrimerOverlay extends StatelessWidget {
  const _SwipePrimerOverlay({
    required this.onStart,
    required this.onSkip,
  });

  final VoidCallback onStart;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final EdgeInsets padding = MediaQuery.paddingOf(context);
    final Size size = MediaQuery.sizeOf(context);
    final bool compact = size.height < 720 || size.width < 380;
    final double screenH = size.height;
    final double swipeHintBottom = padding.bottom +
        (screenH * (compact ? 0.20 : 0.26)).clamp(128.0, 292.0);
    return GestureDetector(
      key: const Key('product-tour-overlay'),
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: (DragUpdateDetails details) {
        if (details.primaryDelta != null && details.primaryDelta! < -8) {
          onStart();
        }
      },
      onVerticalDragEnd: (DragEndDetails details) {
        if ((details.primaryVelocity ?? 0) < 0) {
          onStart();
        }
      },
      child: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Positioned(
              top: padding.top + 12,
              right: 14,
              child: Semantics(
                label: 'Skip onboarding',
                button: true,
                child: IconButton(
                  key: const Key('product-tour-skip-button'),
                  onPressed: onSkip,
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ),
            ),
            Positioned(
              left: compact ? 20 : 28,
              right: compact ? 20 : 28,
              bottom: swipeHintBottom,
              child: IgnorePointer(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.keyboard_arrow_up_rounded,
                      color: Colors.white.withValues(alpha: 0.94),
                      size: compact ? 46 : 58,
                    ),
                    SizedBox(height: compact ? 2 : 4),
                    Text(
                      'Swipe up for more',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: compact ? 28 : 34,
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                        shadows: <Shadow>[
                          Shadow(
                            color: Colors.black54,
                            blurRadius: 18,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: compact ? 8 : 10),
                    Text(
                      'We pause the first video here. Swipe when you are ready.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: compact ? 13 : 15,
                        height: 1.3,
                        shadows: <Shadow>[
                          Shadow(
                            color: Colors.black45,
                            blurRadius: 12,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
