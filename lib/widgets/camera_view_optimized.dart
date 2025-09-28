import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:video_player/video_player.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:async';
import 'video_recording_preview.dart';
import 'video_edit_view.dart';

enum NavigationState {
  none,
  recordingPreview,
  editDescription,
  editVideo,
  share,
}

class CameraViewOptimized extends StatefulWidget {
  const CameraViewOptimized({super.key});

  @override
  State<CameraViewOptimized> createState() => _CameraViewOptimizedState();
}

class _CameraViewOptimizedState extends State<CameraViewOptimized> {
  // Core camera functionality only
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isRecording = false;
  bool _isInitialized = false;
  bool _isFrontCamera = false;
  
  // Recording state
  File? _currentVideoFile;
  VideoPlayerController? _previewController;
  NavigationState _navigationState = NavigationState.none;
  Timer? _recordingTimer;
  int _recordingDuration = 0;
  
  // Simple UI state
  bool _showGrid = false;
  final ImagePicker _imagePicker = ImagePicker();
  
  // Focus and zoom (simplified)
  Offset? _focusPoint;
  double _currentZoom = 1.0;
  bool _isFocusing = false;

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndInitialize();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _previewController?.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkPermissionsAndInitialize() async {
    try {
      final cameraStatus = await Permission.camera.status;
      final micStatus = await Permission.microphone.status;
      
      if (cameraStatus.isGranted && micStatus.isGranted) {
        await _initializeCamera();
      } else {
        final cameraResult = await Permission.camera.request();
        final micResult = await Permission.microphone.request();
        
        if (cameraResult.isGranted && micResult.isGranted) {
          await _initializeCamera();
        } else {
          _showPermissionDeniedDialog();
        }
      }
    } catch (e) {
      debugPrint('Error checking permissions: $e');
      _showPermissionDeniedDialog();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras!.isNotEmpty) {
        _cameraController = CameraController(
          _cameras![_isFrontCamera ? 1 : 0],
          ResolutionPreset.medium, // Use medium resolution to prevent buffer overflow
          enableAudio: true,
          imageFormatGroup: ImageFormatGroup.yuv420, // Use YUV420 to prevent buffer issues
        );
        
        await _cameraController!.initialize();
        
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  Future<void> _startRecording() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    HapticFeedback.mediumImpact();
    try {
      await _cameraController!.startVideoRecording();
      setState(() {
        _isRecording = true;
        _recordingDuration = 0;
      });

      _startRecordingTimer();
    } catch (e) {
      debugPrint('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    if (_cameraController == null || !_isRecording) return;

    // Check minimum recording duration
    if (_recordingDuration < 1) {
      _showRecordingError('Please record for at least 1 second');
      return;
    }

    HapticFeedback.mediumImpact();
    try {
      final XFile videoFile = await _cameraController!.stopVideoRecording();
      
      // Verify the video file was created and has content
      final file = File(videoFile.path);
      if (await file.exists()) {
        final fileSize = await file.length();
        debugPrint('Video file created: ${videoFile.path}, size: $fileSize bytes');
        
        if (fileSize > 0) {
          setState(() {
            _isRecording = false;
            _currentVideoFile = file;
            _navigationState = NavigationState.recordingPreview;
          });
        } else {
          debugPrint('Video file is empty, recording may have failed');
          _showRecordingError('Recording failed - empty file');
        }
      } else {
        debugPrint('Video file was not created');
        _showRecordingError('Recording failed - file not created');
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      _showRecordingError('Recording failed: ${e.toString()}');
    }
  }

  void _showRecordingError(String message) {
    setState(() {
      _isRecording = false;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _startRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isRecording && mounted) {
        setState(() {
          _recordingDuration++;
        });
      } else {
        timer.cancel();
      }
    });
  }


  void _switchCamera() {
    if (_cameras == null || _cameras!.length < 2) return;
    
    HapticFeedback.lightImpact();
    setState(() {
      _isFrontCamera = !_isFrontCamera;
    });
    _initializeCamera();
  }

  void _onBack() {
    setState(() {
      _navigationState = NavigationState.none;
      _currentVideoFile = null;
      _previewController?.dispose();
      _previewController = null;
    });
  }

  void _onNext() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VideoEditView(
          videoFile: _currentVideoFile!,
          onCancel: () => Navigator.of(context).pop(),
          onNext: _onSaveVideo,
        ),
      ),
    );
  }

  void _onSaveVideo() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Video processed successfully! 🎉'),
        backgroundColor: Color(0xFF9248d2),
        duration: Duration(seconds: 3),
      ),
    );
    
    setState(() {
      _navigationState = NavigationState.none;
      _currentVideoFile = null;
    });
    
    Navigator.of(context).pop();
  }

  void _toggleGrid() {
    setState(() {
      _showGrid = !_showGrid;
    });
  }

  void _onTapToFocus(TapDownDetails details) async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    try {
      final RenderBox renderBox = context.findRenderObject() as RenderBox;
      final Offset localPoint = renderBox.globalToLocal(details.globalPosition);
      
      final double x = localPoint.dx / renderBox.size.width;
      final double y = localPoint.dy / renderBox.size.height;
      
      setState(() {
        _focusPoint = localPoint;
        _isFocusing = true;
      });

      await _cameraController!.setFocusPoint(Offset(x, y));
      await _cameraController!.setFocusMode(FocusMode.auto);

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

  void _onScaleUpdate(ScaleUpdateDetails details) async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    try {
      final double newZoom = (_currentZoom * details.scale).clamp(1.0, 4.0);
      
      setState(() {
        _currentZoom = newZoom;
      });

      await _cameraController!.setZoomLevel(newZoom);
    } catch (e) {
      debugPrint('Error zooming: $e');
    }
  }


  Future<void> _pickFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image != null && mounted) {
        // For now, just show a success message
        // Later this will be integrated with the video editing flow
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo selected! Stories feature coming soon.'),
            backgroundColor: Color(0xFF9248d2),
            duration: Duration(seconds: 2),
          ),
        );
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      debugPrint('Error picking from gallery: $e');
    }
  }

  void _showSettingsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E1220),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.grid_on, color: Colors.white),
              title: const Text(
                'Grid Lines',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                _showGrid ? 'Hide grid' : 'Show grid',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              ),
              onTap: () {
                Navigator.pop(context);
                _toggleGrid();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0E1220),
        title: const Text(
          'Camera Access Required',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Please enable camera and microphone access in Settings to use this feature.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: const Text(
              'Open Settings',
              style: TextStyle(color: Color(0xFF9248D2)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Handle navigation states
    if (_navigationState == NavigationState.recordingPreview && _currentVideoFile != null) {
      return VideoRecordingPreview(
        videoFile: _currentVideoFile!,
        onRetake: _onBack,
        onUseVideo: _onNext,
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Preview
          _buildCameraPreview(),

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

  Widget _buildCameraPreview() {
    if (!_isInitialized || _cameraController == null) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    return GestureDetector(
      onTapDown: _onTapToFocus,
      onScaleUpdate: _onScaleUpdate,
      child: Stack(
        children: [
          // Camera preview with proper aspect ratio and front camera distortion correction
          SizedBox.expand(
            child: AspectRatio(
              aspectRatio: _cameraController!.value.aspectRatio,
              child: CameraPreview(_cameraController!),
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
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).pop();
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          // Settings button
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _showSettingsMenu();
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.settings,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 32,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Gallery Button - Single tap to open gallery (stories feature)
          GestureDetector(
            onTap: _pickFromGallery,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.photo_library,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          // Record Button - Single tap to start/stop recording
          GestureDetector(
            onTap: _isRecording ? _stopRecording : _startRecording,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isRecording ? Colors.red : Colors.white,
                border: Border.all(
                  color: Colors.white,
                  width: 4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                _isRecording ? Icons.stop : Icons.videocam,
                color: _isRecording ? Colors.white : Colors.black,
                size: 32,
              ),
            ),
          ),
          // Switch Camera
          GestureDetector(
            onTap: _switchCamera,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(25),
              ),
              child: const Icon(
                Icons.flip_camera_ios,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridLines() {
    return Positioned.fill(
      child: CustomPaint(
        painter: GridPainter(),
      ),
    );
  }
}

// Simple grid painter
class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 1.0;

    // Vertical lines
    for (int i = 1; i < 3; i++) {
      final x = size.width * i / 3;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    // Horizontal lines
    for (int i = 1; i < 3; i++) {
      final y = size.height * i / 3;
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
