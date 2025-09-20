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
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
              SizedBox(height: 20),
              Text(
                'Loading...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
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
