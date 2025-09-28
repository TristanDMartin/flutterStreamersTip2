import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class IOSMinimalStartup extends StatefulWidget {
  final Widget child;
  
  const IOSMinimalStartup({
    super.key,
    required this.child,
  });

  @override
  State<IOSMinimalStartup> createState() => _IOSMinimalStartupState();
}

class _IOSMinimalStartupState extends State<IOSMinimalStartup> {
  bool _isInitialized = false;
  bool _isIOS = false;

  @override
  void initState() {
    super.initState();
    _isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    
    if (_isIOS) {
      // Delayed initialization for iOS to prevent white screen
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
        }
      });
    } else {
      // Immediate initialization for Android
      _isInitialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isIOS && !_isInitialized) {
      return _buildIOSLoadingScreen();
    }
    
    return widget.child;
  }

  Widget _buildIOSLoadingScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF1C135D),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6137EB), Color(0xFF1C135D)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App Logo
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/logo.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      // Fallback to gradient icon if logo fails to load
                      return Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6633CC), Color(0xFF1A1A4D)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.play_circle_fill,
                          color: Colors.white,
                          size: 50,
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // App Name
              const Text(
                'StreamersTip',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 6),
              
              // Tagline
              Text(
                'Connect • Create • Share',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 30),
              
              // Loading Indicator
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
              const SizedBox(height: 16),
              
              // Loading Text
              Text(
                'Loading...',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
