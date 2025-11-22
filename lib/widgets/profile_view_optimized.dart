import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../models/user.dart' as app_user;
import '../models/user_status.dart';
import '../providers/status_provider.dart';
import '../services/profile_update_service.dart';
import '../services/post_counter_service.dart';
import '../views/menu_view.dart';
import 'edit_profile_view.dart';
import 'share_profile_view.dart';
import 'profile_back_view.dart';
import 'profile_video_feed_view.dart';
import 'streamer_card_view.dart';
import '../services/unified_avatar_service.dart';
import '../services/global_playback_manager.dart';

class ProfileViewOptimized extends ConsumerStatefulWidget {
  final app_user.User user;
  final bool isCurrentUser;

  const ProfileViewOptimized({
    super.key,
    required this.user,
    required this.isCurrentUser,
  });

  @override
  ConsumerState<ProfileViewOptimized> createState() =>
      _ProfileViewOptimizedState();
}

class _ProfileViewOptimizedState extends ConsumerState<ProfileViewOptimized>
    with TickerProviderStateMixin {
  late AnimationController _segmentedController;

  // Stats tracking
  int _followersCount = 0;
  int _followingCount = 0;
  int _postsCount = 0;

  // Test flag to show if stats are loading
  bool _statsLoaded = false;
  bool _isLoadingStats =
      false; // 🔴 FIX #2: Prevent multiple simultaneous loads
  bool _isDisposed = false; // 🔴 FIX #2: Track disposal state

  // Stream subscriptions for stats
  StreamSubscription<QuerySnapshot>? _followersSubscription;
  StreamSubscription<QuerySnapshot>? _followingSubscription;
  StreamSubscription<int>? _postsSubscription;
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  int _selectedTabIndex = 0; // 0: Video, 1: Favorites, 2: Tagged
  bool _isFront = true;
  ProfileUpdateService? _profileUpdateService;
  Map<String, dynamic>? _cachedUserData;

  // 🔴 FIX #1 & #5: Cache avatar URL and data dirty flag
  String? _lastSavedAvatarUrl;
  bool _userDataDirty = true;

  // 🔴 FIX #3: Debounce timer for profile updates
  Timer? _rebuildDebounceTimer;

  // 🔴 FIX #4: Cache fix status per user (static to persist across instances)
  static final Map<String, DateTime> _lastFixTimestamp = {};
  static const Duration _fixCooldown = Duration(minutes: 5);

  @override
  void initState() {
    super.initState();
    
    // 🔊 AUDIO FIX: Block playback immediately when ProfileView opens
    GlobalPlaybackManager.instance.block(reason: 'profileViewOpened');
    if (kDebugMode) {
      debugPrint('🚫 ProfileView: Blocking playback on init');
    }
    
    _segmentedController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
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
    _profileUpdateService = ProfileUpdateService();

    // Listen for profile updates
    _profileUpdateService?.addProfileViewListener(_onProfileUpdated);

    // Load stats - this sets up real-time listeners including post count
    _loadStats();

    // Auto-reconcile post count if needed (silent background fix with 5-min cooldown)
    // This ensures accuracy while allowing real-time updates to work
    _autoReconcilePostCountIfNeeded();
  }

  @override
  void dispose() {
    // 🔴 FIX #2: Mark as disposed first
    _isDisposed = true;

    // 🔴 FIX #3: Cancel debounce timer
    _rebuildDebounceTimer?.cancel();
    _rebuildDebounceTimer = null;

    _profileUpdateService?.removeProfileViewListener(_onProfileUpdated);
    _segmentedController.dispose();
    _flipController.dispose();

    // 🔴 FIX #2: Cancel stats subscriptions asynchronously
    _followersSubscription?.cancel();
    _followingSubscription?.cancel();
    _postsSubscription?.cancel();

    super.dispose();
  }

  // 🔴 FIX #3: Debounced profile update callback
  void _onProfileUpdated() {
    // Debounce rebuilds to prevent spam
    _rebuildDebounceTimer?.cancel();
    _rebuildDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted && !_isDisposed) {
        // 🔴 FIX #5: Mark data as dirty to force cache refresh
        _userDataDirty = true;
        // Clear cached avatar URL to force image reload when avatar changes
        final newAvatarURL =
            _profileUpdateService?.userData?['avatarURL'] as String?;
        if (newAvatarURL != null && newAvatarURL != _lastSavedAvatarUrl) {
          _lastSavedAvatarUrl = null; // Clear to force image reload
        }
        setState(() {
          // Trigger rebuild when profile data is updated (especially avatar)
        });
        if (kDebugMode) {
          debugPrint('🔄 ProfileView: Avatar updated, rebuilding UI');
          debugPrint('   New avatar URL: ${newAvatarURL ?? 'null'}');
        }
      }
    });
  }

  /// 🔴 FIX #4: Fix post count with cooldown timer
  Future<void> _autoReconcilePostCountIfNeeded() async {
    try {
      // Only auto-reconcile for current user
      if (!widget.isCurrentUser) return;

      // Check if we recently reconciled this user's count
      final lastFix = _lastFixTimestamp[widget.user.id];
      if (lastFix != null &&
          DateTime.now().difference(lastFix) < _fixCooldown) {
        if (kDebugMode) {
          debugPrint(
              '📊 PROFILE: Skipping auto-reconciliation for user ${widget.user.id} (recently reconciled)');
        }
        return;
      }

      if (kDebugMode) {
        debugPrint(
            '📊 PROFILE: Auto-reconciling post count for user ${widget.user.id}');
      }

      // Use PostCounterService for reconciliation
      final postCounterService = PostCounterService();
      final reconciledCount =
          await postCounterService.reconcilePostCount(widget.user.id);

      if (reconciledCount >= 0) {
        // Cache the reconciliation timestamp
        _lastFixTimestamp[widget.user.id] = DateTime.now();

        if (kDebugMode) {
          debugPrint(
              '✅ PROFILE: Auto-reconciled post count for user ${widget.user.id}: $reconciledCount posts');
        }

        // The PostCounterService.watchPostCount will automatically update the UI
        // No need to manually reload stats
      } else {
        if (kDebugMode) {
          debugPrint(
              '⚠️ PROFILE: Auto-reconciliation failed for user ${widget.user.id}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '❌ PROFILE: Error auto-reconciling post count for user ${widget.user.id}: $e');
      }
    }
  }

  // 🔴 FIX #2: Properly managed stats loading with async cleanup
  Future<void> _loadStats() async {
    if (widget.user.id.isEmpty || _isLoadingStats || _isDisposed) {
      return;
    }

    _isLoadingStats = true;

    try {
      setState(() {
        _statsLoaded = true;
      });

      // Cancel existing subscriptions and wait for cleanup
      await _postsSubscription?.cancel();
      await _followersSubscription?.cancel();
      await _followingSubscription?.cancel();

      _postsSubscription = null;
      _followersSubscription = null;
      _followingSubscription = null;

      // Small delay to ensure cleanup
      await Future.delayed(const Duration(milliseconds: 100));

      // Load posts count using PostCounterService for real-time updates
      final postCounterService = PostCounterService();
      _postsSubscription =
          postCounterService.watchPostCount(widget.user.id).listen(
        (postCount) {
          if (mounted && !_isDisposed) {
            setState(() {
              _postsCount = postCount;
            });
          }
        },
        onError: (error) {
          if (kDebugMode) {
            debugPrint('❌ ProfileView: Error watching post count: $error');
          }
        },
        cancelOnError: false, // Don't auto-cancel on error
      );

      // Load followers count from new follows collection
      _followersSubscription = FirebaseFirestore.instance
          .collection('follows')
          .where('followedId', isEqualTo: widget.user.id)
          .snapshots()
          .listen(
        (snapshot) {
          if (mounted && !_isDisposed) {
            setState(() {
              _followersCount = snapshot.docs.length;
            });
          }
        },
        onError: (error) {
          if (kDebugMode) {
            debugPrint('❌ ProfileView: Error watching followers: $error');
          }
        },
        cancelOnError: false,
      );

      // Load following count from new follows collection
      _followingSubscription = FirebaseFirestore.instance
          .collection('follows')
          .where('followerId', isEqualTo: widget.user.id)
          .snapshots()
          .listen(
        (snapshot) {
          if (mounted && !_isDisposed) {
            setState(() {
              _followingCount = snapshot.docs.length;
            });
          }
        },
        onError: (error) {
          if (kDebugMode) {
            debugPrint('❌ ProfileView: Error watching following: $error');
          }
        },
        cancelOnError: false,
      );
    } finally {
      _isLoadingStats = false;
    }
  }

  void _flipCard() {
    HapticFeedback.lightImpact();
    if (_isFront) {
      _flipController.forward();
    } else {
      _flipController.reverse();
    }
    _isFront = !_isFront;
  }

  // PlatformType _parsePlatformType(String type) {
  //   switch (type.toLowerCase()) {
  //     case 'twitch':
  //       return PlatformType.twitch;
  //     case 'youtube':
  //       return PlatformType.youtube;
  //     case 'kick':
  //       return PlatformType.kick;
  //     case 'tiktok':
  //       return PlatformType.tiktok;
  //     case 'facebook':
  //       return PlatformType.facebook;
  //     case 'bluesky':
  //       return PlatformType.bluesky;
  //     case 'twitter':
  //       return PlatformType.twitter;
  //     case 'instagram':
  //       return PlatformType.instagram;
  //     case 'rednote':
  //       return PlatformType.rednote;
  //     default:
  //       return PlatformType.other;
  //   }
  // }

  // List<String> _parseHashtags(dynamic hashtagsData) {
  //   if (hashtagsData == null) return [];
  //
  //   if (hashtagsData is List<dynamic>) {
  //     return hashtagsData.cast<String>();
  //   } else if (hashtagsData is String) {
  //     // Handle comma-separated string like "Badge, chill"
  //     return hashtagsData.split(',').map((tag) => tag.trim()).where((tag) => tag.isNotEmpty).toList();
  //   }
  //
  //   return [];
  // }

  void _openStreamerCard() {
    if (kDebugMode) {
      // print('ProfileView: StreamerCard button tapped');
    }
    HapticFeedback.lightImpact();

    try {
      // Convert user data to StreamerCard
      // final userData = _currentUserData;
      if (kDebugMode) {
        // print('ProfileView: User data keys: ${userData.keys}');
      }
      // final streamerCard = StreamerCard(
      //   id: userData['id'] as String? ?? '',
      //   displayName: userData['displayName'] as String? ?? '',
      //   username: userData['username'] as String? ?? '',
      //   bio: userData['bio'] as String? ?? '',
      //   avatarURL: userData['avatarUrl'] as String?,
      //   platforms: (userData['platforms'] as List<dynamic>?)?.map((p) {
      //     final platformMap = p as Map<String, dynamic>;
      //     return Platform(
      //       id: platformMap['id'] as String? ?? '',
      //       type: _parsePlatformType(platformMap['type'] as String? ?? ''),
      //       username: platformMap['username'] as String? ?? '',
      //       followers: (platformMap['followers'] as num?)?.toInt() ?? 0,
      //       url: platformMap['url'] as String?,
      //     );
      //   }).toList() ?? [],
      //   hashtags: _parseHashtags(userData['hashtags']),
      //   calendarEvents: (userData['calendarEvents'] as List<dynamic>?)?.map((e) {
      //     final eventMap = e as Map<String, dynamic>;
      //     return CalendarEvent(
      //       id: eventMap['id'] as String? ?? '',
      //       title: eventMap['title'] as String? ?? '',
      //       description: eventMap['description'] as String? ?? '',
      //       date: (eventMap['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      //     );
      //   }).toList() ?? [],
      //   onlineStatus: userData['status'] as String? ?? 'offline',
      // );

      if (kDebugMode) {
        // print('ProfileView: Navigating to StreamerCardView');
      }

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => StreamerCardView(
            userId: widget.user.id,
            currentUserId: _profileUpdateService?.currentUser?.uid,
            onDismiss: () => Navigator.of(context).pop(),
            onFollow: (userId) {
              // Handle follow action
              HapticFeedback.lightImpact();
              if (kDebugMode) {
                // print('ProfileView: Follow action triggered for user: $userId');
              }
              // Follow functionality - placeholder for future implementation
            },
            onMessage: (userId) {
              // Handle message action
              HapticFeedback.lightImpact();
              if (kDebugMode) {
                // print('ProfileView: Message action triggered for user: $userId');
              }
              // Message functionality - placeholder for future implementation
            },
            onShare: (userId) {
              // Handle share action
              HapticFeedback.lightImpact();
              if (kDebugMode) {
                // print('ProfileView: Share action triggered for user: $userId');
              }
              // Share functionality - placeholder for future implementation
            },
          ),
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        // print('ProfileView: Error opening StreamerCard: $e');
      }
      // Show error to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening profile: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// 🔴 FIX #1 & #5: Cached user data method (no longer a getter)
  Map<String, dynamic> _getCurrentUserData() {
    // Only recompute if data is dirty
    if (!_userDataDirty && _cachedUserData != null) {
      return _cachedUserData!;
    }

    try {
      // Check if this is the current user by comparing user IDs
      final currentUserId = _profileUpdateService?.currentUser?.uid;
      final isCurrentUser =
          currentUserId != null && currentUserId == widget.user.id;

      // If this is the current user, get data from ProfileUpdateService
      if (isCurrentUser && _profileUpdateService?.isDataLoaded == true) {
        _cachedUserData =
            _profileUpdateService?.userData ?? widget.user.toMap();
        if (kDebugMode) {
          debugPrint(
              'ProfileView: Using ProfileUpdateService data: ${_cachedUserData?.keys}');
        }

        // 🔴 FIX #1: Only save avatar if changed
        final avatarUrl =
            _cachedUserData?['avatarURL'] ?? widget.user.avatarURL;
        if (avatarUrl != null &&
            avatarUrl.isNotEmpty &&
            avatarUrl != _lastSavedAvatarUrl) {
          UnifiedAvatarService().saveMainUserAvatar(avatarUrl);
          _lastSavedAvatarUrl = avatarUrl;
        }

        _userDataDirty = false;
        return _cachedUserData!;
      }

      // Otherwise use the widget user data
      _cachedUserData = widget.user.toMap();
      if (kDebugMode) {
        debugPrint(
            'ProfileView: Using widget user data: ${_cachedUserData?.keys}');
      }

      // 🔴 FIX #1: Only save avatar if changed
      if (isCurrentUser &&
          widget.user.avatarURL?.isNotEmpty == true &&
          widget.user.avatarURL != _lastSavedAvatarUrl) {
        UnifiedAvatarService().saveMainUserAvatar(widget.user.avatarURL!);
        _lastSavedAvatarUrl = widget.user.avatarURL;
      }

      _userDataDirty = false;
      return _cachedUserData!;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ ProfileView: Error getting user data: $e');
        debugPrint('❌ ProfileView: Stack trace: $stackTrace');
      }
      _userDataDirty = false;
      // Fallback to basic user data
      return _createFallbackUserData();
    }
  }

  /// Create fallback user data
  Map<String, dynamic> _createFallbackUserData() {
    return {
      'id': widget.user.id,
      'displayName': widget.user.displayName,
      'username': widget.user.username,
      'bio': widget.user.bio ?? '',
      'avatarUrl': widget.user.avatarURL,
      'followers': 0,
      'following': 0,
      'videos': 0,
      'hashtags': <String>[],
      'platforms': <Map<String, dynamic>>[],
      'calendarEvents': <Map<String, dynamic>>[],
      'status': 'offline',
      'isOnline': false,
    };
  }

  void _onTabSelected(int index) {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedTabIndex = index;
    });
    _segmentedController.forward().then((_) {
      _segmentedController.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    // 🔴 FIX #5: Cache user data at top of build method
    final userData = _getCurrentUserData();

    // Ensure stats are loaded when widget builds (only once)
    if (!_statsLoaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isLoadingStats) {
          // debugPrint('🔧 ProfileView: Widget built, calling _loadStats()');
          _loadStats();
        }
      });
    }

    // debugPrint('🔧 ProfileView: Building ProfileViewOptimized for user: ${widget.user.id}');

    return Scaffold(
      backgroundColor: Colors.black,
      extendBody: true,
      extendBodyBehindAppBar:
          true, // FIXED: Extend behind status bar for full gradient
      body: AnimatedBuilder(
        animation: _flipAnimation,
        builder: (context, child) {
          final isShowingFront = _flipAnimation.value < 0.5;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(_flipAnimation.value * 3.14159),
            child: isShowingFront
                ? _buildFrontView(userData)
                : Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(3.14159),
                    child: _buildBackView(userData),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildFrontView(Map<String, dynamic> userData) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF6633CC), // Purple (matches NetworkView)
            Color(0xFF1A1A4D), // Dark blue (matches NetworkView)
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar:
            true, // FIXED: Extend behind status bar for full gradient
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: null,
          centerTitle: false,
          actions: [
            // TikTok-style account switcher (HIDDEN for now - needs more work)
            // const TikTokAccountSwitchIcon(),
            IconButton(
              icon: const Icon(
                Icons.flip,
                color: Colors.white,
                size: 24,
              ),
              onPressed: _flipCard,
            ),
            IconButton(
              icon: const Icon(
                Icons.card_membership,
                color: Colors.white,
                size: 24,
              ),
              onPressed: () {
                if (kDebugMode) {
                  // print('ProfileView: Card button onPressed called');
                }
                // Show immediate feedback
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Opening StreamerCard...'),
                    duration: Duration(seconds: 1),
                  ),
                );
                _openStreamerCard();
              },
            ),
            IconButton(
              icon: Icon(
                Icons.more_horiz,
                color: Colors.white.withValues(alpha: 0.7),
                size: 24,
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const MenuView(),
                  ),
                );
              },
            ),
          ],
        ),
        body: SafeArea(
          // FIXED: SafeArea around body content only
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 24),
                _buildProfileHeader(userData),
                const SizedBox(height: 24),
                _buildProfileContent(userData),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackView(Map<String, dynamic> userData) {
    return ProfileBackView(
      user: userData,
      onFlip: _flipCard,
    );
  }

  Widget _buildProfileHeader(Map<String, dynamic> userData) {
    return Column(
      children: [
        _buildAvatarWithGradientRing(userData),
        const SizedBox(height: 16),
        _buildNameAndHandle(userData),
        const SizedBox(height: 24),
        _buildStatsRow(),
        const SizedBox(height: 24),
        // Post count fix is handled by the simple button below in stats row
        _buildPrimaryButtonsRow(),
      ],
    );
  }

  Widget _buildAvatarWithGradientRing(Map<String, dynamic> userData) {
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
                child: userData['avatarURL'] != null &&
                        userData['avatarURL'].toString().isNotEmpty
                    ? Image.network(
                        userData['avatarURL'],
                        key: ValueKey(userData[
                            'avatarURL']), // Force rebuild when avatar URL changes
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 48,
                        ),
                      )
                    : const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 48,
                      ),
              ),
            ),
          ),
        ),
        // Online status indicator - show based on real-time status
        if (widget.isCurrentUser)
          Consumer(
            builder: (context, ref, child) {
              final statusAsync =
                  ref.watch(userStatusProvider(userData['id'] ?? ''));

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

  Widget _buildNameAndHandle(Map<String, dynamic> userData) {
    return Column(
      children: [
        Text(
          userData['displayName'] ?? 'Unknown User',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.w900,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '@${userData['username'] ?? 'unknown'}',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.75),
            fontSize: 18,
            fontWeight: FontWeight.w600,
            height: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Consumer(
      builder: (context, ref, child) {
        // Stats row building

        // Show loading indicator if stats haven't loaded yet
        if (!_statsLoaded) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStatItem('Posts', '...'),
              const SizedBox(width: 54),
              _buildStatItem('Followers', '...'),
              const SizedBox(width: 54),
              _buildStatItem('Following', '...'),
            ],
          );
        }

        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStatItem('Posts', _postsCount.toString()),
                const SizedBox(width: 54),
                _buildStatItem('Followers', _followersCount.toString()),
                const SizedBox(width: 54),
                _buildStatItem('Following', _followingCount.toString()),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 16,
            fontWeight: FontWeight.w600,
            height: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryButtonsRow() {
    // Get fresh user data for navigation
    final userData = _getCurrentUserData();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _buildGradientPillButton(
              text: 'Edit Profile',
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => EditProfileView(
                      user: userData,
                      onUserUpdated: (updatedUser) {
                        // Profile update is handled by ProfileUpdateService
                        // The service will automatically trigger a rebuild
                        HapticFeedback.lightImpact();
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildGradientPillButton(
              text: 'Share Profile',
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ShareProfileView(
                      user: userData,
                      dismiss: () => Navigator.of(context).pop(),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradientPillButton({
    required String text,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF955CFF), Color(0xFF3D99F7)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Center(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSegments() {
    return Container(
      height: 56,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          _buildTab('Video', 0),
          _buildTab('Favorites', 1),
          _buildTab('Tagged', 2),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final isSelected = _selectedTabIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => _onTabSelected(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: isSelected
                ? Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                    width: 1,
                  )
                : null,
          ),
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.7),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              child: Text(label),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContentArea() {
    switch (_selectedTabIndex) {
      case 0:
        return _buildVideoContent();
      case 1:
        return _buildFavoritesContent();
      case 2:
        return _buildTaggedContent();
      default:
        return _buildVideoContent();
    }
  }

  Widget _buildVideoContent() {
    return _buildVideoFeedWithErrorHandling(ProfileVideoFeedType.videos);
  }

  Widget _buildFavoritesContent() {
    return _buildVideoFeedWithErrorHandling(ProfileVideoFeedType.favorites);
  }

  Widget _buildTaggedContent() {
    return _buildVideoFeedWithErrorHandling(ProfileVideoFeedType.tagged);
  }

  Widget _buildVideoFeedWithErrorHandling(ProfileVideoFeedType feedType) {
    return ProfileVideoFeedView(
      feedType: feedType,
      userId: widget.user.id,
      onVideoTap: () {
        // Handle video tap - could navigate to video player
        HapticFeedback.lightImpact();
      },
    );
  }

  Widget _buildProfileContent(Map<String, dynamic> userData) {
    return Column(
      children: [
        _buildSegments(),
        _buildContentArea(),
      ],
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
      case UserStatus.dnd:
        return const Color(0xFFF44336); // Red
      case UserStatus.streaming:
        return const Color(0xFF9C27B0); // Purple
    }
  }
}
