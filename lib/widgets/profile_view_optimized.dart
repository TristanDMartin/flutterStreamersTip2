import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart' as app_user;
import '../models/user_status.dart';
import '../providers/status_provider.dart';
import '../services/profile_update_service.dart';
import '../views/menu_view.dart';
import 'edit_profile_view.dart';
import 'share_profile_view.dart';
import 'profile_back_view.dart';
import 'profile_video_feed_view.dart';
import 'streamer_card_view.dart';
import '../services/unified_avatar_service.dart';
import 'setup_hashtag_permissions_widget.dart';

class ProfileViewOptimized extends ConsumerStatefulWidget {
  final app_user.User user;
  final bool isCurrentUser;

  const ProfileViewOptimized({
    super.key,
    required this.user,
    required this.isCurrentUser,
  });

  @override
  ConsumerState<ProfileViewOptimized> createState() => _ProfileViewOptimizedState();
}

class _ProfileViewOptimizedState extends ConsumerState<ProfileViewOptimized> 
    with TickerProviderStateMixin {
  late AnimationController _segmentedController;
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  int _selectedTabIndex = 0; // 0: Video, 1: Favorites, 2: Tagged
  bool _isFront = true;
  ProfileUpdateService? _profileUpdateService;
  Map<String, dynamic>? _cachedUserData;

  @override
  void initState() {
    super.initState();
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
  }

  @override
  void dispose() {
    _profileUpdateService?.removeProfileViewListener(_onProfileUpdated);
    _segmentedController.dispose();
    _flipController.dispose();
    super.dispose();
  }

  @override
  void activate() {
    super.activate();
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
  }

  void _onProfileUpdated() {
    if (mounted) {
      setState(() {
        // Trigger rebuild when profile data is updated
        // The ProfileUpdateService will have the latest user data
      });
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
            // TODO: Implement follow functionality
          },
          onMessage: (userId) {
            // Handle message action
            HapticFeedback.lightImpact();
            if (kDebugMode) {
    // print('ProfileView: Message action triggered for user: $userId');
            }
            // TODO: Implement message functionality
          },
          onShare: (userId) {
            // Handle share action
            HapticFeedback.lightImpact();
            if (kDebugMode) {
    // print('ProfileView: Share action triggered for user: $userId');
            }
            // TODO: Implement share functionality
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

  /// Get the current user data, either from widget or from ProfileUpdateService
  Map<String, dynamic> get _currentUserData {
    try {
      // Check if this is the current user by comparing user IDs
      final currentUserId = _profileUpdateService?.currentUser?.uid;
      final isCurrentUser = currentUserId != null && currentUserId == widget.user.id;
      
      // If this is the current user, get data from ProfileUpdateService
      if (isCurrentUser && _profileUpdateService?.isDataLoaded == true) {
        _cachedUserData = _profileUpdateService?.userData ?? widget.user.toMap();
        if (kDebugMode) {
    // print('ProfileView: Using ProfileUpdateService data: ${_cachedUserData?.keys}');
        }
        
        // Save main user avatar for persistence
        final avatarUrl = _cachedUserData?['avatarURL'] ?? widget.user.avatarURL;
        if (avatarUrl != null && avatarUrl.isNotEmpty) {
          UnifiedAvatarService().saveMainUserAvatar(avatarUrl);
        }
        
        return _cachedUserData!;
      }
      // Otherwise use the widget user data
      _cachedUserData = widget.user.toMap();
      if (kDebugMode) {
    // print('ProfileView: Using widget user data: ${_cachedUserData?.keys}');
      }
      
      // Save main user avatar for persistence if this is the current user
      if (isCurrentUser && widget.user.avatarURL?.isNotEmpty == true) {
        UnifiedAvatarService().saveMainUserAvatar(widget.user.avatarURL!);
      }
      
      return _cachedUserData!;
    } catch (e) {
      if (kDebugMode) {
    // print('ProfileView: Error getting user data: $e');
      }
      // Fallback to basic user data
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
    return SafeArea( // FIXED: Add SafeArea to prevent status bar overlap
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBody: true,
        extendBodyBehindAppBar: false, // FIXED: Don't extend behind status bar
        floatingActionButton: widget.isCurrentUser ? FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SetupHashtagPermissionsWidget(),
              ),
            );
          },
          backgroundColor: Colors.orange,
          child: const Icon(Icons.admin_panel_settings, color: Colors.white),
        ) : null,
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
                  ? _buildFrontView()
                  : Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..rotateY(3.14159),
                      child: _buildBackView(),
                    ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFrontView() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF6633CC), // Purple (matches NetworkView)
            Color(0xFF1A1A4D), // Dark blue (matches NetworkView)
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: false, // FIXED: Don't extend behind status bar
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
                color: Colors.white.withValues(alpha:0.7),
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
        body: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 24),
              _buildProfileHeader(),
              const SizedBox(height: 24),
              _buildProfileContent(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackView() {
    return ProfileBackView(
      user: _currentUserData,
      onFlip: _flipCard,
    );
  }

  Widget _buildProfileHeader() {
    return Column(
      children: [
        _buildAvatarWithGradientRing(),
        const SizedBox(height: 16),
        _buildNameAndHandle(),
        const SizedBox(height: 24),
        _buildStatsRow(),
        const SizedBox(height: 24),
        _buildPrimaryButtonsRow(),
      ],
    );
  }

  Widget _buildAvatarWithGradientRing() {
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
                child: _currentUserData['avatarURL'] != null && _currentUserData['avatarURL'].toString().isNotEmpty
                    ? Image.network(
                        _currentUserData['avatarURL'],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Icon(
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
              final statusAsync = ref.watch(userStatusProvider(_currentUserData['id'] ?? ''));
              
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
                              color: _getStatusColor(presence.status).withValues(alpha: 0.5),
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

  Widget _buildNameAndHandle() {
    return Column(
      children: [
        Text(
          _currentUserData['displayName'] ?? 'Unknown User',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.w900,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '@${_currentUserData['username'] ?? 'unknown'}',
          style: TextStyle(
            color: Colors.white.withValues(alpha:0.75),
            fontSize: 18,
            fontWeight: FontWeight.w600,
            height: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStatItem('Posts', '0'),
        const SizedBox(width: 54),
        _buildStatItem('Followers', '0'),
        const SizedBox(width: 54),
        _buildStatItem('Following', '0'),
      ],
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
            color: Colors.white.withValues(alpha:0.7),
            fontSize: 16,
            fontWeight: FontWeight.w600,
            height: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryButtonsRow() {
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
                      user: _currentUserData,
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
                      user: _currentUserData,
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
        color: Colors.white.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha:0.15),
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
            color: isSelected ? Colors.white.withValues(alpha:0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: isSelected
                ? Border.all(
                    color: Colors.white.withValues(alpha:0.25),
                    width: 1,
                  )
                : null,
          ),
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white.withValues(alpha:0.7),
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

  Widget _buildProfileContent() {
    return Column(
      children: [
        _buildSegments(),
        SizedBox(
          height: 400, // Fixed height for content area
          child: _buildContentArea(),
        ),
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