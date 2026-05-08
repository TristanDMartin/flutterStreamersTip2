import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import '../providers/activity_provider.dart';
import '../providers/home_provider.dart' as hp;
import '../services/auth_service.dart';
import '../services/notification_navigation_service.dart';
import '../routing/app_navigator.dart';
import '../routing/app_routes.dart';
import '../widgets/activity_row_view.dart';
import '../widgets/threads/thread_detail_screen.dart';
import '../models/activity_notification.dart';
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
  String _selectedFilter = 'All';
  final List<String> _filters = [
    'All',
    'Likes',
    'Follows',
    'Comments',
    'Tags',
    'Mentions'
  ];

  final ScrollController _scrollController = ScrollController();
  bool _isInitialized = false;
  bool _isInitializationQueued = false;

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
      notifier.init(userId);
      _isInitialized = true;
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

    ref.listen(activityProvider, (prev, next) {
      if (prev?.isLoading == true && next.isLoading == false) {
        _fadeController.forward();
      }
      // ❌ REMOVED: SnackBar error display - errors shown in _buildErrorState() instead
    });

    // Activity data is initialized in initState

    final filteredGrouped = _filterNotifications(state.grouped);
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
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final int unread = _getTotalNotificationCount(state.grouped);
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: shell.heroGradient,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: shell.heroBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: shell.isLight
                ? Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).pop();
            },
            icon: Icon(
              Icons.arrow_back_ios_new,
              color: shell.onChrome,
              size: 20,
            ),
            padding: const EdgeInsets.all(8),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Activity',
                      style: TextStyle(
                        color: shell.onChrome,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                    if (unread > 0) ...[
                      const SizedBox(width: 10),
                      AnimatedBuilder(
                        animation: _badgeController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: 0.85 + (0.15 * _badgeController.value),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: <Color>[
                                    scheme.primary,
                                    scheme.secondary,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(999),
                                boxShadow: [
                                  BoxShadow(
                                    color: scheme.primary.withValues(
                                      alpha: 0.35,
                                    ),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Text(
                                '$unread',
                                style: TextStyle(
                                  color: scheme.onPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                if (state.isProcessing)
                  Row(
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            shell.onChrome,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Processing ${state.processingCount}…',
                          style: TextStyle(
                            color: shell.muted,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    unread > 0 ? '$unread unread' : 'Likes, follows & replies',
                    style: TextStyle(
                      color: shell.mutedStrong,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          if (_hasUnreadNotifications(state.grouped))
            IconButton(
              tooltip: 'Mark all read',
              onPressed: _handleMarkAllAsRead,
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      scheme.primary,
                      scheme.secondary,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: scheme.outline.withValues(
                      alpha: shell.isLight ? 0.35 : 0.4,
                    ),
                  ),
                ),
                child: Icon(
                  Icons.done_all_rounded,
                  color: scheme.onPrimary,
                  size: 18,
                ),
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
                    size: 24,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(StSupportShellStyle shell) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _filters.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final String filter = _filters[index];
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
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    child: Text(
                      filter,
                      style: TextStyle(
                        color: isSelected
                            ? shell.chipSelectedFg
                            : shell.chipUnselectedFg,
                        fontSize: 14,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        letterSpacing: 0.2,
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
                      'No Activity Yet',
                      style: TextStyle(
                        color: shell.onChrome,
                        fontSize: 28,
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
                      'When people interact with your content,\nyou\'ll see it here',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: shell.muted,
                        fontSize: 16,
                        height: 1.5,
                        letterSpacing: 0.3,
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
                        AppNavigator.openDiscover(context);
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
                          'Explore content',
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
    Map<String, List<ActivityNotification>> grouped,
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
          final List<ActivityNotification> items =
              grouped[title] ?? <ActivityNotification>[];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(shell, title),
              for (final ActivityNotification notification in items)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: ActivityRowView(
                    key: ValueKey(notification.id),
                    notification: notification,
                    onProfileTap: (user) => _handleProfileTap(user),
                    onPostTap: _handlePostTap,
                    onCardTap: _handleNotificationTap,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(StSupportShellStyle shell, String title) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  scheme.primary,
                  scheme.secondary,
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              color: shell.onChrome.withValues(alpha: 0.88),
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  Map<String, List<ActivityNotification>> _filterNotifications(
      Map<String, List<ActivityNotification>> grouped) {
    if (_selectedFilter == 'All') return grouped;

    final filtered = <String, List<ActivityNotification>>{};
    for (final entry in grouped.entries) {
      final filteredItems = entry.value.where((notification) {
        switch (_selectedFilter) {
          case 'Likes':
            return notification.type == ActivityNotificationType.like;
          case 'Follows':
            return notification.type == ActivityNotificationType.follow;
          case 'Comments':
            return notification.type == ActivityNotificationType.comment;
          case 'Tags':
            return notification.type == ActivityNotificationType.tag;
          case 'Mentions':
            return notification.type == ActivityNotificationType.mention;
          default:
            return true;
        }
      }).toList();

      if (filteredItems.isNotEmpty) {
        filtered[entry.key] = filteredItems;
      }
    }
    return filtered;
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
    await notifier.init(userId);
  }

  void _handleMarkAllAsRead() {
    HapticFeedback.lightImpact();
    final notifier = ref.read(activityProvider.notifier);
    final auth = ref.read(authServiceProvider);
    final userId = auth.currentUser?.id;

    if (userId != null) {
      notifier.markAllDelivered(userId);
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

  void _handleNotificationTap(ActivityNotification notification) {
    HapticFeedback.lightImpact();

    // Mark notification as read
    _markNotificationAsRead(notification);

    if (notification.videoId?.isNotEmpty == true) {
      _handlePostTap(notification);
      return;
    }

    final threadId = notification.threadId ?? notification.postId;
    if (threadId != null && threadId.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ThreadDetailScreen(postId: threadId),
        ),
      );
      return;
    }

    // Navigate based on notification type
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
        if (notification.videoId != null) {
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
        if (_looksLikeContentPlanAction(notification)) {
          AppNavigator.openManagePosts(context);
          return;
        }
        if (_isSystemActor(notification.user)) {
          Navigator.of(context).pushNamed(AppRoutes.inbox);
          return;
        }
        _handleProfileTap(notification.user);
        break;
    }
  }

  void _markNotificationAsRead(ActivityNotification notification) {
    if (notification.status == 'pending') {
      final notifier = ref.read(activityProvider.notifier);
      notifier.markNotificationAsRead(notification.id);

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
    final parts = key.split('/');
    if (parts.length == 3) {
      final month = int.tryParse(parts[0]) ?? 1;
      final day = int.tryParse(parts[1]) ?? 1;
      final year = int.tryParse(parts[2]) ?? DateTime.now().year;
      return DateTime(year, month, day);
    }
    return DateTime(2000);
  }
}
