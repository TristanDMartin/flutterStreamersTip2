import 'package:flutter/material.dart';

class UploadPermissionPromptView extends StatelessWidget {
  final VoidCallback? onContinue;
  
  const UploadPermissionPromptView({
    super.key,
    this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0C10),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            
            // Camera Illustration
            _buildCameraIllustration(),
            
            const SizedBox(height: 32),
            
            // Title
            _buildTitle(),
            
            const SizedBox(height: 32),
            
            // Features
            _buildFeatures(),
            
            const Spacer(),
            
            // Continue Button
            _buildContinueButton(),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraIllustration() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Camera Icon
        const SizedBox(
          width: 160,
          height: 120,
          child: Icon(
            Icons.camera_alt,
            size: 120,
            color: Color(0xFF66FCF1),
          ),
        ),
        
        // Play Button Overlay
        Positioned(
          left: -60,
          bottom: -40,
          child: Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: Colors.pink,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.play_arrow,
              color: Colors.white,
              size: 32,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTitle() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        "Allow StreamersTip to access your camera and microphone",
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildFeatures() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          _buildFeatureRow(
            icon: Icons.camera_alt,
            title: "Enjoy many features using StreamersTip",
            subtitle: "take photos, record sounds and videos or try visual and audio effects",
          ),
          
          const SizedBox(height: 20),
          
          _buildFeatureRow(
            icon: Icons.settings,
            title: "Manage permissions",
            subtitle: "you can go to settings to change preferences at any time",
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: const Color(0xFF66FCF1),
          size: 24,
        ),
        
        const SizedBox(width: 12),
        
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
              
              const SizedBox(height: 2),
              
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFFC5C6C7),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContinueButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onContinue,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.pink,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            "Continue",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
