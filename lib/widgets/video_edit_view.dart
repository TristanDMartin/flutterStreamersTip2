import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:async';
import 'video_publishing_screen.dart';
import 'video_editor_player.dart';
import 'video_timeline.dart';
import 'text_overlay_editor.dart';
import 'visual_effects_editor.dart';
import 'audio_editor.dart';
import 'advanced_video_editor.dart';
import '../services/video_processing_service.dart';
import '../services/logging_service.dart';

class VideoEditView extends StatefulWidget {
  final File videoFile;
  final VoidCallback? onCancel;
  final VoidCallback? onNext;

  const VideoEditView({
    super.key,
    required this.videoFile,
    this.onCancel,
    this.onNext,
  });

  @override
  State<VideoEditView> createState() => _VideoEditViewState();
}

class _VideoEditViewState extends State<VideoEditView>
    with TickerProviderStateMixin {
  int _selectedTabIndex = 0;
  late AnimationController _tabAnimationController;
  late AnimationController _progressController;

  // Video state
  Duration _videoDuration = Duration.zero;
  Duration _currentPosition = Duration.zero;
  Duration _startTime = Duration.zero;
  Duration _endTime = Duration.zero;
  bool _isPlaying = false;
  bool _isDragging = false;
  bool _isProcessing = false;
  double _processingProgress = 0.0;
  String? _processingStatus;

  // Edit state
  VideoEditState? _editState;
  final List<VideoEditAction> _editHistory = [];
  int _historyIndex = -1;
  bool _hasUnsavedChanges = false;

  // Services
  final VideoProcessingService _videoService = VideoProcessingService();
  final String _videoId = DateTime.now().millisecondsSinceEpoch.toString();

  // Tab options
  final List<String> _tabs = ['Trim', 'Audio', 'Effects', 'Text', 'Advanced'];

  @override
  void initState() {
    super.initState();
    _tabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _initializeVideo();
  }

  @override
  void dispose() {
    _tabAnimationController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  Future<void> _initializeVideo() async {
    try {
      _videoDuration = await _videoService.getVideoDuration(widget.videoFile);
      _endTime = _videoDuration;
      
      _editState = VideoEditState(
        videoId: _videoId,
        originalFile: widget.videoFile,
        startTime: _startTime,
        endTime: _endTime,
        audioEffects: AudioEffects(),
        visualEffects: [],
        textOverlays: [],
      );
      
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      LoggingService.instance.error('Error initializing video', tag: 'VideoEditView', error: e);
    }
  }

  void _navigateToPublishing() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VideoPublishingScreen(
          videoFile: widget.videoFile,
          caption: '', // Start with empty caption
          hashtags: const [], // Start with empty hashtags
          onPublish: () {
            // Handle successful publishing
            widget.onNext?.call();
            Navigator.of(context).pop(); // Go back to camera
          },
          onCancel: () {
            Navigator.of(context).pop(); // Go back to video editing
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6137EB), Color(0xFF1C135D)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top Navigation Bar
              _buildTopBar(),
              
              // Video Player Area
              Expanded(
                flex: 3,
                child: _buildVideoPlayer(),
              ),
              
              // Timeline
              if (_videoDuration > Duration.zero)
                VideoTimeline(
                  duration: _videoDuration,
                  position: _currentPosition,
                  startTime: _startTime,
                  endTime: _endTime,
                  onTrimChanged: (startTime, endTime) {
                    setState(() {
                      _startTime = startTime;
                      _endTime = endTime;
                      _hasUnsavedChanges = true;
                    });
                  },
                  onSeekTo: (position) {
                    // Seek functionality handled by VideoEditorPlayer
                  },
                  isDragging: _isDragging,
                  onDraggingChanged: (isDragging) {
                    setState(() {
                      _isDragging = isDragging;
                    });
                  },
              ),
              
              // Editing Tabs
              _buildEditingTabs(),
              
              // Content Area
              Expanded(
                flex: 2,
                child: SingleChildScrollView(
                child: _buildContentArea(),
                ),
              ),
              
              // Bottom Action Buttons
              _buildBottomActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Back Button
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onCancel?.call();
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha:0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha:0.2),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          
          const Spacer(),
          
          // Title
          const Text(
            'Edit Video',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const Spacer(),
          
          // Preview Button
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              // TODO: Implement preview functionality
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF9248D2), Color(0xFF4897D2)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Preview',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: VideoEditorPlayer(
        videoFile: widget.videoFile,
        startTime: _startTime,
        endTime: _endTime,
        isPlaying: _isPlaying,
        onPositionChanged: (position) {
          setState(() {
            _currentPosition = position;
          });
        },
        onPlayPauseChanged: (isPlaying) {
          setState(() {
            _isPlaying = isPlaying;
          });
        },
        onTrimChanged: (startTime, endTime) {
          setState(() {
            _startTime = startTime;
            _endTime = endTime;
            _hasUnsavedChanges = true;
          });
          _addEditAction(VideoEditAction(
            type: 'trim',
            data: {
              'startTime': startTime.inMilliseconds,
              'endTime': endTime.inMilliseconds,
            },
            timestamp: DateTime.now(),
          ));
        },
      ),
    );
  }

  Widget _buildEditingTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: _tabs.asMap().entries.map((entry) {
          final index = entry.key;
          final tab = entry.value;
          final isSelected = index == _selectedTabIndex;
          
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() {
                  _selectedTabIndex = index;
                });
                _tabAnimationController.forward().then((_) {
                  _tabAnimationController.reset();
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: isSelected 
                      ? const LinearGradient(
                          colors: [Color(0xFF9248D2), Color(0xFF4897D2)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        )
                      : null,
                  color: isSelected 
                      ? null
                      : Colors.white.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected 
                        ? Colors.transparent
                        : Colors.white.withValues(alpha:0.2),
                    width: 1,
                  ),
                  boxShadow: isSelected ? [
                    BoxShadow(
                      color: const Color(0xFF9248D2).withValues(alpha:0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ] : null,
                ),
                child: Text(
                  tab,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white.withValues(alpha:0.7),
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                    letterSpacing: isSelected ? 0.5 : 0.0,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildContentArea() {
    switch (_selectedTabIndex) {
      case 0:
        return _buildTrimContent();
      case 1:
        return _buildAudioContent();
      case 2:
        return _buildEffectsContent();
      case 3:
        return _buildTextContent();
      case 4:
        return _buildAdvancedContent();
      default:
        return _buildTrimContent();
    }
  }

  Widget _buildTrimContent() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
        children: [
          const Text(
            'Trim Video',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
              const Spacer(),
              // Undo/Redo buttons
              if (_historyIndex > 0)
                IconButton(
                  onPressed: _undo,
                  icon: const Icon(Icons.undo, color: Colors.white),
                ),
              if (_historyIndex < _editHistory.length - 1)
                IconButton(
                  onPressed: _redo,
                  icon: const Icon(Icons.redo, color: Colors.white),
                ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Time Display
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Start: ${_formatDuration(_startTime)}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
              Text(
                'Duration: ${_formatDuration(_endTime - _startTime)}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
              Text(
                'End: ${_formatDuration(_endTime)}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                  ),
                ),
              ],
          ),
          
          const SizedBox(height: 16),
          
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _resetTrim,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: const Text(
                      'Reset',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: _applyTrim,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF9248D2), Color(0xFF4897D2)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                      'Apply Trim',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          if (_isProcessing) ...[
          const SizedBox(height: 16),
            LinearProgressIndicator(
              value: _processingProgress,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF9248D2)),
            ),
            const SizedBox(height: 8),
          Text(
              _processingStatus ?? 'Processing...',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
          ],
        ],
      ),
    );
  }

  Widget _buildAudioContent() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
            'Audio Settings',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
              const Spacer(),
              GestureDetector(
                onTap: _openAudioEditor,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF9248D2), Color(0xFF4897D2)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'Advanced',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Quick Audio Controls
          _buildQuickAudioControls(),
          
          const SizedBox(height: 16),
          
          // Audio Tracks Preview
          _buildAudioTracksPreview(),
        ],
      ),
    );
  }

  Widget _buildQuickAudioControls() {
    return Column(
      children: [
        // Volume Control
        Row(
          children: [
            const Icon(Icons.volume_up, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Slider(
                value: _editState?.audioEffects.volume ?? 1.0,
                min: 0.0,
                max: 2.0,
                activeColor: const Color(0xFF9248D2),
                inactiveColor: Colors.white.withValues(alpha: 0.3),
                onChanged: (value) {
                  setState(() {
                    _editState = _editState?.copyWith(
                      audioEffects: AudioEffects(
                        volume: value,
                        isMuted: _editState?.audioEffects.isMuted ?? false,
                        fadeIn: _editState?.audioEffects.fadeIn ?? 0.0,
                        fadeOut: _editState?.audioEffects.fadeOut ?? 0.0,
                        audioTrack: _editState?.audioEffects.audioTrack,
                      ),
                    );
                    _hasUnsavedChanges = true;
                  });
                },
              ),
            ),
          Text(
              '${((_editState?.audioEffects.volume ?? 1.0) * 100).round()}%',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
        ),
        
        const SizedBox(height: 12),
        
        // Mute Toggle
        Row(
          children: [
            const Icon(Icons.volume_off, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            const Text(
              'Mute Audio',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            const Spacer(),
            Switch(
              value: _editState?.audioEffects.isMuted ?? false,
              activeColor: const Color(0xFF9248D2),
              onChanged: (value) {
                setState(() {
                  _editState = _editState?.copyWith(
                    audioEffects: AudioEffects(
                      volume: _editState?.audioEffects.volume ?? 1.0,
                      isMuted: value,
                      fadeIn: _editState?.audioEffects.fadeIn ?? 0.0,
                      fadeOut: _editState?.audioEffects.fadeOut ?? 0.0,
                      audioTrack: _editState?.audioEffects.audioTrack,
                    ),
                  );
                  _hasUnsavedChanges = true;
                });
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAudioTracksPreview() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Audio Tracks',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Original Audio',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          if (_editState?.audioEffects.audioTrack != null)
            Text(
              _editState!.audioEffects.audioTrack!,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildEffectsContent() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
            'Visual Effects',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
              const Spacer(),
              GestureDetector(
                onTap: _openVisualEffectsEditor,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF9248D2), Color(0xFF4897D2)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'Advanced',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Quick Effects Grid
          _buildQuickEffectsGrid(),
          
          const SizedBox(height: 8),
          
          // Applied Effects Preview
          _buildAppliedEffectsPreview(),
        ],
      ),
    );
  }

  Widget _buildQuickEffectsGrid() {
    final effects = [
      {'name': 'None', 'icon': Icons.remove},
      {'name': 'Vintage', 'icon': Icons.filter_vintage},
      {'name': 'B&W', 'icon': Icons.filter_b_and_w},
      {'name': 'Sepia', 'icon': Icons.filter_tilt_shift},
      {'name': 'Bright', 'icon': Icons.brightness_6},
      {'name': 'Contrast', 'icon': Icons.contrast},
    ];

    return SizedBox(
      height: 100, // Reduced height
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
          childAspectRatio: 1.1, // Slightly taller
        ),
        itemCount: effects.length,
        itemBuilder: (context, index) {
          final effect = effects[index];
          final isSelected = _editState?.visualEffects.any((e) => e.type == effect['name']) ?? false;
          
          return GestureDetector(
            onTap: () => _selectEffect(effect['name'] as String),
            child: Container(
              decoration: BoxDecoration(
                color: isSelected 
                    ? const Color(0xFF9248D2).withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected 
                      ? const Color(0xFF9248D2)
                      : Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    effect['icon'] as IconData,
                    color: isSelected ? const Color(0xFF9248D2) : Colors.white,
                    size: 18,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    effect['name'] as String,
                    style: TextStyle(
                      color: isSelected ? const Color(0xFF9248D2) : Colors.white,
                      fontSize: 9,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAppliedEffectsPreview() {
    if (_editState?.visualEffects.isEmpty ?? true) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: const Text(
          'No effects applied',
          style: TextStyle(color: Colors.white70, fontSize: 10),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Applied Effects',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          ..._editState!.visualEffects.map((effect) => Text(
            '• ${effect.type}',
            style: const TextStyle(color: Colors.white70, fontSize: 9),
          )),
        ],
      ),
    );
  }

  Widget _buildTextContent() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Text Overlays',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
              const Spacer(),
              GestureDetector(
                onTap: _openTextOverlayEditor,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF9248D2), Color(0xFF4897D2)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'Advanced',
            style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Quick Add Text
          _buildQuickTextInput(),
          
          const SizedBox(height: 16),
          
          // Text Overlays Preview
          _buildTextOverlaysPreview(),
        ],
      ),
    );
  }

  Widget _buildQuickTextInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Add Text',
          style: TextStyle(
            color: Colors.white,
              fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter text to overlay...',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF9248D2)),
            ),
          ),
          onChanged: (value) {
            setState(() {
              _hasUnsavedChanges = true;
            });
          },
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _addTextOverlay,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF9248D2), Color(0xFF4897D2)],
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'Add Text Overlay',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            ),
          ),
        ],
    );
  }

  Widget _buildTextOverlaysPreview() {
    if (_editState?.textOverlays.isEmpty ?? true) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: const Text(
          'No text overlays added',
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Text Overlays',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ..._editState!.textOverlays.map((overlay) => Text(
            '• "${overlay.text}" (${overlay.fontSize.round()}px)',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          )),
        ],
      ),
    );
  }

  Widget _buildAdvancedContent() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Advanced Video Features',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Advanced features grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
            ),
            itemCount: _advancedFeatures.length,
            itemBuilder: (context, index) {
              final feature = _advancedFeatures[index];
              return GestureDetector(
                onTap: feature['onTap'] as VoidCallback,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        feature['icon'] as IconData,
                        color: const Color(0xFF9248D2),
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        feature['title'] as String,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        feature['description'] as String,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> get _advancedFeatures => [
    {
      'title': 'Speed Control',
      'description': 'Slow motion & fast forward',
      'icon': Icons.speed,
      'onTap': _openAdvancedVideoEditor,
    },
    {
      'title': 'Rotation',
      'description': 'Rotate & flip video',
      'icon': Icons.rotate_right,
      'onTap': _openAdvancedVideoEditor,
    },
    {
      'title': 'Crop & Resize',
      'description': 'Crop to different ratios',
      'icon': Icons.crop,
      'onTap': _openAdvancedVideoEditor,
    },
    {
      'title': 'Quality',
      'description': 'Adjust video quality',
      'icon': Icons.high_quality,
      'onTap': _openAdvancedVideoEditor,
    },
  ];


  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Cancel Button
          Expanded(
            child: GestureDetector(
              onTap: _showDiscardDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: const Text(
                  'Cancel',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Save Draft Button
          if (_hasUnsavedChanges)
            Expanded(
              child: GestureDetector(
                onTap: _saveDraft,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: const Text(
                    'Save Draft',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          
          if (_hasUnsavedChanges) const SizedBox(width: 12),
          
          // Next Button
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                _navigateToPublishing();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF9248D2), Color(0xFF4897D2)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Next',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  void _addEditAction(VideoEditAction action) {
    // Remove any actions after current index (for redo functionality)
    if (_historyIndex < _editHistory.length - 1) {
      _editHistory.removeRange(_historyIndex + 1, _editHistory.length);
    }
    
    _editHistory.add(action);
    _historyIndex = _editHistory.length - 1;
    
    // Limit history size
    if (_editHistory.length > 50) {
      _editHistory.removeAt(0);
      _historyIndex--;
    }
  }

  void _undo() {
    if (_historyIndex > 0) {
      _historyIndex--;
      _applyHistoryState();
    }
  }

  void _redo() {
    if (_historyIndex < _editHistory.length - 1) {
      _historyIndex++;
      _applyHistoryState();
    }
  }

  void _applyHistoryState() {
    // Apply the state at current history index
    // This is a simplified implementation
    setState(() {
      _hasUnsavedChanges = true;
    });
  }

  void _resetTrim() {
    setState(() {
      _startTime = Duration.zero;
      _endTime = _videoDuration;
      _hasUnsavedChanges = true;
    });
    
    _addEditAction(VideoEditAction(
      type: 'reset_trim',
      data: {},
      timestamp: DateTime.now(),
    ));
  }

  Future<void> _applyTrim() async {
    if (_isProcessing) return;
    
    setState(() {
      _isProcessing = true;
      _processingProgress = 0.0;
      _processingStatus = 'Trimming video...';
    });

    try {
      await _videoService.trimVideo(
        inputFile: widget.videoFile,
        startTime: _startTime,
        endTime: _endTime,
        videoId: _videoId,
        onProgress: (progress) {
          setState(() {
            _processingProgress = progress;
          });
        },
      );

      setState(() {
        _processingStatus = 'Trim applied successfully!';
        _hasUnsavedChanges = false;
      });

      // Update edit state
      _editState = _editState?.copyWith(
        startTime: _startTime,
        endTime: _endTime,
      );

      LoggingService.instance.debug('Video trimmed successfully', tag: 'VideoEditView');
    } catch (e) {
      LoggingService.instance.error('Error applying trim', tag: 'VideoEditView', error: e);
      setState(() {
        _processingStatus = 'Error: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }


  void _selectEffect(String effectName) {
    setState(() {
      if (effectName == 'None') {
        _editState = _editState?.copyWith(visualEffects: []);
      } else {
        final effects = List<VisualEffect>.from(_editState?.visualEffects ?? []);
        effects.removeWhere((e) => e.type == effectName);
        effects.add(VisualEffect(
          type: effectName,
          parameters: {},
          startTime: Duration.zero,
          endTime: _videoDuration,
        ));
        _editState = _editState?.copyWith(visualEffects: effects);
      }
      _hasUnsavedChanges = true;
    });
  }


  void _addTextOverlay() {
    // This would open a text overlay editor
    // For now, just add a placeholder
    setState(() {
      final textOverlays = List<TextOverlay>.from(_editState?.textOverlays ?? []);
      textOverlays.add(TextOverlay(
        text: 'Sample Text',
        x: 0.5,
        y: 0.5,
        fontFamily: 'Arial',
        fontSize: 24,
        color: '#FFFFFF',
        startTime: Duration.zero,
        endTime: _videoDuration,
      ));
      _editState = _editState?.copyWith(textOverlays: textOverlays);
      _hasUnsavedChanges = true;
    });
  }

  void _openTextOverlayEditor() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TextOverlayEditor(
          textOverlays: _editState?.textOverlays ?? [],
          videoDuration: _videoDuration,
          onTextOverlaysChanged: (overlays) {
            setState(() {
              _editState = _editState?.copyWith(textOverlays: overlays);
              _hasUnsavedChanges = true;
            });
          },
          onClose: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  void _openVisualEffectsEditor() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VisualEffectsEditor(
          visualEffects: _editState?.visualEffects ?? [],
          videoDuration: _videoDuration,
          onEffectsChanged: (effects) {
            setState(() {
              _editState = _editState?.copyWith(visualEffects: effects);
              _hasUnsavedChanges = true;
            });
          },
          onClose: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  void _openAudioEditor() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AudioEditor(
          audioEffects: _editState?.audioEffects ?? AudioEffects(),
          videoDuration: _videoDuration,
          onAudioEffectsChanged: (effects) {
            setState(() {
              _editState = _editState?.copyWith(audioEffects: effects);
              _hasUnsavedChanges = true;
            });
          },
          onClose: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  void _openAdvancedVideoEditor() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AdvancedVideoEditor(
          videoFile: widget.videoFile,
          videoDuration: _videoDuration,
          onSettingsChanged: (settings) {
            // Handle advanced video settings
            setState(() {
              _hasUnsavedChanges = true;
            });
          },
          onClose: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  Future<void> _saveDraft() async {
    if (_editState != null) {
      _videoService.saveEditState(_videoId, _editState!);
      setState(() {
        _hasUnsavedChanges = false;
      });
      LoggingService.instance.debug('Draft saved', tag: 'VideoEditView');
    }
  }

  Future<void> _showDiscardDialog() async {
    if (!_hasUnsavedChanges) {
      widget.onCancel?.call();
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C135D),
        title: const Text(
          'Discard Changes?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'You have unsaved changes. Are you sure you want to discard them?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep Editing', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (result == true) {
      widget.onCancel?.call();
    }
  }
}
