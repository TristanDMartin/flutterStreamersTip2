import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:streamers_tip/utils/secure_log.dart';

import '../utils/swallow_non_fatal.dart';

class CameraService extends ChangeNotifier {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;
  bool _isSessionRunning = false;
  bool _isRecording = false;
  double _recordingProgress = 0.0;
  DateTime? _recordingStartTime;
  bool _isFlashOn = false;
  String? _errorMessage;
  Timer? _recordingTimer;
  File? _currentRecordingFile;

  // Getters
  bool get isSessionRunning => _isSessionRunning;
  bool get isRecording => _isRecording;
  double get recordingProgress => _recordingProgress;
  DateTime? get recordingStartTime => _recordingStartTime;
  bool get isFlashOn => _isFlashOn;
  String? get errorMessage => _errorMessage;
  CameraController? get cameraController => _cameraController;
  List<CameraDescription> get cameras => _cameras;
  int get selectedCameraIndex => _selectedCameraIndex;
  String? get lastRecordedVideoPath => _currentRecordingFile?.path;

  CameraService() {
    secureLog("📱 CameraService: Initializing...");
    _startCameraInstantly();
  }

  void _startCameraInstantly() {
    secureLog("📱 CameraService: Starting camera instantly...");

    // Check if we already have permission
    _checkPermissionsAndConfigure();
  }

  Future<void> _checkPermissionsAndConfigure() async {
    secureLog("📱 CameraService: checkPermissionsAndConfigure called");

    // Clear any existing error message first
    _errorMessage = null;
    notifyListeners();

    // Check current permission status for both camera and microphone
    final cameraStatus = await Permission.camera.status;
    final micStatus = await Permission.microphone.status;
    secureLog(
        "📱 CameraService: Video authorization status: ${cameraStatus.name}");
    secureLog(
        "📱 CameraService: Audio authorization status: ${micStatus.name}");

    // Handle video permissions first
    if (cameraStatus.isGranted) {
      secureLog(
          "📱 CameraService: Video already authorized, checking audio...");
      await _checkAudioPermissionsAndConfigure();
    } else if (cameraStatus.isDenied) {
      secureLog("📱 CameraService: Requesting video permission...");
      final result = await Permission.camera.request();
      if (result.isGranted) {
        secureLog(
            "📱 CameraService: Video permission granted, checking audio...");
        await _checkAudioPermissionsAndConfigure();
      } else {
        secureLog("❌ CameraService: Video permission denied");
        _errorMessage =
            "Camera access is required to use this feature. Please enable it in Settings.";
        notifyListeners();
      }
    } else {
      secureLog("❌ CameraService: Video permission denied/restricted");
      _errorMessage =
          "Camera access is required. Please enable it in Settings.";
      notifyListeners();
    }
  }

  Future<void> _checkAudioPermissionsAndConfigure() async {
    final micStatus = await Permission.microphone.status;

    if (micStatus.isGranted) {
      secureLog(
          "📱 CameraService: Audio already authorized, configuring session...");
      await _configureSession();
    } else if (micStatus.isDenied) {
      secureLog("📱 CameraService: Requesting audio permission...");
      final result = await Permission.microphone.request();
      if (result.isGranted) {
        secureLog(
            "📱 CameraService: Audio permission granted, configuring session...");
        await _configureSession();
      } else {
        secureLog(
            "⚠️ CameraService: Audio permission denied, configuring without audio...");
        await _configureSession();
      }
    } else {
      secureLog(
          "⚠️ CameraService: Audio permission denied/restricted, configuring without audio...");
      await _configureSession();
    }
  }

  Future<void> _configureSession() async {
    secureLog("📱 CameraService: Configuring camera session...");

    try {
      // Get available cameras
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        secureLog("❌ CameraService: No cameras available");
        _errorMessage = "Could not access camera device";
        notifyListeners();
        return;
      }

      // Dispose of existing controller if any
      await _cameraController?.dispose();

      // Initialize camera controller with balanced quality settings
      _cameraController = CameraController(
        _cameras[_selectedCameraIndex],
        ResolutionPreset
            .medium, // Use medium resolution to prevent buffer overflow
        enableAudio: true,
        imageFormatGroup:
            ImageFormatGroup.yuv420, // Use YUV420 to prevent buffer issues
      );

      await _cameraController!.initialize();

      // Apply high quality camera settings
      await _cameraController!.setFlashMode(FlashMode.off);
      await _cameraController!.setFocusMode(FocusMode.auto);
      await _cameraController!.setExposureMode(ExposureMode.auto);

      secureLog("✅ CameraService: Session configuration complete");

      // Start session
      await _startSession();
    } catch (e) {
      secureLog("❌ CameraService: Error configuring session: $e");
      _errorMessage = "Failed to configure camera: $e";
      notifyListeners();
    }
  }

  Future<void> _startSession() async {
    try {
      secureLog("📱 CameraService: Starting camera session...");

      // Start the session
      await _cameraController!.startImageStream((image) {
        // This ensures the camera is running
      });

      _isSessionRunning = true;
      _errorMessage = null;
      secureLog("✅ CameraService: Camera session started successfully");
    } catch (e) {
      secureLog("❌ CameraService: Session failed to start: $e");
      _errorMessage = "Camera session failed to start";
      _isSessionRunning = false;
    }

    notifyListeners();
  }

  void resetCamera() {
    secureLog("📱 CameraService: Resetting camera session...");

    // Stop current session
    _stopSession();

    // Clear error message
    _errorMessage = null;
    _isSessionRunning = false;
    notifyListeners();

    // Wait a moment then reconfigure
    Timer(const Duration(milliseconds: 500), () {
      _checkPermissionsAndConfigure();
    });
  }

  Future<void> _stopSession() async {
    try {
      await _cameraController?.stopImageStream();
      _isSessionRunning = false;
      secureLog("📱 CameraService: Camera session stopped");
    } catch (e) {
      secureLog("❌ CameraService: Error stopping session: $e");
    }
  }

  void ensureSessionIsRunning() {
    if (!_isSessionRunning) {
      secureLog("📱 CameraService: Session not running, starting...");
      _startSession();
    } else {
      secureLog("📱 CameraService: Session is already running");
    }
  }

  Future<void> startRecording() async {
    secureLog("📱 CameraService: startRecording() called");

    // Check mic permission for recording
    final micStatus = await Permission.microphone.status;
    if (micStatus.isDenied) {
      secureLog("📱 CameraService: Requesting mic permission...");
      final result = await Permission.microphone.request();
      if (!result.isGranted) {
        secureLog("📱 CameraService: Mic permission denied");
        _errorMessage = "Microphone access is required for video recording";
        notifyListeners();
        return;
      }
    }

    if (_isRecording) {
      secureLog("📱 CameraService: Already recording, ignoring start request");
      return;
    }

    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      secureLog("❌ CameraService: Camera not initialized");
      return;
    }

    try {
      secureLog("📱 CameraService: Starting recording...");

      // Create temporary file for recording
      final tempDir = await getTemporaryDirectory();
      final fileName = 'recording_${DateTime.now().millisecondsSinceEpoch}.mp4';
      _currentRecordingFile = File('${tempDir.path}/$fileName');

      // Start recording
      await _cameraController!.startVideoRecording();

      _isRecording = true;
      _recordingStartTime = DateTime.now();
      _recordingProgress = 0.0;

      // Start progress timer
      _startProgressTimer();

      secureLog("📱 CameraService: Recording started successfully");
      notifyListeners();
    } catch (e) {
      secureLog("❌ CameraService: Failed to start recording: $e");
      _errorMessage = "Failed to start recording: $e";
      notifyListeners();
    }
  }

  Future<void> stopRecording() async {
    secureLog("📱 CameraService: stopRecording() called");

    if (!_isRecording) {
      secureLog("📱 CameraService: Not recording, ignoring stop request");
      return;
    }

    try {
      secureLog("📱 CameraService: Stopping recording...");

      // Stop recording
      final file = await _cameraController!.stopVideoRecording();

      _isRecording = false;
      _recordingProgress = 0.0;
      _recordingStartTime = null;
      // Save last recorded file path
      try {
        _currentRecordingFile = File(file.path);
      } catch (e, st) {
        swallowNonFatal('CameraService.recordingFile', e, st);
      }

      // Stop progress timer
      _stopProgressTimer();

      secureLog("📱 CameraService: Recording stopped successfully");
      notifyListeners();
    } catch (e) {
      secureLog("❌ CameraService: Failed to stop recording: $e");
      _errorMessage = "Failed to stop recording: $e";
      _isRecording = false;
      notifyListeners();
    }
  }

  void _startProgressTimer() {
    _recordingTimer =
        Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!_isRecording) {
        timer.cancel();
        return;
      }

      // Calculate progress based on elapsed time (max 15 seconds)
      const maxDuration = Duration(seconds: 15);
      final elapsed =
          DateTime.now().difference(_recordingStartTime ?? DateTime.now());
      _recordingProgress = elapsed.inMilliseconds / maxDuration.inMilliseconds;

      // Auto-stop recording if max duration reached
      if (_recordingProgress >= 1.0) {
        stopRecording();
        timer.cancel();
      }

      notifyListeners();
    });
  }

  void _stopProgressTimer() {
    _recordingTimer?.cancel();
    _recordingProgress = 0.0;
  }

  void discardRecording() {
    if (_currentRecordingFile != null && _currentRecordingFile!.existsSync()) {
      try {
        _currentRecordingFile!.deleteSync();
        secureLog("📱 CameraService: Recording discarded");
      } catch (e) {
        secureLog("❌ CameraService: Failed to delete recording: $e");
      }
    }
    _currentRecordingFile = null;
    _isRecording = false;
    _recordingProgress = 0.0;
    notifyListeners();
  }

  String? getRecordingPath() {
    return _currentRecordingFile?.path;
  }

  Future<void> flipCamera() async {
    secureLog("📱 CameraService: flipCamera() called");
    secureLog("📱 CameraService: Current position: $_selectedCameraIndex");

    if (_cameras.length <= 1) {
      secureLog("📱 CameraService: Only one camera available, cannot flip");
      return;
    }

    try {
      // Stop current session
      await _stopSession();

      // Toggle camera index
      _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
      secureLog("📱 CameraService: New position: $_selectedCameraIndex");

      // Reconfigure with new camera
      await _configureSession();

      secureLog("📱 CameraService: Camera flipped successfully");
    } catch (e) {
      secureLog("❌ CameraService: Failed to flip camera: $e");
      _errorMessage = "Failed to flip camera: $e";
      notifyListeners();
    }
  }

  Future<String?> capturePhoto() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      secureLog("❌ CameraService: Camera not initialized");
      return null;
    }

    try {
      secureLog("📱 CameraService: Capturing photo...");

      final image = await _cameraController!.takePicture();
      secureLog("✅ CameraService: Photo captured: ${image.path}");

      // You can return the image path or handle it as needed
      return image.path;
    } catch (e) {
      secureLog("❌ CameraService: Failed to capture photo: $e");
      _errorMessage = "Failed to capture photo: $e";
      notifyListeners();
      return null;
    }
  }

  Future<void> toggleFlash() async {
    secureLog("📱 CameraService: toggleFlash() called");
    secureLog("📱 CameraService: Current flash state: $_isFlashOn");

    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      secureLog("❌ CameraService: Camera not initialized, cannot toggle flash");
      return;
    }

    try {
      if (_isFlashOn) {
        await _cameraController!.setFlashMode(FlashMode.off);
        _isFlashOn = false;
        secureLog("📱 CameraService: Flash turned OFF");
      } else {
        await _cameraController!.setFlashMode(FlashMode.torch);
        _isFlashOn = true;
        secureLog("📱 CameraService: Flash turned ON");
      }

      notifyListeners();
    } catch (e) {
      secureLog("❌ CameraService: Failed to toggle flash: $e");
      _isFlashOn = false;
      notifyListeners();
    }
  }

  void stopCamera() {
    secureLog("📱 CameraService: Stopping camera session");
    _stopSession();
    _isSessionRunning = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }
}
