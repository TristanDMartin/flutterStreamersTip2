import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'feed_dropdown_widget.dart';

/// Feed selector widget for HomeView (single purple pill with dropdown + compass)
class FeedSelectorWidget extends StatefulWidget {
  final String activeTab;
  final VoidCallback onForYouTap;
  final VoidCallback onFollowingTap;
  final VoidCallback onDiscoverTap;

  const FeedSelectorWidget({
    super.key,
    required this.activeTab,
    required this.onForYouTap,
    required this.onFollowingTap,
    required this.onDiscoverTap,
  });

  @override
  State<FeedSelectorWidget> createState() => _FeedSelectorWidgetState();
}

class _FeedSelectorWidgetState extends State<FeedSelectorWidget> {
  bool _isDropdownOpen = false;
  OverlayEntry? _overlayEntry;

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showOverlay() {
    _removeOverlay();

    final overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 100, // Position below the header
        left: 16,
        child: Material(
          elevation: 100,
          color: Colors.transparent,
          child: FeedDropdownWidget(
            activeTab: widget.activeTab,
            isVisible: true,
            onForYouTap: () {
              debugPrint('🔘 FeedSelector: For You tapped in overlay');
              _removeOverlay();
              setState(() {
                _isDropdownOpen = false;
              });
              widget.onForYouTap();
            },
            onFollowingTap: () {
              debugPrint('🔘 FeedSelector: Following tapped in overlay');
              _removeOverlay();
              setState(() {
                _isDropdownOpen = false;
              });
              widget.onFollowingTap();
            },
            onClose: () {
              _removeOverlay();
              setState(() {
                _isDropdownOpen = false;
              });
            },
          ),
        ),
      ),
    );

    overlay.insert(_overlayEntry!);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: true,
      child: Container(
        height: 50,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Single purple pill with dropdown
            GestureDetector(
              onTap: () {
                debugPrint('🔘 FeedSelector: Main dropdown button tapped');
                HapticFeedback.lightImpact();
                setState(() {
                  _isDropdownOpen = !_isDropdownOpen;
                });
                debugPrint(
                    '🔘 FeedSelector: Dropdown state changed to: $_isDropdownOpen');

                if (_isDropdownOpen) {
                  _showOverlay();
                } else {
                  _removeOverlay();
                }
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A).withValues(alpha: 0.98),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: const Color(0xFF9248D2).withValues(alpha: 0.8),
                    width: 2.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.activeTab,
                      style: const TextStyle(
                        color: Color(0xFF9248D2),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      _isDropdownOpen
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: const Color(0xFF9248D2),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),

            // Discover button (compass icon)
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                widget.onDiscoverTap();
              },
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(
                  Icons.explore_outlined,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
