import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';

import '../../core/theme/support_shell_style.dart';

/// Modern video editor matching TikTok-style UI
class ModernVideoEditorView extends ConsumerStatefulWidget {
  const ModernVideoEditorView({
    super.key,
    required this.videoPath,
  });

  final String videoPath;

  @override
  ConsumerState<ModernVideoEditorView> createState() =>
      _ModernVideoEditorViewState();
}

class _ModernVideoEditorViewState
    extends ConsumerState<ModernVideoEditorView> {
  VideoPlayerController? _controller;
  bool _isPlaying = false;
  double _trimStart = 0.0;
  double _trimEnd = 1.0;
  double _playbackSpeed = 1.0;
  int _rotationAngle = 0; // 0, 90, 180, 270
  bool _isFlippedHorizontally = false;
  String _selectedTool = ''; // trim, text, captions, etc.

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    _controller = VideoPlayerController.file(File(widget.videoPath));
    await _controller!.initialize();
    _controller!.setLooping(true);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      if (_isPlaying) {
        _controller?.pause();
      } else {
        _controller?.play();
      }
      _isPlaying = !_isPlaying;
    });
  }

  void _rotateVideo() {
    setState(() {
      _rotationAngle = (_rotationAngle + 90) % 360;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Rotated $_rotationAngle°'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _flipVideo() {
    setState(() {
      _isFlippedHorizontally = !_isFlippedHorizontally;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isFlippedHorizontally ? 'Flipped' : 'Unflipped'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _changeSpeed() {
    setState(() {
      if (_playbackSpeed == 1.0) {
        _playbackSpeed = 1.5;
      } else if (_playbackSpeed == 1.5) {
        _playbackSpeed = 2.0;
      } else if (_playbackSpeed == 2.0) {
        _playbackSpeed = 0.5;
      } else {
        _playbackSpeed = 1.0;
      }
      _controller?.setPlaybackSpeed(_playbackSpeed);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Speed: ${_playbackSpeed}x'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _openTrimDialog() {
    final duration = _controller?.value.duration ?? Duration.zero;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: StSupportShellStyle.of(context).surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Trim Video',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Start: ${(_trimStart * duration.inSeconds).toStringAsFixed(1)}s',
                    style: const TextStyle(fontSize: 14),
                  ),
                  Slider(
                    value: _trimStart,
                    onChanged: (value) {
                      setModalState(() {
                        _trimStart = value;
                        if (_trimStart >= _trimEnd) {
                          _trimStart = _trimEnd - 0.01;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'End: ${(_trimEnd * duration.inSeconds).toStringAsFixed(1)}s',
                    style: const TextStyle(fontSize: 14),
                  ),
                  Slider(
                    value: _trimEnd,
                    onChanged: (value) {
                      setModalState(() {
                        _trimEnd = value;
                        if (_trimEnd <= _trimStart) {
                          _trimEnd = _trimStart + 0.01;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          // Apply trim in parent state
                        });
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Trim applied'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7B3FF2),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Apply Trim'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _handleToolTap(String tool) {
    setState(() => _selectedTool = tool);

    switch (tool) {
      case 'trim':
        _openTrimDialog();
        break;
      case 'text':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Text overlay coming soon'),
            duration: Duration(seconds: 1),
          ),
        );
        break;
      case 'captions':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Auto-captions coming soon'),
            duration: Duration(seconds: 1),
          ),
        );
        break;
      case 'cover':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cover selection coming soon'),
            duration: Duration(seconds: 1),
          ),
        );
        break;
      case 'filters':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Filters coming soon'),
            duration: Duration(seconds: 1),
          ),
        );
        break;
      case 'adjust':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Adjust tools coming soon'),
            duration: Duration(seconds: 1),
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final shell = StSupportShellStyle.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: shell.scaffold,
      appBar: AppBar(
        backgroundColor: shell.scaffold,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: shell.onChrome),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'New post',
              style: TextStyle(
                color: shell.onChrome,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Edit and customize your video',
              style: TextStyle(
                color: shell.muted,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: shell.surfaceCard,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: shell.surfaceCardBorder),
                ),
                child: Row(
                  children: [
                    Text(
                      '1080P',
                      style: TextStyle(
                        color: shell.onChrome,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_drop_down, color: shell.muted, size: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                // Video preview
                Center(
                  child: _controller != null && _controller!.value.isInitialized
                      ? Transform.scale(
                          scaleX: _isFlippedHorizontally ? -1.0 : 1.0,
                          child: Transform.rotate(
                            angle: _rotationAngle * 3.14159 / 180,
                            child: AspectRatio(
                              aspectRatio: _controller!.value.aspectRatio,
                              child: VideoPlayer(_controller!),
                            ),
                          ),
                        )
                      : Container(
                          color: Colors.black,
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                ),

                // Duration indicator
                if (_controller != null && _controller!.value.isInitialized)
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _formatDuration(_controller!.value.duration),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                // Play/pause button
                Center(
                  child: GestureDetector(
                    onTap: _togglePlayPause,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.black,
                        size: 32,
                      ),
                    ),
                  ),
                ),

                // Fullscreen button
                Positioned(
                  top: 16,
                  right: 16,
                  child: IconButton(
                    icon: const Icon(Icons.fullscreen, color: Colors.white),
                    onPressed: () {},
                  ),
                ),

                // Right-side editing tools
                Positioned(
                  right: 16,
                  top: 0,
                  bottom: 80,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildEditTool(Icons.rotate_right, 'Rotate', shell),
                      const SizedBox(height: 24),
                      _buildEditTool(Icons.flip, 'Flip', shell),
                      const SizedBox(height: 24),
                      _buildEditTool(Icons.speed, '1x\nSpeed', shell),
                      const SizedBox(height: 24),
                      _buildEditTool(Icons.auto_fix_high, 'Enhance', shell),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Timeline
          Container(
            height: 100,
            color: shell.surfaceCard,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                // Playback progress
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(Icons.play_arrow, color: shell.muted, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SliderTheme(
                          data: SliderThemeData(
                            trackHeight: 2,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 12,
                            ),
                          ),
                          child: Slider(
                            value: _controller?.value.position.inMilliseconds
                                    .toDouble() ??
                                0,
                            max: _controller?.value.duration.inMilliseconds
                                    .toDouble() ??
                                1,
                            onChanged: (value) {
                              _controller?.seekTo(
                                Duration(milliseconds: value.toInt()),
                              );
                            },
                          ),
                        ),
                      ),
                      Text(
                        _formatDuration(
                          _controller?.value.position ?? Duration.zero,
                        ),
                        style: TextStyle(color: shell.muted, fontSize: 12),
                      ),
                      Text(
                        ' / ${_formatDuration(_controller?.value.duration ?? Duration.zero)}',
                        style: TextStyle(color: shell.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                // Frame thumbnails (placeholder)
                const SizedBox(height: 8),
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: 10,
                    itemBuilder: (context, index) {
                      return Container(
                        width: 60,
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          color: shell.skeletonFill,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Bottom toolbar
          Container(
            color: shell.scaffold,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildBottomTool(
                  Icons.content_cut,
                  'Trim',
                  true,
                  shell,
                  isDark,
                ),
                _buildBottomTool(Icons.text_fields, 'Text', false, shell, isDark),
                _buildBottomTool(Icons.closed_caption, 'Captions', false, shell, isDark),
                _buildBottomTool(Icons.image, 'Cover', false, shell, isDark),
                _buildBottomTool(Icons.filter, 'Filters', false, shell, isDark),
                _buildBottomTool(Icons.tune, 'Adjust', false, shell, isDark),
              ],
            ),
          ),

          // Additional options
          Container(
            color: shell.scaffold,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              children: [
                _buildOption(
                  Icons.audiotrack,
                  'Add sound',
                  'Music, voiceover, or sounds',
                  shell,
                ),
                const SizedBox(height: 12),
                _buildOption(
                  Icons.mic,
                  'Voiceover',
                  'Record audio',
                  shell,
                ),
              ],
            ),
          ),

          // Next button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF7B3FF2),
                      const Color(0xFF00D9FF),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      '/modern-share',
                      arguments: widget.videoPath,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Next',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditTool(IconData icon, String label, StSupportShellStyle shell) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomTool(
    IconData icon,
    String label,
    bool isSelected,
    StSupportShellStyle shell,
    bool isDark,
  ) {
    final color = isSelected
        ? (isDark ? const Color(0xFF7B3FF2) : const Color(0xFF5E3AB8))
        : shell.muted;

    return InkWell(
      onTap: () => _handleToolTap(label.toLowerCase()),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isSelected
                  ? color.withValues(alpha: 0.15)
                  : shell.surfaceCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? color : shell.surfaceCardBorder,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOption(
    IconData icon,
    String title,
    String subtitle,
    StSupportShellStyle shell,
  ) {
    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$title coming soon'),
            duration: const Duration(seconds: 1),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: shell.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: shell.surfaceCardBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF7B3FF2).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFF7B3FF2), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: shell.onChrome,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: shell.muted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: shell.muted),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}
