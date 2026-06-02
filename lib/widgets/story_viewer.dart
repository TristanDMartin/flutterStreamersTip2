import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../models/story.dart';

class StoryViewer extends StatefulWidget {
  final Story? selectedStory;
  final VoidCallback onDismiss;

  const StoryViewer({
    super.key,
    required this.selectedStory,
    required this.onDismiss,
  });

  @override
  State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  Timer? _timer;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 50),
      vsync: this,
    );

    if (widget.selectedStory != null) {
      _startTimer(widget.selectedStory!.duration);
    }

    // Hide status bar
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  }

  @override
  void dispose() {
    _stopTimer();
    _progressController.dispose();
    // Restore status bar
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  void didUpdateWidget(StoryViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedStory != widget.selectedStory &&
        widget.selectedStory != null) {
      _startTimer(widget.selectedStory!.duration);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.selectedStory == null) {
      return const SizedBox.shrink();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onPanEnd: (details) {
          if (details.velocity.pixelsPerSecond.dx.abs() > 500) {
            widget.onDismiss();
          }
        },
        child: SafeArea(
          child: _buildMainStoryView(widget.selectedStory!),
        ),
      ),
    );
  }

  Widget _buildMainStoryView(Story story) {
    return Stack(
      children: [
        // Story content
        _buildStoryContentView(story),

        // Overlay with progress and controls
        _buildOverlayView(story),
      ],
    );
  }

  Widget _buildStoryContentView(Story story) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: Center(
        child: _buildMediaContent(story),
      ),
    );
  }

  Widget _buildMediaContent(Story story) {
    switch (story.mediaType) {
      case MediaType.image:
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: 40),
          child: Icon(
            Icons.photo_library,
            color: Colors.white,
            size: 120,
          ),
        );
      case MediaType.video:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.videocam,
              color: Colors.white,
              size: 80,
            ),
            const SizedBox(height: 16),
            Text(
              'Video Player for ${story.mediaURL}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        );
    }
  }

  Widget _buildOverlayView(Story story) {
    return Column(
      children: [
        // Progress bar
        Padding(
          padding: const EdgeInsets.only(top: 60, left: 16, right: 16),
          child: LinearProgressIndicator(
            value: _progress,
            backgroundColor: Colors.white.withValues(alpha: 0.3),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),

        // Header with creator name and close button
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 8),
          child: Row(
            children: [
              Text(
                story.creatorName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: widget.onDismiss,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 17,
                  ),
                ),
              ),
            ],
          ),
        ),

        const Spacer(),
      ],
    );
  }

  void _startTimer(double duration) {
    _stopTimer();
    _progress = 0.0;

    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (mounted) {
        setState(() {
          _progress += 0.05 / duration;
          if (_progress >= 1.0) {
            _progress = 1.0;
            widget.onDismiss();
          }
        });
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }
}
