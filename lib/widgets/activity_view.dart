import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import '../providers/activity_provider.dart';
import '../providers/home_provider.dart' as hp;
import '../services/auth_service.dart';
import '../services/notification_navigation_service.dart';
import '../routing/app_navigator.dart';
import '../widgets/activity_row_view.dart';
import '../models/activity_notification.dart';
import '../models/user.dart';
// import '../widgets/post_detail_view.dart'; // Removed - unused
import 'instant_response_button.dart';

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

  bool _isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();
  bool _isInitialized = false;

  // Common button gradient used throughout the view
  static const LinearGradient _buttonGradient = LinearGradient(
    colors: [
      Color(0xFF9248D2), // Primary purple
      Color(0xFF7768DF), // Secondary purple
      Color(0xFF1670DE), // Blue
      Color(0xFF3C8BD6), // Lighter blue
      Color(0xFF4897D2), // Lightest blue
    ],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

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

    // Setup scroll listener for pagination
    _scrollController.addListener(_onScroll);

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

    // Clear any pending operations
    _isLoadingMore = false;

    super.dispose();
  }

  // ❌ REMOVED: activate() override - caused duplicate initialization

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authServiceProvider);
    final state = ref.watch(activityProvider);

    if (auth.isLoading) {
      return _buildLoadingScaffold();
    }

    final userId = auth.currentUser?.id;
    if (userId == null) {
      return _buildSignInRequiredScaffold();
    }

    // Initialize ActivityView if not already initialized
    if (!_isInitialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
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

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            SafeArea(
              child: Column(
                  children: [
                    _buildHeader(state),
                    _buildFilterChips(),
                    if (state.isProcessing)
                      _buildProcessingIndicator(state.processingCount),
                    Expanded(
                      child: FadeTransition(
                        opacity: _fadeController,
                        child: state.isLoading
                            ? _buildSkeletonLoading()
                            : state.hasError
                                ? _buildErrorState(
                                    state.error ?? 'Unknown error')
                                : filteredGrouped.isEmpty
                                    ? _buildEmptyState()
                                    : _buildActivityList(
                                        titles, filteredGrouped),
                      ),
                    ),
                  ],
                ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingScaffold() {
    return Scaffold(
      body: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      ),
    );
  }

  Widget _buildSignInRequiredScaffold() {
    return Scaffold(
      body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.notifications_outlined,
                size: 64,
                color: Colors.white70,
              ),
              SizedBox(height: 16),
              Text(
                'Sign in to view your activity',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Stay updated with all your notifications',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
    );
  }

  Widget _buildHeader(ActivityState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          // Back button (matches ProfileView style)
          InstantIconButton(
            onPressed: () => Navigator.of(context).pop(),
            hapticType: HapticFeedbackType.lightImpact,
            icon: const Icon(
              Icons.arrow_back,
              color: Colors.white,
              size: 24,
            ),
          ),
          // Title with animation
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Activity',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (_getTotalNotificationCount(state.grouped) > 0) ...[
                      const SizedBox(width: 12),
                      AnimatedBuilder(
                        animation: _badgeController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: 0.8 + (0.2 * _badgeController.value),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE91E63),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFE91E63)
                                        .withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                '${_getTotalNotificationCount(state.grouped)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
                if (state.isProcessing) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Processing ${state.processingCount} notifications...',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Action buttons
          Row(
            children: [
              // Mark all as read button
              if (_hasUnreadNotifications(state.grouped))
                GestureDetector(
                  onTap: _handleMarkAllAsRead,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: _buttonGradient,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF9248D2).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.done_all,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _handleRefresh,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  child: AnimatedBuilder(
                    animation: _refreshController,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _refreshController.value * 2 * 3.14159,
                        child: const Icon(
                          Icons.refresh,
                          color: Colors.white,
                          size: 20,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = _selectedFilter == filter;

          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() {
                _selectedFilter = filter;
              });
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 28),
              child: Align(
                alignment: Alignment.centerLeft,
                child: isSelected
                    ? ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [
                            Color(0xFF9248D2),
                            Color(0xFF1670DE),
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ).createShader(bounds),
                        child: Text(
                          filter,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : Text(
                        filter,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProcessingIndicator(int count) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: _buildContainerDecoration(),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Processing $count notifications...',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonLoading() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 8),
                spreadRadius: 2,
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, -2),
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.6),
                    width: 1,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 16,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.6),
                          width: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 12,
                      width: 200,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.6),
                          width: 0.5,
                        ),
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

  Widget _buildEmptyState() {
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
                          Colors.white.withValues(alpha: 0.1),
                          Colors.white.withValues(alpha: 0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.notifications_none_outlined,
                      size: 60,
                      color: Colors.white.withValues(alpha: 0.7),
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
                        color: Colors.white.withValues(alpha: 0.9),
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
                        color: Colors.white.withValues(alpha: 0.7),
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
                            horizontal: 32, vertical: 16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF9248D2), // Primary purple
                              Color(0xFF7768DF), // Secondary purple
                              Color(0xFF1670DE), // Blue
                              Color(0xFF3C8BD6), // Lighter blue
                              Color(0xFF4897D2), // Lightest blue
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF9248D2)
                                  .withValues(alpha: 0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Text(
                          'Explore Content',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
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

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 80,
              color: Colors.red.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 24),
            Text(
              'Something went wrong',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF9248D2), // Primary purple
                      Color(0xFF7768DF), // Secondary purple
                      Color(0xFF1670DE), // Blue
                      Color(0xFF3C8BD6), // Lighter blue
                      Color(0xFF4897D2), // Lightest blue
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF9248D2).withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Text(
                  'Try Again',
                  style: TextStyle(
                    color: Colors.white,
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
      List<String> titles, Map<String, List<ActivityNotification>> grouped) {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: Colors.white,
      backgroundColor: const Color(0xFF9248D2),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 100),
        itemCount: titles.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == titles.length) {
            // Loading indicator for pagination
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            );
          }

          final title = titles[index];
          final items = grouped[title] ?? <ActivityNotification>[];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(title),
              for (final notification in items)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: ActivityRowView(
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

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreNotifications();
    }
  }

  Future<void> _loadMoreNotifications() async {
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      // Load more notifications implementation
      // This would involve calling ActivityNotifier.loadMoreNotifications method
      // Currently simulating loading as this feature is not implemented
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      debugPrint('Error loading more notifications: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      margin: const EdgeInsets.only(left: 20, top: 16, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: _buildContainerDecoration(borderRadius: 20),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
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

    _refreshController.forward().then((_) {
      _refreshController.reset();
    });

    // Force refresh the activity data
    final notifier = ref.read(activityProvider.notifier);
    final auth = ref.read(authServiceProvider);
    final userId = auth.currentUser?.id;

    if (userId != null) {
      debugPrint('🔄 Force refreshing activity data...');
      _isInitialized = false; // Reset initialization flag
      notifier.reset(); // Reset the provider
      await notifier.init(userId); // Re-initialize
      debugPrint('🔄 Refresh completed');
    }

    // Simulate refresh delay
    await Future.delayed(const Duration(milliseconds: 1500));
  }

  void _handleMarkAllAsRead() {
    HapticFeedback.lightImpact();
    final notifier = ref.read(activityProvider.notifier);
    final auth = ref.read(authServiceProvider);
    final userId = auth.currentUser?.id;

    if (userId != null) {
      notifier.markAllDelivered(userId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All notifications marked as read'),
          backgroundColor: Color(0xFF9248D2),
          duration: Duration(seconds: 2),
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

  void _handleNotificationTap(ActivityNotification notification) {
    HapticFeedback.lightImpact();

    // Mark notification as read
    _markNotificationAsRead(notification);

    // Navigate based on notification type
    switch (notification.type) {
      case ActivityNotificationType.like:
      case ActivityNotificationType.comment:
        if (notification.postThumbnailUrl != null) {
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

  BoxDecoration _buildContainerDecoration({
    double alpha = 0.1,
    double borderRadius = 16,
    bool hasBorder = true,
    bool hasShadow = false,
  }) {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: alpha),
      borderRadius: BorderRadius.circular(borderRadius),
      border: hasBorder
          ? Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1,
            )
          : null,
      boxShadow: hasShadow
          ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ]
          : null,
    );
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
