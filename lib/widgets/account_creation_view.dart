import 'package:flutter/material.dart';

class AccountCreationView extends StatelessWidget {
  final VoidCallback onComplete;

  const AccountCreationView({
    super.key,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD8DDE4), // Light grayish-blue background
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 1),
              
              // Main Content Card
              _buildMainCard(),
              
              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.1),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Character Icon (overlapping the top)
            Transform.translate(
              offset: const Offset(0, -30),
              child: _buildCharacterIcon(),
            ),
            
            const SizedBox(height: 20),
            
            // Title
            const Text(
              'Finally, you\'ll need to create an account to secure your journal',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C2C2E),
                height: 1.2,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Description
            const Text(
              'Creating an account will also give you automated cloud backups for your data, device syncing and much more!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF6C6C70),
                height: 1.4,
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Call-to-Action Button
            _buildGradientButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildCharacterIcon() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFE5E5EA), // Light blue/off-white
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.1),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Top segment (light gray cap)
          Positioned(
            top: 15,
            child: Container(
              width: 50,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          // Eyes
          Positioned(
            top: 35,
            left: 25,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 35,
            right: 25,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Smiling mouth (orange/yellow)
          Positioned(
            bottom: 25,
            child: Container(
              width: 40,
              height: 18,
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradientButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF9248d2), // Purple
            Color(0xFF7768df), // Another purple
            Color(0xFF1670de), // Blue
            Color(0xFF3c8bd6), // Lighter blue
            Color(0xFF4897d2), // Lightest blue
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onComplete,
          child: const Center(
            child: Text(
              'LET\'S DO IT',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
