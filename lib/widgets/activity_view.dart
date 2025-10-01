import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/activity_provider.dart';
import '../services/auth_service.dart';
import '../widgets/activity_row_view.dart';
import '../models/activity_notification.dart';
import '../models/user_model.dart' as user_model;
import '../models/user.dart';
import '../views/streamer_card_page.dart';
import 'discover_view.dart';
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
  final List<String> _filters = ['All', 'Likes', 'Follows', 'Comments', 'Tags', 'Mentions'];
  
  bool _isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();
  bool _isInitialized = false;

  // Common gradient used throughout the view
  static const LinearGradient _backgroundGradient = LinearGradient(
    colors: [
      Color(0xFF6137EB), // Purple (matches ProfileView)
      Color(0xFF1C135D), // Dark purple (matches ProfileView)
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

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

  // Common navigation transition
  static const Duration _transitionDuration = Duration(milliseconds: 300);
  static const Curve _transitionCurve = Curves.easeOutCubic;

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

  @override
  void activate() {
    super.activate();
    // Re-initialize when user navigates back to ActivityView
    if (_isInitialized) {
      _initializeActivityView();
    }
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
  }

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
      if (next.hasError && next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });

    // Activity data is initialized in initState

    final filteredGrouped = _filterNotifications(state.grouped);
    final titles = _orderedSectionTitles(filteredGrouped.keys.toList());

    // Debug information (reduced for production)
    if (state.grouped.isNotEmpty) {
      debugPrint('🔍 ActivityView: ${state.grouped.length} sections, ${filteredGrouped.length} filtered');
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: _backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(state),
              _buildFilterChips(),
              if (state.isProcessing) _buildProcessingIndicator(state.processingCount),
              Expanded(
                child: FadeTransition(
                  opacity: _fadeController,
                  child: state.isLoading
                      ? _buildSkeletonLoading()
                      : state.hasError
                          ? _buildErrorState(state.error ?? 'Unknown error')
                          : filteredGrouped.isEmpty
                              ? _buildEmptyState()
                              : _buildActivityList(titles, filteredGrouped),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingScaffold() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: _backgroundGradient,
        ),
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildSignInRequiredScaffold() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: _backgroundGradient,
        ),
        child: const Center(
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
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE91E63),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFE91E63).withValues(alpha:0.3),
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
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Processing ${state.processingCount} notifications...',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha:0.8),
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
                        color: Colors.white.withValues(alpha:0.2),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF9248D2).withValues(alpha:0.3),
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
              // Test notifications button (for development)
              if (kDebugMode)
                GestureDetector(
                  onTap: _handleCreateTestNotifications,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha:0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.orange.withValues(alpha:0.4),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.science,
                      color: Colors.orange,
                      size: 20,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              // Simulate comment button (for development)
              if (kDebugMode)
                GestureDetector(
                  onTap: _handleSimulateComment,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha:0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.green.withValues(alpha:0.4),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.comment,
                      color: Colors.green,
                      size: 20,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              // Refresh button (no background)
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
      height: 50,
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
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                gradient: isSelected 
                    ? const LinearGradient(
                        colors: [
                          Color(0xFF9248D2), // Primary purple
                          Color(0xFF7768DF), // Secondary purple
                          Color(0xFF1670DE), // Blue
                          Color(0xFF3C8BD6), // Lighter blue
                          Color(0xFF4897D2), // Lightest blue
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      )
                    : null,
                color: isSelected 
                    ? null
                    : Colors.white.withValues(alpha:0.1),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: isSelected 
                      ? Colors.white.withValues(alpha:0.4)
                      : Colors.white.withValues(alpha:0.2),
                  width: 1,
                ),
                boxShadow: isSelected ? [
                  BoxShadow(
                    color: const Color(0xFF9248D2).withValues(alpha:0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ] : null,
              ),
              child: Text(
                filter,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
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
                color: Colors.white.withValues(alpha:0.9),
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
            color: Colors.white.withValues(alpha:0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha:0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha:0.3),
                blurRadius: 16,
                offset: const Offset(0, 8),
                spreadRadius: 2,
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha:0.1),
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
                  color: Colors.white.withValues(alpha:0.4),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha:0.6),
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
                        color: Colors.white.withValues(alpha:0.4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white.withValues(alpha:0.6),
                          width: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 12,
                      width: 200,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha:0.4),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.white.withValues(alpha:0.6),
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
                          Colors.white.withValues(alpha:0.1),
                          Colors.white.withValues(alpha:0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha:0.2),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha:0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.notifications_none_outlined,
                      size: 60,
                      color: Colors.white.withValues(alpha:0.7),
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
                        color: Colors.white.withValues(alpha:0.9),
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
                        color: Colors.white.withValues(alpha:0.7),
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
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const DiscoverView(),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
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
                              color: const Color(0xFF9248D2).withValues(alpha:0.4),
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
              color: Colors.red.withValues(alpha:0.7),
            ),
            const SizedBox(height: 24),
            Text(
              'Something went wrong',
              style: TextStyle(
                color: Colors.white.withValues(alpha:0.9),
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha:0.7),
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
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
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
                      color: const Color(0xFF9248D2).withValues(alpha:0.3),
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

  Widget _buildActivityList(List<String> titles, Map<String, List<ActivityNotification>> grouped) {
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
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: ActivityRowView(
                    notification: notification,
                    onProfileTap: (user) => _handleProfileTap(user as user_model.User),
                    onPostTap: _handlePostTap,
                    onFollowAction: _handleFollowAction,
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
      // TODO: Implement loadMoreNotifications method in ActivityNotifier
      // For now, just simulate loading
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

  void _handleCreateTestNotifications() {
    HapticFeedback.lightImpact();
    final notifier = ref.read(activityProvider.notifier);
    final auth = ref.read(authServiceProvider);
    final userId = auth.currentUser?.id;
    
    if (userId != null) {
      notifier.createRealisticTestNotifications(userId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test notifications created! Check your activity feed.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _handleSimulateComment() {
    HapticFeedback.lightImpact();
    final notifier = ref.read(activityProvider.notifier);
    final auth = ref.read(authServiceProvider);
    final userId = auth.currentUser?.id;
    
    if (userId != null) {
      // Use a test commenter ID - you can change this to a real user ID
      const testCommenterId = 'test_commenter_123';
      const testVideoId = 'test_video_456';
      
      notifier.simulateCommentNotification(userId, testCommenterId, testVideoId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Comment notification simulated! Check your activity feed.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  bool _hasUnreadNotifications(Map<String, List<ActivityNotification>> grouped) {
    for (final notifications in grouped.values) {
      for (final notification in notifications) {
        if (notification.status == 'pending') {
          return true;
        }
      }
    }
    return false;
  }

  int _getTotalNotificationCount(Map<String, List<ActivityNotification>> grouped) {
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

  void _handleProfileTap(user_model.User user) {
    HapticFeedback.lightImpact();
    // Convert user_model.User to User for StreamerCardPage
    final userForCard = User(
      id: user.id,
      displayName: user.displayName,
      username: user.username,
      bio: user.bio,
      avatarURL: user.avatarURL,
      onlineStatus: user.onlineStatus.name,
      hashtags: user.hashtags,
      followerCount: user.followerCount,
      followingCount: user.followingCount,
      postCount: user.postCount,
    );
    
    _navigateWithSlideTransition(
      StreamerCardPage(user: userForCard),
      const Offset(1.0, 0.0),
    );
  }

  void _handlePostTap(ActivityNotification notification) {
    HapticFeedback.lightImpact();
    
    // Mark notification as read
    _markNotificationAsRead(notification);
    
    // _navigateWithSlideTransition(
    //   PostDetailView(notification: notification),
    //   const Offset(0.0, 1.0),
    //   fullscreenDialog: true,
    // );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Post detail view coming soon!')),
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
          _handleProfileTap(notification.user as user_model.User);
        }
        break;
      case ActivityNotificationType.follow:
      case ActivityNotificationType.mention:
      case ActivityNotificationType.tag:
        _handleProfileTap(notification.user as user_model.User);
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

  void _handleFollowAction(User user) {
    HapticFeedback.lightImpact();
    
    // Navigate to StreamerCardView
    _handleProfileTap(user as user_model.User);
  }


  void _navigateWithSlideTransition(Widget page, Offset beginOffset, {bool fullscreenDialog = false}) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: beginOffset,
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: _transitionCurve,
            )),
            child: child,
          );
        },
        transitionDuration: _transitionDuration,
        fullscreenDialog: fullscreenDialog,
      ),
    );
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
      border: hasBorder ? Border.all(
        color: Colors.white.withValues(alpha: 0.2),
        width: 1,
      ) : null,
      boxShadow: hasShadow ? [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.1),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ] : null,
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
    if (key == 'Yesterday') return DateTime.now().subtract(const Duration(days: 1));
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

