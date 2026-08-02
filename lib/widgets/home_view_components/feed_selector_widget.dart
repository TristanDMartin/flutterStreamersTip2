import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/st_theme_tokens.dart';
import '../../models/feed_tab.dart';
import '../../providers/activity_provider.dart';
import '../../qa/qa_keys.dart';
import 'feed_dropdown_widget.dart';

/// Feed selector widget for HomeView (single themed pill with dropdown + compass)
class FeedSelectorWidget extends ConsumerStatefulWidget {
  const FeedSelectorWidget({
    super.key,
    required this.activeTab,
    required this.onTabSelected,
    required this.onDiscoverTap,
    this.onDropdownOpenChanged,
  });

  final FeedTab activeTab;
  final ValueChanged<FeedTab> onTabSelected;
  final VoidCallback onDiscoverTap;
  final ValueChanged<bool>? onDropdownOpenChanged;

  @override
  ConsumerState<FeedSelectorWidget> createState() => _FeedSelectorWidgetState();
}

class _FeedSelectorWidgetState extends ConsumerState<FeedSelectorWidget>
    with WidgetsBindingObserver {
  bool _isDropdownOpen = false;
  OverlayEntry? _overlayEntry;
  final LayerLink _dropdownLink = LayerLink();
  Timer? _overlayAutoCloseTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _overlayAutoCloseTimer?.cancel();
    if (_isDropdownOpen) {
      widget.onDropdownOpenChanged?.call(false);
    }
    _removeOverlay();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.resumed) {
      _closeDropdown();
    }
  }

  void _removeOverlay() {
    _overlayAutoCloseTimer?.cancel();
    _overlayAutoCloseTimer = null;
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _setDropdownOpen(bool isOpen) {
    if (_isDropdownOpen == isOpen) return;
    setState(() {
      _isDropdownOpen = isOpen;
    });
    widget.onDropdownOpenChanged?.call(isOpen);
  }

  void _closeDropdown() {
    if (!mounted) {
      _removeOverlay();
      return;
    }
    _removeOverlay();
    if (_isDropdownOpen) {
      _setDropdownOpen(false);
    }
  }

  void _showOverlay() {
    _removeOverlay();

    final OverlayState overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (BuildContext overlayContext) {
        return Stack(
          key: QaKeys.feedSelectorOverlay,
          children: <Widget>[
            Positioned.fill(
              child: GestureDetector(
                key: QaKeys.feedSelectorBarrier,
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
        );
      },
    );

    overlay.insert(_overlayEntry!);
    _overlayAutoCloseTimer = Timer(const Duration(seconds: 8), _closeDropdown);
  }

  @override
  Widget build(BuildContext context) {
    final int unreadActivityCount = ref.watch(activityNavUnreadCountProvider);
    return SafeArea(
      top: true,
      child: Container(
        height: 56,
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            CompositedTransformTarget(
                link: _dropdownLink,
                child: Semantics(
                  button: true,
                  expanded: _isDropdownOpen,
                  label: 'Choose home feed',
                  child: GestureDetector(
                    key: QaKeys.feedSelectorButton,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      final bool shouldOpen = !_isDropdownOpen;
                      _setDropdownOpen(shouldOpen);

                      if (shouldOpen) {
                        _showOverlay();
                      } else {
                        _removeOverlay();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color:
                            StThemeColors.darkSurface.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.10),
                        ),
                        boxShadow: StShadows.glass(Colors.black),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            widget.activeTab.displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            _isDropdownOpen
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            color: Colors.white.withValues(alpha: 0.9),
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                widget.onDiscoverTap();
              },
              child: Semantics(
                label: unreadActivityCount > 0
                    ? 'Discover, $unreadActivityCount unread notifications'
                    : 'Discover',
                button: true,
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: StThemeColors.darkSurface
                              .withValues(alpha: 0.72),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.10),
                          ),
                          boxShadow: StShadows.glass(Colors.black),
                        ),
                        child: Icon(
                          Icons.explore_rounded,
                          color: Colors.white.withValues(alpha: 0.96),
                          size: 24,
                        ),
                      ),
                      if (unreadActivityCount > 0)
                        Positioned(
                          right: -1,
                          top: -1,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF0F56),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.black.withValues(alpha: 0.72),
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
