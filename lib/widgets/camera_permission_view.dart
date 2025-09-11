import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraPermissionView extends StatefulWidget {
  final VoidCallback? onPermissionGranted;
  
  const CameraPermissionView({
    super.key,
    this.onPermissionGranted,
  });

  @override
  State<CameraPermissionView> createState() => _CameraPermissionViewState();
}

class _CameraPermissionViewState extends State<CameraPermissionView> {
  // Unused fields commented out
  // final bool _showCamera = false;
  // final bool _showPermissionAlert = false;
  // final int _permissionStep = 0; // 0: camera, 1: microphone, 2: complete

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final cameraStatus = await Permission.camera.status;
    final micStatus = await Permission.microphone.status;
    
    if (cameraStatus.isGranted && micStatus.isGranted) {
      // Permissions already granted, go directly to camera
      widget.onPermissionGranted?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Color(0xFF9A33CC), // Purple
              Color(0xFF3366CC),  // Blue
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(),
              
              // Camera Icon with Play Button Overlay
              _buildCameraIcon(),
              
              const SizedBox(height: 40),
              
              // Permission Request Text
              _buildPermissionText(),
              
              const Spacer(),
              
              // Camera Interface Preview
              _buildCameraPreview(),
              
              const Spacer(),
              
              // Continue Button
              _buildContinueButton(),
              
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraIcon() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Main Camera Icon (white rounded rectangle)
        Container(
          width: 100,
          height: 70,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Black circle (lens)
              Container(
                width: 45,
                height: 45,
                decoration: const BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
              ),
              // White circle (inner lens)
              Container(
                width: 35,
                height: 35,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              // Black circle (center)
              Container(
                width: 25,
                height: 25,
                decoration: const BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
        
        // Play/Record Button Overlay (red circle)
        Positioned(
          left: -25,
          bottom: -15,
          child: Container(
            width: 35,
            height: 35,
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.play_arrow,
              color: Colors.white,
              size: 14,
            ),
          ),
        ),
        
        // Sparkle Icon (yellow star)
        const Positioned(
          left: -35,
          top: -25,
          child: Icon(
            Icons.auto_awesome,
            color: Colors.yellow,
            size: 18,
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionText() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const Text(
            "Allow StreamersTip to access your camera and microphone",
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 16),
          
          // Feature Explanation
          _buildFeatureRow(
            Icons.camera_alt,
            "Enjoy many features using StreamersTip",
            "take photos, record sounds and videos or try visual and audio effects",
          ),
          
          const SizedBox(height: 16),
          
          // Manage Permissions
          _buildFeatureRow(
            Icons.settings,
            "Manage permissions",
            "you can go to settings to change preferences at any time",
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String title, String subtitle) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 14,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildCameraPreview() {
    return Column(
      children: [
        // Recording Duration Options
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildDurationOption("10m", false),
            const SizedBox(width: 20),
            _buildDurationOption("60s", false),
            const SizedBox(width: 20),
            _buildDurationOption("15s", true),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Mode Options
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildModeOption("PHOTO", false),
            const SizedBox(width: 20),
            _buildModeOption("TEXT", false),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Record Button
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Container(
            margin: const EdgeInsets.all(5),
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Gallery Icon (landscape)
        Container(
          width: 30,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(
            Icons.landscape,
            color: Colors.white,
            size: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildDurationOption(String text, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF9A33CC) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.6),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildModeOption(String text, bool isSelected) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.6),
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildContinueButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _startPermissionFlow,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text(
            "Continue",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _startPermissionFlow() async {
    // Request camera permission first
    final cameraStatus = await Permission.camera.request();
    
    if (cameraStatus.isGranted) {
      // Camera granted, now request microphone
      final micStatus = await Permission.microphone.request();
      
      if (micStatus.isGranted) {
        // Both permissions granted, open camera
        widget.onPermissionGranted?.call();
      } else {
        // Microphone denied, show alert
        _showPermissionDeniedDialog();
      }
    } else {
      // Camera denied, show alert
      _showPermissionDeniedDialog();
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Camera Access Required"),
        content: const Text(
          "Please enable camera and microphone access in Settings to use this feature."
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: const Text("Open Settings"),
          ),
        ],
      ),
    );
  }
}
