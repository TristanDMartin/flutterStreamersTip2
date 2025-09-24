import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;
import 'package:mobile_scanner/mobile_scanner.dart';

class QRScannerView extends StatefulWidget {
  final ValueChanged<String> onCodeScanned;
  const QRScannerView({super.key, required this.onCodeScanned});

  @override
  State<QRScannerView> createState() => _QRScannerViewState();
}

class _QRScannerViewState extends State<QRScannerView> with TickerProviderStateMixin {
  late MobileScannerController _controller;
  bool _handled = false;
  bool _isLoading = true;
  String? _errorMessage;
  late AnimationController _pulseController;
  late AnimationController _scanLineController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scanLineAnimation;
  
  // Define the scanning area (center square)
  static const double _scanAreaSize = 300.0;
  static const double _cornerRadius = 20.0;
  
  // Cache screen dimensions to avoid repeated MediaQuery calls
  late Size _screenSize;
  late double _centerX;
  late double _centerY;
  late double _leftBound;
  late double _rightBound;
  late double _topBound;
  late double _bottomBound;
  
  // Extract gradient to constant for better performance
  static const LinearGradient _profileGradient = LinearGradient(
    colors: [
      Color(0xFF6633CC), // Purple (matches ProfileView)
      Color(0xFF1A1A4D), // Dark blue (matches ProfileView)
    ],
  );

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(torchEnabled: false);
    _initializeAnimations();
    _initializeScanner();
    _setupControllerListener();
  }

  void _setupControllerListener() {
    _controller.addListener(() {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _scanLineController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _scanLineAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scanLineController,
      curve: Curves.easeInOut,
    ));
    
    _pulseController.repeat(reverse: true);
    _scanLineController.repeat();
  }

  Future<void> _initializeScanner() async {
    // Don't call start() here - let MobileScanner handle initialization
    // Just set loading to false after a short delay to show the scanner
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scanLineController.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Cache screen dimensions for better performance
  void _cacheScreenDimensions() {
    _screenSize = MediaQuery.of(context).size;
    _centerX = _screenSize.width / 2;
    _centerY = _screenSize.height / 2;
    _leftBound = _centerX - (_scanAreaSize / 2);
    _rightBound = _centerX + (_scanAreaSize / 2);
    _topBound = _centerY - (_scanAreaSize / 2);
    _bottomBound = _centerY + (_scanAreaSize / 2);
  }

  /// Optimized QR code validation with cached bounds
  bool _isQRCodeInScanArea(Barcode barcode) {
    if (barcode.corners.isEmpty) return false;

    // Use cached bounds for better performance
    for (final corner in barcode.corners) {
      final double x = corner.dx;
      final double y = corner.dy;
      
      // Quick bounds check first
      if (x < _leftBound || x > _rightBound || y < _topBound || y > _bottomBound) {
        continue;
      }
      
      // Check if point is in rounded corner areas
      final bool inTopLeftCorner = x < _leftBound + _cornerRadius && y < _topBound + _cornerRadius;
      final bool inTopRightCorner = x > _rightBound - _cornerRadius && y < _topBound + _cornerRadius;
      final bool inBottomLeftCorner = x < _leftBound + _cornerRadius && y > _bottomBound - _cornerRadius;
      final bool inBottomRightCorner = x > _rightBound - _cornerRadius && y > _bottomBound - _cornerRadius;
      
      // If in corner area, check if within rounded rectangle
      if (inTopLeftCorner || inTopRightCorner || inBottomLeftCorner || inBottomRightCorner) {
        final double cornerCenterX = inTopLeftCorner || inBottomLeftCorner 
            ? _leftBound + _cornerRadius 
            : _rightBound - _cornerRadius;
        final double cornerCenterY = inTopLeftCorner || inTopRightCorner 
            ? _topBound + _cornerRadius 
            : _bottomBound - _cornerRadius;
        
        final double distanceSquared = (x - cornerCenterX) * (x - cornerCenterX) + 
                                     (y - cornerCenterY) * (y - cornerCenterY);
        if (distanceSquared > _cornerRadius * _cornerRadius) {
          continue;
        }
      }
      
      return true;
    }
    
    return false;
  }

  /// Creates a seamless background with cutout for scanning area
  Widget _buildCutoutOverlay() {
    return Positioned.fill(
      child: CustomPaint(
        painter: CutoutPainter(
          scanAreaSize: _scanAreaSize,
          screenSize: _screenSize,
          cornerRadius: _cornerRadius,
        ),
        child: Container(
          decoration: const BoxDecoration(gradient: _profileGradient),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Cache screen dimensions for performance
    _cacheScreenDimensions();
    
    final bool unsupported = kIsWeb || (!Platform.isAndroid && !Platform.isIOS);
    if (unsupported) {
      return _buildUnsupportedView();
    }

    if (_isLoading) {
      return _buildLoadingView();
    }

    if (_errorMessage != null) {
      return _buildErrorView();
    }

    return _buildScannerView();
  }

  Widget _buildUnsupportedView() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.qr_code_scanner, size: 64, color: Colors.white),
              const SizedBox(height: 16),
              const Text(
                'QR Scanner',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              const Text(
                'QR scanning is not available on this platform',
                style: TextStyle(fontSize: 16, color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: const BoxDecoration(gradient: _profileGradient),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                'Initializing Camera...',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: const BoxDecoration(gradient: _profileGradient),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'Camera Error',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(fontSize: 16, color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton(
                        onPressed: () async {
                          setState(() {
                            _errorMessage = null;
                            _isLoading = true;
                          });
                          // Dispose and recreate the controller
                          await _controller.dispose();
                          _controller = MobileScannerController(torchEnabled: false);
                          await _initializeScanner();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                        ),
                        child: const Text('Retry'),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScannerView() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: const BoxDecoration(gradient: _profileGradient),
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: Stack(
                children: [
                  _buildCutoutOverlay(),
                  _buildScanningArea(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleBarcodeDetection(BarcodeCapture capture) {
    if (_handled) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (_isQRCodeInScanArea(barcode)) {
        final String? raw = barcode.rawValue;
        if (raw != null && raw.isNotEmpty) {
          HapticFeedback.mediumImpact();
          _handled = true;
          widget.onCodeScanned(raw);
          if (mounted) Navigator.of(context).pop();
          break;
        }
      }
    }
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
              style: IconButton.styleFrom(
                padding: const EdgeInsets.all(8),
              ),
            ),
            const Spacer(),
            const Text(
              'Scan QR Code',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                shadows: [
                  Shadow(
                    offset: Offset(0, 1),
                    blurRadius: 3,
                    color: Colors.black54,
                  ),
                ],
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: () => _controller.toggleTorch(),
              icon: const Icon(Icons.flash_on, color: Colors.white, size: 28),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanningArea() {
    return Positioned.fill(
      child: Align(
        alignment: Alignment.center,
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(_cornerRadius),
                child: Container(
                  width: _scanAreaSize,
                  height: _scanAreaSize,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(_cornerRadius),
                    border: Border.all(
                      width: 3,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Camera view clipped to the scanning area
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(_cornerRadius - 3),
                          child: MobileScanner(
                            controller: _controller,
                            onDetect: _handleBarcodeDetection,
                          ),
                        ),
                      ),
                      _buildCornerIndicators(),
                      _buildScanLine(),
                      _buildCenterText(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCornerIndicators() {
    return Stack(
      children: [
        // Top-left corner
        Positioned(
          top: 0,
          left: 0,
          child: Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.white, width: 3),
                left: BorderSide(color: Colors.white, width: 3),
              ),
            ),
          ),
        ),
        // Top-right corner
        Positioned(
          top: 0,
          right: 0,
          child: Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.white, width: 3),
                right: BorderSide(color: Colors.white, width: 3),
              ),
            ),
          ),
        ),
        // Bottom-left corner
        Positioned(
          bottom: 0,
          left: 0,
          child: Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white, width: 3),
                left: BorderSide(color: Colors.white, width: 3),
              ),
            ),
          ),
        ),
        // Bottom-right corner
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white, width: 3),
                right: BorderSide(color: Colors.white, width: 3),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScanLine() {
    return AnimatedBuilder(
      animation: _scanLineAnimation,
      builder: (context, child) {
        return Positioned(
          top: _scanLineAnimation.value * (_scanAreaSize - 2),
          left: 0,
          right: 0,
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.white.withValues(alpha: 0.8),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCenterText() {
    return const Center(
      child: Text(
        'Position QR code here',
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          shadows: [
            Shadow(
              offset: Offset(0, 1),
              blurRadius: 2,
              color: Colors.black54,
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter to create a seamless background with rounded rectangle cutout
class CutoutPainter extends CustomPainter {
  final double scanAreaSize;
  final Size screenSize;
  final double cornerRadius;

  CutoutPainter({
    required this.scanAreaSize,
    required this.screenSize,
    required this.cornerRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.black
      ..blendMode = BlendMode.dstOut;

    // Calculate the center position of the scanning area
    final double centerX = screenSize.width / 2;
    final double centerY = screenSize.height / 2;
    
    // Create rounded rectangle path for the cutout
    final Rect scanRect = Rect.fromCenter(
      center: Offset(centerX, centerY),
      width: scanAreaSize,
      height: scanAreaSize,
    );
    
    final RRect roundedRect = RRect.fromRectAndRadius(
      scanRect,
      Radius.circular(cornerRadius),
    );
    
    // Create the cutout path
    final Path cutoutPath = Path()
      ..addRRect(roundedRect);
    
    // Apply the cutout
    canvas.drawPath(cutoutPath, paint);
  }

  @override
  bool shouldRepaint(CutoutPainter oldDelegate) {
    return oldDelegate.scanAreaSize != scanAreaSize ||
           oldDelegate.screenSize != screenSize ||
           oldDelegate.cornerRadius != cornerRadius;
  }
}

