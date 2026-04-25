import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/calendar_event.dart';
import '../providers/status_provider.dart';
import '../models/user_status.dart';
import '../widgets/profile_video_feed_view.dart';
import '../services/enhanced_bookmark_service.dart';
import 'streamer_share_sheet.dart';
import 'brand_icons.dart';
import '../services/unified_avatar_service.dart';
import '../services/chat_service.dart';
import '../providers/follows_provider.dart';
import '../providers/follow_refresh_provider.dart';
import '../utils/avatar_url_resolver.dart';
import '../providers/following_provider.dart';
import '../providers/home_provider.dart' as hp;
import '../providers/video_service_provider.dart' as video_providers;
import '../services/user_blocking_service.dart';
import '../services/global_playback_manager.dart';
import '../routing/app_navigator.dart';
import '../constants/app_colors.dart';
import 'streamer_card_profile_controller.dart';
import 'streamer_card_relationship_controller.dart';
import 'streamer_card_sections.dart';

class StreamerCardView extends ConsumerStatefulWidget {
  final String userId; // Changed from StreamerCard to userId for live data
  final String? currentUserId;
  final VoidCallback? onDismiss;
  final Function(String userId)? onFollow;
  final Function(String userId)? onMessage;
  final Function(String userId)? onShare;
  final Function(String tabName)?
      onNavigateToTab; // New callback for tab navigation

  const StreamerCardView({
    super.key,
    required this.userId,
    this.currentUserId,
    this.onDismiss,
    this.onFollow,
    this.onMessage,
    this.onShare,
    this.onNavigateToTab,
  });

  @override
  ConsumerState<StreamerCardView> createState() => _StreamerCardViewState();
}

class _StreamerCardViewState extends ConsumerState<StreamerCardView>
    with TickerProviderStateMixin {
  late AnimationController _flipController;
  late final GlobalPlaybackManager _playbackManager;
  late Animation<double> _flipAnimation;
  bool _isFront = true;

  // MARK: - State Management
  String _selectedHashtag = "";
  bool _showBio = true;
  bool _showPlatforms = true;
  bool _showCalendar = true;
  final Set<String> _bookmarkedEventIds = {};
  List<Map<String, dynamic>> _platforms = [];
  List<CalendarEvent> _calendarEvents = [];

  // Gradient for selected hashtag
  final LinearGradient _selectedHashtagGradient = const LinearGradient(
    colors: [Color(0xFF955CFF), Color(0xFF3D99F7)], // Match ProfileBackView
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // Bookmark service
  late final EnhancedBookmarkService _bookmarkService;

  // Blocking service
  late final UserBlockingService _blockingService;

  // Real-time data
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  String? _error;
  String? _resolvedUserDocId;
  late final StreamerCardProfileController _profileController;

  late final StreamerCardRelationshipController _relationshipController;

  // Tab management
  int _selectedTabIndex = 0; // 0: Video, 1: Favorites, 2: Tagged

  // Chat UI State
  bool _showChatView = false;
  Map<String, dynamic>? _selectedChat;

  // ✅ FIX #6: Debouncing timer for batched rebuilds
  Timer? _rebuildDebouncer;

  @override
  void initState() {
    super.initState();

    // Initialize FollowsService with EventTriggerService for notifications
    _playbackManager = GlobalPlaybackManager.instance;
    _playbackManager.pauseAll();

    _bookmarkService = EnhancedBookmarkService();
    _blockingService = UserBlockingService();
    _relationshipController = StreamerCardRelationshipController(
      followsService: ref.read(followsServiceProvider),
    )..addListener(_handleRelationshipStateChanged);
    _profileController = StreamerCardProfileController()
      ..addListener(_handleProfileStateChanged);
    _blockingService.blockListRevision.addListener(_handleBlockListChanged);
    _initializeBookmarks();
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _flipAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _flipController,
      curve: Curves.easeInOut,
    ));

    // ✅ FIX #4: Schedule async load to avoid blocking initState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint(
          '🔍 StreamerCardView: User ID from NetworkView: ${widget.userId}');
      debugPrint(
          '🔍 StreamerCardView: User ID length: ${widget.userId.length}');

      // Check if this looks like a Firebase UID (long string)
      if (widget.userId.length > 20) {
        debugPrint(
            '🔍 StreamerCardView: Detected Firebase UID, trying to find user by ID first');
        _loadUserProfile();
      } else {
        debugPrint('🔍 StreamerCardView: Short user ID, trying direct load');
        _loadUserProfile();
      }
    });
  }

  void _handleProfileStateChanged() {
    if (!mounted) return;

    final profileState = _profileController.state;
    final previousResolvedUserDocId = _resolvedUserDocId;
    final previousUserData = _userData;

    setState(() {
      _userData = profileState.userData;
      _resolvedUserDocId = profileState.resolvedUserDocId;
      _isLoading = profileState.isLoading;
      _error = profileState.error;
    });

    final profileChanged = previousResolvedUserDocId != _resolvedUserDocId ||
        !identical(previousUserData, _userData);
    if (profileChanged && _userData != null) {
      unawaited(
        _relationshipController.bind(
          currentUserId: widget.currentUserId,
          targetUserId: widget.userId,
        ),
      );
      _loadPlatforms();
      _loadCalendarEvents();
    }
  }

  void _handleRelationshipStateChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _handleBlockListChanged() {
    if (widget.currentUserId == widget.userId) {
      return;
    }
    unawaited(_dismissIfViewingBlockedUser());
  }

  Future<void> _dismissIfViewingBlockedUser() async {
    final blockedUserIds = await _blockingService.getBlockedUsers();
    if (!mounted || !blockedUserIds.contains(widget.userId)) {
      return;
    }

    if (widget.onDismiss != null) {
      widget.onDismiss!();
      return;
    }

    Navigator.of(context).maybePop();
  }

  Future<void> _initializeBookmarks() async {
    try {
      await _bookmarkService.initialize();
      await _fetchBookmarkedEventIds();
    } catch (e) {
      if (kDebugMode) {
        // debugPrint('❌ StreamerCardView: Error initializing bookmarks: $e');
      }
    }
  }

  Future<void> _fetchBookmarkedEventIds() async {
    try {
      if (kDebugMode) {
        // debugPrint('📚 StreamerCardView: Fetching bookmarked event IDs...');
      }
      final bookmarkedIds = await _bookmarkService.fetchBookmarkedEventIds();
      if (kDebugMode) {
        // debugPrint('📚 StreamerCardView: Found ${bookmarkedIds.length} bookmarked events: $bookmarkedIds');
      }
      if (mounted) {
        setState(() {
          _bookmarkedEventIds.clear();
          _bookmarkedEventIds.addAll(bookmarkedIds);
        });
      }
    } catch (e) {
      if (kDebugMode) {
        // debugPrint('❌ StreamerCardView: Error fetching bookmarked event IDs: $e');
      }
    }
  }

  Future<void> _loadUserProfile() async {
    debugPrint(
        '🔍 StreamerCardView: Loading user data for userId: ${widget.userId}');
    await _profileController.load(widget.userId);
  }

  @override
  void didUpdateWidget(covariant StreamerCardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_loadUserProfile());
        }
      });
    }
  }

  // MARK: - Computed Properties
  Map<String, dynamic> get userData => _userData ?? {};
  String get _effectiveUserId => _resolvedUserDocId ?? widget.userId;
  StreamerCardRelationshipState get relationshipState =>
      _relationshipController.state;
  bool get _isFollowing => relationshipState.isFollowing;
  bool get _isFollowedByStreamer => relationshipState.isFollowedByStreamer;
  bool get _isConnected => relationshipState.isConnected;
  bool get _isFollowingOperation => relationshipState.isFollowingOperation;
  bool get _isUnfollowingOperation => relationshipState.isUnfollowingOperation;

  String get displayName =>
      userData['displayName'] as String? ?? 'Unknown User';
  String get username => userData['username'] as String? ?? 'unknown';
  String get bio => userData['bio'] as String? ?? '';
  String? get avatarURL => resolveAvatarUrl(userData);

  List<String> get hashtags {
    final hashtagsData = userData['hashtags'];
    if (hashtagsData == null) return [];

    if (hashtagsData is List<dynamic>) {
      return hashtagsData.cast<String>();
    } else if (hashtagsData is String) {
      return hashtagsData
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();
    }

    return [];
  }

  int get selectedHashtagIndex {
    final index = hashtags.indexOf(_selectedHashtag);
    return index >= 0 ? index : 0;
  }

  bool get isOwner {
    // For StreamerCardView, visitors should see bookmark buttons, not delete buttons
    // Only allow deletion if explicitly viewing own profile (which should use ProfileView instead)
    // For now, always show bookmark buttons to visitors
    return false;
  }

  @override
  void dispose() {
    // ✅ FIX #6: Cancel debounce timer
    _rebuildDebouncer?.cancel();

    _flipController.dispose();
    _blockingService.blockListRevision.removeListener(_handleBlockListChanged);

    _profileController
      ..removeListener(_handleProfileStateChanged)
      ..dispose();
    _relationshipController
      ..removeListener(_handleRelationshipStateChanged)
      ..dispose();

    // Unblock playback now that this card is closing
    _playbackManager.unblock();

    super.dispose();
  }

  void _notifyFollowStateChanged() {
    ref.read(followRefreshProvider.notifier).state++;
    ref.invalidate(followingProvider);
    ref.invalidate(hp.homeProvider);
  }

  Future<void> _toggleBookmark(CalendarEvent event) async {
    HapticFeedback.lightImpact();

    final isBookmarked = _bookmarkedEventIds.contains(event.id);

    if (kDebugMode) {
      // debugPrint('🔖 StreamerCardView: Toggling bookmark for event: ${event.id}');
      // debugPrint('🔖 StreamerCardView: Currently bookmarked: $isBookmarked');
      // debugPrint('🔖 StreamerCardView: Event title: ${event.title}');
      // debugPrint('🔖 StreamerCardView: Event date: ${event.date}');
      // debugPrint('🔖 StreamerCardView: Creator ID: ${widget.userId}');
    }

    // Check if user is authenticated
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (kDebugMode) {
        // debugPrint('❌ StreamerCardView: No authenticated user');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in to bookmark events'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    if (kDebugMode) {
      // debugPrint('✅ StreamerCardView: User authenticated: ${currentUser.uid}');
    }

    // Optimistic UI update
    if (isBookmarked) {
      _bookmarkedEventIds.remove(event.id);
    } else {
      _bookmarkedEventIds.add(event.id);
    }
    setState(() {});

    try {
      bool success;
      String message;

      if (isBookmarked) {
        // Remove bookmark
        success = await _bookmarkService.deleteBookmark(eventId: event.id);
        message = success
            ? 'Event removed from bookmarks!'
            : 'Failed to remove bookmark';
      } else {
        // Add bookmark
        success = await _bookmarkService.bookmarkEvent(
          eventId: event.id,
          creatorId: widget.userId,
          title: event.title,
          startAt: event.date,
          notifyAt: event.date.subtract(const Duration(minutes: 15)),
          source: 'streamer_card',
        );
        message = success
            ? 'Event saved to your bookmarks! You can view it in the menu.'
            : 'Failed to save bookmark';
      }

      if (!success && mounted) {
        // Revert optimistic update on failure
        if (isBookmarked) {
          _bookmarkedEventIds.add(event.id);
        } else {
          _bookmarkedEventIds.remove(event.id);
        }
        setState(() {});
      }

      if (mounted) {
        // Show message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: success ? Colors.green : Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Revert optimistic update on error
      if (isBookmarked) {
        _bookmarkedEventIds.add(event.id);
      } else {
        _bookmarkedEventIds.remove(event.id);
      }
      setState(() {});

      if (kDebugMode) {
        // debugPrint('❌ StreamerCardView: Error toggling bookmark: $e');
        // debugPrint('❌ StreamerCardView: Error type: ${e.runtimeType}');
        if (e is FirebaseException) {
          // debugPrint('❌ StreamerCardView: Firebase error code: ${e.code}');
          // debugPrint('❌ StreamerCardView: Firebase error message: ${e.message}');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _deleteEvent(String eventId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0E1220),
        title: const Text(
          'Delete Event',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to delete this event?',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Event deletion functionality - placeholder for future implementation
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Event deleted'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 1),
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _flipCard() {
    if (_isFront) {
      _flipController.forward();
    } else {
      _flipController.reverse();
    }
    _isFront = !_isFront;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_error != null) {
      return _buildErrorState();
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: AppColors.supportBackground,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.supportBackground,
        extendBody: true,
        extendBodyBehindAppBar:
            false, // SAFE AREA FIX: Don't extend behind system UI
        body: Stack(
          children: [
            // Main StreamerCardView
            AnimatedBuilder(
              animation: _flipAnimation,
              builder: (context, child) {
                final isShowingFront = _flipAnimation.value < 0.5;
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateY(_flipAnimation.value * 3.14159),
                  child: isShowingFront
                      ? _buildFrontView()
                      : Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()..rotateY(3.14159),
                          child: _buildBackView(),
                        ),
                );
              },
            ),
            // Chat View Overlay (Full Screen Cover)
            if (_showChatView) _buildChatView(),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Scaffold(
      backgroundColor: AppColors.supportBackground,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: AppColors.supportSurfaceGradient,
          ),
        ),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Scaffold(
      backgroundColor: AppColors.supportBackground,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: AppColors.supportSurfaceGradient,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.white,
                size: 64,
              ),
              const SizedBox(height: 16),
              const Text(
                'Error Loading Profile',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error ?? 'Unknown error',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _error = null;
                  });
                  _loadUserProfile();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Chat View Presentation - Full Screen Cover
  Widget _buildChatView() {
    if (_selectedChat == null) return const SizedBox.shrink();

    return Container(
      color: AppColors.supportBackground,
      child: SafeArea(
        child: Column(
          children: [
            // Chat Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0E1220),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _showChatView = false;
                        _selectedChat = null;
                      });
                    },
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  UnifiedAvatarService().getAvatar(
                    imageUrl: avatarURL ?? '',
                    radius: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '@$username',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Chat Content Placeholder
            Expanded(
              child: Container(
                color: const Color(0xFF0E1220),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        color: Colors.white.withValues(alpha: 0.3),
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Chat with $displayName',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Chat ID: ${_selectedChat!['id']}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Chat functionality will be implemented here',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFrontView() {
    final videoServiceState =
        ref.watch(video_providers.videoServiceStateProvider);
    final bool isVideoServiceLoading =
        ref.watch(video_providers.videoServiceLoadingProvider);
    final visibleProfilePosts =
        ref.watch(video_providers.userVideosProvider(_effectiveUserId));
    final int? postsCountOverride = visibleProfilePosts.isNotEmpty ||
            (!isVideoServiceLoading && videoServiceState.isNotEmpty)
        ? visibleProfilePosts.length
        : null;

    return StreamerCardFrontSection(
      onDismiss: _handleDismiss,
      onFlip: _flipCard,
      onMore: () => _showShareSheet(context),
      profileSection: _buildProfileSection(),
      userId: _effectiveUserId,
      postsCountOverride: postsCountOverride,
      followButtonText: _getFollowButtonText(),
      followButtonOnPressed: _getFollowButtonAction(),
      followButtonLoading: _isFollowingOperation || _isUnfollowingOperation,
      messageButtonOnPressed: _getMessageButtonAction(),
      shareButtonOnPressed: () => widget.onShare?.call(widget.userId),
      tabs: _tabs,
      selectedTabIndex: _selectedTabIndex,
      onTabSelected: (index) {
        setState(() {
          _selectedTabIndex = index;
        });
      },
      content: _buildVideoFeed(),
    );
  }

  Widget _buildProfileSection() {
    return Column(
      children: [
        const SizedBox(height: 14),
        _buildAvatarWithOnlineIndicator(),
        const SizedBox(height: 14),
        _buildProfileTextInfo(),
        const SizedBox(height: 8),
      ],
    );
  }

  String _getFollowButtonText() {
    // 🎯 FOLLOW LOGIC: Use local state that's updated by real-time listeners
    // Check if viewing own profile
    if (widget.currentUserId == widget.userId) {
      return 'You';
    }

    // Use the same logic as _getConnectionStatusText for consistency
    if (_isConnected) {
      return 'Connected'; // Mutual follow
    } else if (_isFollowing && _isFollowedByStreamer) {
      return 'Connected'; // Both follow each other
    } else if (_isFollowing) {
      return 'Following'; // You follow them
    }

    return 'Follow'; // Not following
  }

  /// Get connection status text for NetworkView-style display
  /// Matches the three tabs: Connections | Followers | Following
  String _getConnectionStatusText() {
    if (_isConnected) {
      return 'Connected'; // Appears in Connections tab
    } else if (_isFollowing && _isFollowedByStreamer) {
      return 'Connected'; // Both follow each other
    } else if (_isFollowing) {
      return 'Following'; // You follow them (Following tab)
    } else if (_isFollowedByStreamer) {
      return 'Follows You'; // They follow you (Followers tab)
    }
    return 'Not Following';
  }

  VoidCallback? _getFollowButtonAction() {
    // Disable button during operations
    if (_isFollowingOperation || _isUnfollowingOperation) {
      return null;
    }

    // 🎯 FOLLOW LOGIC: Hide button for viewing own profile
    if (widget.currentUserId == widget.userId) {
      return null;
    }

    return _handleFollowButtonTap;
  }

  VoidCallback? _getMessageButtonAction() {
    if (kDebugMode) {
      debugPrint(
          "💬 StreamerCardView: _getMessageButtonAction - _isConnected: $_isConnected, _isFollowing: $_isFollowing, _isFollowedByStreamer: $_isFollowedByStreamer");
    }
    if (_isConnected) {
      return _handleMessage; // Only enabled when connected (mutual follow)
    }
    return null; // Disabled when not connected
  }

  // MARK: - Follow Button Action Handler (Real-time Updates)
  void _handleFollowButtonTap() {
    if (kDebugMode) {
      debugPrint("🔘 Follow button tapped for user: ${widget.userId}");
      debugPrint("🔘 Current follow state: $_isFollowing");
      debugPrint("🔘 Is followed by other: $_isFollowedByStreamer");
      debugPrint("🔘 Is connected: $_isConnected");
    }

    HapticFeedback.lightImpact();

    // 🎯 NETWORKVIEW LOGIC: Match disjoint tabs model
    // Connected → Immediately unfollow (moves user from Connections to Followers)
    // Following → Immediately unfollow (removes from Following)
    // Follow → Follow user (adds to Following, or Connections if they follow back)

    if (_isConnected || _isFollowing) {
      // Both "Connected" and "Following" → Immediate unfollow
      _handleUnfollowWithOptimisticUpdate();
    } else {
      // "Follow" → Follow the user
      _handleFollow();
    }
  }

  /// Unfollow with optimistic UI update for instant feedback
  /// Matches NetworkView behavior: Connected → Follow, moves to Followers tab
  void _handleUnfollowWithOptimisticUpdate() {
    if (kDebugMode) {
      debugPrint("🔘 Unfollowing user: ${widget.userId}");
      debugPrint("🔘 Was connected: $_isConnected");
      debugPrint("🔘 Was following: $_isFollowing");
    }

    final wasConnected = _isConnected;

    // Show feedback based on what happened
    if (wasConnected) {
      // User moved from Connections → Followers (if they still follow you)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isFollowedByStreamer
                  ? 'Removed from Connections. They\'re now in Followers.'
                  : 'Unfollowed successfully.',
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }

    // Perform the actual unfollow
    _handleUnfollow();
  }

  /// Show options menu for connected users (Message, Manage Connection, Report)
  /// NOTE: Currently not used for single-tap behavior (immediate unfollow)
  /// Keeping for potential future use (long-press, menu button, etc.)
  // ignore: unused_element
  void _showConnectedUserOptions() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // User info header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    // Avatar
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: _buildAvatarWithOnlineIndicator(),
                    ),
                    const SizedBox(width: 12),
                    // Username
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _userData?['username'] ?? 'Unknown',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            _getConnectionStatusText(), // Shows NetworkView-style status
                            style: const TextStyle(
                              color: Color(0xFF9248D2),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Divider(color: Colors.grey, height: 1),

              // Option 1: Message
              _buildOptionTile(
                icon: Icons.chat_bubble_outline,
                title: 'Message',
                subtitle: 'Send a direct message',
                onTap: () {
                  Navigator.pop(context);
                  _handleMessage();
                },
              ),

              // Option 2: Manage Connection (Dynamic based on relationship)
              // Shows: "Unfollow" if following/connected, "Follow" if not following
              _buildOptionTile(
                icon: _isFollowing
                    ? Icons.person_remove_outlined
                    : Icons.person_add_outlined,
                title: _isFollowing ? 'Unfollow' : 'Follow',
                subtitle: _isConnected
                    ? 'Remove from Connections (both will be unfollowed)'
                    : (_isFollowing
                        ? 'Stop following this user'
                        : 'Follow this user'),
                onTap: () {
                  Navigator.pop(context);
                  if (_isFollowing) {
                    _confirmUnfollowWithConnectionWarning();
                  } else {
                    _handleFollow();
                  }
                },
                isDestructive: _isFollowing,
              ),

              // Option 3: Report
              _buildOptionTile(
                icon: Icons.flag_outlined,
                title: 'Report',
                subtitle: 'Report this user',
                onTap: () {
                  Navigator.pop(context);
                  _showReportOptions();
                },
                isDestructive: true,
              ),

              const SizedBox(height: 12),
              const Divider(color: Colors.grey, height: 1),

              // Option 4: Block
              _buildOptionTile(
                icon: Icons.block,
                title: 'Block',
                subtitle: 'Block this user',
                onTap: () {
                  Navigator.pop(context);
                  _handleBlockUser();
                },
                isDestructive: true,
              ),

              const SizedBox(height: 12),

              // Cancel button
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.grey[800],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build option tile for bottom sheet
  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive ? Colors.red : Colors.white,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isDestructive ? Colors.red : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.grey[600],
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  /// Show confirmation dialog before unfollowing (with connection awareness)
  void _confirmUnfollowWithConnectionWarning() {
    final username = _userData?['username'] ?? 'this user';

    // Different messages based on connection state
    final title = _isConnected ? 'Remove Connection?' : 'Unfollow User?';
    final message = _isConnected
        ? 'Are you sure you want to unfollow $username?\n\n'
            'This will remove them from your Connections and move them to Followers '
            '(if they still follow you).'
        : 'Are you sure you want to unfollow $username?';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          message,
          style: TextStyle(
            color: Colors.grey[300],
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _handleUnfollow();
            },
            child: const Text(
              'Unfollow',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Show report options for the user
  void _showReportOptions() {
    final reportReasons = [
      'Spam or scam',
      'Inappropriate content',
      'Harassment or bullying',
      'Fake account',
      'Other',
    ];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Why are you reporting this user?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Divider(color: Colors.grey, height: 1),

              // Report reasons
              ...reportReasons.map((reason) => InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      _submitReport(reason);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              reason,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: Colors.grey[600],
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  )),

              const SizedBox(height: 12),

              // Cancel button
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.grey[800],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Handle block user action
  Future<void> _handleBlockUser() async {
    final displayName = _userData?['displayName'] ?? 'this user';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Block User',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to block $displayName? They will not be able to interact with you and you will not see their content.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Block',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _blockingService.blockUser(
          targetUserId: widget.userId,
          reason: 'User blocked from StreamerCardView',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$displayName has been blocked'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );

          // Navigate back
          Navigator.of(context).pop();
          if (widget.onDismiss != null) {
            widget.onDismiss!();
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to block user: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  /// Submit report to backend
  Future<void> _submitReport(String reason) async {
    try {
      await FirebaseFirestore.instance.collection('reports').add({
        'reporterId': widget.currentUserId,
        'reportedUserId': widget.userId,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'user_report',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Report submitted. Thank you for keeping our community safe.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error submitting report: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to submit report. Please try again.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _handleFollow() async {
    if (widget.currentUserId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in to follow users'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    if (kDebugMode) {
      debugPrint("🔘 StreamerCardView: Following user: ${widget.userId}");
      debugPrint(
          "🔘 StreamerCardView: Current user ID: ${widget.currentUserId}");
    }

    final result = await _relationshipController.follow(
      onFollow: widget.onFollow,
    );
    if (!mounted) return;

    switch (result) {
      case StreamerCardRelationshipActionResult.success:
        _notifyFollowStateChanged();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully followed user!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        _navigateToAppropriateTab();
        break;
      case StreamerCardRelationshipActionResult.authRequired:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in to follow users'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
        break;
      case StreamerCardRelationshipActionResult.notFound:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User not found'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
        break;
      case StreamerCardRelationshipActionResult.permissionDenied:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permission denied'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
        break;
      case StreamerCardRelationshipActionResult.networkError:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Network error'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
        break;
      case StreamerCardRelationshipActionResult.busy:
      case StreamerCardRelationshipActionResult.failure:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to follow user'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
        break;
    }
  }

  Future<void> _handleUnfollow() async {
    if (kDebugMode) {
      debugPrint("🔘 StreamerCardView: Unfollowing user: ${widget.userId}");
      debugPrint(
          "🔘 StreamerCardView: Current state - _isFollowing: $_isFollowing, _isFollowedByStreamer: $_isFollowedByStreamer, _isConnected: $_isConnected");
    }

    final result = await _relationshipController.unfollow();
    if (!mounted) return;

    if (result == StreamerCardRelationshipActionResult.success) {
      _notifyFollowStateChanged();
      await _removeFollowNotification();
      _navigateToAppropriateTab();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Failed to unfollow user'),
        backgroundColor: Colors.red,
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: () => _handleUnfollow(),
        ),
      ),
    );
  }

  void _handleMessage() {
    if (kDebugMode) {
      debugPrint(
          "💬 StreamerCardView: _handleMessage called - _isConnected: $_isConnected, _isFollowing: $_isFollowing, _isFollowedByStreamer: $_isFollowedByStreamer");
    }

    HapticFeedback.lightImpact();

    // Check if users are connected (mutual follow)
    if (!_isConnected) {
      if (kDebugMode) {
        debugPrint(
            "💬 StreamerCardView: Users are not connected, showing error message");
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You can only message users you are connected with'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    if (kDebugMode) {
      debugPrint(
          "💬 StreamerCardView: Users are connected, proceeding with message");
    }

    // Call the parent callback first
    widget.onMessage?.call(widget.userId);

    // Navigate to chat view
    _navigateToChat();
  }

  Future<void> _navigateToChat() async {
    try {
      // Import the necessary services
      final chatService = ChatService.shared;
      final currentUser = FirebaseAuth.instance.currentUser;

      if (kDebugMode) {
        debugPrint(
            "💬 StreamerCardView: Starting chat navigation for user: ${widget.userId}");
        debugPrint("💬 StreamerCardView: Current user: ${currentUser?.uid}");
        debugPrint("💬 StreamerCardView: User data: $_userData");
      }

      if (currentUser == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please sign in to send messages'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      // Show loading indicator
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        );
      }

      // Create or fetch chat
      final chat = await chatService.fetchOrCreateChat(widget.userId);

      if (kDebugMode) {
        debugPrint("💬 StreamerCardView: Chat created/fetched: $chat");
      }

      // Hide loading indicator
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      if (chat != null && mounted) {
        // Get user data for the chat view
        final otherUserName = _userData?['displayName'] ??
            _userData?['username'] ??
            'Unknown User';
        final String otherUserAvatarURL = avatarURL ?? '';
        final otherUserIsOnline = _userData?['isOnline'] ??
            _userData?['onlineStatus'] == 'online' ??
            false;

        if (kDebugMode) {
          debugPrint("💬 StreamerCardView: Navigating to chat with:");
          debugPrint("💬 StreamerCardView: - Name: $otherUserName");
          debugPrint("💬 StreamerCardView: - Avatar: $otherUserAvatarURL");
          debugPrint("💬 StreamerCardView: - Online: $otherUserIsOnline");
        }

        AppNavigator.openChat(
          context,
          chat: chat,
          otherUserId: widget.userId,
          otherUserName: otherUserName,
          otherUserAvatarUrl: otherUserAvatarURL,
          otherUserIsOnline: otherUserIsOnline,
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to start conversation'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        }

        if (kDebugMode) {
          debugPrint(
              "💬 StreamerCardView: Failed to create/fetch chat - chat is null");
        }
      }
    } catch (e) {
      // Hide loading indicator if still showing
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting conversation: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      if (kDebugMode) {
        debugPrint("💬 StreamerCardView: Error starting conversation: $e");
      }
    }
  }

  void _navigateToAppropriateTab() {
    if (widget.onNavigateToTab == null) return;

    // Determine which tab to navigate to based on current relationship state
    if (_isConnected) {
      // Both users follow each other - go to Connections tab
      widget.onNavigateToTab!('connections');
      if (kDebugMode) {
        debugPrint(
            "🔘 StreamerCardView: Navigating to Connections tab (mutual follow)");
      }
    } else if (_isFollowing) {
      // Current user follows the other user - go to Following tab
      widget.onNavigateToTab!('following');
      if (kDebugMode) {
        debugPrint("🔘 StreamerCardView: Navigating to Following tab");
      }
    } else if (_isFollowedByStreamer) {
      // Other user follows current user - go to Followers tab
      widget.onNavigateToTab!('followers');
      if (kDebugMode) {
        debugPrint("🔘 StreamerCardView: Navigating to Followers tab");
      }
    } else {
      // No relationship - go to Following tab (where they'll be added)
      widget.onNavigateToTab!('following');
      if (kDebugMode) {
        debugPrint(
            "🔘 StreamerCardView: Navigating to Following tab (new follow)");
      }
    }
  }

  // MARK: - Video Navigation

  // ✅ FIX: Removed placeholder _navigateToPlayerScreen method
  // ProfileVideoFeedView now handles video taps directly and opens the real PlayerScreen

  // MARK: - Helper Methods for Follow/Unfollow Operations

  Future<void> _removeFollowNotification() async {
    try {
      final notificationQuery = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: widget.userId)
          .where('type', isEqualTo: 'follow')
          .where('fromUserId', isEqualTo: widget.currentUserId!)
          .get();

      for (final doc in notificationQuery.docs) {
        await doc.reference.delete();
      }
    } catch (error) {
      if (kDebugMode) {
        // debugPrint("❌ Error removing follow notification: $error");
      }
      // Don't throw here - notification cleanup is not critical
    }
  }

  List<StreamerCardTabItem> get _tabs {
    final tabs = <StreamerCardTabItem>[
      const StreamerCardTabItem(label: 'Video', index: 0),
    ];

    if (_showFavoritesOnCard) {
      tabs.add(const StreamerCardTabItem(label: 'Favorites', index: 1));
    }

    tabs.add(const StreamerCardTabItem(label: 'Tagged', index: 2));
    return tabs;
  }

  bool get _showFavoritesOnCard {
    final privacy = _userData?['privacy'] as Map<String, dynamic>? ?? {};
    return privacy['showFavoritesOnCard'] ?? false;
  }

  ProfileVideoFeedType _getSelectedFeedType() {
    if (_selectedTabIndex == 0) {
      return ProfileVideoFeedType.videos;
    }

    if (!_showFavoritesOnCard) {
      return _selectedTabIndex == 1
          ? ProfileVideoFeedType.tagged
          : ProfileVideoFeedType.videos;
    }

    if (_selectedTabIndex == 1) {
      return ProfileVideoFeedType.favorites;
    }

    if (_selectedTabIndex == 2) {
      return ProfileVideoFeedType.tagged;
    }

    return ProfileVideoFeedType.videos;
  }

  Widget _buildVideoFeed() {
    return ProfileVideoFeedView(
      userId: _effectiveUserId,
      feedType: _getSelectedFeedType(),
      // ✅ FIX: Let ProfileVideoFeedView handle video taps directly
      // It will open the real PlayerScreen with actual videos
      onVideoTap: null,
    );
  }

  void _handleDismiss() {
    if (widget.onDismiss != null) {
      widget.onDismiss!();
      return;
    }

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Widget _buildAvatarWithOnlineIndicator() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 112,
          height: 112,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              colors: [
                Color(0xFFFF6CAB),
                Color(0xFF8E54E9),
                Color(0xFF3D99F7),
                Color(0xFFFF6CAB),
              ],
            ),
          ),
          child: Center(
            child: Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.2),
              ),
              child: ClipOval(
                child: buildCachedAvatarCircle(
                  url: avatarURL,
                  size: 104,
                  iconSize: 48,
                ),
              ),
            ),
          ),
        ),
        // Online status indicator - show based on real-time status
        Consumer(
          builder: (context, ref, child) {
            final statusAsync = ref.watch(userStatusProvider(widget.userId));

            return statusAsync.when(
              data: (presence) {
                if (presence.status != UserStatus.offline) {
                  return Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: _getStatusColor(presence.status),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: _getStatusColor(presence.status)
                                .withValues(alpha: 0.5),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
              loading: () => const SizedBox.shrink(),
              error: (error, stack) => const SizedBox.shrink(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildProfileTextInfo() {
    return Column(
      children: [
        Text(
          displayName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '@$username',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.75),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildBackView() {
    return StreamerCardDetailsSection(
      onFlip: _flipCard,
      identity: _buildIdentity(),
      tags: _buildTags(),
      showBio: _showBio,
      onToggleBio: () => setState(() => _showBio = !_showBio),
      bioBody: _buildBioBody(),
      showPlatforms: _showPlatforms,
      onTogglePlatforms: () => setState(() => _showPlatforms = !_showPlatforms),
      platformsBody: _buildPlatforms(_platforms),
      showCalendar: _showCalendar,
      onToggleCalendar: () => setState(() => _showCalendar = !_showCalendar),
      calendarBody: _buildCalendar(_calendarEvents),
    );
  }

  Widget _buildIdentity() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _SmallAvatar(imageUrl: avatarURL),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userData?['displayName'] ?? 'User',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '@${_userData?['username'] ?? 'username'}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTags() {
    final hashtagsData = _userData?['hashtags'];
    List<String> hashtags = [];

    if (hashtagsData != null) {
      if (hashtagsData is List) {
        hashtags = hashtagsData.map((tag) => tag.toString()).toList();
      } else if (hashtagsData is String) {
        // If it's a string, split by comma or space
        hashtags = hashtagsData
            .split(RegExp(r'[,\s]+'))
            .where((tag) => tag.isNotEmpty)
            .toList();
      }
    }

    if (hashtags.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: hashtags.map((hashtag) {
          final isSelected = _selectedHashtag == hashtag;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedHashtag = isSelected ? "" : hashtag;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: isSelected ? _selectedHashtagGradient : null,
                color: isSelected ? null : Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Text(
                '#$hashtag',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBioBody() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        _userData?['bio'] ?? 'No bio available',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.75),
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildPlatforms(List<Map<String, dynamic>> platforms) {
    if (kDebugMode) {
      // ✅ FIX #5: Wrap in kDebugMode
      debugPrint(
          '🔗 _buildPlatforms: Building platforms section with ${platforms.length} platforms');
    }
    if (platforms.isEmpty) {
      if (kDebugMode) {
        // ✅ FIX #5: Wrap in kDebugMode
        debugPrint(
            '🔗 _buildPlatforms: No platforms found, showing empty state');
      }
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.10),
              width: 1,
            ),
          ),
          child: Text(
            'No platforms added yet.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        children: [
          for (final platform in platforms)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
              child: _ClickablePlatformRow(
                platform: platform,
                onTap: () => _launchPlatformUrl(platform),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCalendar(List<CalendarEvent> events) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (events.isEmpty)
            const _EmptyStateWidget(
              icon: Icons.event,
              message: 'No upcoming events',
            )
          else ...[
            // Show first 5 events
            ...events.take(5).map((event) => _buildCalendarRow(event)),
            // Show "+X more..." if there are more than 5 events
            if (events.length > 5) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  '+${events.length - 5} more…',
                  style: const TextStyle(
                    color: Color(0x80FFFFFF),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildCalendarRow(CalendarEvent event) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.calendar_today,
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  event.description,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatEventTime(event.date),
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // MARK: - Role-based Actions (Owner vs Visitor)
          if (isOwner) ...[
            // Owner sees trash button for deletion
            GestureDetector(
              onTap: () => _deleteEvent(event.id),
              child: const Icon(
                Icons.delete,
                color: Colors.red,
                size: 20,
              ),
            ),
          ] else ...[
            // Visitors see bookmark button
            GestureDetector(
              onTap: () => _toggleBookmark(event),
              child: Icon(
                _bookmarkedEventIds.contains(event.id)
                    ? Icons.bookmark
                    : Icons.bookmark_border,
                color: Colors.white,
                size: 20,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatEventTime(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now).inDays;

    if (difference == 0) {
      return 'Today · ${_formatTime(date)}';
    } else if (difference == 1) {
      return 'Tomorrow · ${_formatTime(date)}';
    } else if (difference == -1) {
      return 'Yesterday · ${_formatTime(date)}';
    } else {
      return '${_formatDate(date)} · ${_formatTime(date)}';
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour;
    final minute = date.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final displayMinute = minute.toString().padLeft(2, '0');
    return '$displayHour:$displayMinute $period';
  }

  Color _getStatusColor(UserStatus status) {
    switch (status) {
      case UserStatus.online:
        return const Color(0xFF4CAF50); // Green
      case UserStatus.offline:
        return const Color(0xFF9E9E9E); // Grey
      case UserStatus.busy:
        return const Color(0xFFFF9800); // Orange
      case UserStatus.dnd:
        return const Color(0xFFF44336); // Red
      case UserStatus.streaming:
        return const Color(0xFF9C27B0); // Purple
    }
  }

  /// ✅ FIX #2: Optimized to only setState when platforms actually change
  void _loadPlatforms() {
    if (_userData == null || _userData!['platforms'] == null) {
      // Only setState if platforms were previously non-empty
      if (_platforms.isNotEmpty) {
        _platforms = [];
      }
      return;
    }

    try {
      final platformsData = _userData!['platforms'];
      if (platformsData is! List) {
        if (_platforms.isNotEmpty) {
          _platforms = [];
        }
        return;
      }

      final newPlatforms = platformsData
          .whereType<Map<String, dynamic>>()
          .map((platform) => {
                'id': platform['id']?.toString() ?? '',
                'type': platform['type']?.toString() ?? '',
                'username': platform['username']?.toString() ?? '',
                'followers': (platform['followers'] as num?)?.toInt() ?? 0,
                'url': platform['url']?.toString(),
              })
          .toList();

      // ✅ Only update if platforms actually changed (no unnecessary setState)
      if (!_platformsEqual(newPlatforms, _platforms)) {
        _platforms = newPlatforms;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ StreamerCardView: Error loading platforms: $e');
      }
      if (_platforms.isNotEmpty) {
        _platforms = [];
      }
    }
  }

  /// Helper to compare platform lists
  bool _platformsEqual(
      List<Map<String, dynamic>> a, List<Map<String, dynamic>> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i]['id'] != b[i]['id'] || a[i]['url'] != b[i]['url']) {
        return false;
      }
    }
    return true;
  }

  /// ✅ FIX #3: Optimized to only update when calendar events actually change
  void _loadCalendarEvents() {
    if (_userData == null || _userData!['calendarEvents'] == null) {
      // Only update if events were previously non-empty
      if (_calendarEvents.isNotEmpty) {
        _calendarEvents = [];
      }
      return;
    }

    try {
      final eventsData = _userData!['calendarEvents'];
      if (eventsData is! List) {
        if (_calendarEvents.isNotEmpty) {
          _calendarEvents = [];
        }
        return;
      }

      final newEvents = eventsData
          .where((e) =>
              e is Map<String, dynamic> &&
              e['id'] != null &&
              e['title'] != null &&
              e['description'] != null &&
              e['date'] != null)
          .map((eventData) {
            try {
              return CalendarEvent(
                id: eventData['id'] as String,
                title: eventData['title'] as String,
                description: eventData['description'] as String,
                date: _parseDate(
                    eventData['date']), // ✅ FIX #3: Safe date parsing
              );
            } catch (e) {
              if (kDebugMode) {
                debugPrint(
                    '❌ StreamerCardView: Error creating CalendarEvent: $e');
              }
              return null;
            }
          })
          .where((event) => event != null)
          .cast<CalendarEvent>()
          .toList();

      // ✅ Only update if events actually changed (no unnecessary setState)
      if (!_eventsEqual(newEvents, _calendarEvents)) {
        _calendarEvents = newEvents;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ StreamerCardView: Error loading calendar events: $e');
      }
      if (_calendarEvents.isNotEmpty) {
        _calendarEvents = [];
      }
    }
  }

  /// Helper to compare calendar event lists
  bool _eventsEqual(List<CalendarEvent> a, List<CalendarEvent> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id || a[i].date != b[i].date) {
        return false;
      }
    }
    return true;
  }

  /// ✅ FIX #3: Safely parse date from various formats (copied from ProfileBackView)
  DateTime _parseDate(dynamic dateValue) {
    if (dateValue == null) {
      return DateTime.now();
    }

    if (dateValue is Timestamp) {
      return dateValue.toDate();
    }

    if (dateValue is DateTime) {
      return dateValue;
    }

    if (dateValue is String) {
      try {
        return DateTime.parse(dateValue);
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
              '❌ StreamerCardView: Error parsing date string: $dateValue');
        }
        return DateTime.now();
      }
    }

    if (kDebugMode) {
      debugPrint(
          '❌ StreamerCardView: Unknown date type: ${dateValue.runtimeType}');
    }
    return DateTime.now();
  }

  /// ✅ FIX #4: Added timeout protection to prevent UI freeze
  Future<void> _launchPlatformUrl(Map<String, dynamic> platform) async {
    final url = platform['url'] as String?;
    final platformType = platform['type'] as String?;

    if (url == null || url.isEmpty) return;

    try {
      // ✅ FIX #4: Add timeout to prevent hanging (10 seconds)
      await Future.any([
        _launchUrlWithTimeout(url),
        Future.delayed(const Duration(seconds: 10), () {
          throw TimeoutException(
              'URL launch timed out', const Duration(seconds: 10));
        }),
      ]);

      // Show success feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Opening ${_getPlatformDisplayName(platformType)}...'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        // ✅ FIX #5: Wrap in kDebugMode
        debugPrint('❌ StreamerCardView: Error launching URL: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot open this link'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// ✅ FIX #4: Helper method for URL launching with proper error handling
  Future<void> _launchUrlWithTimeout(String url) async {
    String finalUrl = url;
    if (!finalUrl.startsWith('http://') && !finalUrl.startsWith('https://')) {
      finalUrl = 'https://$finalUrl';
    }

    if (kDebugMode) {
      // ✅ FIX #5: Wrap in kDebugMode
      debugPrint('🔗 StreamerCardView: Launching URL: $finalUrl');
    }

    final uri = Uri.parse(finalUrl);
    final canLaunch = await canLaunchUrl(uri);

    if (canLaunch) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  }

  String _getPlatformDisplayName(String? platformType) {
    if (platformType == null) return 'Platform';
    switch (platformType.toLowerCase()) {
      case 'twitch':
        return 'Twitch';
      case 'youtube':
        return 'YouTube';
      case 'kick':
        return 'Kick';
      case 'tiktok':
        return 'TikTok';
      case 'facebook':
        return 'Facebook';
      case 'bluesky':
        return 'Bluesky';
      case 'twitter':
        return 'Twitter';
      case 'instagram':
        return 'Instagram';
      case 'reddit':
        return 'Reddit';
      case 'discord':
        return 'Discord';
      case 'other':
        return 'Website';
      default:
        return platformType;
    }
  }

  void _showShareSheet(BuildContext context) {
    HapticFeedback.lightImpact();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (context) => StreamerShareSheet(
        userId: widget.userId,
        displayName: _userData?['displayName'] as String?,
        profileImageUrl: _userData?['photoURL'] as String?,
        onDismiss: () {
          // Don't call Navigator.pop() here as it's already handled in the X button
          // This prevents double pop which causes black screen
        },
      ),
    );
  }
}

Widget buildCachedAvatarCircle({
  required String? url,
  required double size,
  required double iconSize,
}) {
  final placeholder = Container(
    width: size,
    height: size,
    color: Colors.grey.shade800,
    child: Icon(
      Icons.person,
      color: Colors.white,
      size: iconSize,
    ),
  );

  if (url == null || url.isEmpty) {
    return placeholder;
  }

  final cacheSize = (size * 2).round();

  return CachedNetworkImage(
    imageUrl: url,
    memCacheWidth: cacheSize,
    memCacheHeight: cacheSize,
    fadeInDuration: const Duration(milliseconds: 120),
    imageBuilder: (context, imageProvider) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        image: DecorationImage(
          image: imageProvider,
          fit: BoxFit.cover,
        ),
      ),
    ),
    placeholder: (context, _) => placeholder,
    errorWidget: (context, _, __) => placeholder,
  );
}

// MARK: - Calendar Event Sheet
class CalendarEventSheet extends StatefulWidget {
  final Function(CalendarEvent) onSave;

  const CalendarEventSheet({
    super.key,
    required this.onSave,
  });

  @override
  State<CalendarEventSheet> createState() => _CalendarEventSheetState();
}

class _CalendarEventSheetState extends State<CalendarEventSheet> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add Calendar Event',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _titleController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Event Title',
              labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF9248D2)),
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Description (Optional)',
              labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF9248D2)),
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.1),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _selectDate,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Date',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GestureDetector(
                  onTap: _selectTime,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Time',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _selectedTime.format(context),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saveEvent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9248D2),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Save Event'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF9248D2),
              onPrimary: Colors.white,
              surface: Color(0xFF0E1220),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      setState(() {
        _selectedDate = date;
      });
    }
  }

  Future<void> _selectTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF9248D2),
              onPrimary: Colors.white,
              surface: Color(0xFF0E1220),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (time != null) {
      setState(() {
        _selectedTime = time;
      });
    }
  }

  void _saveEvent() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an event title'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final event = CalendarEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      date: DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      ),
    );

    widget.onSave(event);
    Navigator.pop(context);
  }
}

class _SmallAvatar extends StatelessWidget {
  final String? imageUrl;
  const _SmallAvatar({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          colors: [
            Color(0xFFFF6CAB),
            Color(0xFF8E54E9),
            Color(0xFF3D99F7),
            Color(0xFFFF6CAB)
          ],
        ),
      ),
      child: Center(
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: 0.2),
          ),
          child: ClipOval(
            child: buildCachedAvatarCircle(
              url: imageUrl,
              size: 56,
              iconSize: 28,
            ),
          ),
        ),
      ),
    );
  }
}

class _ClickablePlatformRow extends StatelessWidget {
  final Map<String, dynamic> platform;
  final VoidCallback onTap;

  const _ClickablePlatformRow({
    required this.platform,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final platformType = platform['type'] as String? ?? '';
    final username = platform['username'] as String? ?? '';
    // final url = platform['url'] as String? ?? '';

    debugPrint(
        '🔗 _ClickablePlatformRow: Building platform card - type: $platformType, username: $username');

    return GestureDetector(
      onTap: () {
        debugPrint('🔗 _ClickablePlatformRow: Platform card tapped!');
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            BrandIcon(
              platformType: platformType,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getPlatformDisplayName(platformType),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (username.isNotEmpty)
                    Text(
                      '@$username',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  String _getPlatformDisplayName(String platformType) {
    switch (platformType.toLowerCase()) {
      case 'twitch':
        return 'Twitch';
      case 'youtube':
        return 'YouTube';
      case 'kick':
        return 'Kick';
      case 'tiktok':
        return 'TikTok';
      case 'facebook':
        return 'Facebook';
      case 'twitter':
        return 'Twitter';
      case 'instagram':
        return 'Instagram';
      default:
        return platformType;
    }
  }
}

class _EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyStateWidget({
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Center(
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 320),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: AppColors.supportAccentGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  icon,
                  color: Colors.white.withValues(alpha: 0.95),
                  size: 30,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'This section will show up here once there is something to share.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.68),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
