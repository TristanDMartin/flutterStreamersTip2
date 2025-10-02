import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/home_video.dart';
import '../providers/home_provider.dart' as hp;
import '../providers/video_service_provider.dart';
import 'video_player_view_optimized.dart';

enum PlayerMode {
  homeFeed,
  favorites,
}

class PlayerScreen extends ConsumerStatefulWidget {
  final PlayerMode mode;
  final int initialIndex;
  final List<String> videoIds;
  final List<HomeVideo>? videos; // For home feed mode

  const PlayerScreen({
    super.key,
    required this.mode,
    required this.initialIndex,
    required this.videoIds,
    this.videos,
  });

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  late PageController _pageController;
  late List<HomeVideo> _videos;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _loadVideos();
  }

  @override
  void dispose() {
    _pageController.dispose();
    // Video controllers are disposed by their respective VideoPlayerViewSimple widgets
    super.dispose();
  }

  Future<void> _loadVideos() async {
    if (widget.mode == PlayerMode.favorites) {
      final videoService = ref.read(videoServiceProvider);
      _videos = await videoService.getVideosByIds(widget.videoIds);
    } else {
      _videos = widget.videos ?? [];
    }
  }

  void _onVideoChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_videos.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: const Center(
          child: Text(
            'No videos available',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video player
          PageView.builder(
            controller: _pageController,
            onPageChanged: _onVideoChanged,
            itemCount: _videos.length,
            itemBuilder: (context, index) {
              final video = _videos[index];
              return VideoPlayerViewOptimized(
                video: video,
                isCurrentVideo: _currentIndex == index,
                isFirstVideo: index == 0,
                tabId: 'playerScreen', // Generic tab ID for standalone player
                homeViewModel: ref.read(hp.homeProvider.notifier),
                showSheet: false,
                sheetType: '',
                onShowProfile: () {},
                onShowComments: () {},
                onShowShare: () {},
                onShowStreamerCard: () {},
                isLiked: false,
                isBookmarked: false,
              );
            },
          ),
          // Top bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                if (widget.mode == PlayerMode.favorites)
                  IconButton(
                    onPressed: () {
                      // TODO: Implement share functionality
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Share functionality coming soon'),
                          backgroundColor: Color(0xFF9248d2),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.share,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
