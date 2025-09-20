import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import 'dart:async';
import 'video_publishing_screen.dart';
import 'instant_response_button.dart';
import '../services/video_processing_service.dart';
import '../services/music_library_service.dart';
import '../services/hashtag_lock_service.dart';
import 'music_selection_widget.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VideoEditingScreen extends StatefulWidget {
  final File videoFile;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  const VideoEditingScreen({
    super.key,
    required this.videoFile,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<VideoEditingScreen> createState() => _VideoEditingScreenState();
}

class _VideoEditingScreenState extends State<VideoEditingScreen>
    with TickerProviderStateMixin {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  late TabController _tabController;
  
  // Editing state
  String _selectedFilter = 'none';
  MusicTrack? _selectedMusicTrack;
  bool _hasVoiceover = false;
  String _caption = '';
  final List<String> _hashtags = [];
  
  // Trimming state
  double _trimStart = 0.0;
  double _trimEnd = 1.0;
  
  // Video processing
  final VideoProcessingService _videoProcessor = VideoProcessingService();
  File? _processedVideoFile;
  bool _isProcessing = false;
  double _processingProgress = 0.0;
  String _processingMessage = '';
  StreamSubscription<VideoProcessingProgress>? _progressSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initializeVideo();
    _setupProgressListener();
  }

  Future<void> _initializeVideo() async {
    _controller = VideoPlayerController.file(widget.videoFile);
    await _controller.initialize();
    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _tabController.dispose();
    _progressSubscription?.cancel();
    super.dispose();
  }

  void _setupProgressListener() {
    _progressSubscription = _videoProcessor.progressStream.listen((progress) {
      if (mounted) {
        setState(() {
          _processingProgress = progress.progress;
          _processingMessage = progress.message;
        });
      }
    });
  }

  void _togglePlayPause() {
    setState(() {
      if (_isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
      }
      _isPlaying = !_isPlaying;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1220),
      body: Column(
        children: [
          // Header
          _buildHeader(),
          
          // Video Preview
          _buildVideoPreview(),
          
          // Editing Tabs
          _buildEditingTabs(),
          
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTrimTab(),
                _buildAudioTab(),
                _buildEffectsTab(),
                _buildTextTab(),
              ],
            ),
          ),
          
          // Bottom Actions
          _buildBottomActions(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      child: Row(
        children: [
          InstantIconButton(
            onPressed: widget.onCancel,
            icon: const Icon(
              Icons.arrow_back_ios,
              color: Colors.white,
              size: 24,
            ),
            hapticType: HapticFeedbackType.selectionClick,
          ),
          const SizedBox(width: 16),
          const Text(
            'Edit Video',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          InstantResponseButton(
            onPressed: _showPreview,
            hapticType: HapticFeedbackType.mediumImpact,
            scaleOnPress: 0.95,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF9248D2),
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

  Widget _buildVideoPreview() {
    return Container(
      height: 300,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.black,
      ),
      child: Stack(
        children: [
          if (_isInitialized)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          
          // Play/Pause Overlay
          Center(
            child: InstantResponseButton(
              onPressed: _togglePlayPause,
              hapticType: HapticFeedbackType.lightImpact,
              scaleOnPress: 0.9,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha:0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
          ),
          
          // Filter Overlay
          if (_selectedFilter != 'none')
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: _getFilterColor().withValues(alpha:0.3),
                ),
              ),
            ),
          
          // Processing Overlay
          if (_isProcessing)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha:0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: _processingProgress > 0 ? _processingProgress : null,
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF9248D2)),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _processingMessage,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_processingProgress > 0) ...[
                        const SizedBox(height: 8),
                        Text(
                          '${(_processingProgress * 100).toInt()}%',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEditingTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: const Color(0xFF9248D2),
          borderRadius: BorderRadius.circular(12),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white.withValues(alpha:0.7),
        tabs: const [
          Tab(text: 'Trim'),
          Tab(text: 'Audio'),
          Tab(text: 'Effects'),
          Tab(text: 'Text'),
        ],
      ),
    );
  }

  Widget _buildTrimTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Trim Video',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Video duration info
          if (_isInitialized)
            Text(
              'Duration: ${_controller.value.duration.inSeconds}s',
              style: TextStyle(
                color: Colors.white.withValues(alpha:0.7),
                fontSize: 14,
              ),
            ),
          
          const SizedBox(height: 16),
          
          // Timeline slider
          Container(
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha:0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _isInitialized ? _buildTimelineSlider() : const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Trim controls
          Row(
            children: [
              Expanded(
                child: InstantResponseButton(
                  onPressed: _isInitialized ? _resetTrim : null,
                  hapticType: HapticFeedbackType.selectionClick,
                  scaleOnPress: 0.95,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha:0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Reset',
                      style: TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InstantResponseButton(
                  onPressed: (_isInitialized && !_isProcessing) ? _applyTrim : null,
                  hapticType: HapticFeedbackType.mediumImpact,
                  scaleOnPress: 0.95,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: (_isInitialized && !_isProcessing) 
                          ? const Color(0xFF9248D2) 
                          : Colors.grey,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _isProcessing
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Processing...',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          )
                        : const Text(
                            'Apply Trim',
                            style: TextStyle(color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          Text(
            'Start: ${(_trimStart * (_controller.value.duration.inMilliseconds / 1000)).toStringAsFixed(1)}s | End: ${(_trimEnd * (_controller.value.duration.inMilliseconds / 1000)).toStringAsFixed(1)}s',
            style: TextStyle(
              color: Colors.white.withValues(alpha:0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioTab() {
    return Column(
      children: [
        // Audio Options Header
        Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Audio & Music',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Original Audio
          _buildAudioOption(
            icon: Icons.music_note,
            title: 'Original Audio',
            subtitle: 'Keep original video audio',
                isSelected: _selectedMusicTrack == null && !_hasVoiceover,
                onTap: () => setState(() {
                  _selectedMusicTrack = null;
                  _hasVoiceover = false;
                }),
          ),
          
          const SizedBox(height: 12),
          
          // Music Library
          _buildAudioOption(
            icon: Icons.library_music,
            title: 'Music Library',
                subtitle: _selectedMusicTrack != null 
                    ? '${_selectedMusicTrack!.title} - ${_selectedMusicTrack!.artist}'
                    : 'Choose from free music library',
                isSelected: _selectedMusicTrack != null,
                onTap: () {
                  // This will be handled by the music selection widget below
                },
          ),
          
          const SizedBox(height: 12),
          
          // Voiceover
          _buildAudioOption(
            icon: Icons.mic,
            title: 'Record Voiceover',
            subtitle: 'Add your own voice',
            isSelected: _hasVoiceover,
                onTap: () => setState(() {
                  _hasVoiceover = !_hasVoiceover;
                  if (_hasVoiceover) {
                    _selectedMusicTrack = null;
                  }
                }),
          ),
        ],
      ),
        ),
        
        // Music Selection Widget
        if (_selectedMusicTrack != null || _selectedMusicTrack == null)
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: MusicSelectionWidget(
                onMusicSelected: (track) {
                  setState(() {
                    _selectedMusicTrack = track;
                    if (track != null) {
                      _hasVoiceover = false;
                    }
                  });
                },
                selectedTrack: _selectedMusicTrack,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEffectsTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filters & Effects',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Filter Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.2,
            ),
            itemCount: 9,
            itemBuilder: (context, index) {
              final filters = [
                'None', 'Vintage', 'B&W', 'Sepia', 'Cool', 'Warm', 'Bright', 'Dark', 'Blur'
              ];
              final isSelected = _selectedFilter == filters[index].toLowerCase();
              
              return InstantResponseButton(
                onPressed: () => _applyFilter(filters[index].toLowerCase()),
                hapticType: HapticFeedbackType.selectionClick,
                scaleOnPress: 0.95,
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF9248D2) : Colors.white.withValues(alpha:0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF9248D2) : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      filters[index],
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHashtagChip(String hashtag) {
    final isSelected = _hashtags.contains(hashtag);
    return InstantResponseButton(
      onPressed: () {
        setState(() {
          if (isSelected) {
            _hashtags.remove(hashtag);
          } else {
            _hashtags.add(hashtag);
          }
        });
      },
      hapticType: HapticFeedbackType.selectionClick,
      scaleOnPress: 0.95,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected 
              ? const Color(0xFF9248D2)
              : Colors.white.withValues(alpha:0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected 
                ? const Color(0xFF9248D2)
                : Colors.white.withValues(alpha:0.3),
          ),
        ),
        child: Text(
          hashtag,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildTextTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Text & Captions',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Caption Input
          TextField(
            onChanged: (value) => setState(() => _caption = value),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Add a caption...',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha:0.5)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withValues(alpha:0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withValues(alpha:0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF9248D2)),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Text Overlay
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha:0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Text Overlay\n(Coming Soon)',
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Hashtags
          const Text(
            'Hashtags',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          
          // Hashtag input
          TextField(
            onChanged: (value) async {
              // Extract hashtags from text
              final hashtagRegex = RegExp(r'#\w+');
              final matches = hashtagRegex.allMatches(value);
              final extractedHashtags = matches.map((match) => match.group(0)!).toList();
              
              // Validate each hashtag
              final currentUser = FirebaseAuth.instance.currentUser;
              final hashtagService = HashtagLockService();
              final validHashtags = <String>[];
              
              for (final hashtag in extractedHashtags) {
                final cleaned = hashtag.replaceAll('#', '');
                final validation = await hashtagService.validateHashtag(cleaned, currentUser?.uid);
                if (validation.isValid) {
                  validHashtags.add(hashtag);
                } else {
                  // Show error for invalid hashtag
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${validation.errorMessage} for #$cleaned'),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                }
              }
              
              setState(() {
                _hashtags.clear();
                _hashtags.addAll(validHashtags);
              });
            },
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Add hashtags (e.g., #gaming #fun #viral)',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha:0.5)),
              border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withValues(alpha:0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withValues(alpha:0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF9248D2)),
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Hashtag suggestions
          if (_hashtags.isNotEmpty) ...[
            const Text(
              'Detected Hashtags:',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _hashtags.map((hashtag) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF9248D2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  hashtag,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )).toList(),
            ),
          ],
          
          const SizedBox(height: 16),
          
          // Popular hashtag suggestions
          const Text(
            'Popular Hashtags:',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildHashtagChip('#trending'),
              _buildHashtagChip('#viral'),
              _buildHashtagChip('#fyp'),
              _buildHashtagChip('#gaming'),
              _buildHashtagChip('#fun'),
              _buildHashtagChip('#streaming'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAudioOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InstantResponseButton(
      onPressed: onTap,
      hapticType: HapticFeedbackType.selectionClick,
      scaleOnPress: 0.98,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF9248D2) : Colors.white.withValues(alpha:0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF9248D2) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha:0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: InstantResponseButton(
              onPressed: widget.onCancel,
              hapticType: HapticFeedbackType.mediumImpact,
              scaleOnPress: 0.95,
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: const Center(
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: InstantResponseButton(
              onPressed: _proceedToPublishing,
              hapticType: HapticFeedbackType.mediumImpact,
              scaleOnPress: 0.95,
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF9248D2), Color(0xFF1670DE)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: const Center(
                  child: Text(
                    'Next',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getFilterColor() {
    switch (_selectedFilter) {
      case 'vintage':
        return Colors.brown;
      case 'b&w':
        return Colors.grey;
      case 'sepia':
        return Colors.orange;
      case 'cool':
        return Colors.blue;
      case 'warm':
        return Colors.red;
      case 'bright':
        return Colors.yellow;
      case 'dark':
        return Colors.black;
      case 'blur':
        return Colors.purple;
      default:
        return Colors.transparent;
    }
  }

  void _showPreview() {
    // Show full-screen preview
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        child: AspectRatio(
          aspectRatio: _controller.value.aspectRatio,
          child: VideoPlayer(_controller),
        ),
      ),
    );
  }

  Widget _buildTimelineSlider() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Start handle
          Container(
            width: 20,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF9248D2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Icon(
                Icons.drag_handle,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
          
          // Timeline track
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: const Color(0xFF9248D2),
                inactiveTrackColor: Colors.white.withValues(alpha:0.3),
                thumbColor: const Color(0xFF9248D2),
                overlayColor: const Color(0xFF9248D2).withValues(alpha:0.2),
                trackHeight: 4,
              ),
              child: RangeSlider(
                values: RangeValues(_trimStart, _trimEnd),
                onChanged: (values) {
                  setState(() {
                    _trimStart = values.start;
                    _trimEnd = values.end;
                  });
                },
                min: 0.0,
                max: 1.0,
              ),
            ),
          ),
          
          // End handle
          Container(
            width: 20,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF9248D2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Icon(
                Icons.drag_handle,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _resetTrim() {
    setState(() {
      _trimStart = 0.0;
      _trimEnd = 1.0;
    });
  }

  Future<void> _applyTrim() async {
    if (!_isInitialized) return;
    
    setState(() {
      _isProcessing = true;
      _processingMessage = 'Trimming video...';
    });
    
    try {
      final startTime = Duration(
        milliseconds: (_trimStart * _controller.value.duration.inMilliseconds).round(),
      );
      final endTime = Duration(
        milliseconds: (_trimEnd * _controller.value.duration.inMilliseconds).round(),
      );
      
      final result = await _videoProcessor.trimVideo(
        inputPath: widget.videoFile.path,
        startTime: startTime,
        endTime: endTime,
      );
      
      if (result.success && result.outputPath != null) {
        _processedVideoFile = File(result.outputPath!);
        
        // Update video controller to show trimmed video
        await _controller.dispose();
        _controller = VideoPlayerController.file(_processedVideoFile!);
        await _controller.initialize();
        
        if (mounted) {
          setState(() {
            _isInitialized = true;
            _isProcessing = false;
          });
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Video trimmed successfully! ${(_trimStart * _controller.value.duration.inSeconds).toStringAsFixed(1)}s - ${(_trimEnd * _controller.value.duration.inSeconds).toStringAsFixed(1)}s',
              ),
              backgroundColor: const Color(0xFF9248D2),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        setState(() {
          _isProcessing = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to trim video: ${result.error}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error trimming video: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }


  Future<void> _applyFilter(String filterName) async {
    setState(() {
      _selectedFilter = filterName;
    });
    
    if (filterName == 'none') {
      // Reset to original video
      if (_processedVideoFile != null) {
        await _controller.dispose();
        _controller = VideoPlayerController.file(widget.videoFile);
        await _controller.initialize();
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
        }
      }
      return;
    }
    
    setState(() {
      _isProcessing = true;
      _processingMessage = 'Applying filter...';
    });
    
    try {
      final filter = VideoFilter.values.firstWhere(
        (f) => f.displayName.toLowerCase() == filterName,
        orElse: () => VideoFilter.none,
      );
      
      final inputFile = _processedVideoFile ?? widget.videoFile;
      final result = await _videoProcessor.applyFilter(
        inputPath: inputFile.path,
        filter: filter,
      );
      
      if (result.success && result.outputPath != null) {
        _processedVideoFile = File(result.outputPath!);
        
        // Update video controller to show filtered video
        await _controller.dispose();
        _controller = VideoPlayerController.file(_processedVideoFile!);
        await _controller.initialize();
        
        if (mounted) {
          setState(() {
            _isInitialized = true;
            _isProcessing = false;
          });
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${filter.displayName} filter applied successfully!'),
              backgroundColor: const Color(0xFF9248D2),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        setState(() {
          _isProcessing = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to apply filter: ${result.error}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error applying filter: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _proceedToPublishing() {
    // Use processed video if available, otherwise use original
    final videoFileToUse = _processedVideoFile ?? widget.videoFile;
    
    // Navigate to publishing screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VideoPublishingScreen(
          videoFile: videoFileToUse,
          caption: _caption,
          hashtags: _hashtags,
          onPublish: widget.onSave,
          onCancel: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}
