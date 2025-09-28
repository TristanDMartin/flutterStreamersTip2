import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

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
    log("📱 CameraService: Initializing...");
    _startCameraInstantly();
  }

  void _startCameraInstantly() {
    log("📱 CameraService: Starting camera instantly...");
    
    // Check if we already have permission
    _checkPermissionsAndConfigure();
  }

  Future<void> _checkPermissionsAndConfigure() async {
    log("📱 CameraService: checkPermissionsAndConfigure called");
    
    // Clear any existing error message first
    _errorMessage = null;
    notifyListeners();
    
    // Check current permission status for both camera and microphone
    final cameraStatus = await Permission.camera.status;
    final micStatus = await Permission.microphone.status;
    log("📱 CameraService: Video authorization status: ${cameraStatus.name}");
    log("📱 CameraService: Audio authorization status: ${micStatus.name}");
    
    // Handle video permissions first
    if (cameraStatus.isGranted) {
      log("📱 CameraService: Video already authorized, checking audio...");
      await _checkAudioPermissionsAndConfigure();
    } else if (cameraStatus.isDenied) {
      log("📱 CameraService: Requesting video permission...");
      final result = await Permission.camera.request();
      if (result.isGranted) {
        log("📱 CameraService: Video permission granted, checking audio...");
        await _checkAudioPermissionsAndConfigure();
      } else {
        log("❌ CameraService: Video permission denied");
        _errorMessage = "Camera access is required to use this feature. Please enable it in Settings.";
        notifyListeners();
      }
    } else {
      log("❌ CameraService: Video permission denied/restricted");
      _errorMessage = "Camera access is required. Please enable it in Settings.";
      notifyListeners();
    }
  }

  Future<void> _checkAudioPermissionsAndConfigure() async {
    final micStatus = await Permission.microphone.status;
    
    if (micStatus.isGranted) {
      log("📱 CameraService: Audio already authorized, configuring session...");
      await _configureSession();
    } else if (micStatus.isDenied) {
      log("📱 CameraService: Requesting audio permission...");
      final result = await Permission.microphone.request();
      if (result.isGranted) {
        log("📱 CameraService: Audio permission granted, configuring session...");
        await _configureSession();
      } else {
        log("⚠️ CameraService: Audio permission denied, configuring without audio...");
        await _configureSession();
      }
    } else {
      log("⚠️ CameraService: Audio permission denied/restricted, configuring without audio...");
      await _configureSession();
    }
  }

  Future<void> _configureSession() async {
    log("📱 CameraService: Configuring camera session...");
    
    try {
      // Get available cameras
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        log("❌ CameraService: No cameras available");
        _errorMessage = "Could not access camera device";
        notifyListeners();
        return;
      }
      
      // Dispose of existing controller if any
      await _cameraController?.dispose();
      
      // Initialize camera controller with balanced quality settings
      _cameraController = CameraController(
        _cameras[_selectedCameraIndex],
        ResolutionPreset.medium, // Use medium resolution to prevent buffer overflow
        enableAudio: true,
        imageFormatGroup: ImageFormatGroup.yuv420, // Use YUV420 to prevent buffer issues
      );
      
      await _cameraController!.initialize();
      
      // Apply high quality camera settings
      await _cameraController!.setFlashMode(FlashMode.off);
      await _cameraController!.setFocusMode(FocusMode.auto);
      await _cameraController!.setExposureMode(ExposureMode.auto);
      
      log("✅ CameraService: Session configuration complete");
      
      // Start session
      await _startSession();
      
    } catch (e) {
      log("❌ CameraService: Error configuring session: $e");
      _errorMessage = "Failed to configure camera: $e";
      notifyListeners();
    }
  }

  Future<void> _startSession() async {
    try {
      log("📱 CameraService: Starting camera session...");
      
      // Start the session
      await _cameraController!.startImageStream((image) {
        // This ensures the camera is running
      });
      
      _isSessionRunning = true;
      _errorMessage = null;
      log("✅ CameraService: Camera session started successfully");
      
    } catch (e) {
      log("❌ CameraService: Session failed to start: $e");
      _errorMessage = "Camera session failed to start";
      _isSessionRunning = false;
    }
    
    notifyListeners();
  }

  void resetCamera() {
    log("📱 CameraService: Resetting camera session...");
    
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
      log("📱 CameraService: Camera session stopped");
    } catch (e) {
      log("❌ CameraService: Error stopping session: $e");
    }
  }

  void ensureSessionIsRunning() {
    if (!_isSessionRunning) {
      log("📱 CameraService: Session not running, starting...");
      _startSession();
    } else {
      log("📱 CameraService: Session is already running");
    }
  }

  Future<void> startRecording() async {
    log("📱 CameraService: startRecording() called");
    
    // Check mic permission for recording
    final micStatus = await Permission.microphone.status;
    if (micStatus.isDenied) {
      log("📱 CameraService: Requesting mic permission...");
      final result = await Permission.microphone.request();
      if (!result.isGranted) {
        log("📱 CameraService: Mic permission denied");
        _errorMessage = "Microphone access is required for video recording";
        notifyListeners();
        return;
      }
    }

    if (_isRecording) { 
      log("📱 CameraService: Already recording, ignoring start request");
      return; 
    }
    
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      log("❌ CameraService: Camera not initialized");
      return;
    }
    
    try {
      log("📱 CameraService: Starting recording...");
      
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
      
      log("📱 CameraService: Recording started successfully");
      notifyListeners();
      
    } catch (e) {
      log("❌ CameraService: Failed to start recording: $e");
      _errorMessage = "Failed to start recording: $e";
      notifyListeners();
    }
  }

  Future<void> stopRecording() async {
    log("📱 CameraService: stopRecording() called");
    
    if (!_isRecording) { 
      log("📱 CameraService: Not recording, ignoring stop request");
      return; 
    }
    
    try {
      log("📱 CameraService: Stopping recording...");
      
      // Stop recording
      final file = await _cameraController!.stopVideoRecording();
      
      _isRecording = false;
      _recordingProgress = 0.0;
      _recordingStartTime = null;
      // Save last recorded file path
      try {
        _currentRecordingFile = File(file.path);
      } catch (_) {}
      
      // Stop progress timer
      _stopProgressTimer();
      
      log("📱 CameraService: Recording stopped successfully");
      notifyListeners();
      
    } catch (e) {
      log("❌ CameraService: Failed to stop recording: $e");
      _errorMessage = "Failed to stop recording: $e";
      _isRecording = false;
      notifyListeners();
    }
  }

  void _startProgressTimer() {
    _recordingTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!_isRecording) {
        timer.cancel();
        return;
      }
      
      // Calculate progress based on elapsed time (max 15 seconds)
      const maxDuration = Duration(seconds: 15);
      final elapsed = DateTime.now().difference(_recordingStartTime ?? DateTime.now());
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
        log("📱 CameraService: Recording discarded");
      } catch (e) {
        log("❌ CameraService: Failed to delete recording: $e");
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
    log("📱 CameraService: flipCamera() called");
    log("📱 CameraService: Current position: $_selectedCameraIndex");
    
    if (_cameras.length <= 1) {
      log("📱 CameraService: Only one camera available, cannot flip");
      return;
    }
    
    try {
      // Stop current session
      await _stopSession();
      
      // Toggle camera index
      _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
      log("📱 CameraService: New position: $_selectedCameraIndex");
      
      // Reconfigure with new camera
      await _configureSession();
      
      log("📱 CameraService: Camera flipped successfully");
      
    } catch (e) {
      log("❌ CameraService: Failed to flip camera: $e");
      _errorMessage = "Failed to flip camera: $e";
      notifyListeners();
    }
  }

  Future<String?> capturePhoto() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      log("❌ CameraService: Camera not initialized");
      return null;
    }
    
    try {
      log("📱 CameraService: Capturing photo...");
      
      final image = await _cameraController!.takePicture();
      log("✅ CameraService: Photo captured: ${image.path}");
      
      // You can return the image path or handle it as needed
      return image.path;
      
    } catch (e) {
      log("❌ CameraService: Failed to capture photo: $e");
      _errorMessage = "Failed to capture photo: $e";
      notifyListeners();
      return null;
    }
  }

  Future<void> toggleFlash() async {
    log("📱 CameraService: toggleFlash() called");
    log("📱 CameraService: Current flash state: $_isFlashOn");
    
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      log("❌ CameraService: Camera not initialized, cannot toggle flash");
      return;
    }
    
    try {
      if (_isFlashOn) {
        await _cameraController!.setFlashMode(FlashMode.off);
        _isFlashOn = false;
        log("📱 CameraService: Flash turned OFF");
      } else {
        await _cameraController!.setFlashMode(FlashMode.torch);
        _isFlashOn = true;
        log("📱 CameraService: Flash turned ON");
      }
      
      notifyListeners();
      
    } catch (e) {
      log("❌ CameraService: Failed to toggle flash: $e");
      _isFlashOn = false;
      notifyListeners();
    }
  }

  void stopCamera() {
    log("📱 CameraService: Stopping camera session");
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
