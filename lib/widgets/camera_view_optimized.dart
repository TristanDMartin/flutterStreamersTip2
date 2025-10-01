import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
// import 'recording_preview_view.dart'; // Removed - unused
// import 'video_edit_view.dart'; // Removed - unused

class CameraViewOptimized extends StatefulWidget {
  const CameraViewOptimized({super.key});

  @override
  State<CameraViewOptimized> createState() => _CameraViewOptimizedState();
}

class _CameraViewOptimizedState extends State<CameraViewOptimized> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isRecording = false;
  Timer? _recordingTimer;
  Offset? _focusPoint;
  bool _isFocusing = false;
  double _currentZoom = 1.0;
  bool _showGrid = false;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }

  // Clean, simple camera initialization following the brief
  Future<void> _initializeCamera() async {
    try {
      debugPrint('🎥 Starting camera initialization...');
      _cameras = await availableCameras();
      
      if (_cameras!.isNotEmpty) {
        // Select back camera explicitly for best quality
        final backCamera = _cameras!.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.back,
          orElse: () => _cameras!.first,
        );
        
        debugPrint('🎥 Selected camera: ${backCamera.name} (Back Wide)');
        
        _cameraController = CameraController(
          backCamera,
          ResolutionPreset.max, // Highest available resolution for crisp preview
          enableAudio: true,
          imageFormatGroup: ImageFormatGroup.yuv420, // Best preview quality on Android
        );
        
        await _cameraController!.initialize();
        
        // Lock orientation to portrait for consistent preview
        await _cameraController!.lockCaptureOrientation(DeviceOrientation.portraitUp);
        
        // Apply professional camera settings
        await _applyCameraSettings();
        
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
          debugPrint('✅ Camera ready with professional settings');
        }
      }
    } catch (e) {
      debugPrint('❌ Camera initialization failed: $e');
      _showErrorDialog('Camera initialization failed');
    }
  }

  // Simple, professional camera settings
  Future<void> _applyCameraSettings() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    
    try {
      // Set continuous autofocus for sharp preview
      await _cameraController!.setFocusMode(FocusMode.auto);
      
      // Set continuous auto exposure for proper lighting
      await _cameraController!.setExposureMode(ExposureMode.auto);
      
      // Set flash mode
      await _cameraController!.setFlashMode(FlashMode.off);
      
      // Reset zoom to 1.0 for natural view
      try {
        await _cameraController!.setZoomLevel(1.0);
      } catch (e) {
        debugPrint('Zoom reset not available: $e');
      }
      
      debugPrint('✅ Professional camera settings applied');
    } catch (e) {
      debugPrint('Error applying camera settings: $e');
    }
  }

  // Clean tap-to-focus implementation
  void _onTapToFocus(TapDownDetails details) async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    try {
      final RenderBox renderBox = context.findRenderObject() as RenderBox;
      final Offset localPoint = renderBox.globalToLocal(details.globalPosition);
      
      final double x = localPoint.dx / renderBox.size.width;
      final double y = localPoint.dy / renderBox.size.height;
      
      // Clamp values to valid range
      final double clampedX = x.clamp(0.0, 1.0);
      final double clampedY = y.clamp(0.0, 1.0);
      
      setState(() {
        _focusPoint = localPoint;
        _isFocusing = true;
      });

      // Set exposure point for proper lighting
      try {
        await _cameraController!.setExposurePoint(Offset(clampedX, clampedY));
      } catch (e) {
        debugPrint('Exposure point setting not supported: $e');
      }
      
      // Set focus point
      try {
        await _cameraController!.setFocusPoint(Offset(clampedX, clampedY));
      } catch (e) {
        debugPrint('Focus point setting not supported: $e');
      }

      // Hide focus indicator after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _isFocusing = false;
          });
        }
      });

      HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint('Error focusing: $e');
    }
  }

  // Simple zoom implementation
  void _onScaleUpdate(ScaleUpdateDetails details) async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    try {
      final double newZoom = (_currentZoom * details.scale).clamp(1.0, 4.0);
      
      setState(() {
        _currentZoom = newZoom;
      });

      try {
        await _cameraController!.setZoomLevel(newZoom);
      } catch (e) {
        debugPrint('Zoom not available: $e');
      }
    } catch (e) {
      debugPrint('Error zooming: $e');
    }
  }

  // Simple recording functions
  Future<void> _startRecording() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    try {
      await _cameraController!.startVideoRecording();
      
      setState(() {
        _isRecording = true;
      });
      
      _startRecordingTimer();
      HapticFeedback.mediumImpact();
      
      debugPrint('✅ Recording started');
    } catch (e) {
      debugPrint('Error starting recording: $e');
      _showErrorDialog('Failed to start recording');
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording || _cameraController == null) return;

    try {
      final XFile videoFile = await _cameraController!.stopVideoRecording();
      
      _recordingTimer?.cancel();
      
      setState(() {
        _isRecording = false;
      });
      
      // Navigate to RecordingPreviewView
      if (mounted) {
        // Navigator.of(context).push(
        //   MaterialPageRoute(
        //     builder: (context) => RecordingPreviewView(
        //       videoFile: File(videoFile.path),
        //       onBack: () => Navigator.of(context).pop(),
        //       onUseVideo: () {
        //         // Close RecordingPreviewView and navigate to VideoEditView
        //         Navigator.of(context).pop(); // Close RecordingPreviewView
        //         Navigator.of(context).pop(); // Close CameraView
        //         // Navigate to VideoEditView
        //         Navigator.of(context).push(
        //           MaterialPageRoute(
        //             builder: (context) => VideoEditView(
        //               videoFile: File(videoFile.path),
        //               onCancel: () => Navigator.of(context).pop(),
        //               onNext: () {
        //                 // Handle next step (publishing, etc.)
        //                 Navigator.of(context).pop();
        //               },
        //             ),
        //           ),
        //         );
        //       },
        //     ),
        //   ),
        // );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video recording and editing features coming soon!')),
        );
      }
      
      HapticFeedback.mediumImpact();
      debugPrint('✅ Recording stopped: ${videoFile.path}');
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      _showErrorDialog('Failed to stop recording');
    }
  }

  void _startRecordingTimer() {
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isRecording) {
        timer.cancel();
      }
    });
  }

  // Simple gallery picker (TikTok style - video only)
  Future<void> _pickFromGallery() async {
    try {
      final XFile? video = await _imagePicker.pickVideo(source: ImageSource.gallery);
      
      if (video != null && mounted) {
        HapticFeedback.lightImpact();
        
        // Navigate to RecordingPreviewView
        // Navigator.of(context).push(
        //   MaterialPageRoute(
        //     builder: (context) => RecordingPreviewView(
        //       videoFile: File(video.path),
        //       onBack: () => Navigator.of(context).pop(),
        //       onUseVideo: () {
        //         // Close RecordingPreviewView and navigate to VideoEditView
        //         Navigator.of(context).pop(); // Close RecordingPreviewView
        //         Navigator.of(context).pop(); // Close CameraView
        //         // Navigate to VideoEditView
        //         Navigator.of(context).push(
        //           MaterialPageRoute(
        //             builder: (context) => VideoEditView(
        //               videoFile: File(video.path),
        //               onCancel: () => Navigator.of(context).pop(),
        //               onNext: () {
        //                 // Handle next step (publishing, etc.)
        //                 Navigator.of(context).pop();
        //               },
        //             ),
        //           ),
        //         );
        //       },
        //     ),
        //   ),
        // );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video editing features coming soon!')),
        );
      }
    } catch (e) {
      debugPrint('Error picking video from gallery: $e');
      _showErrorDialog('Error selecting video');
    }
  }


  void _toggleGrid() {
    setState(() {
      _showGrid = !_showGrid;
    });
  }

  void _showErrorDialog(String message) {
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Full-screen, razor-sharp preview layout (no stretch, no blur)
          _buildFullScreenPreview(),
          
          // Top Controls
          _buildTopControls(),
          
          // Bottom Controls
          _buildBottomControls(),
          
          // Grid Lines
          if (_showGrid) _buildGridLines(),
        ],
      ),
    );
  }

  // Full-screen, razor-sharp preview layout (no stretch, no blur)
  Widget _buildFullScreenPreview() {
    if (!_isInitialized || _cameraController == null) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    final screenSize = MediaQuery.of(context).size;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _onTapToFocus,
      onScaleUpdate: _onScaleUpdate,
      child: Stack(
        children: [
          // Truly fullscreen preview - fill entire screen height
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: screenSize.width,
                height: screenSize.height,
                child: CameraPreview(_cameraController!),
              ),
            ),
          ),
          // Focus indicator
          if (_focusPoint != null && _isFocusing)
            Positioned(
              left: _focusPoint!.dx - 30,
              top: _focusPoint!.dy - 30,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.8),
                    width: 2,
                  ),
                ),
              ),
            ),
          // Zoom indicator
          if (_currentZoom > 1.0)
            Positioned(
              top: MediaQuery.of(context).padding.top + 120,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${_currentZoom.toStringAsFixed(1)}x',
                  style: const TextStyle(
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

  Widget _buildTopControls() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Close button
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          
          // Grid toggle
          GestureDetector(
            onTap: _toggleGrid,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _showGrid ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.grid_on,
                color: _showGrid ? Colors.white : Colors.white.withValues(alpha: 0.7),
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 20,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Gallery button (TikTok style - video only)
          GestureDetector(
            onTap: _pickFromGallery,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
              ),
              child: const Icon(
                Icons.photo_library_outlined,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
          
          // Record button
          GestureDetector(
            onTap: _isRecording ? _stopRecording : _startRecording,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _isRecording ? Colors.red : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: _isRecording ? Colors.red : Colors.white,
                  width: 4,
                ),
              ),
              child: Center(
                child: _isRecording
                    ? const Icon(
                        Icons.stop,
                        color: Colors.white,
                        size: 32,
                      )
                    : Container(
                        width: 60,
                        height: 60,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
              ),
            ),
          ),
          
          // Camera flip button
          GestureDetector(
            onTap: () {
              // Camera flip functionality can be added here if needed
              HapticFeedback.lightImpact();
            },
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
              ),
              child: const Icon(
                Icons.flip_camera_ios_outlined,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridLines() {
    return CustomPaint(
      painter: GridPainter(),
      size: Size.infinite,
    );
  }
}

// Simple grid painter
class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 1.0;

    // Vertical lines
    for (int i = 1; i < 3; i++) {
      final double x = size.width * i / 3;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    // Horizontal lines
    for (int i = 1; i < 3; i++) {
      final double y = size.height * i / 3;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
