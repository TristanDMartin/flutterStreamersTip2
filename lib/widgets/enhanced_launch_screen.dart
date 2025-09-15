import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

/// Enhanced launch screen with beautiful animations and proper branding
class EnhancedLaunchScreen extends StatefulWidget {
  final VoidCallback? onLaunchComplete;
  final Duration launchDuration;
  final bool showLoadingIndicator;

  const EnhancedLaunchScreen({
    super.key,
    this.onLaunchComplete,
    this.launchDuration = const Duration(milliseconds: 3000),
    this.showLoadingIndicator = true,
  });

  @override
  State<EnhancedLaunchScreen> createState() => _EnhancedLaunchScreenState();
}

class _EnhancedLaunchScreenState extends State<EnhancedLaunchScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _loadingController;
  late AnimationController _fadeController;
  
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoRotationAnimation;
  late Animation<double> _textFadeAnimation;
  late Animation<double> _textSlideAnimation;
  late Animation<double> _loadingAnimation;
  late Animation<double> _fadeAnimation;
  
  Timer? _launchTimer;
  bool _isComplete = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startLaunchSequence();
  }

  void _initializeAnimations() {
    // Logo animations
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _logoScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    ));
    
    _logoRotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.1,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeInOut,
    ));

    // Text animations
    _textController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _textFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.easeIn,
    ));
    
    _textSlideAnimation = Tween<double>(
      begin: 50.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.easeOutCubic,
    ));

    // Loading animation
    _loadingController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _loadingAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _loadingController,
      curve: Curves.easeInOut,
    ));

    // Fade out animation
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));
  }

  void _startLaunchSequence() async {
    // Start with haptic feedback
    HapticFeedback.lightImpact();
    
    // Start logo animation
    _logoController.forward();
    
    // Start text animation after logo starts
    Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        _textController.forward();
      }
    });
    
    // Start loading animation after text
    Timer(const Duration(milliseconds: 1000), () {
      if (mounted) {
        _loadingController.repeat();
      }
    });
    
    // Complete launch sequence
    _launchTimer = Timer(widget.launchDuration, () {
      if (mounted) {
        _completeLaunch();
      }
    });
  }

  void _completeLaunch() async {
    if (_isComplete) return;
    _isComplete = true;
    
    // Haptic feedback for completion
    HapticFeedback.mediumImpact();
    
    // Start fade out animation
    _fadeController.forward();
    
    // Wait for fade animation to complete
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (mounted) {
      widget.onLaunchComplete?.call();
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _loadingController.dispose();
    _fadeController.dispose();
    _launchTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF6137EB), Color(0xFF1C135D)],
                ),
              ),
              child: SafeArea(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo section
                      _buildLogoSection(),
                      
                      const SizedBox(height: 40),
                      
                      // Text section
                      _buildTextSection(),
                      
                      const SizedBox(height: 60),
                      
                      // Loading section
                      if (widget.showLoadingIndicator) _buildLoadingSection(),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }


  Widget _buildLogoSection() {
    return AnimatedBuilder(
      animation: Listenable.merge([_logoScaleAnimation, _logoRotationAnimation]),
      builder: (context, child) {
        return Transform.scale(
          scale: _logoScaleAnimation.value,
          child: Transform.rotate(
            angle: _logoRotationAnimation.value,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Center(
                child: _buildLogoIcon(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLogoIcon() {
    print('🎯 Attempting to load logo from: assets/logo.png');
    return Image.asset(
      'assets/logo.png',
      width: 80,
      height: 80,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        print('❌ Error loading logo: $error');
        print('❌ Stack trace: $stackTrace');
        // Fallback to gradient icon if logo fails to load
        return ShaderMask(
          shaderCallback: (Rect rect) {
            return const LinearGradient(
              colors: [
                Color(0xFF9248D2),
                Color(0xFF7768DF),
                Color(0xFF1670DE),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(rect);
          },
          blendMode: BlendMode.srcIn,
          child: const Icon(
            Icons.play_circle_filled,
            size: 80,
            color: Colors.white,
          ),
        );
      },
    );
  }

  Widget _buildTextSection() {
    return AnimatedBuilder(
      animation: Listenable.merge([_textFadeAnimation, _textSlideAnimation]),
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _textSlideAnimation.value),
          child: Opacity(
            opacity: _textFadeAnimation.value,
            child: const Column(
              children: [
                // App name
                Text(
                  'StreamersTip',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2.0,
                    shadows: [
                      Shadow(
                        color: Colors.black26,
                        offset: Offset(0, 2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: 12),
                
                // Tagline
                Text(
                  'Connect • Create • Share',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: Colors.white70,
                    letterSpacing: 1.5,
                    shadows: [
                      Shadow(
                        color: Colors.black26,
                        offset: Offset(0, 1),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingSection() {
    return AnimatedBuilder(
      animation: _loadingAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _textFadeAnimation.value,
          child: Column(
            children: [
              const SizedBox(height: 40),
              
              // Loading indicator
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  value: _loadingAnimation.value,
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white.withValues(alpha: 0.8),
                  ),
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Loading text
              const Text(
                'Loading...',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.white60,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Launch screen wrapper that handles the complete app startup flow
class LaunchScreenWrapper extends StatefulWidget {
  final Widget child;
  final Duration launchDuration;
  final bool showLoadingIndicator;

  const LaunchScreenWrapper({
    super.key,
    required this.child,
    this.launchDuration = const Duration(milliseconds: 3000),
    this.showLoadingIndicator = true,
  });

  @override
  State<LaunchScreenWrapper> createState() => _LaunchScreenWrapperState();
}

class _LaunchScreenWrapperState extends State<LaunchScreenWrapper> {
  bool _showLaunchScreen = true;

  void _onLaunchComplete() {
    if (mounted) {
      setState(() {
        _showLaunchScreen = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showLaunchScreen) {
      return EnhancedLaunchScreen(
        onLaunchComplete: _onLaunchComplete,
        launchDuration: widget.launchDuration,
        showLoadingIndicator: widget.showLoadingIndicator,
      );
    }
    
    return widget.child;
  }
}
