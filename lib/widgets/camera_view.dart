import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:video_player/video_player.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:async';
import 'video_recording_preview.dart';
import 'video_editing_screen.dart' as editing;
import '../services/enhanced_error_handling_service.dart';


enum NavigationState {
  none,
  recordingPreview,
  editDescription,
  editVideo,
  share,
}

class CameraView extends StatefulWidget {
  const CameraView({super.key});

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> with TickerProviderStateMixin {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isRecording = false;
  List<File> _recordedClips = [];
  NavigationState _navigationState = NavigationState.none;
  File? _currentVideoFile;
  VideoPlayerController? _previewController;
  bool _isInitialized = false;
  bool _isFrontCamera = false;
  double _recordingProgress = 0.0;
  int _recordingDuration = 0;
  late AnimationController _pulseController;
  late AnimationController _recordButtonController;
  
  // New UI state variables
  bool _isFlashOn = false;
  bool _showFilters = false;
  String _selectedFilter = 'none';
  bool _showGrid = false;
  bool _showTimer = false;
  int _timerValue = 0;
  File? _lastCapturedImage;
  final ImagePicker _imagePicker = ImagePicker();
  Timer? _recordingTimer;
  
  // Focus and zoom variables
  Offset? _focusPoint;
  double _currentZoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 4.0;
  bool _isFocusing = false;
  late AnimationController _focusAnimationController;
  final EnhancedErrorHandlingService _errorHandler = EnhancedErrorHandlingService();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _recordButtonController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _focusAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _checkPermissionsAndInitialize();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _previewController?.dispose();
    _pulseController.dispose();
    _recordButtonController.dispose();
    _focusAnimationController.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkPermissionsAndInitialize() async {
    try {
      // Check camera permission
      final cameraStatus = await Permission.camera.status;
      final micStatus = await Permission.microphone.status;
      
      if (cameraStatus.isGranted && micStatus.isGranted) {
        // Permissions already granted, initialize camera immediately
        await _initializeCamera();
      } else {
        // Request permissions
        final cameraResult = await Permission.camera.request();
        final micResult = await Permission.microphone.request();
        
        if (cameraResult.isGranted && micResult.isGranted) {
          await _initializeCamera();
        } else {
          // Handle permission denied
          await _errorHandler.handleCameraError(
            operation: 'permission_check',
            error: 'Camera or microphone permission denied',
            context: {
              'camera_status': cameraStatus.toString(),
              'microphone_status': micStatus.toString(),
            },
          );
          _showPermissionDeniedDialog();
        }
      }
    } catch (e) {
      await _errorHandler.handleCameraError(
        operation: 'permission_check',
        error: e,
        context: {'step': 'check_permissions'},
      );
      _showPermissionDeniedDialog();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras!.isNotEmpty) {
        _cameraController = CameraController(
          _cameras![_isFrontCamera ? 1 : 0],
          ResolutionPreset.high,
          enableAudio: true,
        );
        await _cameraController!.initialize();
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
        }
      } else {
        await _errorHandler.handleCameraError(
          operation: 'camera_initialization',
          error: 'No cameras available on this device',
          context: {'cameras_found': _cameras?.length ?? 0},
        );
      }
    } catch (e) {
      await _errorHandler.handleCameraError(
        operation: 'camera_initialization',
        error: e,
        context: {'cameras_found': _cameras?.length ?? 0},
      );
      debugPrint('Error initializing camera: $e');
    }
  }

  Future<void> _startRecording() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    try {
      await _cameraController!.startVideoRecording();
      setState(() {
        _isRecording = true;
        _recordingDuration = 0;
        _recordingProgress = 0.0;
      });

      // Start recording timer
      _startRecordingTimer();
    } catch (e) {
      await _errorHandler.handleCameraError(
        operation: 'start_recording',
        error: e,
        context: {
          'camera_initialized': _cameraController?.value.isInitialized ?? false,
          'is_recording': _isRecording,
        },
      );
      debugPrint('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    if (_cameraController == null || !_isRecording) return;

    try {
      final XFile videoFile = await _cameraController!.stopVideoRecording();
      setState(() {
        _isRecording = false;
        _recordedClips.add(File(videoFile.path));
        _currentVideoFile = File(videoFile.path);
        _navigationState = NavigationState.recordingPreview;
      });

      // Initialize preview player
      _initializePreviewPlayer();
    } catch (e) {
      await _errorHandler.handleCameraError(
        operation: 'stop_recording',
        error: e,
        context: {
          'camera_initialized': _cameraController?.value.isInitialized ?? false,
          'is_recording': _isRecording,
          'recording_duration': _recordingDuration,
        },
      );
      debugPrint('Error stopping recording: $e');
    }
  }

  void _startRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isRecording && mounted) {
        setState(() {
          _recordingDuration++;
          _recordingProgress = (_recordingDuration / 60.0).clamp(0.0, 1.0);
        });
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _initializePreviewPlayer() async {
    if (_currentVideoFile != null) {
      _previewController = VideoPlayerController.file(_currentVideoFile!);
      await _previewController!.initialize();
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _switchCamera() {
    if (_cameras == null || _cameras!.length < 2) return;
    
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
    // Navigate to video editing screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => editing.VideoEditingScreen(
          videoFile: _currentVideoFile!,
          onCancel: () => Navigator.of(context).pop(),
          onSave: _onSaveVideo,
        ),
      ),
    );
  }

  void _onSaveVideo() {
    // This method is called after successful video processing
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Video processed successfully! 🎉'),
        backgroundColor: Color(0xFF9248d2),
        duration: Duration(seconds: 3),
      ),
    );
    
    // Reset camera state
    setState(() {
      _navigationState = NavigationState.none;
      _currentVideoFile = null;
      _recordedClips.clear();
    });
    
    // Navigate back to profile or home
    Navigator.of(context).pop();
  }

  // New UI methods
  void _toggleFlash() {
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      setState(() {
        _isFlashOn = !_isFlashOn;
      });
      _cameraController!.setFlashMode(_isFlashOn ? FlashMode.torch : FlashMode.off);
    }
  }

  void _toggleFilters() {
    setState(() {
      _showFilters = !_showFilters;
    });
  }

  void _toggleGrid() {
    setState(() {
      _showGrid = !_showGrid;
    });
  }

  void _toggleTimer() {
    setState(() {
      _showTimer = !_showTimer;
      if (!_showTimer) _timerValue = 0;
    });
  }

  void _setTimer(int seconds) {
    setState(() {
      _timerValue = seconds;
    });
  }

  // Focus and zoom methods
  void _onTapToFocus(TapDownDetails details) async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    try {
      final RenderBox renderBox = context.findRenderObject() as RenderBox;
      final Offset localPoint = renderBox.globalToLocal(details.globalPosition);
      
      // Calculate focus point relative to camera preview
      final double x = localPoint.dx / renderBox.size.width;
      final double y = localPoint.dy / renderBox.size.height;
      
      setState(() {
        _focusPoint = localPoint;
        _isFocusing = true;
      });

      // Start focus animation
      _focusAnimationController.forward().then((_) {
        _focusAnimationController.reverse();
      });

      // Set focus point on camera
      await _cameraController!.setFocusPoint(Offset(x, y));
      await _cameraController!.setFocusMode(FocusMode.auto);

      // Hide focus indicator after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _isFocusing = false;
          });
        }
      });

      // Haptic feedback
      HapticFeedback.lightImpact();
    } catch (e) {
      await _errorHandler.handleCameraError(
        operation: 'tap_to_focus',
        error: e,
        context: {
          'camera_initialized': _cameraController?.value.isInitialized ?? false,
          'focus_point': details.globalPosition.toString(),
        },
      );
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails details) async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    try {
      final double newZoom = (_currentZoom * details.scale).clamp(_minZoom, _maxZoom);
      
      setState(() {
        _currentZoom = newZoom;
      });

      await _cameraController!.setZoomLevel(newZoom);
    } catch (e) {
      await _errorHandler.handleCameraError(
        operation: 'zoom_update',
        error: e,
        context: {
          'camera_initialized': _cameraController?.value.isInitialized ?? false,
          'current_zoom': _currentZoom,
          'new_zoom': (_currentZoom * details.scale).clamp(_minZoom, _maxZoom),
        },
      );
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    // Optional: Add momentum or snap to zoom levels
  }

  Future<void> _openGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _lastCapturedImage = File(image.path);
        });
        // Navigate to gallery or show image
      }
    } catch (e) {
      debugPrint('Error opening gallery: $e');
    }
  }

  Future<void> _capturePhoto() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    try {
      final XFile photo = await _cameraController!.takePicture();
      setState(() {
        _lastCapturedImage = File(photo.path);
      });
      HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint('Error capturing photo: $e');
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
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            _buildSettingsItem(
              icon: Icons.grid_on,
              title: 'Grid Lines',
              subtitle: 'Show composition grid',
              onTap: () {
                Navigator.pop(context);
                _toggleGrid();
              },
            ),
            _buildSettingsItem(
              icon: Icons.timer,
              title: 'Timer',
              subtitle: 'Set countdown timer',
              onTap: () {
                Navigator.pop(context);
                _showTimerOptions();
              },
            ),
            _buildSettingsItem(
              icon: Icons.flash_on,
              title: 'Flash',
              subtitle: _isFlashOn ? 'Flash On' : 'Flash Off',
              onTap: () {
                Navigator.pop(context);
                _toggleFlash();
              },
            ),
            _buildSettingsItem(
              icon: Icons.photo_camera,
              title: 'Take Photo',
              subtitle: 'Capture a photo',
              onTap: () {
                Navigator.pop(context);
                _capturePhoto();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
      ),
      onTap: onTap,
    );
  }

  void _showTimerOptions() {
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
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Timer Options',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildTimerOption(0, 'Off'),
                _buildTimerOption(3, '3s'),
                _buildTimerOption(5, '5s'),
                _buildTimerOption(10, '10s'),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerOption(int seconds, String label) {
    final isSelected = _timerValue == seconds;
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        _setTimer(seconds);
        if (seconds > 0) {
          _toggleTimer();
        }
      },
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF9248D2) : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
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
    
    if (_navigationState == NavigationState.editDescription && _currentVideoFile != null) {
      return editing.VideoEditingScreen(
        videoFile: _currentVideoFile!,
        onCancel: _onBack,
        onSave: _onSaveVideo,
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Preview
          _buildCameraPreview(),

          // Status Bar (Time, Signal, Battery)
          _buildStatusBar(),

          // Top Controls (Close, Flash)
          _buildTopControls(),

          // Right Side Controls (Filters, Settings)
          _buildRightControls(),

          // Bottom Controls (Gallery, Record, Switch Camera)
          _buildBottomControls(),

          // Recording Progress
          if (_isRecording) _buildRecordingProgress(),

          // Mode Selector

          // Grid Lines
          if (_showGrid) _buildGridLines(),

          // Filters Overlay
          if (_showFilters) _buildFiltersOverlay(),

          // Timer Overlay
          if (_showTimer && _timerValue > 0) _buildTimerOverlay(),
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
      onScaleEnd: _onScaleEnd,
      child: Stack(
        children: [
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _cameraController!.value.previewSize?.width ?? 400,
                height: _cameraController!.value.previewSize?.height ?? 300,
                child: CameraPreview(_cameraController!),
              ),
            ),
          ),
          // Focus indicator
          if (_focusPoint != null && _isFocusing)
            Positioned(
              left: _focusPoint!.dx - 30,
              top: _focusPoint!.dy - 30,
              child: AnimatedBuilder(
                animation: _focusAnimationController,
                builder: (context, child) {
                  return Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.8),
                        width: 2,
                      ),
                    ),
                    child: Container(
                      margin: EdgeInsets.all(8 + (_focusAnimationController.value * 4)),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.6),
                          width: 1,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          // Zoom level indicator
          if (_currentZoom > 1.0)
            Positioned(
              top: MediaQuery.of(context).padding.top + 120,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
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


  Widget _buildStatusBar() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 16,
      right: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Time display
          const Text(
            '3:28', // This would be dynamic in a real app
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          // Status indicators (Signal, Wi-Fi, Battery)
          Row(
            children: [
              const Icon(Icons.signal_cellular_4_bar, color: Colors.white, size: 16),
              const SizedBox(width: 4),
              const Icon(Icons.wifi, color: Colors.white, size: 16),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '29',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopControls() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 50,
      left: 16,
      right: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Close button
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          // Flash toggle
          GestureDetector(
            onTap: _toggleFlash,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                _isFlashOn ? Icons.flash_on : Icons.flash_off,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightControls() {
    return Positioned(
      right: 16,
      top: MediaQuery.of(context).padding.top + 100,
      child: Column(
        children: [
          // Filters button
          GestureDetector(
            onTap: _toggleFilters,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(25),
              ),
              child: const Icon(
                Icons.face,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Settings/More button
          GestureDetector(
            onTap: _showSettingsMenu,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(25),
              ),
              child: const Icon(
                Icons.keyboard_arrow_down,
                color: Colors.white,
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
      bottom: MediaQuery.of(context).padding.bottom + 32,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Gallery Thumbnail
          GestureDetector(
            onTap: _openGallery,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: _lastCapturedImage != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.file(
                        _lastCapturedImage!,
                        fit: BoxFit.cover,
                        width: 50,
                        height: 50,
                      ),
                    )
                  : const Icon(
                      Icons.photo_library,
                      color: Colors.white,
                      size: 24,
                    ),
            ),
          ),
          // Record Button
          GestureDetector(
            onTap: _isRecording ? _stopRecording : _startRecording,
            onLongPress: _capturePhoto,
            onTapDown: (_) => _recordButtonController.forward(),
            onTapUp: (_) => _recordButtonController.reverse(),
            onTapCancel: () => _recordButtonController.reverse(),
            child: AnimatedBuilder(
              animation: _recordButtonController,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1.0 - (_recordButtonController.value * 0.1),
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF9248D2), Color(0xFF1670DE)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: Colors.white,
                        width: 4,
                      ),
                    ),
                    child: _isRecording
                        ? AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              return Container(
                                margin: EdgeInsets.all(8 + (_pulseController.value * 4)),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.red,
                                ),
                              );
                            },
                          )
                        : Container(
                            margin: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                          ),
                  ),
                );
              },
            ),
          ),
          // Switch Camera
          GestureDetector(
            onTap: _switchCamera,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
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

  Widget _buildRecordingProgress() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 80,
      left: 16,
      right: 16,
      child: Column(
        children: [
          // Recording indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'REC ${_recordingDuration}s',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Progress bar
          LinearProgressIndicator(
            value: _recordingProgress,
            backgroundColor: Colors.white.withValues(alpha: 0.3),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
            minHeight: 4,
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

  Widget _buildFiltersOverlay() {
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 120,
      left: 0,
      right: 0,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: 10,
                itemBuilder: (context, index) {
                  final filters = ['None', 'Vintage', 'B&W', 'Sepia', 'Cool', 'Warm', 'Bright', 'Dark', 'Blur', 'Sharp'];
                  final isSelected = _selectedFilter == filters[index].toLowerCase();
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedFilter = filters[index].toLowerCase();
                      });
                    },
                    child: Container(
                      width: 60,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          filters[index],
                          style: TextStyle(
                            color: isSelected ? Colors.black : Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerOverlay() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 120,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Timer: ${_timerValue}s',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// Custom painter for grid lines
class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.3)
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