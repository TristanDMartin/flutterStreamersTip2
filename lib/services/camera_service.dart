import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
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
    print("📱 CameraService: Initializing...");
    _startCameraInstantly();
  }

  void _startCameraInstantly() {
    print("📱 CameraService: Starting camera instantly...");
    
    // Check if we already have permission
    _checkPermissionsAndConfigure();
  }

  Future<void> _checkPermissionsAndConfigure() async {
    print("📱 CameraService: checkPermissionsAndConfigure called");
    
    // Clear any existing error message first
    _errorMessage = null;
    notifyListeners();
    
    // Check current permission status for both camera and microphone
    final cameraStatus = await Permission.camera.status;
    final micStatus = await Permission.microphone.status;
    print("📱 CameraService: Video authorization status: ${cameraStatus.name}");
    print("📱 CameraService: Audio authorization status: ${micStatus.name}");
    
    // Handle video permissions first
    if (cameraStatus.isGranted) {
      print("📱 CameraService: Video already authorized, checking audio...");
      await _checkAudioPermissionsAndConfigure();
    } else if (cameraStatus.isDenied) {
      print("📱 CameraService: Requesting video permission...");
      final result = await Permission.camera.request();
      if (result.isGranted) {
        print("📱 CameraService: Video permission granted, checking audio...");
        await _checkAudioPermissionsAndConfigure();
      } else {
        print("❌ CameraService: Video permission denied");
        _errorMessage = "Camera access is required to use this feature. Please enable it in Settings.";
        notifyListeners();
      }
    } else {
      print("❌ CameraService: Video permission denied/restricted");
      _errorMessage = "Camera access is required. Please enable it in Settings.";
      notifyListeners();
    }
  }

  Future<void> _checkAudioPermissionsAndConfigure() async {
    final micStatus = await Permission.microphone.status;
    
    if (micStatus.isGranted) {
      print("📱 CameraService: Audio already authorized, configuring session...");
      await _configureSession();
    } else if (micStatus.isDenied) {
      print("📱 CameraService: Requesting audio permission...");
      final result = await Permission.microphone.request();
      if (result.isGranted) {
        print("📱 CameraService: Audio permission granted, configuring session...");
        await _configureSession();
      } else {
        print("⚠️ CameraService: Audio permission denied, configuring without audio...");
        await _configureSession();
      }
    } else {
      print("⚠️ CameraService: Audio permission denied/restricted, configuring without audio...");
      await _configureSession();
    }
  }

  Future<void> _configureSession() async {
    print("📱 CameraService: Configuring camera session...");
    
    try {
      // Get available cameras
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        print("❌ CameraService: No cameras available");
        _errorMessage = "Could not access camera device";
        notifyListeners();
        return;
      }
      
      // Dispose of existing controller if any
      await _cameraController?.dispose();
      
      // Initialize camera controller
      _cameraController = CameraController(
        _cameras[_selectedCameraIndex],
        ResolutionPreset.high,
        enableAudio: true,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      
      await _cameraController!.initialize();
      
      // Set flash mode
      await _cameraController!.setFlashMode(FlashMode.off);
      
      print("✅ CameraService: Session configuration complete");
      
      // Start session
      await _startSession();
      
    } catch (e) {
      print("❌ CameraService: Error configuring session: $e");
      _errorMessage = "Failed to configure camera: $e";
      notifyListeners();
    }
  }

  Future<void> _startSession() async {
    try {
      print("📱 CameraService: Starting camera session...");
      
      // Start the session
      await _cameraController!.startImageStream((image) {
        // This ensures the camera is running
      });
      
      _isSessionRunning = true;
      _errorMessage = null;
      print("✅ CameraService: Camera session started successfully");
      
    } catch (e) {
      print("❌ CameraService: Session failed to start: $e");
      _errorMessage = "Camera session failed to start";
      _isSessionRunning = false;
    }
    
    notifyListeners();
  }

  void resetCamera() {
    print("📱 CameraService: Resetting camera session...");
    
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
      print("📱 CameraService: Camera session stopped");
    } catch (e) {
      print("❌ CameraService: Error stopping session: $e");
    }
  }

  void ensureSessionIsRunning() {
    if (!_isSessionRunning) {
      print("📱 CameraService: Session not running, starting...");
      _startSession();
    } else {
      print("📱 CameraService: Session is already running");
    }
  }

  Future<void> startRecording() async {
    print("📱 CameraService: startRecording() called");
    
    // Check mic permission for recording
    final micStatus = await Permission.microphone.status;
    if (micStatus.isDenied) {
      print("📱 CameraService: Requesting mic permission...");
      final result = await Permission.microphone.request();
      if (!result.isGranted) {
        print("📱 CameraService: Mic permission denied");
        _errorMessage = "Microphone access is required for video recording";
        notifyListeners();
        return;
      }
    }

    if (_isRecording) { 
      print("📱 CameraService: Already recording, ignoring start request");
      return; 
    }
    
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      print("❌ CameraService: Camera not initialized");
      return;
    }
    
    try {
      print("📱 CameraService: Starting recording...");
      
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
      
      print("📱 CameraService: Recording started successfully");
      notifyListeners();
      
    } catch (e) {
      print("❌ CameraService: Failed to start recording: $e");
      _errorMessage = "Failed to start recording: $e";
      notifyListeners();
    }
  }

  Future<void> stopRecording() async {
    print("📱 CameraService: stopRecording() called");
    
    if (!_isRecording) { 
      print("📱 CameraService: Not recording, ignoring stop request");
      return; 
    }
    
    try {
      print("📱 CameraService: Stopping recording...");
      
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
      
      print("📱 CameraService: Recording stopped successfully");
      notifyListeners();
      
    } catch (e) {
      print("❌ CameraService: Failed to stop recording: $e");
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
        print("📱 CameraService: Recording discarded");
      } catch (e) {
        print("❌ CameraService: Failed to delete recording: $e");
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
    print("📱 CameraService: flipCamera() called");
    print("📱 CameraService: Current position: $_selectedCameraIndex");
    
    if (_cameras.length <= 1) {
      print("📱 CameraService: Only one camera available, cannot flip");
      return;
    }
    
    try {
      // Stop current session
      await _stopSession();
      
      // Toggle camera index
      _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
      print("📱 CameraService: New position: $_selectedCameraIndex");
      
      // Reconfigure with new camera
      await _configureSession();
      
      print("📱 CameraService: Camera flipped successfully");
      
    } catch (e) {
      print("❌ CameraService: Failed to flip camera: $e");
      _errorMessage = "Failed to flip camera: $e";
      notifyListeners();
    }
  }

  Future<String?> capturePhoto() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      print("❌ CameraService: Camera not initialized");
      return null;
    }
    
    try {
      print("📱 CameraService: Capturing photo...");
      
      final image = await _cameraController!.takePicture();
      print("✅ CameraService: Photo captured: ${image.path}");
      
      // You can return the image path or handle it as needed
      return image.path;
      
    } catch (e) {
      print("❌ CameraService: Failed to capture photo: $e");
      _errorMessage = "Failed to capture photo: $e";
      notifyListeners();
      return null;
    }
  }

  Future<void> toggleFlash() async {
    print("📱 CameraService: toggleFlash() called");
    print("📱 CameraService: Current flash state: $_isFlashOn");
    
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      print("❌ CameraService: Camera not initialized, cannot toggle flash");
      return;
    }
    
    try {
      if (_isFlashOn) {
        await _cameraController!.setFlashMode(FlashMode.off);
        _isFlashOn = false;
        print("📱 CameraService: Flash turned OFF");
      } else {
        await _cameraController!.setFlashMode(FlashMode.torch);
        _isFlashOn = true;
        print("📱 CameraService: Flash turned ON");
      }
      
      notifyListeners();
      
    } catch (e) {
      print("❌ CameraService: Failed to toggle flash: $e");
      _isFlashOn = false;
      notifyListeners();
    }
  }

  void stopCamera() {
    print("📱 CameraService: Stopping camera session");
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
