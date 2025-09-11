import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/home_video.dart';
import '../providers/home_provider.dart' as hp;
import 'horizontal_video_feed.dart' as hv;
// import 'comments_view.dart'; // TODO: add when available

class CategoryVideoViewer extends ConsumerStatefulWidget {
  final List<HomeVideo> videos;
  final int selectedIndex;

  const CategoryVideoViewer({
    super.key,
    required this.videos,
    required this.selectedIndex,
  });

  @override
  ConsumerState<CategoryVideoViewer> createState() => _CategoryVideoViewerState();
}

class _CategoryVideoViewerState extends ConsumerState<CategoryVideoViewer> {
  late int _currentVideoIndex;
  late List<HomeVideo> _videos;

  @override
  void initState() {
    super.initState();
    _videos = List.from(widget.videos);
    _currentVideoIndex = widget.selectedIndex;
    
    // Initialize HomeViewModel with dependencies
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeHomeViewModel();
    });
  }

  void _initializeHomeViewModel() {
    // final homeViewModel = ref.read(hp.homeProvider.notifier);
    
    // Set UserManager in HomeViewModel for like persistence
    // homeViewModel.setUserManager(userManager); // method not present
    
    // Set NotificationService in HomeViewModel for notification badge
    // Note: We'll need to create a NotificationService provider
    // homeViewModel.setNotificationService(notificationService);
    
    // Set TagService in services
    // Note: We'll need to create a TagService provider
    // homeViewModel.videoService.setTagService(tagService);
  }

  void _onVideoIndexChanged(int index) {
    setState(() {
      _currentVideoIndex = index;
    });

    // Record watched category if video index is valid
    if (_videos.asMap().containsKey(index)) {
      // final video = _videos[index];
      // TODO: record watched category if needed
    }
  }

  // void _onShowProfile(HomeVideo video) {
  //   // TODO: Implement profile navigation
  //   print('Show profile for user: ${video.creator.id}');
  // }

  void _onShowComments(HomeVideo video) {
    // CommentsView not available yet
  }

  void _onShowShare(HomeVideo video) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const SizedBox.shrink(),
    );
  }

  // Future<void> _refreshVideoData(String videoId) async {
  //   // Refresh the specific video data to get updated comment count
  //   // TODO: implement when API available
  // }

  @override
  Widget build(BuildContext context) {
    final homeViewModel = ref.watch(hp.homeProvider.notifier);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Main video content
          if (_videos.isEmpty)
            const Center(
              child: Text(
                'No videos found',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                ),
              ),
            )
          else
            hv.HorizontalVideoFeed(
              videos: _videos,
              currentVideoIndex: _currentVideoIndex,
              homeViewModel: homeViewModel,
              onVideoIndexChanged: _onVideoIndexChanged,
              feedType: hv.FeedType.forYou,
              onShowProfile: (user) {},
              onShowComments: _onShowComments,
              onShowShare: _onShowShare,
              showFloatingComments: false,
            ),

          // Overlay UI - Top bar with back button only
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 20,
                left: 16,
                right: 16,
              ),
              child: Row(
                children: [
                  // Back button (top-left)
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.chevron_left,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
