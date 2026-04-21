import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/feed_tab.dart';
import '../../constants/app_colors.dart';
import 'feed_dropdown_widget.dart';

/// Feed selector widget for HomeView (single purple pill with dropdown + compass)
class FeedSelectorWidget extends StatefulWidget {
  final FeedTab activeTab;
  final ValueChanged<FeedTab> onTabSelected;
  final VoidCallback onDiscoverTap;

  const FeedSelectorWidget({
    super.key,
    required this.activeTab,
    required this.onTabSelected,
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
            onTabSelected: (FeedTab tab) {
              debugPrint(
                '🔘 FeedSelector: ${tab.displayName} tapped in overlay',
              );
              _removeOverlay();
              setState(() {
                _isDropdownOpen = false;
              });
              widget.onTabSelected(tab);
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
                  '🔘 FeedSelector: Dropdown state changed to: $_isDropdownOpen',
                );

                if (_isDropdownOpen) {
                  _showOverlay();
                } else {
                  _removeOverlay();
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.14),
                      Colors.white.withValues(alpha: 0.05),
                    ],
                  ),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.18),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.activeTab.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      _isDropdownOpen
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: AppColors.supportAccent,
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
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.12),
                      Colors.white.withValues(alpha: 0.04),
                    ],
                  ),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.28),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.explore_outlined,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
