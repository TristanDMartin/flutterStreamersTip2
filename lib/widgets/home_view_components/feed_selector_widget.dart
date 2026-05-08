import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/feed_tab.dart';
import 'feed_dropdown_widget.dart';

/// Feed selector widget for HomeView (single themed pill with dropdown + compass)
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
  final LayerLink _dropdownLink = LayerLink();

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _closeDropdown() {
    if (!mounted) {
      _removeOverlay();
      return;
    }
    _removeOverlay();
    if (_isDropdownOpen) {
      setState(() {
        _isDropdownOpen = false;
      });
    }
  }

  void _showOverlay() {
    _removeOverlay();

    final overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              key: const ValueKey('feed-selector-overlay-barrier'),
              behavior: HitTestBehavior.translucent,
              onTap: _closeDropdown,
              child: const SizedBox.expand(),
            ),
          ),
          CompositedTransformFollower(
            link: _dropdownLink,
            showWhenUnlinked: false,
            targetAnchor: Alignment.bottomLeft,
            followerAnchor: Alignment.topLeft,
            offset: const Offset(0, 8),
            child: Material(
              elevation: 100,
              color: Colors.transparent,
              child: FeedDropdownWidget(
                activeTab: widget.activeTab,
                isVisible: true,
                onTabSelected: (FeedTab tab) {
                  _closeDropdown();
                  widget.onTabSelected(tab);
                },
                onClose: _closeDropdown,
              ),
            ),
          ),
        ],
      ),
    );

    overlay.insert(_overlayEntry!);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isLight = Theme.of(context).brightness == Brightness.light;
    final Color labelColor = scheme.onSurface;
    final List<Color> glassColors = <Color>[
      scheme.surface.withValues(alpha: isLight ? 0.95 : 0.94),
      scheme.surfaceContainerLow.withValues(alpha: isLight ? 0.9 : 0.88),
    ];
    final Color borderColor =
        scheme.outline.withValues(alpha: isLight ? 0.4 : 0.36);
    final List<BoxShadow> pillShadows = <BoxShadow>[
      BoxShadow(
        color: scheme.shadow.withValues(alpha: isLight ? 0.12 : 0.35),
        blurRadius: 20,
        offset: const Offset(0, 8),
      ),
      if (!isLight)
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.28),
          blurRadius: 16,
          offset: const Offset(0, 10),
        ),
    ];
    return SafeArea(
      top: true,
      child: Container(
        height: 50,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Single themed pill with dropdown
            CompositedTransformTarget(
              link: _dropdownLink,
              child: Semantics(
                button: true,
                expanded: _isDropdownOpen,
                label: 'Choose home feed',
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    final bool shouldOpen = !_isDropdownOpen;
                    setState(() {
                      _isDropdownOpen = shouldOpen;
                    });

                    if (shouldOpen) {
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
                        colors: glassColors,
                      ),
                      border: Border.all(
                        color: borderColor,
                        width: 1.2,
                      ),
                      boxShadow: pillShadows,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.activeTab.displayName,
                          style: TextStyle(
                            color: labelColor,
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
                          color: scheme.primary,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
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
                    colors: <Color>[
                      scheme.surface.withValues(alpha: isLight ? 0.95 : 0.92),
                      scheme.surfaceContainerLow.withValues(
                        alpha: isLight ? 0.88 : 0.85,
                      ),
                    ],
                  ),
                  border: Border.all(
                    color:
                        scheme.outline.withValues(alpha: isLight ? 0.4 : 0.34),
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: scheme.shadow.withValues(
                        alpha: isLight ? 0.1 : 0.28,
                      ),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.explore_outlined,
                  color: scheme.primary,
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
