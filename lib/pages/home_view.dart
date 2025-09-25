import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../services/share_service_optimized.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import '../models/home_video.dart';
import '../widgets/video_player_view_optimized.dart';
import '../providers/home_provider.dart' as hp;
import '../providers/favorites_provider.dart';
import '../providers/following_provider.dart';
import '../services/error_handling_service.dart';
import '../widgets/instant_response_button.dart';
import '../services/offline_data_service.dart';
import '../services/engagement_analytics_service.dart';
import '../services/video_performance_service.dart';
import '../widgets/network_status_widget.dart';
import '../widgets/discover_view.dart';
import '../widgets/comments_view_optimized.dart';
import '../widgets/streamer_card_view.dart';
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

  // Video data is now managed by Riverpod provider

  @override
  void initState() {
    super.initState();
    log('🏠 HomeView: initState() called');
    debugPrint('🏠 HomeView: initState() called');
    
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController();
    
    // Initialize services
    ErrorHandlingService().initialize();
    OfflineDataService();
    EngagementAnalyticsService().initialize();

    // Setup favorites manager and load videos
    WidgetsBinding.instance.addPostFrameCallback((_) {
      log('📋 HomeView: addPostFrameCallback executing');
      debugPrint('📋 HomeView: addPostFrameCallback executing');
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
    
    // Favorites manager setup complete
  }

  /// Load videos from VideoService based on current feed tab
  Future<void> _loadVideos() async {
    try {
      log('🚀 HomeView: _loadVideos() called');
      debugPrint('🚀 HomeView: _loadVideos() called');
      
      final homeVM = ref.read(hp.homeProvider.notifier);
      log('📱 HomeView: Got homeVM notifier');
      debugPrint('📱 HomeView: Got homeVM notifier');
      
      // Use the new instant play loadVideos method
      await homeVM.loadVideos();
      
      // Prewarm the first video for instant play (TikTok style)
      await _prewarmFirstVideo();
      
      log('✅ HomeView: Videos loaded successfully');
      debugPrint('✅ HomeView: Videos loaded successfully');
    } catch (e) {
      log('❌ HomeView: Error in _loadVideos: $e');
      debugPrint('❌ HomeView: Error in _loadVideos: $e');
      final error = ErrorHandlingService().handleError(e, context: 'load_videos');
      debugPrint('❌ HomeView: Error loading videos: ${error.message}');
    }
  }

  /// Prewarm the first video for instant play (TikTok style)
  Future<void> _prewarmFirstVideo() async {
    try {
      final homeState = ref.read(hp.homeProvider);
      final videos = _feedTab == FeedTab.forYou ? homeState.forYouVideos : homeState.followingVideos;
      
      if (videos.isNotEmpty) {
        final firstVideo = videos.first;
        log('🔥 Prewarming first video: ${firstVideo.id}');
        debugPrint('🔥 Prewarming first video: ${firstVideo.id}');
        
        // Prewarm the first video controller
        await VideoPerformanceService().prewarm(firstVideo.id, firstVideo.videoURL);
        
        log('✅ First video prewarmed successfully');
        debugPrint('✅ First video prewarmed successfully');
      }
    } catch (e) {
      log('❌ Error prewarming first video: $e');
      debugPrint('❌ Error prewarming first video: $e');
    }
  }


  // @override
  // void didChangeAppLifecycleState(AppLifecycleState state) {
  //   super.didChangeAppLifecycleState(state);
  //   // VideoPlayerView handles lifecycle management
  // }

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
        return CommentsViewOptimized(videoId: videoId);
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
              if (mounted) {
                setState(() {
                  _feedTab = FeedTab.forYou;
                  _isFeedMenuOpen = false;
                });
              }
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
              if (mounted) {
                setState(() {
                  _feedTab = FeedTab.following;
                  _isFeedMenuOpen = false;
                });
              }
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
    
    if (mounted) {
      setState(() {
        _currentStreamerCard = streamerCard;
        _showStreamerCard = true;
      });
    }
  }

  void _dismissStreamerCard() {
    if (mounted) {
      setState(() {
        _showStreamerCard = false;
        _currentStreamerCard = null;
      });
    }
  }

  Widget _buildVideoContent(hp.HomeState homeState) {
    // Use videos from the provider based on current feed tab
    final videos = _feedTab == FeedTab.forYou ? homeState.forYouVideos : homeState.followingVideos;
    final isLoading = _feedTab == FeedTab.forYou ? homeState.isLoading : homeState.isLoading;
    
    // Show loading state if we're loading OR if videos are empty but we haven't loaded yet
    final shouldShowLoading = isLoading || (!homeState.hasLoaded && videos.isEmpty);
    
    if (shouldShowLoading) {
      return const Center(
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
      );
    } else if (videos.isEmpty) {
      // Only show "No videos available" if we've actually loaded but found no videos
      return const Center(
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
      );
    } else {
        return SizedBox.expand(
          child: PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical, // TikTok-style vertical scrolling
            itemCount: videos.length,
            onPageChanged: (index) {
              if (mounted) {
                setState(() {
                  _currentIndex = index;
                });
              }
            },
            itemBuilder: (context, index) {
              final video = videos[index];
              final homeVM = ref.read(hp.homeProvider.notifier);
              return VideoPlayerViewOptimized(
                key: ValueKey(video.id),
                video: video,
                isCurrentVideo: index == _currentIndex,
                isFirstVideo: index == 0,
                homeViewModel: homeVM,
                showSheet: false,
                sheetType: '',
                onShowProfile: () => _showStreamerCardModal(video.creator),
                onShowComments: () => _openComments(video.id),
                onShowShare: () => _shareVideo(video),
                onShowStreamerCard: () => _showStreamerCardModal(video.creator),
                isLiked: video.isLiked,
                isBookmarked: video.isFavorited, // cSpell:ignore Favorited
              );
            },
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final homeState = ref.watch(hp.homeProvider);
    
    return NetworkStatusWidget(
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBody: true, // This allows content to extend behind the bottom navigation
        body: MediaQuery.removePadding(
          context: context,
          removeTop: true, // Remove top padding to extend behind status bar
          removeBottom: true, // Remove bottom padding to extend behind bottom nav
          child: SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: Stack(
              children: [
                // Main content - Full screen video that extends behind everything
                Positioned.fill(
                  child: SizedBox(
                    width: double.infinity,
                    height: double.infinity,
                    child: _buildVideoContent(homeState),
                  ),
                ),
          
                // Header overlay - positioned with proper status bar padding
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _buildHeader(),
                ),
            
                // Feed dropdown
                if (_isFeedMenuOpen)
                  Positioned(
                    left: 40,
                    top: MediaQuery.of(context).padding.top + 56,
                    child: _buildFeedDropdown(),
                  ),
                
                // StreamerCard full-screen modal
                if (_showStreamerCard && _currentStreamerCard != null)
                  Positioned.fill(
                    child: SafeArea(
                      child: StreamerCardView(
                        userId: _currentStreamerCard!.id,
                        currentUserId: firebase_auth.FirebaseAuth.instance.currentUser?.uid,
                        onDismiss: _dismissStreamerCard,
                      onFollow: (userId) async {
                        // Handle follow action
                        HapticFeedback.lightImpact();
                        if (kDebugMode) {
                          print('HomeView: Follow action triggered for user: $userId');
                        }
                        
                        // Capture context before async operations
                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        
                        try {
                          // Get the following provider
                          final followingNotifier = ref.read(followingProvider.notifier);
                          
                          // Check if already following
                          final isCurrentlyFollowing = followingNotifier.isFollowing(userId);
                          
                          if (isCurrentlyFollowing) {
                            // Unfollow the user
                            final success = await followingNotifier.unfollowUser(userId);
                            if (success) {
                              if (mounted) {
                                scaffoldMessenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Unfollowed user'),
                                    backgroundColor: Colors.orange,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            } else {
                              if (mounted) {
                                scaffoldMessenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Failed to unfollow user'),
                                    backgroundColor: Colors.red,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            }
                          } else {
                            // Follow the user
                            final success = await followingNotifier.followUser(userId);
                            if (success) {
                              if (mounted) {
                                scaffoldMessenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Following user'),
                                    backgroundColor: Colors.green,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            } else {
                              if (mounted) {
                                scaffoldMessenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Failed to follow user'),
                                    backgroundColor: Colors.red,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            }
                          }
                        } catch (e) {
                          if (kDebugMode) {
                            print('HomeView: Error in follow action: $e');
                          }
                          if (mounted) {
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text('Error: ${e.toString()}'),
                                backgroundColor: Colors.red,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        }
                      },
                      onMessage: (userId) {
                        // Handle message action
                        HapticFeedback.lightImpact();
                        if (kDebugMode) {
                          print('HomeView: Message action triggered for user: $userId');
                        }
                        
                        // Show a dialog for messaging functionality
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Message User'),
                            content: Text('Messaging functionality will be implemented here for user: $userId'),
                            actions: [
                              InstantTextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                hapticType: HapticFeedbackType.lightImpact,
                                child: const Text('Close'),
                              ),
                              InstantTextButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  // Navigate to chat/messaging screen
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Messaging feature coming soon!'),
                                      backgroundColor: Colors.blue,
                                    ),
                                  );
                                },
                                child: const Text('Open Chat'),
                              ),
                            ],
                          ),
                        );
                      },
                      onShare: (userId) async {
                        // Handle share action
                        HapticFeedback.lightImpact();
                        if (kDebugMode) {
                          print('HomeView: Share action triggered for user: $userId');
                        }
                        
                        // Capture context before async operations
                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        
                        try {
                          // Get user information for sharing
                          final currentStreamer = _currentStreamerCard;
                          if (currentStreamer == null) {
                            if (mounted) {
                              scaffoldMessenger.showSnackBar(
                                const SnackBar(
                                  content: Text('User information not available'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                            return;
                          }
                          
                          // Generate share content for user profile
                          final shareText = 'Check out @${currentStreamer.username} on StreamersTip!\n\n'
                              '${currentStreamer.displayName}\n\n'
                              'Follow them for amazing content!\n\n'
                              '#StreamersTip #${currentStreamer.username}';
                          
                          final shareUrl = 'https://streamerstip.com/user/${currentStreamer.username}';
                          
                          // Use system share sheet
                          await SharePlus.instance.share(
                            ShareParams(
                              text: '$shareText\n\n$shareUrl',
                            ),
                          );
                          
                          if (mounted) {
                            scaffoldMessenger.showSnackBar(
                              const SnackBar(
                                content: Text('User profile shared successfully!'),
                                backgroundColor: Colors.green,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        } catch (e) {
                          if (kDebugMode) {
                            print('HomeView: Error sharing user profile: $e');
                          }
                          if (mounted) {
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text('Failed to share user profile: ${e.toString()}'),
                                backgroundColor: Colors.red,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ),
                  ),
              ],
            ),
          ),
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
              if (mounted) {
                setState(() {
                  _isFeedMenuOpen = !_isFeedMenuOpen;
                });
              }
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
          const SizedBox(width: 16),
          // Discover button - bare icon with soft shadow
          InkResponse(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DiscoverView()),
              );
            },
            radius: 24, // keeps 44x44 tap target
            child: Container(
              padding: const EdgeInsets.all(8), // transparent padding for hit area
              child: Icon(
                Icons.explore_outlined, 
                color: Colors.white, 
                size: 28, // 28-32pt as specified
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
