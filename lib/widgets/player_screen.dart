import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/home_video.dart';
import '../providers/video_service_provider.dart';
import 'video_player_view_simple.dart';

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
  bool _isMuted = false;

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

  void _loadVideos() {
    if (widget.mode == PlayerMode.favorites) {
      final videoService = ref.read(videoServiceProvider);
      _videos = videoService.getVideosByIds(widget.videoIds);
    } else {
      _videos = widget.videos ?? [];
    }
  }

  void _onVideoChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _onVideoUnfavorited(String videoId) {
    // Remove from local list
    setState(() {
      _videos.removeWhere((video) => video.id == videoId);
    });

    // If we're at the end, go back
    if (_currentIndex >= _videos.length) {
      Navigator.of(context).pop();
    } else {
      // Stay on current video (which is now the next one)
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
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
              return VideoPlayerViewSimple(
                video: video,
                isMuted: _isMuted,
                isPlaying: _currentIndex == index,
                onMuteChanged: () => setState(() => _isMuted = !_isMuted),
                onVideoUnfavorited: () => _onVideoUnfavorited(video.id),
                showForYouToggle: widget.mode == PlayerMode.homeFeed,
                showDiscoverButton: widget.mode == PlayerMode.homeFeed,
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
