import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:math' as math;

class AdvancedVideoEditor extends StatefulWidget {
  final File videoFile;
  final Duration videoDuration;
  final Function(VideoEditSettings) onSettingsChanged;
  final VoidCallback? onClose;

  const AdvancedVideoEditor({
    super.key,
    required this.videoFile,
    required this.videoDuration,
    required this.onSettingsChanged,
    this.onClose,
  });

  @override
  State<AdvancedVideoEditor> createState() => _AdvancedVideoEditorState();
}

class _AdvancedVideoEditorState extends State<AdvancedVideoEditor>
    with TickerProviderStateMixin {
  late VideoEditSettings _settings;
  
  // Animation controllers
  late AnimationController _previewController;
  late AnimationController _rotationController;
  
  // Video preview state
  double _previewScale = 1.0;
  double _previewRotation = 0.0;
  bool _isFlippedHorizontal = false;
  bool _isFlippedVertical = false;

  @override
  void initState() {
    super.initState();
    _settings = VideoEditSettings(
      speed: 1.0,
      rotation: 0.0,
      isFlippedHorizontal: false,
      isFlippedVertical: false,
      cropSettings: CropSettings(
        x: 0.0,
        y: 0.0,
        width: 1.0,
        height: 1.0,
      ),
      quality: VideoQuality.high,
      resolution: VideoResolution.original,
    );
    
    _previewController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _previewController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  void _updateSettings() {
    widget.onSettingsChanged(_settings);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
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
              _buildTopBar(),
              Expanded(
                child: Row(
                  children: [
                    // Video preview area
                    Expanded(
                      flex: 3,
                      child: _buildVideoPreview(),
                    ),
                    // Controls panel
                    Expanded(
                      flex: 2,
                      child: _buildControlsPanel(),
                    ),
                  ],
                ),
              ),
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
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onClose?.call();
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
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
          const SizedBox(width: 16),
          const Text(
            'Advanced Video Editor',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _resetToDefaults();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: const Text(
                'Reset',
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
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Video preview with transformations
            Center(
              child: AnimatedBuilder(
                animation: _rotationController,
                builder: (context, child) {
                  return Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..scale(_previewScale)
                      ..rotateZ(_previewRotation + _rotationController.value * 2 * math.pi)
                      ..scale(_isFlippedHorizontal ? -1.0 : 1.0, _isFlippedVertical ? -1.0 : 1.0),
                    child: Container(
                      width: 200,
                      height: 300,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.videocam,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            
            // Crop overlay
            _buildCropOverlay(),
            
            // Play button
            Center(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  if (_previewController.isAnimating) {
                    _previewController.stop();
                  } else {
                    _previewController.forward();
                  }
                },
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: AnimatedBuilder(
                    animation: _previewController,
                    builder: (context, child) {
                      return Icon(
                        _previewController.isAnimating ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 30,
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCropOverlay() {
    return Positioned.fill(
      child: CustomPaint(
        painter: CropOverlayPainter(
          cropSettings: _settings.cropSettings,
        ),
      ),
    );
  }

  Widget _buildControlsPanel() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Speed control
            _buildSpeedControl(),
            const SizedBox(height: 24),
            
            // Rotation control
            _buildRotationControl(),
            const SizedBox(height: 24),
            
            // Flip controls
            _buildFlipControls(),
            const SizedBox(height: 24),
            
            // Crop controls
            _buildCropControls(),
            const SizedBox(height: 24),
            
            // Quality settings
            _buildQualitySettings(),
            const SizedBox(height: 24),
            
            // Resolution settings
            _buildResolutionSettings(),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeedControl() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Playback Speed',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${_settings.speed.toStringAsFixed(1)}x',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: _settings.speed,
          min: 0.25,
          max: 4.0,
          divisions: 15,
          activeColor: const Color(0xFF9248D2),
          inactiveColor: Colors.white.withValues(alpha: 0.3),
          onChanged: (value) {
            setState(() {
              _settings = _settings.copyWith(speed: value);
            });
            _updateSettings();
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('0.25x', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
            Text('1.0x', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
            Text('4.0x', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
          ],
        ),
      ],
    );
  }

  Widget _buildRotationControl() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Rotation',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${_settings.rotation.round()}°',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: _settings.rotation,
          min: 0.0,
          max: 360.0,
          divisions: 36,
          activeColor: const Color(0xFF9248D2),
          inactiveColor: Colors.white.withValues(alpha: 0.3),
          onChanged: (value) {
            setState(() {
              _settings = _settings.copyWith(rotation: value);
              _previewRotation = value * math.pi / 180;
            });
            _updateSettings();
          },
        ),
        Row(
          children: [
            Expanded(
              child: _buildRotationButton('90°', 90),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildRotationButton('180°', 180),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildRotationButton('270°', 270),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRotationButton(String label, double degrees) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _settings = _settings.copyWith(rotation: degrees);
          _previewRotation = degrees * math.pi / 180;
        });
        _updateSettings();
        _rotationController.forward().then((_) {
          _rotationController.reset();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildFlipControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Flip',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildFlipButton('Horizontal', Icons.flip, _settings.isFlippedHorizontal, (value) {
                setState(() {
                  _settings = _settings.copyWith(isFlippedHorizontal: value);
                  _isFlippedHorizontal = value;
                });
                _updateSettings();
              }),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildFlipButton('Vertical', Icons.flip, _settings.isFlippedVertical, (value) {
                setState(() {
                  _settings = _settings.copyWith(isFlippedVertical: value);
                  _isFlippedVertical = value;
                });
                _updateSettings();
              }),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFlipButton(String label, IconData icon, bool isActive, Function(bool) onChanged) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onChanged(!isActive);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive 
              ? const Color(0xFF9248D2).withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive 
                ? const Color(0xFF9248D2)
                : Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isActive ? const Color(0xFF9248D2) : Colors.white,
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? const Color(0xFF9248D2) : Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCropControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Crop',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildCropButton('16:9', 16/9),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildCropButton('4:3', 4/3),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildCropButton('1:1', 1),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildCropButton('9:16', 9/16),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildCropButton('3:4', 3/4),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildCropButton('Free', 0),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCropButton(String label, double aspectRatio) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        // Crop implementation would go here
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildQualitySettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quality',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<VideoQuality>(
          value: _settings.quality,
          dropdownColor: const Color(0xFF1C135D),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
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
          items: VideoQuality.values.map((quality) {
            return DropdownMenuItem(
              value: quality,
              child: Text(
                quality.name.toUpperCase(),
                style: const TextStyle(color: Colors.white),
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _settings = _settings.copyWith(quality: value);
              });
              _updateSettings();
            }
          },
        ),
      ],
    );
  }

  Widget _buildResolutionSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Resolution',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<VideoResolution>(
          value: _settings.resolution,
          dropdownColor: const Color(0xFF1C135D),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
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
          items: VideoResolution.values.map((resolution) {
            return DropdownMenuItem(
              value: resolution,
              child: Text(
                resolution.name.toUpperCase(),
                style: const TextStyle(color: Colors.white),
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _settings = _settings.copyWith(resolution: value);
              });
              _updateSettings();
            }
          },
        ),
      ],
    );
  }

  void _resetToDefaults() {
    setState(() {
      _settings = VideoEditSettings(
        speed: 1.0,
        rotation: 0.0,
        isFlippedHorizontal: false,
        isFlippedVertical: false,
        cropSettings: CropSettings(
          x: 0.0,
          y: 0.0,
          width: 1.0,
          height: 1.0,
        ),
        quality: VideoQuality.high,
        resolution: VideoResolution.original,
      );
      _previewScale = 1.0;
      _previewRotation = 0.0;
      _isFlippedHorizontal = false;
      _isFlippedVertical = false;
    });
    _updateSettings();
  }
}

// Data models
class VideoEditSettings {
  final double speed;
  final double rotation;
  final bool isFlippedHorizontal;
  final bool isFlippedVertical;
  final CropSettings cropSettings;
  final VideoQuality quality;
  final VideoResolution resolution;

  VideoEditSettings({
    required this.speed,
    required this.rotation,
    required this.isFlippedHorizontal,
    required this.isFlippedVertical,
    required this.cropSettings,
    required this.quality,
    required this.resolution,
  });

  VideoEditSettings copyWith({
    double? speed,
    double? rotation,
    bool? isFlippedHorizontal,
    bool? isFlippedVertical,
    CropSettings? cropSettings,
    VideoQuality? quality,
    VideoResolution? resolution,
  }) {
    return VideoEditSettings(
      speed: speed ?? this.speed,
      rotation: rotation ?? this.rotation,
      isFlippedHorizontal: isFlippedHorizontal ?? this.isFlippedHorizontal,
      isFlippedVertical: isFlippedVertical ?? this.isFlippedVertical,
      cropSettings: cropSettings ?? this.cropSettings,
      quality: quality ?? this.quality,
      resolution: resolution ?? this.resolution,
    );
  }
}

class CropSettings {
  final double x;
  final double y;
  final double width;
  final double height;

  CropSettings({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
}

enum VideoQuality { low, medium, high, ultra }

enum VideoResolution { original, hd, fhd, uhd }

class CropOverlayPainter extends CustomPainter {
  final CropSettings cropSettings;

  CropOverlayPainter({required this.cropSettings});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = const Color(0xFF9248D2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Calculate crop rectangle
    final cropRect = Rect.fromLTWH(
      cropSettings.x * size.width,
      cropSettings.y * size.height,
      cropSettings.width * size.width,
      cropSettings.height * size.height,
    );

    // Draw overlay outside crop area
    final overlayPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(cropRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(overlayPath, paint);
    canvas.drawRect(cropRect, borderPaint);

    // Draw corner handles
    final handleSize = 8.0;
    final handles = [
      Offset(cropRect.left, cropRect.top),
      Offset(cropRect.right, cropRect.top),
      Offset(cropRect.left, cropRect.bottom),
      Offset(cropRect.right, cropRect.bottom),
    ];

    for (final handle in handles) {
      canvas.drawCircle(handle, handleSize, borderPaint);
      canvas.drawCircle(handle, handleSize - 2, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
