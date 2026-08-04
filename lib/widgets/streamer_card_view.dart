import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/calendar_event.dart';
import '../providers/status_provider.dart';
import '../models/user_status.dart';
import '../widgets/profile_video_feed_view.dart';
import '../services/unified_bookmark_service.dart';
import 'streamer_share_sheet.dart';
import 'adult_external_link_dialog.dart';
import 'brand_icons.dart';
import '../services/unified_avatar_service.dart';
import '../services/chat_service.dart';
import '../services/profile_link_service.dart';
import '../utils/post_count_rules.dart';
import '../utils/platform_rules.dart';
import '../utils/user_profile_firestore.dart';
import '../providers/follows_provider.dart';
import '../providers/follow_refresh_provider.dart';
import '../utils/avatar_url_resolver.dart';
import '../providers/following_provider.dart';
import '../providers/home_provider.dart' as hp;
import '../providers/video_service_provider.dart' as video_providers;
import '../services/user_blocking_service.dart';
import '../services/global_playback_manager.dart';
import '../services/creator_cache_service.dart';
import '../services/creator_intelligence_analytics_service.dart';
import '../routing/app_navigator.dart';
import '../constants/app_colors.dart';
import 'profile/profile_username_utils.dart';
import '../core/theme/support_shell_style.dart';
import '../core/theme/st_theme_tokens.dart';
import '../features/creator_score/creator_score.dart';
import '../features/creator_score/creator_score_service.dart';
import '../features/creator_score/creator_score_widgets.dart';
import '../features/content_planning/calendar_visibility_contract.dart';
import '../models/creator_profile_snapshot.dart';
import '../models/user.dart' as app_models;
import 'streamer_card_profile_controller.dart';
import 'streamer_card_relationship_controller.dart';
import 'streamer_card_sections.dart';
import 'streamer_mirror_calendar.dart';
import 'connected_user_options_sheet.dart';

enum _StreamerSnackKind {
  success,
  error,
  warning,
}

SnackBar _streamerSnackBar(
  BuildContext context,
  String message, {
  _StreamerSnackKind kind = _StreamerSnackKind.success,
  Duration duration = const Duration(seconds: 2),
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final ColorScheme scheme = Theme.of(context).colorScheme;
  final (Color background, Color foreground) = switch (kind) {
    _StreamerSnackKind.error => (scheme.error, scheme.onError),
    _StreamerSnackKind.warning => (
        scheme.surfaceContainerHighest,
        scheme.onSurface,
      ),
    _StreamerSnackKind.success => (scheme.primary, scheme.onPrimary),
  };
  return SnackBar(
    content: Text(message, style: TextStyle(color: foreground)),
    backgroundColor: background,
    duration: duration,
    behavior: SnackBarBehavior.floating,
    action: actionLabel != null && onAction != null
        ? SnackBarAction(
            label: actionLabel,
            textColor: foreground,
            onPressed: onAction,
          )
        : null,
  );
}

class StreamerCardView extends ConsumerStatefulWidget {
  final String userId;
  final CreatorProfileSnapshot? initialCreator;
  final String? currentUserId;
  final VoidCallback? onDismiss;
  final Function(String userId)? onFollow;
  final Function(String userId)? onMessage;
  final Function(String userId)? onShare;
  final Function(String tabName)? onNavigateToTab;

  const StreamerCardView({
    super.key,
    required this.userId,
    this.initialCreator,
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

  // Bookmark service
  final UnifiedBookmarkService _bookmarkService =
      UnifiedBookmarkService.instance;

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
  int _selectedTabIndex = 0; // 0: Video, 1: Platforms, 2: Calendar

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

    _blockingService = UserBlockingService();
    _relationshipController = StreamerCardRelationshipController(
      followsService: ref.read(followsServiceProvider),
    )..addListener(_handleRelationshipStateChanged);
    _profileController = StreamerCardProfileController()
      ..addListener(_handleProfileStateChanged);
    _blockingService.blockListRevision.addListener(_handleBlockListChanged);
    final CreatorProfileSnapshot? seed = widget.initialCreator ??
        CreatorCacheService.instance.get(widget.userId);
    if (seed != null && seed.hasDisplayIdentity) {
      _userData = seed.toUserDataMap();
      _resolvedUserDocId = seed.creatorId;
      _isLoading = false;
    }
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(
        CreatorIntelligenceAnalyticsService().trackCreatorCardOpened(
          creatorId: widget.userId,
        ),
      );
      unawaited(_loadUserProfile());
      if (_userData != null) {
        unawaited(
          _relationshipController.bind(
            currentUserId: widget.currentUserId,
            targetUserId: widget.userId,
          ),
        );
        setState(_syncDerivedProfileFields);
      }
    });
  }

  void _syncDerivedProfileFields() {
    final List<Map<String, dynamic>> platforms =
        UserProfileFirestore.parsePlatformsFromUserData(
      _userData,
      connectedOnly: true,
    );
    final bool viewerIsOwner = widget.currentUserId != null &&
        widget.currentUserId ==
            (_resolvedUserDocId ?? widget.userId);
    // Match website streamer page: streamer mirror only (not profile calendarEvents).
    final List<CalendarEvent> events =
        filterActiveUpcomingCalendarEvents(
      events: UserProfileFirestore.parseStreamerFacingCalendarEvents(
        _userData,
        viewerIsOwner: viewerIsOwner,
      ),
      startsAtOf: (CalendarEvent e) => e.date,
    );
    final String uid = (_userData?['id'] ??
            _userData?['uid'] ??
            _resolvedUserDocId ??
            widget.userId)
        .toString();
    if (uid.isNotEmpty) {
      UserProfileFirestore.logPlatformRead(
        uid: uid,
        view: 'StreamerCardBackView',
        count: platforms.length,
      );
      UserProfileFirestore.logCalendarRead(
        uid: uid,
        source: 'StreamerCardBackView',
        count: events.length,
        readPath: viewerIsOwner
            ? UserProfileFirestore.streamerCalendarProjectionPath(uid)
            : UserProfileFirestore.publicStreamerCalendarPath(uid),
      );
    }
    _platforms = platforms;
    _calendarEvents = events;
  }

  void _handleProfileStateChanged() {
    if (!mounted) return;
    _rebuildDebouncer?.cancel();
    _rebuildDebouncer = Timer(const Duration(milliseconds: 80), () {
      if (!mounted) return;
      final profileState = _profileController.state;
      final previousResolvedUserDocId = _resolvedUserDocId;
      final previousUserData = _userData;
      setState(() {
        _userData = profileState.userData;
        _resolvedUserDocId = profileState.resolvedUserDocId;
        _isLoading = profileState.isLoading;
        _error = profileState.error;
        _syncDerivedProfileFields();
      });
      final bool profileChanged =
          previousResolvedUserDocId != _resolvedUserDocId ||
              !identical(previousUserData, _userData);
      if (profileChanged && _userData != null) {
        final String cacheId = _resolvedUserDocId ?? widget.userId;
        CreatorCacheService.instance.setFromUserData(cacheId, _userData!);
        unawaited(
          _relationshipController.bind(
            currentUserId: widget.currentUserId,
            targetUserId: widget.userId,
          ),
        );
      }
    });
  }

  void _handleRelationshipStateChanged() {
    if (!mounted) return;
    _rebuildDebouncer?.cancel();
    _rebuildDebouncer = Timer(const Duration(milliseconds: 80), () {
      if (!mounted) {
        return;
      }
      setState(() {});
    });
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
      await _bookmarkService.initializeCalendarEventBookmarks();
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
      final bookmarkedIds =
          await _bookmarkService.fetchBookmarkedCalendarEventIds();
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
    await _profileController.load(
      widget.userId,
      initialCreator: widget.initialCreator,
    );
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
          _streamerSnackBar(
            context,
            'Please log in to bookmark events',
            kind: _StreamerSnackKind.error,
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
        success = await _bookmarkService.deleteCalendarEventBookmark(
          eventId: event.id,
        );
        message = success
            ? 'Event removed from bookmarks!'
            : 'Failed to remove bookmark';
      } else {
        // Add bookmark
        success = await _bookmarkService.bookmarkCalendarEvent(
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
        ScaffoldMessenger.of(context).showSnackBar(
          _streamerSnackBar(
            context,
            message,
            kind:
                success ? _StreamerSnackKind.success : _StreamerSnackKind.error,
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
          _streamerSnackBar(
            context,
            'Error: ${e.toString()}',
            kind: _StreamerSnackKind.error,
          ),
        );
      }
    }
  }

  void _flipCard() {
    if (_isFront) {
      _flipController.forward();
    } else {
      _flipController.reverse();
    }
    _isFront = !_isFront;
  }

  bool get _hasDisplayData {
    final Map<String, dynamic>? data = _userData;
    if (data == null || data.isEmpty) {
      return false;
    }
    final String name = data['displayName'] as String? ?? '';
    final String handle = data['username'] as String? ?? '';
    return name.isNotEmpty || handle.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasDisplayData && _isLoading) {
      return _buildLoadingState(context);
    }

    if (_error != null && !_hasDisplayData) {
      return _buildErrorState(context);
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: AppColors.profileViewBackground,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.profileViewBackground,
        extendBody: false,
        extendBodyBehindAppBar: false,
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

  Widget _buildLoadingState(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.profileViewBackground,
      body: ColoredBox(
        color: AppColors.profileViewBackground,
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.profileViewBackground,
      body: ColoredBox(
        color: AppColors.profileViewBackground,
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
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.68),
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
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

    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Container(
      color: shell.scaffold,
      child: SafeArea(
        child: Column(
          children: [
            // Chat Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: shell.panelSurface,
                border: Border(
                  bottom: BorderSide(
                    color: shell.panelBorder,
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
                    icon: Icon(Icons.arrow_back, color: shell.onChrome),
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
                          style: TextStyle(
                            color: shell.onChrome,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '@$username',
                          style: TextStyle(
                            color: shell.muted,
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
                color: shell.panelSurface,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        color: shell.iconDim,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Chat with $displayName',
                        style: TextStyle(
                          color: shell.muted,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Chat ID: ${_selectedChat!['id']}',
                        style: TextStyle(
                          color: shell.mutedStrong,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Chat functionality will be implemented here',
                        style: TextStyle(
                          color: shell.mutedStrong,
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
    final int? postsCountOverride = resolvePostsCountOverride(
      userVideos: visibleProfilePosts,
      allVideos: videoServiceState,
      isVideoServiceLoading: isVideoServiceLoading,
    );

    return StreamerCardFrontSection(
      onDismiss: _handleDismiss,
      onFlip: _flipCard,
      onMore: _showStreamerCardMoreMenu,
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
      content: _buildSelectedTabContent(),
    );
  }

  Widget _buildProfileSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Center(
            child: Column(
              children: [
                const SizedBox(height: 14),
                _buildAvatarWithOnlineIndicator(),
                const SizedBox(height: 14),
                _buildProfileTextInfo(),
                const SizedBox(height: 8),
              ],
            ),
          ),
          Positioned(
            top: 10,
            right: 0,
            child: CreatorScoreBadge(
              userId: _effectiveUserId,
              compact: true,
            ),
          ),
        ],
      ),
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

    if (_isConnected) {
      final String name = _userData?['displayName'] as String? ??
          _userData?['username'] as String? ??
          'Connected';
      ConnectedUserOptionsSheet.show(
        context,
        displayName: name,
        onMessage: _handleMessage,
        onUnfollow: _handleUnfollowWithOptimisticUpdate,
        onReport: _showReportOptions,
      );
      return;
    }
    if (_isFollowing) {
      _handleUnfollowWithOptimisticUpdate();
    } else {
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
          _streamerSnackBar(
            context,
            _isFollowedByStreamer
                ? 'Removed from Connections. They\'re now in Followers.'
                : 'Unfollowed successfully.',
            kind: _StreamerSnackKind.warning,
          ),
        );
      }
    }

    // Perform the actual unfollow
    _handleUnfollow();
  }

  bool get _isViewingOwnStreamerCard =>
      widget.currentUserId != null && widget.currentUserId == widget.userId;

  void _showStreamerCardMoreMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        final StSupportShellStyle shell = StSupportShellStyle.of(sheetContext);
        final ColorScheme scheme = Theme.of(sheetContext).colorScheme;
        final bool isSelf = _isViewingOwnStreamerCard;
        return Container(
          decoration: BoxDecoration(
            color: shell.panelSurface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20),
            ),
            border: Border.all(color: shell.panelBorder),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: shell.muted.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: <Widget>[
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: ClipOval(
                          child: buildCachedAvatarCircle(
                            context: sheetContext,
                            url: avatarURL,
                            size: 48,
                            iconSize: 24,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              _userData?['displayName'] as String? ??
                                  _userData?['username'] as String? ??
                                  'Unknown',
                              style: TextStyle(
                                color: shell.onChrome,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '@${_userData?['username'] ?? 'unknown'}',
                              style: TextStyle(
                                color: shell.muted,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (!isSelf)
                              Text(
                                _getConnectionStatusText(),
                                style: TextStyle(
                                  color: scheme.primary,
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
                const SizedBox(height: 16),
                Divider(color: shell.surfaceCardBorder, height: 1),
                _buildOptionTile(
                  sheetContext,
                  icon: Icons.person_outline_rounded,
                  title: 'View profile',
                  subtitle: 'Open this streamer profile',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        _openStreamerProfile();
                      }
                    });
                  },
                ),
                _buildOptionTile(
                  sheetContext,
                  icon: Icons.ios_share_rounded,
                  title: 'Share',
                  subtitle: 'Share this streamer profile',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        _showShareSheet(context);
                      }
                    });
                  },
                ),
                if (!isSelf) ...<Widget>[
                  _buildOptionTile(
                    sheetContext,
                    icon: Icons.chat_bubble_outline,
                    title: 'Message',
                    subtitle: 'Send a direct message',
                    onTap: () {
                      Navigator.pop(sheetContext);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          _handleMessage();
                        }
                      });
                    },
                  ),
                  _buildOptionTile(
                    sheetContext,
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
                      Navigator.pop(sheetContext);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) {
                          return;
                        }
                        if (_isFollowing) {
                          _confirmUnfollowWithConnectionWarning();
                        } else {
                          _handleFollow();
                        }
                      });
                    },
                    isDestructive: _isFollowing,
                  ),
                  const SizedBox(height: 8),
                  Divider(color: shell.surfaceCardBorder, height: 1),
                  _buildOptionTile(
                    sheetContext,
                    icon: Icons.flag_outlined,
                    title: 'Report',
                    subtitle: 'Report this user',
                    onTap: () {
                      Navigator.pop(sheetContext);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          _showReportOptions();
                        }
                      });
                    },
                    isDestructive: true,
                  ),
                  _buildOptionTile(
                    sheetContext,
                    icon: Icons.block,
                    title: 'Block',
                    subtitle: 'Block this user',
                    onTap: () {
                      Navigator.pop(sheetContext);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          _handleBlockUser();
                        }
                      });
                    },
                    isDestructive: true,
                  ),
                ],
                _buildOptionTile(
                  sheetContext,
                  icon: Icons.link_rounded,
                  title: 'Copy link',
                  subtitle: 'Copy profile URL',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        _copyStreamerProfileLink();
                      }
                    });
                  },
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        foregroundColor: shell.onChrome,
                        side: BorderSide(color: shell.surfaceCardBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
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
        );
      },
    );
  }

  Widget _buildOptionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color titleColor = isDestructive ? Colors.red : shell.onChrome;
    final Color iconColor = isDestructive ? Colors.red : shell.onChrome;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: <Widget>[
            Icon(
              icon,
              color: iconColor,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: shell.muted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _openStreamerProfile() {
    final Map<String, dynamic> data = <String, dynamic>{
      ...?_userData,
      'id': widget.userId,
      'uid': widget.userId,
      'avatarURL': avatarURL,
    };
    AppNavigator.openProfile(
      context,
      user: app_models.User.fromMap(data),
      isCurrentUser: _isViewingOwnStreamerCard,
    );
  }

  Future<void> _copyStreamerProfileLink() async {
    final String profileUrl = ProfileLinkService.publicProfileUrl(
      username: _userData?['username'] as String?,
      userId: widget.userId,
    );
    await Clipboard.setData(ClipboardData(text: profileUrl));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      _streamerSnackBar(
        context,
        'Profile link copied',
        kind: _StreamerSnackKind.success,
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

    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        final ColorScheme scheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          backgroundColor: scheme.surfaceContainerHigh,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            title,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            message,
            style: TextStyle(
              color: scheme.onSurface.withValues(alpha: 0.85),
              fontSize: 14,
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Cancel',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
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
        );
      },
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
      builder: (BuildContext sheetContext) {
        final StSupportShellStyle shell = StSupportShellStyle.of(sheetContext);
        return Container(
          decoration: BoxDecoration(
            color: shell.panelSurface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20),
            ),
            border: Border.all(color: shell.panelBorder),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: shell.muted.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Why are you reporting this user?',
                    style: TextStyle(
                      color: shell.onChrome,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Divider(color: shell.surfaceCardBorder, height: 1),
                ...reportReasons.map(
                  (String reason) => InkWell(
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _submitReport(reason);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              reason,
                              style: TextStyle(
                                color: shell.onChrome,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: shell.muted,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        foregroundColor: shell.onChrome,
                        side: BorderSide(color: shell.surfaceCardBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
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
        );
      },
    );
  }

  /// Handle block user action
  Future<void> _handleBlockUser() async {
    final displayName = _userData?['displayName'] ?? 'this user';

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final ColorScheme scheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          backgroundColor: scheme.surfaceContainerHigh,
          title: Text(
            'Block User',
            style: TextStyle(
              color: scheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Are you sure you want to block $displayName? They will not be able to interact with you and you will not see their content.',
            style: TextStyle(
              color: scheme.onSurface.withValues(alpha: 0.75),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text(
                'Block',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await _blockingService.blockUser(
          targetUserId: widget.userId,
          reason: 'User blocked from StreamerCardView',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            _streamerSnackBar(
              context,
              '$displayName has been blocked',
              kind: _StreamerSnackKind.success,
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
            _streamerSnackBar(
              context,
              'Failed to block user: $e',
              kind: _StreamerSnackKind.error,
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
          _streamerSnackBar(
            context,
            'Report submitted. Thank you for keeping our community safe.',
            kind: _StreamerSnackKind.success,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error submitting report: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          _streamerSnackBar(
            context,
            'Failed to submit report. Please try again.',
            kind: _StreamerSnackKind.error,
          ),
        );
      }
    }
  }

  Future<void> _handleFollow() async {
    if (widget.currentUserId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          _streamerSnackBar(
            context,
            'Please log in to follow users',
            kind: _StreamerSnackKind.warning,
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
          _streamerSnackBar(
            context,
            'Successfully followed user!',
            kind: _StreamerSnackKind.success,
          ),
        );
        _navigateToAppropriateTab();
        break;
      case StreamerCardRelationshipActionResult.authRequired:
        ScaffoldMessenger.of(context).showSnackBar(
          _streamerSnackBar(
            context,
            'Please log in to follow users',
            kind: _StreamerSnackKind.warning,
          ),
        );
        break;
      case StreamerCardRelationshipActionResult.notFound:
        ScaffoldMessenger.of(context).showSnackBar(
          _streamerSnackBar(
            context,
            'User not found',
            kind: _StreamerSnackKind.warning,
          ),
        );
        break;
      case StreamerCardRelationshipActionResult.permissionDenied:
        ScaffoldMessenger.of(context).showSnackBar(
          _streamerSnackBar(
            context,
            'Permission denied',
            kind: _StreamerSnackKind.warning,
          ),
        );
        break;
      case StreamerCardRelationshipActionResult.networkError:
        ScaffoldMessenger.of(context).showSnackBar(
          _streamerSnackBar(
            context,
            'Network error',
            kind: _StreamerSnackKind.warning,
          ),
        );
        break;
      case StreamerCardRelationshipActionResult.busy:
      case StreamerCardRelationshipActionResult.failure:
        ScaffoldMessenger.of(context).showSnackBar(
          _streamerSnackBar(
            context,
            'Failed to follow user',
            kind: _StreamerSnackKind.warning,
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
      _streamerSnackBar(
        context,
        'Failed to unfollow user',
        kind: _StreamerSnackKind.error,
        actionLabel: 'Retry',
        onAction: _handleUnfollow,
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
          _streamerSnackBar(
            context,
            'You can only message users you are connected with',
            kind: _StreamerSnackKind.warning,
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
            _streamerSnackBar(
              context,
              'Please sign in to send messages',
              kind: _StreamerSnackKind.error,
            ),
          );
        }
        return;
      }

      // Show loading indicator
      if (mounted) {
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          barrierColor:
              Theme.of(context).colorScheme.scrim.withValues(alpha: 0.35),
          builder: (BuildContext dialogContext) => Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(dialogContext).colorScheme.primary,
              ),
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
            _streamerSnackBar(
              context,
              'Failed to start conversation',
              kind: _StreamerSnackKind.error,
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
          _streamerSnackBar(
            context,
            'Error starting conversation: ${e.toString()}',
            kind: _StreamerSnackKind.error,
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
    return const <StreamerCardTabItem>[
      StreamerCardTabItem(label: 'Video', index: 0),
      StreamerCardTabItem(label: 'Platforms', index: 1),
      StreamerCardTabItem(label: 'Calendar', index: 2),
    ];
  }

  Widget _buildSelectedTabContent() {
    if (_selectedTabIndex == 1) {
      return _buildPlatforms(_platforms);
    }
    if (_selectedTabIndex == 2) {
      return _buildCalendar(_calendarEvents);
    }
    return _buildVideoFeed();
  }

  Widget _buildVideoFeed() {
    return ProfileVideoFeedView(
      userId: _effectiveUserId,
      feedType: ProfileVideoFeedType.videos,
      viewName: 'StreamerCardView',
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
              colors: <Color>[
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
                color: Colors.black.withValues(alpha: 0.35),
              ),
              child: ClipOval(
                child: buildCachedAvatarCircle(
                  context: context,
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
                        border: Border.all(
                          color: AppColors.profileViewBackground,
                          width: 2,
                        ),
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
    final String resolvedName =
        ProfileUsernameUtils.resolveDisplayName(_userData);
    final String atHandle = ProfileUsernameUtils.formatAtHandle(_userData);
    return Column(
      children: [
        Text(
          resolvedName.isNotEmpty ? resolvedName : displayName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w900,
            height: 1.05,
          ),
        ),
        if (atHandle.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            atHandle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBackView() {
    return StreamerCardDetailsSection(
      onFlip: _flipCard,
      identity: _buildIdentity(),
      tags: _buildTags(),
      creatorScoreBreakdown: _buildCreatorScoreBreakdown(),
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
    final String resolvedName =
        ProfileUsernameUtils.resolveDisplayName(_userData);
    final String atHandle = ProfileUsernameUtils.formatAtHandle(_userData);
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
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    resolvedName.isNotEmpty ? resolvedName : 'Creator',
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      height: 1.05,
                    ),
                  ),
                ),
                if (atHandle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    atHandle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.68),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 1.0,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          CreatorScoreBadge(
            userId: _effectiveUserId,
            compact: true,
          ),
        ],
      ),
    );
  }

  Widget _buildCreatorScoreBreakdown() {
    final AsyncValue<CreatorScore> scoreAsync =
        ref.watch(creatorScoreProvider(_effectiveUserId));
    final CreatorScore score = scoreAsync.value ?? CreatorScore.fallback;
    if (!score.isAvailable) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.10),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Expanded(
                  child: Text(
                    'Creator Score Breakdown',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (scoreAsync.isLoading)
                  const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            CreatorScoreBreakdownRow(
              label: 'Consistency',
              value: score.consistencyScore,
            ),
            CreatorScoreBreakdownRow(
              label: 'Content',
              value: score.contentScore,
            ),
            CreatorScoreBreakdownRow(
              label: 'Networking',
              value: score.networkingScore,
            ),
            CreatorScoreBreakdownRow(
              label: 'Engagement',
              value: score.engagementScore,
            ),
          ],
        ),
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
          final bool isSelected = _selectedHashtag == hashtag;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedHashtag = isSelected ? '' : hashtag;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(
                        colors: <Color>[
                          AppColors.primary,
                          Color(0xFF7768DF),
                          Color(0xFF4897D2),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      )
                    : null,
                color: isSelected
                    ? null
                    : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.18)
                      : Colors.white.withValues(alpha: 0.10),
                ),
              ),
              child: Text(
                '#$hashtag',
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.68),
                  fontSize: 15,
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
    final String bio = (_userData?['bio'] as String?)?.trim() ?? '';
    if (bio.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Text(
        bio,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.72),
          fontSize: 16,
          fontWeight: FontWeight.w600,
          height: 1.35,
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
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.10),
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
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          StreamerMirrorCalendar(
            key: ValueKey<String>(
              'mirror_cal_${events.map((CalendarEvent e) => e.id).join('_')}',
            ),
            events: events,
            onEventTap: (CalendarEvent event) {
              unawaited(_toggleBookmark(event));
            },
          ),
          if (events.isEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              "This streamer hasn't scheduled any events yet",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: shell.muted,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ] else ...<Widget>[
            const SizedBox(height: 14),
            Text(
              'Upcoming',
              style: TextStyle(
                color: shell.onChrome,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ...events.take(5).map(
              (CalendarEvent event) => _UpcomingCalendarRow(
                event: event,
                isBookmarked: _bookmarkedEventIds.contains(event.id),
                onTap: () => unawaited(_toggleBookmark(event)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getStatusColor(UserStatus status) {
    switch (status) {
      case UserStatus.online:
        return const Color(0xFF4CAF50); // Green
      case UserStatus.offline:
        return const Color(0xFF9E9E9E); // Grey
      case UserStatus.busy:
        return const Color(0xFFFF9800); // Orange
      case UserStatus.away:
        return const Color(0xFFF44336); // Red
      case UserStatus.streaming:
        return const Color(0xFF9C27B0); // Purple
    }
  }

  /// ✅ FIX #4: Added timeout protection to prevent UI freeze
  Future<void> _launchPlatformUrl(Map<String, dynamic> platform) async {
    final String platformType = PlatformRules.normalizePlatformType(
      platform['type']?.toString() ?? '',
    );
    if (PlatformRules.isAgeRestrictedEntry(platform)) {
      final bool confirmed = await showAdultExternalLinkDialog(context);
      if (!confirmed || !mounted) {
        return;
      }
    }
    final String rawUrl = (platform['url']?.toString() ?? '').trim();
    final String username = (platform['username']?.toString() ?? '').trim();
    final String? resolvedUrl = rawUrl.isNotEmpty
        ? rawUrl
        : PlatformRules.previewPlatformUrl(platformType, username);
    if (resolvedUrl == null || resolvedUrl.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          _streamerSnackBar(
            context,
            'No link available for this platform',
            kind: _StreamerSnackKind.error,
          ),
        );
      }
      return;
    }

    try {
      await Future.any([
        _launchUrlWithTimeout(resolvedUrl),
        Future.delayed(const Duration(seconds: 10), () {
          throw TimeoutException(
            'URL launch timed out',
            const Duration(seconds: 10),
          );
        }),
      ]);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          _streamerSnackBar(
            context,
            'Opening ${_getPlatformDisplayName(platformType)}...',
            kind: _StreamerSnackKind.success,
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ StreamerCardView: Error launching URL: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          _streamerSnackBar(
            context,
            'Cannot open this link',
            kind: _StreamerSnackKind.error,
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
    if (platformType == null || platformType.isEmpty) {
      return 'Platform';
    }
    return PlatformRules.displayNameForType(platformType);
  }

  void _showShareSheet(BuildContext context) {
    HapticFeedback.lightImpact();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.55),
      builder: (context) => StreamerShareSheet(
        userId: widget.userId,
        username: _userData?['username'] as String?,
        displayName: _userData?['displayName'] as String?,
        profileImageUrl: avatarURL,
        onDismiss: () {
          // Don't call Navigator.pop() here as it's already handled in the X button
          // This prevents double pop which causes black screen
        },
      ),
    );
  }
}

Widget buildCachedAvatarCircle({
  required BuildContext context,
  required String? url,
  required double size,
  required double iconSize,
}) {
  final StSupportShellStyle shell = StSupportShellStyle.of(context);
  final Widget placeholder = Container(
    width: size,
    height: size,
    color: shell.skeletonFill,
    child: Icon(
      Icons.person,
      color: shell.iconDim,
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
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color border = scheme.outline.withValues(alpha: 0.45);
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
          Text(
            'Add Calendar Event',
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _titleController,
            style: TextStyle(color: scheme.onSurface),
            decoration: InputDecoration(
              labelText: 'Event Title',
              labelStyle: TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.65),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: scheme.primary),
              ),
              filled: true,
              fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            style: TextStyle(color: scheme.onSurface),
            decoration: InputDecoration(
              labelText: 'Description (Optional)',
              labelStyle: TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.65),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: scheme.primary),
              ),
              filled: true,
              fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
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
                      border: Border.all(color: border),
                      borderRadius: BorderRadius.circular(8),
                      color: scheme.surfaceContainerHighest.withValues(
                        alpha: 0.45,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Date',
                          style: TextStyle(
                            color: scheme.onSurface.withValues(alpha: 0.65),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                          style: TextStyle(color: scheme.onSurface),
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
                      border: Border.all(color: border),
                      borderRadius: BorderRadius.circular(8),
                      color: scheme.surfaceContainerHighest.withValues(
                        alpha: 0.45,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Time',
                          style: TextStyle(
                            color: scheme.onSurface.withValues(alpha: 0.65),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _selectedTime.format(context),
                          style: TextStyle(color: scheme.onSurface),
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
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
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
        _streamerSnackBar(
          context,
          'Please enter an event title',
          kind: _StreamerSnackKind.error,
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
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final Color inner = shell.isLight
        ? scheme.surfaceContainerHighest.withValues(alpha: 0.85)
        : Colors.black.withValues(alpha: 0.2);
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          colors: <Color>[
            scheme.primary,
            scheme.secondary,
            scheme.primary,
            scheme.secondary,
          ],
        ),
      ),
      child: Center(
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: inner,
          ),
          child: ClipOval(
            child: buildCachedAvatarCircle(
              context: context,
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
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.10),
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
                      username.startsWith('@') ? username : '@$username',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.68),
                        fontSize: 14,
                      ),
                    )
                  else if ((platform['url']?.toString() ?? '').isNotEmpty)
                    Text(
                      platform['url'].toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.68),
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.white.withValues(alpha: 0.55),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  String _getPlatformDisplayName(String platformType) {
    return PlatformRules.displayNameForType(platformType);
  }
}

class _UpcomingCalendarRow extends StatelessWidget {
  const _UpcomingCalendarRow({
    required this.event,
    required this.isBookmarked,
    required this.onTap,
  });

  final CalendarEvent event;
  final bool isBookmarked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final String meta = DateFormat('EEE, MMM d · h:mm a').format(event.date);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: shell.surfaceCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: shell.surfaceCardBorder),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.event_outlined,
                  color: shell.onChrome,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        event.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: shell.onChrome,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        meta,
                        style: TextStyle(
                          color: shell.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                  color: isBookmarked
                      ? StThemeColors.brandPurple
                      : shell.mutedStrong,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
