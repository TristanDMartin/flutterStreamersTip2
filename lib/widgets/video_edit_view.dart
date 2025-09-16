import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'video_publishing_screen.dart';

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

  // Trim video state
  double _startTrim = 0.0;
  double _endTrim = 1.0;
  double _videoDuration = 60.0; // Example duration in seconds

  // Tab options
  final List<String> _tabs = ['Trim', 'Audio', 'Effects', 'Text'];

  @override
  void initState() {
    super.initState();
    _tabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabAnimationController.dispose();
    super.dispose();
  }

  void _navigateToPublishing() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VideoPublishingScreen(
          videoFile: widget.videoFile,
          caption: '', // Start with empty caption
          hashtags: [], // Start with empty hashtags
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
              
              // Editing Tabs
              _buildEditingTabs(),
              
              // Content Area
              Expanded(
                flex: 2,
                child: _buildContentArea(),
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
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.chevron_left,
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
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Video placeholder (replace with actual video player)
            Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.black,
              child: const Icon(
                Icons.play_circle_filled,
                color: Colors.white,
                size: 60,
              ),
            ),
            
            // Play button overlay
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                // TODO: Implement play/pause functionality
              },
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
          ],
        ),
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
                      : Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected 
                        ? Colors.transparent
                        : Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                  boxShadow: isSelected ? [
                    BoxShadow(
                      color: const Color(0xFF9248D2).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ] : null,
                ),
                child: Text(
                  tab,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
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
          const Text(
            'Trim Video',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Timeline Slider
          Container(
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Stack(
              children: [
                // Background track
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                
                // Trim handles
                Positioned(
                  left: 20 + (_startTrim * (MediaQuery.of(context).size.width - 80)),
                  top: 20,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        _startTrim = ((details.localPosition.dx + 20) / (MediaQuery.of(context).size.width - 80)).clamp(0.0, _endTrim - 0.1);
                      });
                    },
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: Color(0xFF9248D2),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                
                Positioned(
                  left: 20 + (_endTrim * (MediaQuery.of(context).size.width - 80)),
                  top: 20,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        _endTrim = ((details.localPosition.dx + 20) / (MediaQuery.of(context).size.width - 80)).clamp(_startTrim + 0.1, 1.0);
                      });
                    },
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: Color(0xFF9248D2),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _startTrim = 0.0;
                      _endTrim = 1.0;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
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
                  onTap: () {
                    HapticFeedback.lightImpact();
                    // TODO: Implement apply trim functionality
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF9248D2), Color(0xFF4897D2)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
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
          
          const SizedBox(height: 16),
          
          // Time Display
          Text(
            'Start: ${(_startTrim * _videoDuration).toStringAsFixed(1)}s | End: ${(_endTrim * _videoDuration).toStringAsFixed(1)}s',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioContent() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Audio Settings',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Audio editing features coming soon!',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEffectsContent() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Visual Effects',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Effects editing features coming soon!',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextContent() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add Text',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Text editing features coming soon!',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Cancel Button
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                widget.onCancel?.call();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
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
          
          const SizedBox(width: 16),
          
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
}
