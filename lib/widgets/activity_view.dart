import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../features/activity/pulse/activity_pulse_logic.dart';
import '../features/activity/pulse/activity_pulse_tokens.dart';
import '../features/activity/pulse/widgets/activity_pulse_grouped_card.dart';
import '../features/activity/pulse/widgets/activity_pulse_insight_card.dart';
import '../features/activity/activity_notification_rules.dart';
import '../features/gamification/gamification_providers.dart';
import '../features/gamification/models/user_progress_bundle.dart';
import '../features/tippy/models/tippy_launch_context.dart';
import '../providers/activity_provider.dart';
import '../providers/home_provider.dart' as hp;
import '../services/auth_service.dart';
import '../services/notification_navigation_service.dart';
import '../routing/app_navigator.dart';
import '../routing/app_routes.dart';
import '../features/approvals/approval_queue_contract.dart';
import '../widgets/activity_row_view.dart';
import '../widgets/threads/thread_detail_screen.dart';
import '../models/activity_notification.dart';
import '../models/creator_profile_snapshot.dart';
import '../models/user.dart';
import '../core/theme/support_shell_style.dart';

class ActivityView extends ConsumerStatefulWidget {
  const ActivityView({super.key});

  @override
  ConsumerState<ActivityView> createState() => _ActivityViewState();
}

class _ActivityViewState extends ConsumerState<ActivityView>
    with TickerProviderStateMixin {
  late AnimationController _refreshController;
  late AnimationController _fadeController;
  late AnimationController _badgeController;
  ActivityPulseFilter _selectedFilter = ActivityPulseFilter.all;

  final ScrollController _scrollController = ScrollController();
  bool _isInitialized = false;
  bool _isInitializationQueued = false;
  bool _isMarkingVisibleAsRead = false;

  @override
  void initState() {
    super.initState();
    _refreshController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _badgeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeController.forward();
    _badgeController.forward();

    // Initialize activity data will be called in build method
  }

  void _initializeActivityView() {
    final notifier = ref.read(activityProvider.notifier);
    final auth = ref.read(authServiceProvider);
    final userId = auth.currentUser?.id;

    if (userId != null) {
      debugPrint('🔄 Initializing ActivityView for user: $userId');
      notifier.startProcessingListener(userId);
      _isInitialized = true;
      // Clear Discover/nav indicator as soon as Activity is opened.
      ref.read(activityNavUnreadCountProvider.notifier).clearAfterActivityViewed();
      unawaited(() async {
        await notifier.init(userId);
        if (!mounted) return;
        await notifier.markAllDelivered(userId);
        if (!mounted) return;
        ref
            .read(activityNavUnreadCountProvider.notifier)
            .clearAfterActivityViewed();
      }());
    }
  }

  @override
  void dispose() {
    _refreshController.dispose();
    _fadeController.dispose();
    _badgeController.dispose();
    _scrollController.dispose();

    super.dispose();
  }

  // ❌ REMOVED: activate() override - caused duplicate initialization

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authServiceProvider);
    final state = ref.watch(activityProvider);
    final int unreadActivityCount =
        ref.watch(unreadActivityCountProvider).valueOrNull ?? 0;

    if (auth.isLoading) {
      return _buildLoadingScaffold(context);
    }

    final userId = auth.currentUser?.id;
    if (userId == null) {
      return _buildSignInRequiredScaffold(context);
    }

    // Initialize ActivityView if not already initialized
    if (!_isInitialized && !_isInitializationQueued) {
      _isInitializationQueued = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _isInitializationQueued = false;
        if (!mounted || _isInitialized) return;
        _initializeActivityView();
      });
    }
    // Keep badge clear while Activity is open: retry until Firestore unread is 0.
    final bool hasLocalPending = state.grouped.values.any(
      (List<ActivityNotification> list) => list.any(
        (ActivityNotification n) => n.status == 'pending',
      ),
    );
    if (!_isMarkingVisibleAsRead &&
        !state.isLoading &&
        (unreadActivityCount > 0 || hasLocalPending)) {
      _isMarkingVisibleAsRead = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        // Clear Discover/nav indicator after build completes.
        ref
            .read(activityNavUnreadCountProvider.notifier)
            .clearAfterActivityViewed();
        final String? activeUserId =
            ref.read(authServiceProvider).currentUser?.id;
        if (activeUserId == null) {
          _isMarkingVisibleAsRead = false;
          return;
        }
        try {
          await ref.read(activityProvider.notifier).markAllDelivered(
                activeUserId,
              );
          if (mounted) {
            ref
                .read(activityNavUnreadCountProvider.notifier)
                .clearAfterActivityViewed();
          }
        } finally {
          if (mounted) {
            _isMarkingVisibleAsRead = false;
          }
        }
      });
    }

    ref.listen(activityProvider, (prev, next) {
      if (prev?.isLoading == true && next.isLoading == false) {
        _fadeController.forward();
      }
      // ❌ REMOVED: SnackBar error display - errors shown in _buildErrorState() instead
    });

    // Activity data is initialized in initState

    final UserProgressBundle? bundle =
        ref.watch(userProgressBundleProvider).valueOrNull;
    final Map<String, List<ActivityPulseEntry>> filteredGrouped =
        ActivityPulseLogic.processGrouped(
      grouped: state.grouped,
      filter: _selectedFilter,
      bundle: bundle,
    );
    final titles = _orderedSectionTitles(filteredGrouped.keys.toList());

    // Debug information (reduced for production)
    if (state.grouped.isNotEmpty) {
      debugPrint(
          '🔍 ActivityView: ${state.grouped.length} sections, ${filteredGrouped.length} filtered');
    }

    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: shell.scaffold,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(context, state, shell),
              _buildFilterChips(shell),
              if (state.isProcessing)
                _buildProcessingIndicator(shell, state.processingCount),
              Expanded(
                child: FadeTransition(
                  opacity: _fadeController,
                  child: state.isLoading
                      ? _buildSkeletonLoading(shell)
                      : state.hasError
                          ? _buildErrorState(
                              context,
                              shell,
                              state.error ?? 'Unknown error',
                            )
                          : filteredGrouped.isEmpty
                              ? _buildEmptyState(shell)
                              : _buildActivityList(
                                  context,
                                  shell,
                                  titles,
                                  filteredGrouped,
                                ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingScaffold(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Scaffold(
      backgroundColor: shell.scaffold,
      body: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(shell.refreshColor),
        ),
      ),
    );
  }

  Widget _buildSignInRequiredScaffold(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Scaffold(
      backgroundColor: shell.scaffold,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.notifications_outlined,
                size: 64,
                color: shell.muted,
              ),
              const SizedBox(height: 16),
              Text(
                'Sign in to view your activity',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: shell.onChrome,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Stay updated with likes, follows, and comments',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: shell.muted,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ActivityState state,
    StSupportShellStyle shell,
  ) {
    final int unread = _getTotalNotificationCount(state.grouped);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).pop();
            },
            icon: Icon(
              Icons.arrow_back_ios_new,
              color: shell.onChrome,
              size: 18,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      'Activity',
                      style: TextStyle(
                        color: shell.onChrome,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (unread > 0) ...<Widget>[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          gradient: ActivityPulseTokens.activeChipGradient,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$unread',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  'Your creator pulse',
                  style: TextStyle(
                    color: shell.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _handleRefresh,
            icon: AnimatedBuilder(
              animation: _refreshController,
              builder: (BuildContext ctx, Widget? child) {
                return Transform.rotate(
                  angle: _refreshController.value * 2 * 3.14159,
                  child: Icon(
                    Icons.refresh_rounded,
                    color: shell.onChrome,
                    size: 22,
                  ),
                );
              },
            ),
          ),
          IconButton(
            tooltip: 'Mark all read',
            onPressed: _hasUnreadNotifications(state.grouped)
                ? _handleMarkAllAsRead
                : null,
            icon: Icon(
              Icons.tune_rounded,
              color: _hasUnreadNotifications(state.grouped)
                  ? shell.onChrome
                  : shell.iconDim,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(StSupportShellStyle shell) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: SizedBox(
        height: 34,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: ActivityPulseLogic.filters.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final ActivityPulseFilter filter =
                ActivityPulseLogic.filters[index];
            final bool isSelected = _selectedFilter == filter;
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedFilter = filter);
                },
                borderRadius: BorderRadius.circular(20),
                child: Ink(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? shell.chipSelectedBg
                        : shell.chipUnselectedBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? shell.chipSelectedBorder
                          : shell.chipUnselectedBorder,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    child: Text(
                      filter.label,
                      style: TextStyle(
                        color: isSelected
                            ? shell.chipSelectedFg
                            : shell.chipUnselectedFg,
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildProcessingIndicator(StSupportShellStyle shell, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: shell.surfaceCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: shell.surfaceCardBorder,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(shell.refreshColor),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Processing $count notifications…',
                style: TextStyle(
                  color: shell.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonLoading(StSupportShellStyle shell) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: shell.skeletonFill,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: shell.surfaceCardBorder,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: shell.skeletonLine,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 14,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: shell.skeletonLine,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 11,
                      width: 160,
                      decoration: BoxDecoration(
                        color: shell.skeletonLineDim,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(StSupportShellStyle shell) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated icon with glass morphism effect // cspell:ignore morphism
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 1000),
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Transform.scale(
                  scale: 0.8 + (0.2 * value),
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          shell.glassCircleGradientStart,
                          shell.glassCircleGradientEnd,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: shell.glassCircleBorder,
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: shell.shadowSoft,
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.notifications_none_outlined,
                      size: 60,
                      color: shell.muted,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),

            // Title with animation
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 1200),
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - value)),
                    child: Text(
                      'No new activity yet',
                      style: TextStyle(
                        color: shell.onChrome,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            // Subtitle with animation
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 1400),
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - value)),
                    child: Text(
                      'Post consistently.\nJoin threads.\nBuild momentum.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: shell.muted,
                        fontSize: 15,
                        height: 1.5,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 40),

            // Action button with animation
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 1600),
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 30 * (1 - value)),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.of(context).pushNamed(AppRoutes.camera);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: <Color>[
                              Theme.of(context).colorScheme.primary,
                              Theme.of(context).colorScheme.secondary,
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .outline
                                .withValues(alpha: 0.35),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.35),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Text(
                          'Upload content',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    StSupportShellStyle shell,
    String error,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 72,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 24),
            Text(
              'Something went wrong',
              style: TextStyle(
                color: shell.onChrome,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: shell.muted,
                fontSize: 16,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                final notifier = ref.read(activityProvider.notifier);
                final auth = ref.read(authServiceProvider);
                final userId = auth.currentUser?.id;
                if (userId != null) {
                  notifier.init(userId);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.secondary,
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.35),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.32),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Text(
                  'Try again',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityList(
    BuildContext context,
    StSupportShellStyle shell,
    List<String> titles,
    Map<String, List<ActivityPulseEntry>> grouped,
  ) {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: shell.refreshColor,
      backgroundColor: shell.refreshBackground,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 100),
        itemCount: titles.length,
        itemBuilder: (context, index) {
          final String title = titles[index];
          final List<ActivityPulseEntry> items =
              grouped[title] ?? <ActivityPulseEntry>[];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _buildSectionHeader(shell, title),
              for (final ActivityPulseEntry entry in items)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _buildPulseEntry(context, entry),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPulseEntry(BuildContext context, ActivityPulseEntry entry) {
    switch (entry) {
      case ActivityPulseSingle(:final ActivityNotification notification):
        return ActivityRowView(
          key: ValueKey(notification.id),
          notification: notification,
          onProfileTap: _handleProfileTap,
          onPostTap: _handlePostTap,
          onCardTap: _handleNotificationTap,
        );
      case ActivityPulseGrouped(
          :final List<ActivityNotification> notifications
        ):
        return ActivityPulseGroupedCard(
          key: ValueKey('group_${notifications.first.id}'),
          notifications: notifications,
          onTap: () => _handleGroupedTap(notifications),
        );
      case ActivityPulseInsight insight:
        return ActivityPulseInsightCard(
          key: ValueKey(insight.id),
          insight: insight,
          onTap: () => _handleInsightTap(insight),
        );
    }
  }

  void _handleGroupedTap(List<ActivityNotification> notifications) {
    HapticFeedback.lightImpact();
    for (final ActivityNotification n in notifications) {
      _markNotificationAsRead(n);
    }
    final ActivityNotification first = notifications.first;
    if (first.videoId?.isNotEmpty == true) {
      _handlePostTap(first);
      return;
    }
    _handleProfileTap(first.user);
  }

  void _handleInsightTap(ActivityPulseInsight insight) {
    HapticFeedback.lightImpact();
    if (insight.accent == ActivityPulseAccent.tippy) {
      AppNavigator.openTippyChat(context);
      return;
    }
    AppNavigator.openDiscover(context);
  }

  Widget _buildSectionHeader(StSupportShellStyle shell, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: Text(
        title,
        style: TextStyle(
          color: shell.muted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> _handleRefresh() async {
    HapticFeedback.lightImpact();
    unawaited(
      _refreshController.forward().then((_) => _refreshController.reset()),
    );
    final notifier = ref.read(activityProvider.notifier);
    final auth = ref.read(authServiceProvider);
    final String? userId = auth.currentUser?.id;
    if (userId == null) return;
    notifier.reset();
    notifier.startProcessingListener(userId);
    await notifier.init(userId, forceReload: true);
    await notifier.markAllDelivered(userId);
  }

  void _handleMarkAllAsRead() {
    HapticFeedback.lightImpact();
    final notifier = ref.read(activityProvider.notifier);
    final auth = ref.read(authServiceProvider);
    final userId = auth.currentUser?.id;

    if (userId != null) {
      unawaited(notifier.markAllDelivered(userId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('All notifications marked as read'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  bool _hasUnreadNotifications(
      Map<String, List<ActivityNotification>> grouped) {
    for (final notifications in grouped.values) {
      for (final notification in notifications) {
        if (notification.status == 'pending') {
          return true;
        }
      }
    }
    return false;
  }

  int _getTotalNotificationCount(
      Map<String, List<ActivityNotification>> grouped) {
    int count = 0;
    for (final notifications in grouped.values) {
      for (final notification in notifications) {
        if (notification.status == 'pending') {
          count++;
        }
      }
    }
    return count;
  }

  void _handleProfileTap(User user) {
    HapticFeedback.lightImpact();

    if (_isSystemActor(user)) {
      Navigator.of(context).pushNamed(AppRoutes.inbox);
      return;
    }

    debugPrint(
        '👆 ActivityView: Profile tap - userId: ${user.id}, username: ${user.username}');

    // Show StreamerCardView as full-screen modal (matching ProfileView/VideoPlayerView pattern)
    AppNavigator.openStreamerCard(
      context,
      userId: user.id,
      initialCreator: CreatorProfileSnapshot.fromUser(user),
      currentUserId: fa.FirebaseAuth.instance.currentUser?.uid,
      onDismiss: () => Navigator.of(context).pop(),
    );
  }

  void _handlePostTap(ActivityNotification notification) {
    HapticFeedback.lightImpact();

    // Mark notification as read
    _markNotificationAsRead(notification);

    // Check if videoId exists
    if (notification.videoId == null || notification.videoId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video not available')),
      );
      return;
    }

    // Navigate to video using notification navigation service
    final navigationService = NotificationNavigationService();
    final homeViewModel = ref.read(hp.homeProvider.notifier);

    navigationService.navigateToVideo(
      context: context,
      videoId: notification.videoId!,
      homeViewModel: homeViewModel,
    );
  }

  bool _isSystemActor(User user) {
    final id = user.id.toLowerCase().trim();
    final username = user.username.toLowerCase().trim();
    return id.contains('system') ||
        username == 'streamerstip' ||
        username == 'system';
  }

  bool _looksLikeContentPlanAction(ActivityNotification notification) {
    final actionText =
        '${notification.actionUrl ?? ''} ${notification.actionType ?? ''}'
            .toLowerCase();
    return actionText.contains('content') || actionText.contains('plan');
  }

  void _openThread(String threadId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ThreadDetailScreen(postId: threadId),
      ),
    );
  }

  void _handleNotificationTap(ActivityNotification notification) {
    HapticFeedback.lightImpact();
    _markNotificationAsRead(notification);

    final String? approvalId = parseApprovalRequestIdFromDeepLink(
      actionUrl: notification.actionUrl,
      actionType: notification.actionType,
      commentText: notification.commentText,
    );
    if (approvalId != null && approvalId.isNotEmpty) {
      final String workspaceId =
          parseWorkspaceIdFromDeepLink(
            actionUrl: notification.actionUrl,
            actionType: notification.actionType,
          ) ??
          fa.FirebaseAuth.instance.currentUser?.uid ??
          '';
      if (workspaceId.isNotEmpty) {
        unawaited(
          AppNavigator.openApprovalReview(
            context,
            requestId: approvalId,
            workspaceId: workspaceId,
          ),
        );
        return;
      }
    }
    if (looksLikeApprovalNotification(
      actionUrl: notification.actionUrl,
      actionType: notification.actionType,
      typeName: notification.type.name,
    )) {
      unawaited(AppNavigator.openStudioTeamControl(context));
      return;
    }

    final String? threadId = notification.effectiveThreadId;
    if (notification.type == ActivityNotificationType.commentReply &&
        threadId != null) {
      _openThread(threadId);
      return;
    }

    if (threadId != null &&
        (notification.isThreadType ||
            notification.type == ActivityNotificationType.mention)) {
      _openThread(threadId);
      return;
    }

    // Website parity: trend coach notifs open Trend Discovery, not blank Tippy.
    if (activityActionUrlLooksLikeTrendDiscovery(notification.actionUrl)) {
      unawaited(_openWebsiteActionUrl(notification.actionUrl));
      return;
    }

    if (notification.isTippyType) {
      AppNavigator.openTippyChat(
        context,
        launchContext: TippyLaunchContext(
          surface: 'activity_tippy_coach',
          prefilledPrompt: tippyPromptFromActivityNotification(
            titleAndBody: notification.commentText,
            actionUrl: notification.actionUrl,
          ),
          insightPrompt: notification.commentText,
        ),
      );
      return;
    }

    if (notification.isContentPlanType ||
        _looksLikeContentPlanAction(notification)) {
      unawaited(AppNavigator.openContentPlanner(context));
      return;
    }

    if (notification.videoId?.isNotEmpty == true) {
      _handlePostTap(notification);
      return;
    }

    switch (notification.type) {
      case ActivityNotificationType.like:
      case ActivityNotificationType.comment:
        if (notification.postThumbnailUrl?.isNotEmpty == true) {
          _handlePostTap(notification);
        } else {
          _handleProfileTap(notification.user);
        }
        break;
      case ActivityNotificationType.follow:
      case ActivityNotificationType.mention:
      case ActivityNotificationType.tag:
        _handleProfileTap(notification.user);
        break;
      case ActivityNotificationType.commentReply:
      case ActivityNotificationType.newVideo:
      case ActivityNotificationType.milestone:
        if (threadId != null) {
          _openThread(threadId);
        } else if (notification.videoId != null) {
          _handlePostTap(notification);
        } else {
          _handleProfileTap(notification.user);
        }
        break;
      case ActivityNotificationType.liveStream:
      case ActivityNotificationType.adminBroadcast:
        if (notification.chatId?.isNotEmpty == true) {
          Navigator.of(context).pushNamed(AppRoutes.inbox);
          return;
        }
        if (activityActionUrlLooksLikeTrendDiscovery(notification.actionUrl)) {
          unawaited(_openWebsiteActionUrl(notification.actionUrl));
          return;
        }
        if (_isSystemActor(notification.user)) {
          AppNavigator.openTippyChat(
            context,
            launchContext: TippyLaunchContext(
              surface: 'activity_system',
              prefilledPrompt: tippyPromptFromActivityNotification(
                titleAndBody: notification.commentText,
                actionUrl: notification.actionUrl,
              ),
            ),
          );
          return;
        }
        _handleProfileTap(notification.user);
        break;
    }
  }

  Future<void> _openWebsiteActionUrl(String? actionUrl) async {
    final String url = resolveActivityWebsiteActionUrl(actionUrl);
    final Uri? uri = Uri.tryParse(url);
    if (uri == null) {
      return;
    }
    try {
      final bool launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open Trend Discovery.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open Trend Discovery.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _markNotificationAsRead(ActivityNotification notification) {
    if (notification.status == 'pending') {
      final notifier = ref.read(activityProvider.notifier);
      unawaited(notifier.markNotificationAsRead(notification.id).then((ok) {
        if (!ok && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Couldn’t mark as read. Try again.'),
              backgroundColor: Theme.of(context).colorScheme.error,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }));

      // Trigger badge animation for visual feedback
      _badgeController.reset();
      _badgeController.forward();
    }
  }

  List<String> _orderedSectionTitles(List<String> titles) {
    final set = titles.toSet();
    final List<String> ordered = [];
    if (set.remove('Today')) ordered.add('Today');
    if (set.remove('Yesterday')) ordered.add('Yesterday');
    final rest = set.toList();
    rest.sort((a, b) => _parseDate(b).compareTo(_parseDate(a)));
    ordered.addAll(rest);
    return ordered;
  }

  DateTime _parseDate(String key) {
    if (key == 'Today') return DateTime.now();
    if (key == 'Yesterday') {
      return DateTime.now().subtract(const Duration(days: 1));
    }
    // Legacy numeric keys: M/d/yyyy
    final List<String> slashParts = key.split('/');
    if (slashParts.length == 3) {
      final int month = int.tryParse(slashParts[0]) ?? 1;
      final int day = int.tryParse(slashParts[1]) ?? 1;
      final int year = int.tryParse(slashParts[2]) ?? DateTime.now().year;
      return DateTime(year, month, day);
    }
    // Feed labels: "Aug 9"
    try {
      final DateTime parsed = DateFormat('MMM d').parse(key);
      final DateTime now = DateTime.now();
      DateTime withYear = DateTime(now.year, parsed.month, parsed.day);
      if (withYear.isAfter(now.add(const Duration(days: 1)))) {
        withYear = DateTime(now.year - 1, parsed.month, parsed.day);
      }
      return withYear;
    } catch (_) {
      return DateTime(2000);
    }
  }
}
