import 'package:flutter/material.dart';
import '../services/error_handling_service.dart';

class NetworkStatusWidget extends StatefulWidget {
  final Widget child;
  final bool showOfflineIndicator;

  const NetworkStatusWidget({
    super.key,
    required this.child,
    this.showOfflineIndicator = true,
  });

  @override
  State<NetworkStatusWidget> createState() => _NetworkStatusWidgetState();
}

class _NetworkStatusWidgetState extends State<NetworkStatusWidget>
    with SingleTickerProviderStateMixin {
  final ErrorHandlingService _errorService = ErrorHandlingService();
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  bool _isOnline = true;
  bool _showOfflineBanner = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<double>(
      begin: -1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    // Listen to connectivity changes
    _errorService.connectivityStream.listen((isOnline) {
      if (mounted) {
        setState(() {
          _isOnline = isOnline;
          _showOfflineBanner = !isOnline;
        });

        if (!isOnline) {
          _animationController.forward();
        } else {
          _animationController.reverse();
        }
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (widget.showOfflineIndicator && _showOfflineBanner)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _slideAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _slideAnimation.value * 50),
                  child: _buildOfflineBanner(),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.orange,
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.wifi_off,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'You\'re offline. Some features may not be available.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (_isOnline)
            GestureDetector(
              onTap: () {
                setState(() {
                  _showOfflineBanner = false;
                });
                _animationController.reverse();
              },
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 20,
              ),
            ),
        ],
      ),
    );
  }
}

/// Network status indicator for app bar
class NetworkStatusIndicator extends StatelessWidget {
  const NetworkStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: ErrorHandlingService().connectivityStream,
      builder: (context, snapshot) {
        final isOnline = snapshot.data ?? true;
        
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isOnline ? Colors.green : Colors.red,
          ),
        );
      },
    );
  }
}

/// Offline mode banner
class OfflineModeBanner extends StatelessWidget {
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;

  const OfflineModeBanner({
    super.key,
    this.onRetry,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        border: Border.all(color: Colors.orange),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.wifi_off,
                color: Colors.orange,
                size: 24,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Offline Mode',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ),
              if (onDismiss != null)
                GestureDetector(
                  onTap: onDismiss,
                  child: const Icon(
                    Icons.close,
                    color: Colors.orange,
                    size: 20,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'You\'re currently offline. Some features may not be available. '
            'Your data will sync when you\'re back online.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.orange,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry Connection'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
