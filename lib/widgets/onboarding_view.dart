import 'package:flutter/material.dart';

class OnboardingView extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingView({
    super.key,
    required this.onComplete,
  });

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> with TickerProviderStateMixin {
  final TextEditingController _streamerNameController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  int _currentStep = 0; // 0 = first step, 1 = second step, 2 = account creation
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  // Paper plane animations
  late AnimationController _plane1Controller;
  late AnimationController _plane2Controller;
  late AnimationController _plane3Controller;
  late Animation<Offset> _plane1Animation;
  late Animation<Offset> _plane2Animation;
  late Animation<Offset> _plane3Animation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  @override
  void dispose() {
    _streamerNameController.dispose();
    _focusNode.dispose();
    _pulseController.dispose();
    _plane1Controller.dispose();
    _plane2Controller.dispose();
    _plane3Controller.dispose();
    super.dispose();
  }

  void _initializeAnimations() {
    // Initialize pulse animation
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    // Initialize paper plane animations
    _plane1Controller = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );
    _plane2Controller = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    );
    _plane3Controller = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    );
    
    _plane1Animation = Tween<Offset>(
      begin: const Offset(-1.5, -0.5),
      end: const Offset(1.5, 0.5),
    ).animate(CurvedAnimation(
      parent: _plane1Controller,
      curve: Curves.easeInOut,
    ));
    
    _plane2Animation = Tween<Offset>(
      begin: const Offset(1.0, -0.8),
      end: const Offset(-0.5, 0.3),
    ).animate(CurvedAnimation(
      parent: _plane2Controller,
      curve: Curves.easeInOut,
    ));
    
    _plane3Animation = Tween<Offset>(
      begin: const Offset(-0.8, 0.6),
      end: const Offset(1.2, -0.4),
    ).animate(CurvedAnimation(
      parent: _plane3Controller,
      curve: Curves.easeInOut,
    ));
    
    // Start animations
    _pulseController.repeat(reverse: true);
    _plane1Controller.repeat();
    _plane2Controller.repeat();
    _plane3Controller.repeat();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
              body: Container(
                  decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1a1a2e),
              Color(0xFF16213e),
              Color(0xFF0f3460),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                // Back button (show on all steps)
                _buildBackButton(),
                
                // Top spacer for centering
                const Spacer(flex: 1),
                
                // Character Avatar
                _buildCharacterAvatar(),
                
                const SizedBox(height: 32),
                
                // Content based on current step
                if (_currentStep == 0) ...[
                  // First step: Streamer name input
                  _buildGreetingText(),
                  const SizedBox(height: 40),
                  _buildStreamerNameInput(),
                  const SizedBox(height: 60),
                  _buildContinueButton(),
                ] else if (_currentStep == 1) ...[
                  // Second step: Alerts permission
                  _buildAlertsText(),
                  const SizedBox(height: 40),
                  _buildEnableButton(),
                ] else ...[
                  // Third step: Account creation
                  _buildAccountCreationContent(),
                ],
                
                const SizedBox(height: 32),
                
                // Page Indicator
                _buildPageIndicator(),
                
                // Bottom spacer for centering
                const Spacer(flex: 1),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCharacterAvatar() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Pulsing wave circles behind the logo
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: 1.0 + (_pulseAnimation.value * 0.3),
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha:0.1 * _pulseAnimation.value),
                ),
              ),
            );
          },
        ),
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: 1.0 + (_pulseAnimation.value * 0.5),
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha:0.05 * _pulseAnimation.value),
                ),
              ),
            );
          },
        ),
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: 1.0 + (_pulseAnimation.value * 0.7),
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha:0.03 * _pulseAnimation.value),
                ),
              ),
            );
          },
        ),
        
        // Main logo - trying to load actual logo.png
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha:0.1),
                blurRadius: 20,
                spreadRadius: 0,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/logo.png',
              width: 120,
              height: 120,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                print('❌ OnboardingView: Error loading logo: $error');
                return Container(
                  color: Colors.grey[800],
                  child: const Center(
                    child: Icon(
                      Icons.play_circle_filled,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGreetingText() {
    return const Text(
      'For me to get to know you better\nwhat\'s your Streamer name?',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Colors.white,
        height: 1.2,
      ),
    );
  }

  Widget _buildStreamerNameInput() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha:0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha:0.3),
          width: 1,
        ),
      ),
      child: TextField(
        controller: _streamerNameController,
        focusNode: _focusNode,
        maxLength: 20,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
        decoration: const InputDecoration(
          hintText: 'Your streamer name...',
          hintStyle: TextStyle(
            color: Colors.white70,
            fontSize: 18,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          counterText: '', // Hide the character counter
        ),
        textAlign: TextAlign.center,
        onSubmitted: (_) => _handleContinue(),
        onChanged: (_) => setState(() {}), // Rebuild to update button state
      ),
    );
  }

  Widget _buildContinueButton() {
    final hasText = _streamerNameController.text.trim().isNotEmpty;
    
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: hasText 
            ? const LinearGradient(
                colors: [
                  Color(0xFF9248d2), // Purple
                  Color(0xFF7768df), // Another purple
                  Color(0xFF1670de), // Blue
                  Color(0xFF3c8bd6), // Lighter blue
                  Color(0xFF4897d2), // Lightest blue
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              )
            : null,
        color: hasText ? null : Colors.white.withValues(alpha:0.1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: hasText ? _handleContinue : null,
          child: Center(
            child: Text(
              'CONTINUE',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: hasText ? Colors.white : Colors.white.withValues(alpha:0.5),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return Align(
      alignment: Alignment.topLeft,
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: IconButton(
          onPressed: () {
            if (_currentStep > 0) {
              setState(() {
                _currentStep--;
              });
            } else {
              // Go back to welcome view
              Navigator.of(context).pop();
            }
          },
          icon: const Icon(
            Icons.arrow_back_ios,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // First page indicator
        Container(
          width: _currentStep == 0 ? 12 : 8,
          height: _currentStep == 0 ? 12 : 8,
          decoration: BoxDecoration(
            color: _currentStep == 0 
                ? Colors.white 
                : Colors.white.withValues(alpha:0.5),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 16),
        // Second page indicator
        Container(
          width: _currentStep == 1 ? 12 : 8,
          height: _currentStep == 1 ? 12 : 8,
          decoration: BoxDecoration(
            color: _currentStep == 1 
                ? Colors.white 
                : Colors.white.withValues(alpha:0.5),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 16),
        // Third page indicator
        Container(
          width: _currentStep == 2 ? 12 : 8,
          height: _currentStep == 2 ? 12 : 8,
          decoration: BoxDecoration(
            color: _currentStep == 2 
                ? Colors.white 
                : Colors.white.withValues(alpha:0.5),
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }

  Widget _buildAlertsText() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Animated paper planes
        AnimatedBuilder(
          animation: _plane1Animation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(
                _plane1Animation.value.dx * 100,
                _plane1Animation.value.dy * 100,
              ),
              child: Transform.rotate(
                angle: _plane1Animation.value.dx * 0.5,
                child: _buildPaperPlane(Colors.white.withValues(alpha:0.7), 24),
              ),
            );
          },
        ),
        AnimatedBuilder(
          animation: _plane2Animation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(
                _plane2Animation.value.dx * 80,
                _plane2Animation.value.dy * 80,
              ),
              child: Transform.rotate(
                angle: _plane2Animation.value.dx * 0.3,
                child: _buildPaperPlane(Colors.white.withValues(alpha:0.5), 20),
              ),
            );
          },
        ),
        AnimatedBuilder(
          animation: _plane3Animation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(
                _plane3Animation.value.dx * 120,
                _plane3Animation.value.dy * 120,
              ),
              child: Transform.rotate(
                angle: _plane3Animation.value.dx * 0.4,
                child: _buildPaperPlane(Colors.white.withValues(alpha:0.6), 18),
              ),
            );
          },
        ),
        
        // Main text content
        Column(
          children: [
            const Text(
              'Never Miss a Moment –\nTap to Enable Alerts!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'LIFE GETS BUSY, FOCUS IS KEY',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha:0.8),
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEnableButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _handleEnable,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF7B24E1), // Purple color
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: const Text(
          'ENABLE',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }

  void _handleContinue() {
    final streamerName = _streamerNameController.text.trim();
    if (streamerName.isNotEmpty) {
      // TODO: Save streamer name to preferences/storage
    // print('Streamer name: $streamerName');
      setState(() {
        _currentStep = 1; // Move to second step
      });
    }
  }

  Widget _buildPaperPlane(Color color, double size) {
    return Icon(
      Icons.send,
      size: size,
      color: color,
    );
  }

  Widget _buildAccountCreationContent() {
    return Column(
      children: [
        // Logo (smaller version) - only one logo at the top
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha:0.1),
                blurRadius: 10,
                spreadRadius: 0,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipOval(
            child: Container(
              color: Colors.white,
              child: const Center(
                child: Text(
                  'LOGO',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF7B24E1),
                  ),
                ),
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 32),
        
        // Title
        const Text(
          'Finally, you\'ll need to create an account to secure your journal',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
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
            color: Colors.white70,
            height: 1.4,
          ),
        ),
        
        const SizedBox(height: 40),
        
        // Call-to-Action Button
        _buildLetsDoItButton(),
      ],
    );
  }

  Widget _buildLetsDoItButton() {
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
          onTap: () {
            // Complete onboarding and navigate to account creation
            widget.onComplete();
          },
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

  void _handleEnable() {
    setState(() {
      _currentStep = 2; // Move to account creation step
    });
  }

  // void _showNotificationPermissionDialog() {
  //   // Unused method commented out
  // }
}
