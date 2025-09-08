import 'package:flutter/material.dart';
import 'share_profile_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/favorites_provider.dart';
import '../providers/video_service_provider.dart';
import '../models/home_video.dart';
import 'edit_profile_view.dart';
import '../repositories/user_repository.dart';
import '../widgets/streamer_card_view.dart';
import '../models/streamer_card.dart';
import '../models/calendar_event.dart';
import '../providers/status_provider.dart';
import '../models/user_status.dart';
import '../views/menu_view.dart';
import 'player_screen.dart';

class UserProfileView extends ConsumerStatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback? onFlip;
  
  const UserProfileView({
    super.key,
    required this.user,
    this.onFlip,
  });

  @override
  ConsumerState<UserProfileView> createState() => _UserProfileViewState();
}

class _UserProfileViewState extends ConsumerState<UserProfileView> {
  final UserRepository _userRepository = UserRepository();
  int _selectedTabIndex = 0; // 0: Video, 1: Favorites, 2: Tagged

  void _onTabSelected(int index) {
    setState(() {
      _selectedTabIndex = index;
    });
  }

  Widget _buildSegments() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildTab('Video', 0),
            ),
            Expanded(
              child: Consumer(
                builder: (BuildContext context, WidgetRef ref, Widget? _) {
                  final favoritesState = ref.watch(favoritesProvider);
                  final int favCount = favoritesState.favorites.length;
                  final String label = favCount > 0 ? 'Favorites ($favCount)' : 'Favorites';
                  return _buildTab(label, 1);
                },
              ),
            ),
            Expanded(
              child: _buildTab('Tagged', 2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String text, int index) {
    final bool isSelected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () => _onTabSelected(index),
      child: Container(
        height: 32,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContentArea() {
    switch (_selectedTabIndex) {
      case 0: // Video
        return _buildVideoContent();
      case 1: // Favorites
        return _buildFavoritesContent();
      case 2: // Tagged
        return _buildTaggedContent();
      default:
        return _buildVideoContent();
    }
  }

  Widget _buildVideoContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.video_library_outlined,
            size: 80,
            color: Colors.white.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 24),
          Text(
            'No Videos Yet',
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.75),
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your published videos will appear here',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoritesContent() {
    return Consumer(
      builder: (context, ref, child) {
        final favoritesState = ref.watch(favoritesProvider);
        final favorites = favoritesState.favorites.toList();
        final videoService = ref.watch(videoServiceProvider);


        if (favorites.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.bookmark_border,
                  size: 80,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 24),
                Text(
                  'No Saved Videos',
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.75),
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Videos you save will appear here',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 24),
                // Test button to add some favorites
                ElevatedButton(
                  onPressed: () {
                    ref.read(favoritesProvider.notifier).toggleFavorite('1');
                    ref.read(favoritesProvider.notifier).toggleFavorite('2');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9248d2),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Add Test Favorites'),
                ),
              ],
            ),
          );
        }

        // Get actual video data for favorites
        final favoriteVideos = videoService.getVideosByIds(favorites);

        return SizedBox(
          height: MediaQuery.of(context).size.height - 200, // Constrain the height
          child: RefreshIndicator(
            onRefresh: () async {
              await ref.read(favoritesProvider.notifier).forceSync();
            },
            color: const Color(0xFF9248d2),
            backgroundColor: Colors.black,
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 110 / 170, // Width / Height ratio
              ),
              itemCount: favoriteVideos.length,
              itemBuilder: (context, index) {
                final video = favoriteVideos[index];
                return _buildFavoriteVideoGridCard(video, index);
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildFavoriteVideoGridCard(HomeVideo video, int index) {
    return GestureDetector(
      onTap: () => _openVideoPlayer(video, index),
      onLongPress: () {
        // Remove from favorites on long press
        ref.read(favoritesProvider.notifier).toggleFavorite(video.id);
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Video thumbnail
              Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.grey[800],
                child: video.videoURL.isNotEmpty
                    ? Image.network(
                        video.videoURL,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[800],
                            child: const Icon(
                              Icons.play_circle_outline,
                              color: Colors.white54,
                              size: 40,
                            ),
                          );
                        },
                      )
                    : Container(
                        color: Colors.grey[800],
                        child: const Icon(
                          Icons.play_circle_outline,
                          color: Colors.white54,
                          size: 40,
                        ),
                      ),
              ),
              // Play icon and view count overlay
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.play_circle_fill,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatViews(video.views),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Bookmark indicator
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.bookmark,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
              // Duration indicator (bottom-right)
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _formatDuration(video.views), // Using views as placeholder for duration
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
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

  String _formatViews(int views) {
    if (views >= 1000000) {
      return '${(views / 1000000).toStringAsFixed(1)}M';
    } else if (views >= 1000) {
      return '${(views / 1000).toStringAsFixed(1)}K';
    } else {
      return views.toString();
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }


  void _openVideoPlayer(HomeVideo video, int index) {
    // Get all favorite videos for the player
    final favoritesState = ref.read(favoritesProvider);
    final favoriteIds = favoritesState.favorites.toList();
    
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => PlayerScreen(
          mode: PlayerMode.favorites,
          initialIndex: index,
          videoIds: favoriteIds,
        ),
      ),
    );
  }


  Widget _buildTaggedContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_add_outlined,
            size: 80,
            color: Colors.white.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 24),
          Text(
            'No Tagged Content',
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.75),
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
          ),
          const SizedBox(height: 8),
          Text(
            'Videos where you\'re tagged will appear here',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  List<Platform> _convertToPlatforms(dynamic platformsData) {
    if (platformsData == null) return [];
    if (platformsData is! List) return [];
    
    return platformsData.map((platform) {
      if (platform is Map<String, dynamic>) {
        return Platform.fromJson(platform);
      }
      return null;
    }).where((platform) => platform != null).cast<Platform>().toList();
  }

  List<SocialLink> _convertToSocialLinks(dynamic socialLinksData) {
    if (socialLinksData == null) return [];
    if (socialLinksData is! List) return [];
    
    return socialLinksData.map((link) {
      if (link is Map<String, dynamic>) {
        return SocialLink.fromJson(link);
      }
      return null;
    }).where((link) => link != null).cast<SocialLink>().toList();
  }

  List<CalendarEvent> _convertToCalendarEvents(dynamic eventsData) {
    if (eventsData == null) return [];
    if (eventsData is! List) return [];
    
    return eventsData.map((event) {
      if (event is Map<String, dynamic>) {
        return CalendarEvent.fromMap(event);
      }
      return null;
    }).where((event) => event != null).cast<CalendarEvent>().toList();
  }

  void _presentStreamerCard() {
    // Convert user data to StreamerCard
    final StreamerCard streamerCard = StreamerCard(
      id: (widget.user['id'] ?? '').toString(),
      username: (widget.user['username'] ?? '').toString(),
      displayName: (widget.user['displayName'] ?? '').toString(),
      bio: widget.user['bio']?.toString() ?? '',
      avatarURL: widget.user['avatarURL'] as String?,
      coverImageURL: widget.user['coverImageURL'] as String?,
      platforms: _convertToPlatforms(widget.user['platforms']),
      hashtags: (widget.user['hashtags'] as List<dynamic>?)?.cast<String>() ?? [],
      socialLinks: _convertToSocialLinks(widget.user['socialLinks']),
      isConnected: false,
      onlineStatus: (widget.user['onlineStatus'] ?? 'offline').toString(),
      calendarEvents: _convertToCalendarEvents(widget.user['calendarEvents']),
      isFollowing: false,
      isFollowingYou: false,
    );
    
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => StreamerCardView(
          displayStreamer: streamerCard,
          currentUserId: widget.user['id']?.toString(),
          onDismiss: () => Navigator.of(context).pop(),
          onFollow: (streamer) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Followed ${streamer.displayName}'),
                backgroundColor: const Color(0xFF25E5D2),
              ),
            );
          },
          onMessage: (streamer) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Messaged ${streamer.displayName}'),
                backgroundColor: const Color(0xFF25E5D2),
              ),
            );
          },
          onShare: (streamer) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Shared ${streamer.displayName}\'s profile'),
                backgroundColor: const Color(0xFF25E5D2),
              ),
            );
          },
        ),
      ),
    );
  }

  void _presentMenu() {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const MenuView(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 8,
            right: 20,
            left: 20,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                onPressed: widget.onFlip,
                tooltip: 'Flip',
                icon: const Icon(
                  Icons.flip_camera_android_outlined,
                  color: Colors.white,
                ),
              ),
              IconButton(
                onPressed: _presentStreamerCard,
                tooltip: 'Streamer Card',
                icon: const Icon(
                  Icons.badge_outlined,
                  color: Colors.white,
                ),
              ),
              IconButton(
                onPressed: _presentMenu,
                tooltip: 'Menu',
                icon: const Icon(
                  Icons.menu,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Add top padding to account for status bar and app bar
            SizedBox(height: MediaQuery.of(context).padding.top + 72),
            // Profile Header
            _buildProfileHeader(),
            
            // Profile Content
            _buildProfileContent(),
            // Add bottom padding to account for bottom navigation
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.only(top: 32),
      child: Column(
        children: [
          Column(
            children: [
              _AvatarWithStatus(
                imageUrl: widget.user['avatarURL'],
                userId: widget.user['id'],
              ),
              const SizedBox(height: 16),
              Column(
                children: [
                  Text(
                    widget.user['displayName'] ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '@${widget.user['username'] ?? ''}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                ],
              ),
              const SizedBox(height: 20),
              // Hashtags removed as requested
              // _TagsRow(hashtags: List<String>.from(widget.user['hashtags'] ?? const [])),
              // const SizedBox(height: 20),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStatItem('${widget.user['postCount'] ?? 0}', 'Posts'),
              const SizedBox(width: 54),
              _buildStatItem('${widget.user['followerCount'] ?? 0}', 'Followers'),
              const SizedBox(width: 54),
              _buildStatItem('${widget.user['followingCount'] ?? 0}', 'Following'),
            ],
          ),
          const SizedBox(height: 18),
          TextButton(
            onPressed: _presentStreamerCard,
            child: const Text(
              'View Streamer Card',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(child: _pillButton('Edit Profile', () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => EditProfileView(
                        user: widget.user,
                        onUserUpdated: (updated) async {
                          if (updated['hashtags'] is String) {
                            final List<String> parsed = (updated['hashtags'] as String)
                                .split(',')
                                .map((e) => e.trim())
                                .where((e) => e.isNotEmpty)
                                .toList();
                            updated['hashtags'] = parsed;
                          }
                          setState(() {
                            widget.user.addAll(updated);
                          });
                          final String uid = _userRepository.currentUid ?? (widget.user['id'] ?? 'user_123');
                          await _userRepository.upsertUser(uid, widget.user);
                        },
                      ),
                    ),
                  );
                })),
                const SizedBox(width: 16),
                Expanded(child: _pillButton('Share Profile', () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ShareProfileView(
                        user: widget.user,
                        dismiss: () => Navigator.of(context).pop(),
                      ),
                    ),
                  );
                })),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _buildSegments(),
          const SizedBox(height: 28),
          _buildContentArea(),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _pillButton(String text, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF955CFF), Color(0xFF3D99F7)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(28),
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

  Widget _buildProfileContent() {
    return const SizedBox.shrink();
  }

  // Unused modal methods removed
}

class _AvatarWithStatus extends ConsumerWidget {
  final String? imageUrl;
  final String userId;
  
  const _AvatarWithStatus({
    required this.imageUrl,
    required this.userId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(userStatusProvider(userId));
    
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
                child: imageUrl != null && imageUrl!.isNotEmpty
                    ? Image.network(
                        imageUrl!,
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
        statusAsync.when(
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







// _TagsRow class removed as hashtags are no longer displayed
