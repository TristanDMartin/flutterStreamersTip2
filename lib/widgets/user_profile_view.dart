import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'share_profile_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/favorites_provider.dart';
import '../providers/video_service_provider.dart';
import '../providers/status_provider.dart';
import '../models/home_video.dart';
import '../models/user_status.dart';
import 'edit_profile_view.dart';
import '../repositories/user_repository.dart';
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

class _UserProfileViewState extends ConsumerState<UserProfileView> with TickerProviderStateMixin {
  final UserRepository _userRepository = UserRepository();
  int _selectedTabIndex = 0; // 0: Video, 1: Favorites, 2: Tagged
  late AnimationController _segmentedController;

  @override
  void initState() {
    super.initState();
    _segmentedController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _segmentedController.dispose();
    super.dispose();
  }

  void _onTabSelected(int index) {
    setState(() {
      _selectedTabIndex = index;
    });
    _segmentedController.forward().then((_) {
      _segmentedController.reset();
    });
  }

  Widget _buildSegments() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: const Color(0x1AFFFFFF), // 10% white (glass look)
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0x26FFFFFF), // 15% white stroke
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
      onTap: () {
        HapticFeedback.lightImpact();
        _onTabSelected(index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        height: 48,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0x14FFFFFF) : Colors.transparent, // 8% white fill
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? Border.all(
            color: const Color(0x40FFFFFF), // 25% white stroke
            width: 1,
          ) : null,
        ),
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xB3FFFFFF), // 70% white
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            child: Text(text),
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
    return const Center(
      child: Text(
        'No videos yet.',
        style: TextStyle(
          color: Color(0xBFFFFFFF), // 75% white
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
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

        // Get actual video data for favorites using FutureBuilder
        return FutureBuilder<List<HomeVideo>>(
          future: videoService.getVideosByIds(favorites),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9248d2)),
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error loading favorites: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              );
            }

            final favoriteVideos = snapshot.data ?? [];

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
    return const Center(
      child: Text(
        'No videos yet.',
        style: TextStyle(
          color: Color(0xBFFFFFFF), // 75% white
          fontSize: 20,
          fontWeight: FontWeight.w600,
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
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  widget.onFlip?.call();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: const Text(
                    'Flip',
                    style: TextStyle(
                      color: Color(0xFF40DCD1), // Accent teal
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _presentMenu();
                },
                child: const Icon(
                  Icons.more_horiz,
                  color: Colors.white,
                  size: 24,
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
    return Column(
      children: [
        // Avatar with gradient ring
        _buildAvatarWithGradientRing(),
        const SizedBox(height: 16),
        
        // Name & Handle
        _buildNameAndHandle(),
        const SizedBox(height: 20),
        
        // Stats Row
        _buildStatsRow(),
        const SizedBox(height: 18),
        
        // Primary Buttons Row
        _buildPrimaryButtonsRow(),
        const SizedBox(height: 18),
        
        // Segmented Control
        _buildSegments(),
        const SizedBox(height: 28),
        
        // Content Area
        _buildContentArea(),
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
                child: widget.user['avatarURL'] != null && widget.user['avatarURL'].toString().isNotEmpty
                    ? Image.network(
                        widget.user['avatarURL'],
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
        Consumer(
          builder: (context, ref, child) {
            final statusAsync = ref.watch(userStatusProvider(widget.user['id'] ?? ''));
            
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
          widget.user['displayName'] ?? 'Technqs',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.w900, // Heavy/Bold
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '@${widget.user['username'] ?? 'technqs'}',
          style: const TextStyle(
            color: Color(0xBFFFFFFF), // 75% white
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStatItem('${widget.user['postCount'] ?? 0}', 'Posts'),
        const SizedBox(width: 54),
        _buildStatItem('${widget.user['followerCount'] ?? 0}', 'Followers'),
        const SizedBox(width: 54),
        _buildStatItem('${widget.user['followingCount'] ?? 0}', 'Following'),
      ],
    );
  }

  Widget _buildPrimaryButtonsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _buildGradientPillButton('Edit Profile', () {
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
            }),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildGradientPillButton('Share Profile', () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ShareProfileView(
                    user: widget.user,
                    dismiss: () => Navigator.of(context).pop(),
                  ),
                ),
              );
            }),
          ),
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
            fontWeight: FontWeight.w900, // Heavy
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xB3FFFFFF), // 70% white
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildGradientPillButton(String text, VoidCallback onPressed) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onPressed();
      },
      child: Container(
        height: 48, // Visually ~44-48px content height
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF955CFF), Color(0xFF3D99F7)], // Left to Right gradient
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(24), // >24px corner radius (pill)
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

  // Unused modal methods removed
}








