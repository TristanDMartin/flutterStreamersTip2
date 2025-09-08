import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/share_service_optimized.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import '../models/home_video.dart';
import '../widgets/video_player_view_optimized.dart';
import '../providers/home_provider.dart' as hp;
import '../providers/favorites_provider.dart';
import '../providers/following_provider.dart';
import '../services/video_service.dart';
import '../services/user_service.dart';
import '../services/favorites_service.dart';
import '../services/error_handling_service.dart';
import '../services/offline_data_service.dart';
import '../services/engagement_analytics_service.dart';
import '../widgets/network_status_widget.dart';
import '../widgets/discover_view.dart';
import '../widgets/comments_view.dart';
import '../widgets/profile_view.dart';
import '../widgets/streamer_card_view_optimized.dart';
import '../models/user.dart';
import '../models/streamer_card.dart';


class HomeView extends ConsumerStatefulWidget {
  const HomeView({super.key});

  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}

enum FeedTab { forYou, following }

class _HomeViewState extends ConsumerState<HomeView> with WidgetsBindingObserver {
  
  late PageController _pageController;
  int _currentIndex = 0;

  // Feed selector (For You / Following)
  FeedTab _feedTab = FeedTab.forYou;
  bool _isFeedMenuOpen = false;

  // StreamerCard modal state
  bool _showStreamerCard = false;
  StreamerCard? _currentStreamerCard;

  // Performance state
  final Map<String, int> _videoEngagementScores = {};

  late hp.HomeViewModel _homeVM;

  // Video data from VideoService
  List<HomeVideo> _videos = [];
  bool _isLoadingVideos = true;
  String? _lastDocument;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController();
    
    // Initialize services
    ErrorHandlingService().initialize();
    OfflineDataService();
    EngagementAnalyticsService().initialize();
    
    // Build lightweight HomeViewModel for actions
    _homeVM = hp.HomeViewModel(
      videoService: VideoService(),
      userService: UserService(),
      favoritesService: FavoritesService(),
    );

    // Setup favorites manager and load videos
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupFavoritesManager();
      _loadVideos();
    });
  }

  /// Setup favorites manager - equivalent to Swift's .onAppear
  void _setupFavoritesManager() {
    // The favorites service is automatically initialized via Riverpod
    // This is equivalent to: viewModel.setFavoritesManager(favoritesManager)
    final favoritesNotifier = ref.read(favoritesProvider.notifier);
    
    // Force sync with Firebase when HomeView appears
    favoritesNotifier.forceSync();
    
    print('🏠 HomeView: Favorites manager setup complete');
  }

  /// Load videos from VideoService based on current feed tab
  Future<void> _loadVideos() async {
    try {
      setState(() {
        _isLoadingVideos = true;
      });

      final videoService = VideoService();
      VideoFetchResult result;

      // Try to load videos with error handling and retry
      final retryResult = await ErrorHandlingService().retryOperation(() async {
        if (_feedTab == FeedTab.forYou) {
          // Load For You feed (algorithmic recommendations)
          return await videoService.fetchForYouVideos(
            pageSize: 20,
            lastDocument: _lastDocument,
          );
        } else {
          // Load Following feed (videos from followed users)
          final followingState = ref.read(followingProvider);
          return await videoService.fetchFollowingVideos(
            followingIds: followingState.followingList,
            pageSize: 20,
            lastDocument: _lastDocument,
          );
        }
      }, operationId: 'load_videos_${_feedTab.name}');

      if (retryResult != null) {
        result = retryResult;
        setState(() {
          _videos = result.videos;
          _lastDocument = result.lastDocument;
          _isLoadingVideos = false;
        });

        // Save videos for offline access
        await OfflineDataService().saveVideosOffline(result.videos);

        // Videos will be handled by VideoPlayerView
      } else {
        // If network request failed, try to load from offline storage
        await _loadVideosOffline();
      }
    } catch (e) {
      final error = ErrorHandlingService().handleError(e, context: 'load_videos');
      debugPrint('Error loading videos: ${error.message}');
      
      // Try to load from offline storage
      await _loadVideosOffline();
    }
  }

  /// Load videos from offline storage
  Future<void> _loadVideosOffline() async {
    try {
      final offlineVideos = await OfflineDataService().loadVideosOffline();
      if (offlineVideos.isNotEmpty) {
        setState(() {
          _videos = offlineVideos;
          _isLoadingVideos = false;
        });
        
        // Show offline mode indicator
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Showing offline content'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        setState(() {
          _isLoadingVideos = false;
        });
        
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to load videos. Please check your connection.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoadingVideos = false;
      });
      debugPrint('Error loading offline videos: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // VideoPlayerView handles lifecycle management
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    
    // Clear performance data
    _videoEngagementScores.clear();
    
    super.dispose();
  }




  void _openComments(String videoId) {
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return CommentsView(videoId: videoId);
      },
    );
  }





  Widget _buildFeedDropdown() {
    final BorderRadius radius = BorderRadius.circular(20);
    final Color tileColor = const Color(0xFF1A1A1A).withValues(alpha: 0.95);

    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: radius,
        border: Border.all(
          color: const Color(0xFF9248D2).withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _feedMenuItem(
            title: 'For You',
            isSelected: _feedTab == FeedTab.forYou,
            onTap: () {
              setState(() {
                _feedTab = FeedTab.forYou;
                _isFeedMenuOpen = false;
              });
              _loadVideos();
            },
          ),
          Container(
            height: 1,
            color: Colors.grey.withValues(alpha: 0.2),
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
          _feedMenuItem(
            title: 'Following',
            isSelected: _feedTab == FeedTab.following,
            onTap: () {
              setState(() {
                _feedTab = FeedTab.following;
                _isFeedMenuOpen = false;
              });
              _loadVideos();
            },
          ),
        ],
      ),
    );
  }

  Widget _feedMenuItem({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected 
            ? const Color(0xFF9248D2).withValues(alpha: 0.1)
            : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(
              title == 'For You' ? Icons.explore : Icons.people,
              color: isSelected 
                ? const Color(0xFF9248D2)
                : Colors.white.withValues(alpha: 0.7),
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                color: isSelected 
                  ? const Color(0xFF9248D2)
                  : Colors.white,
                fontSize: 16,
                fontWeight: isSelected 
                  ? FontWeight.w600
                  : FontWeight.w500,
              ),
            ),
            const Spacer(),
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Color(0xFF9248D2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showProfile(User user) {
    HapticFeedback.lightImpact();
    // Navigate to user profile
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileView(
          user: user,
          isCurrentUser: false,
        ),
      ),
    );
  }

  void _shareVideo(HomeVideo video) {
    HapticFeedback.lightImpact();
    ShareServiceOptimized().shareVideo(video);
  }

  void _showStreamerCardModal(User user) {
    HapticFeedback.lightImpact();
    
    // Convert User to StreamerCard
    final streamerCard = StreamerCard(
      id: user.id,
      displayName: user.displayName,
      username: user.username,
      avatarURL: user.avatarURL,
      bio: user.bio ?? '',
      hashtags: user.hashtags,
    );
    
    setState(() {
      _currentStreamerCard = streamerCard;
      _showStreamerCard = true;
    });
  }

  void _dismissStreamerCard() {
    setState(() {
      _showStreamerCard = false;
      _currentStreamerCard = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return NetworkStatusWidget(
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            if (_isLoadingVideos)
              const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9248D2)),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Loading videos...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              )
            else if (_videos.isEmpty)
              const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.video_library_outlined,
                      size: 80,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No videos available',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Pull to refresh or check your connection',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              )
            else
              PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical, // Changed to vertical for TikTok-style feed
                itemCount: _videos.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                itemBuilder: (context, index) {
                  final video = _videos[index];
                  return VideoPlayerViewOptimized(
                    key: ValueKey(video.id),
                    video: video,
                    isCurrentVideo: index == _currentIndex,
                    isFirstVideo: index == 0,
                    homeViewModel: _homeVM,
                    showSheet: false,
                    sheetType: '',
                    onShowProfile: () => _showProfile(video.creator),
                    onShowComments: () => _openComments(video.id),
                    onShowShare: () => _shareVideo(video),
                    onShowStreamerCard: () => _showStreamerCardModal(video.creator),
                  );
                },
              ),
          
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildHeader(),
          ),
          if (_isFeedMenuOpen)
            Positioned(
              left: 40,
              top: MediaQuery.of(context).padding.top + 56,
              child: _buildFeedDropdown(),
            ),
          
          // StreamerCard full-screen modal
          if (_showStreamerCard && _currentStreamerCard != null)
            Positioned.fill(
              child: StreamerCardViewOptimized(
                displayStreamer: _currentStreamerCard!,
                currentUserId: firebase_auth.FirebaseAuth.instance.currentUser?.uid,
                onDismiss: _dismissStreamerCard,
              ),
            ),
        ],
      ),
    ),
  );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.8),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          // Feed menu button
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() {
                _isFeedMenuOpen = !_isFeedMenuOpen;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: _feedTab == FeedTab.forYou 
                    ? const Color(0xFF9248D2) 
                    : Colors.white.withValues(alpha: 0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _feedTab == FeedTab.forYou ? 'For You' : 'Following',
                    style: TextStyle(
                      color: _feedTab == FeedTab.forYou 
                        ? const Color(0xFF9248D2) 
                        : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _isFeedMenuOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: _feedTab == FeedTab.forYou 
                      ? const Color(0xFF9248D2) 
                      : Colors.white,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          // Discover button
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DiscoverView()),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.explore_outlined, 
                color: Colors.white, 
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
