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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: true,
      child: Stack(
        children: [
          // Header row
          Container(
            height: 50,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Single purple pill with dropdown
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _isDropdownOpen = !_isDropdownOpen;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF9248D2),
                      borderRadius: BorderRadius.circular(25),
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
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          _isDropdownOpen
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: Colors.white,
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
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.explore_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Dropdown overlay
          FeedDropdownWidget(
            activeTab: widget.activeTab,
            isVisible: _isDropdownOpen,
            onForYouTap: widget.onForYouTap,
            onFollowingTap: widget.onFollowingTap,
            onClose: () {
              setState(() {
                _isDropdownOpen = false;
              });
            },
          ),

          // Tap outside to close dropdown
          if (_isDropdownOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _isDropdownOpen = false;
                  });
                },
                child: Container(
                  color: Colors.transparent,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
