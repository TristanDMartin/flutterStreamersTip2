import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../models/user.dart' as app_user;
import '../models/user_status.dart';
import '../providers/status_provider.dart';
import '../providers/home_provider.dart';
import '../services/profile_update_service.dart';
import '../views/menu_view.dart';
import 'edit_profile_view.dart';
import 'share_profile_view.dart';
import 'profile_back_view.dart';
import 'profile_video_feed_view.dart';
import 'streamer_card_view.dart';
import '../services/unified_avatar_service.dart';
import 'setup_hashtag_permissions_widget.dart';
import 'tiktok_account_switch_button.dart';

class BeautifulProfileView extends ConsumerStatefulWidget {
  final app_user.User user;
  final bool isCurrentUser;

  const BeautifulProfileView({
    super.key,
    required this.user,
    required this.isCurrentUser,
  });

  @override
  ConsumerState<BeautifulProfileView> createState() =>
      _BeautifulProfileViewState();
}

class _BeautifulProfileViewState extends ConsumerState<BeautifulProfileView> {
  // Stats tracking
  int _followersCount = 0;
  int _followingCount = 0;
  int _postsCount = 0;

  // Test flag to show if stats are loading
  bool _statsLoaded = false;

  // Stream subscriptions for stats
  StreamSubscription<QuerySnapshot>? _followersSubscription;
  StreamSubscription<QuerySnapshot>? _followingSubscription;
  StreamSubscription<QuerySnapshot>? _postsSubscription;

  // Profile update service
  ProfileUpdateService? _profileUpdateService;

  // Cached user data
  Map<String, dynamic>? _cachedUserData;

  @override
  void initState() {
    super.initState();
    debugPrint(
        '🔧 BeautifulProfileView: Initializing for user: ${widget.user.id}');

    // Initialize profile update service for current user
    if (widget.isCurrentUser) {
      _profileUpdateService = ProfileUpdateService();
      _profileUpdateService?.initialize();
    }

    // Load stats
    _loadStats();
  }

  @override
  void dispose() {
    _followersSubscription?.cancel();
    _followingSubscription?.cancel();
    _postsSubscription?.cancel();
    super.dispose();
  }

  Map<String, dynamic> get _currentUserData {
    try {
      // Always fallback to widget user data first to prevent blank screen
      final fallbackData = widget.user.toMap();

      // Check if this is the current user by comparing user IDs
      final currentUserId = _profileUpdateService?.currentUser?.uid;
      final isCurrentUser =
          currentUserId != null && currentUserId == widget.user.id;

      // If this is the current user, get data from ProfileUpdateService
      if (isCurrentUser && _profileUpdateService?.isDataLoaded == true) {
        _cachedUserData = _profileUpdateService?.userData ?? fallbackData;
        if (kDebugMode) {
          debugPrint(
              'BeautifulProfileView: Using ProfileUpdateService data: ${_cachedUserData?.keys}');
        }

        // Save main user avatar for persistence
        final avatarUrl =
            _cachedUserData?['avatarURL'] ?? widget.user.avatarURL;
        if (avatarUrl != null && avatarUrl.isNotEmpty) {
          UnifiedAvatarService().saveMainUserAvatar(avatarUrl);
        }

        return _cachedUserData ?? fallbackData;
      }
      // Otherwise use the widget user data
      _cachedUserData = fallbackData;
      if (kDebugMode) {
        debugPrint(
            'BeautifulProfileView: Using widget user data: ${_cachedUserData?.keys}');
      }

      // Save main user avatar for persistence if this is the current user
      if (isCurrentUser && widget.user.avatarURL?.isNotEmpty == true) {
        UnifiedAvatarService().saveMainUserAvatar(widget.user.avatarURL!);
      }

      return _cachedUserData!;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ BeautifulProfileView: Error getting user data: $e');
        debugPrint('❌ BeautifulProfileView: Stack trace: $stackTrace');
      }
      // Fallback to basic user data
      return {
        'id': widget.user.id,
        'displayName': widget.user.displayName,
        'username': widget.user.username,
        'avatarURL': widget.user.avatarURL,
        'bio': widget.user.bio,
      };
    }
  }

  void _loadStats() {
    if (!mounted) return;

    try {
      // Load followers count
      _followersSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserData['id'])
          .collection('followers')
          .snapshots()
          .listen((snapshot) {
        if (mounted) {
          setState(() {
            _followersCount = snapshot.docs.length;
            _statsLoaded = true;
          });
        }
      });

      // Load following count
      _followingSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserData['id'])
          .collection('following')
          .snapshots()
          .listen((snapshot) {
        if (mounted) {
          setState(() {
            _followingCount = snapshot.docs.length;
          });
        }
      });

      // Load posts count
      _postsSubscription = FirebaseFirestore.instance
          .collection('videos')
          .where('userId', isEqualTo: _currentUserData['id'])
          .snapshots()
          .listen((snapshot) {
        if (mounted) {
          setState(() {
            _postsCount = snapshot.docs.length;
          });
        }
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ BeautifulProfileView: Error loading stats: $e');
      }
    }
  }

  Color _getStatusColor(UserStatus status) {
    switch (status) {
      case UserStatus.online:
        return Colors.green;
      case UserStatus.dnd:
        return Colors.red;
      case UserStatus.busy:
        return Colors.orange;
      case UserStatus.streaming:
        return Colors.purple;
      case UserStatus.offline:
        return Colors.grey;
    }
  }

  void _openStreamerCard() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => StreamerCardView(
          userId: _currentUserData['id'] ?? widget.user.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🔧 BeautifulProfileView: Building for user: ${widget.user.id}');
    debugPrint(
        '🔧 BeautifulProfileView: User data: ${widget.user.displayName}');

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      floatingActionButton: widget.isCurrentUser
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SetupHashtagPermissionsWidget(),
                  ),
                );
              },
              backgroundColor: Colors.orange,
              child:
                  const Icon(Icons.admin_panel_settings, color: Colors.white),
            )
          : null,
      body: Container(
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
        child: SafeArea(
          child: Column(
            children: [
              // Custom App Bar
              _buildCustomAppBar(),
              // Profile Content
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      _buildProfileHeader(),
                      const SizedBox(height: 24),
                      _buildSegments(),
                      const SizedBox(height: 16),
                      _buildContentArea(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Spacer(),
          // TikTok-style account switcher
          const TikTokAccountSwitchIcon(),
          IconButton(
            icon: const Icon(
              Icons.card_membership,
              color: Colors.white,
              size: 24,
            ),
            onPressed: () {
              if (kDebugMode) {
                debugPrint(
                    'BeautifulProfileView: Card button onPressed called');
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
                child: _currentUserData['avatarURL'] != null &&
                        _currentUserData['avatarURL'].toString().isNotEmpty
                    ? Image.network(
                        _currentUserData['avatarURL'],
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
                  ref.watch(userStatusProvider(_currentUserData['id'] ?? ''));

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

  Widget _buildNameAndHandle() {
    return Column(
      children: [
        Text(
          _currentUserData['displayName'] ?? 'Unknown User',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          '@${_currentUserData['username'] ?? 'unknown'}',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 16,
          ),
          textAlign: TextAlign.center,
        ),
        if (_currentUserData['bio'] != null &&
            _currentUserData['bio'].toString().isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            _currentUserData['bio'],
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatItem('Posts', _postsCount),
        _buildStatItem('Followers', _followersCount),
        _buildStatItem('Following', _followingCount),
      ],
    );
  }

  Widget _buildStatItem(String label, int count) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryButtonsRow() {
    if (widget.isCurrentUser) {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => EditProfileView(
                      user: _currentUserData,
                      onUserUpdated: (updatedUser) {
                        // Handle user update
                        setState(() {
                          _cachedUserData = updatedUser;
                        });
                      },
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Edit Profile'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ShareProfileView(
                      user: _currentUserData,
                      dismiss: () => Navigator.of(context).pop(),
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Share Profile'),
            ),
          ),
        ],
      );
    } else {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                // Follow/Unfollow logic here
                HapticFeedback.lightImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Follow functionality coming soon'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Follow'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ShareProfileView(
                      user: _currentUserData,
                      dismiss: () => Navigator.of(context).pop(),
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Share Profile'),
            ),
          ),
        ],
      );
    }
  }

  Widget _buildSegments() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSegmentButton('Videos', true),
          ),
          Expanded(
            child: _buildSegmentButton('Favorites', false),
          ),
          Expanded(
            child: _buildSegmentButton('Tagged', false),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton(String label, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: isSelected
            ? Colors.white.withValues(alpha: 0.2)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color:
              isSelected ? Colors.white : Colors.white.withValues(alpha: 0.7),
          fontSize: 16,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildContentArea() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: const Center(
        child: Text(
          'Video grid coming soon',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}
