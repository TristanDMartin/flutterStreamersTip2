import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import '../providers/current_user_provider.dart';
import '../providers/unread_messages_provider.dart';
import '../qa/qa_keys.dart';
import '../utils/avatar_url_resolver.dart';
import '../utils/performance_utils.dart';
import '../utils/responsive_layout.dart';
import 'navigation/liquid_glass_dock_tokens.dart';

class CustomBottomNav extends ConsumerStatefulWidget {
  const CustomBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  ConsumerState<CustomBottomNav> createState() => _CustomBottomNavState();
}

class _CustomBottomNavState extends ConsumerState<CustomBottomNav>
    with SingleTickerProviderStateMixin {
  static const int _slotCount = 5;
  static const int _createIndex = 2;

  late final AnimationController _indicatorController;
  late Animation<double> _indicatorCenterAnimation;
  double _indicatorCenter = 0.5;

  @override
  void initState() {
    super.initState();
    _indicatorCenter = _centerFractionForIndex(widget.currentIndex);
    _indicatorController = AnimationController(
      vsync: this,
      duration: LiquidGlassDockTokens.orbDuration,
    );
    _indicatorCenterAnimation = AlwaysStoppedAnimation<double>(
      _indicatorCenter,
    );
    _indicatorController.value = 1;
  }

  @override
  void didUpdateWidget(CustomBottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _animateIndicatorTo(widget.currentIndex);
    }
  }

  @override
  void dispose() {
    _indicatorController.dispose();
    super.dispose();
  }

  double _centerFractionForIndex(int index) {
    return (index + 0.5) / _slotCount;
  }

  void _animateIndicatorTo(int index) {
    final double begin = _indicatorController.isAnimating
        ? _indicatorCenterAnimation.value
        : _indicatorCenter;
    final double end = _centerFractionForIndex(index);
    _indicatorCenter = end;
    _indicatorCenterAnimation = Tween<double>(begin: begin, end: end).animate(
      CurvedAnimation(
        parent: _indicatorController,
        curve: LiquidGlassDockTokens.orbCurve,
        reverseCurve: LiquidGlassDockTokens.orbReverseCurve,
      ),
    );
    _indicatorController
      ..reset()
      ..forward();
  }

  void _handleTap(int index) {
    if (index != widget.currentIndex) {
      HapticFeedback.selectionClick();
      widget.onTap(index);
    } else {
      HapticFeedback.lightImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppResponsive responsive = context.responsive;
    final double viewBottom = MediaQuery.viewPaddingOf(context).bottom;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final ColorScheme colorScheme = Theme.of(context).colorScheme;
        final bool isLight = Theme.of(context).brightness == Brightness.light;
        final Color on = colorScheme.onSurface;
        final List<Color> glassColors = isLight
            ? <Color>[
                colorScheme.surface.withValues(alpha: 0.58),
                colorScheme.surface.withValues(alpha: 0.42),
                colorScheme.surfaceContainerLow.withValues(alpha: 0.3),
                colorScheme.surface.withValues(alpha: 0.5),
              ]
            : <Color>[
                Colors.white.withValues(alpha: 0.2),
                Colors.white.withValues(alpha: 0.11),
                Colors.white.withValues(alpha: 0.04),
                Colors.black.withValues(alpha: 0.48),
              ];
        final Color borderGlass = isLight
            ? colorScheme.outline.withValues(alpha: 0.22)
            : Colors.white.withValues(alpha: 0.32);
        final Color glow = isLight
            ? colorScheme.shadow.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.1);
        final _NavMetrics metrics = _NavMetrics.from(
          availableWidth: constraints.maxWidth,
          responsive: responsive,
          hasSystemNavBar: viewBottom > 0,
        );
        final double dockWidth =
            (constraints.maxWidth - metrics.horizontalMargin * 2)
                .clamp(0.0, double.infinity)
                .toDouble();
        final double contentWidth =
            (dockWidth - metrics.contentPadding.horizontal)
                .clamp(0.0, double.infinity)
                .toDouble();
        final double slotWidth = contentWidth / _slotCount;
        final double indicatorWidth = (slotWidth * metrics.indicatorWidthFactor)
            .clamp(metrics.indicatorMinWidth, metrics.indicatorMaxWidth)
            .toDouble();
        return RepaintBoundary(
          child: SafeArea(
            bottom: true,
            minimum: EdgeInsets.zero,
            child: Padding(
              padding: EdgeInsets.only(
                left: metrics.horizontalMargin,
                right: metrics.horizontalMargin,
                bottom: metrics.outerBottomGap,
              ),
              child: SizedBox(
                height: metrics.height,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(metrics.radius),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: metrics.shadowBlur,
                        spreadRadius: 0,
                        offset: Offset(0, metrics.shadowOffset),
                      ),
                      BoxShadow(
                        color: glow,
                        blurRadius: metrics.glowBlur,
                        spreadRadius: -5,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(metrics.radius),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: LiquidGlassDockTokens.dockBlurSigma,
                        sigmaY: LiquidGlassDockTokens.dockBlurSigma,
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(metrics.radius),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: glassColors,
                            stops: const <double>[0.0, 0.3, 0.7, 1.0],
                          ),
                          border: Border.all(color: borderGlass, width: 1.5),
                        ),
                        child: Padding(
                          padding: metrics.contentPadding,
                          child: AnimatedBuilder(
                            animation: _indicatorController,
                            builder: (BuildContext context, Widget? child) {
                              final double center =
                                  _indicatorController.isAnimating
                                      ? _indicatorCenterAnimation.value
                                      : _indicatorCenter;
                              final double rawLeft =
                                  center * contentWidth - indicatorWidth / 2;
                              final double maxLeft =
                                  contentWidth > indicatorWidth + 8
                                      ? contentWidth - indicatorWidth - 4
                                      : 4;
                              final double left =
                                  rawLeft.clamp(4.0, maxLeft).toDouble();
                              return Stack(
                                alignment: Alignment.center,
                                children: <Widget>[
                                  Positioned(
                                    left: left,
                                    top: metrics.indicatorTop,
                                    child: _SlidingGlassIndicator(
                                      width: indicatorWidth,
                                      height: metrics.indicatorHeight,
                                    ),
                                  ),
                                  child!,
                                ],
                              );
                            },
                            child: Row(
                              children: <Widget>[
                                Expanded(
                                  child: Center(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: _buildNavItem(
                                        colorScheme: colorScheme,
                                        isLight: isLight,
                                        index: 0,
                                        icon: Icons.home,
                                        label: 'Home',
                                        metrics: metrics,
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Center(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: _buildNavItem(
                                        colorScheme: colorScheme,
                                        isLight: isLight,
                                        index: 1,
                                        icon: Icons.people,
                                        label: 'Network',
                                        metrics: metrics,
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Center(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: _buildCreateButton(
                                        colorScheme: colorScheme,
                                        isLight: isLight,
                                        on: on,
                                        metrics: metrics,
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Center(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: _buildInboxNavItem(
                                        colorScheme: colorScheme,
                                        isLight: isLight,
                                        on: on,
                                        metrics: metrics,
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Center(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: _buildNavItem(
                                        colorScheme: colorScheme,
                                        isLight: isLight,
                                        index: 4,
                                        label: 'Profile',
                                        metrics: metrics,
                                        customIcon: _buildProfileAvatarNavIcon(
                                          colorScheme: colorScheme,
                                          isLight: isLight,
                                          metrics: metrics,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavItem({
    required ColorScheme colorScheme,
    required bool isLight,
    required int index,
    IconData? icon,
    required String label,
    required _NavMetrics metrics,
    Widget? customIcon,
    GlobalKey? tourKey,
  }) {
    final bool isSelected = widget.currentIndex == index;
    final Color on = colorScheme.onSurface;
    final Color activeColor = isLight ? colorScheme.primary : Colors.white;
    final Color inactiveColor = isLight
        ? colorScheme.onSurfaceVariant.withValues(
            alpha: LiquidGlassDockTokens.inactiveIconOpacity,
          )
        : on.withValues(alpha: LiquidGlassDockTokens.inactiveIconOpacity);
    final Color contentColor = isSelected ? activeColor : inactiveColor;
    final Widget renderedIcon = customIcon ??
        Icon(
          icon,
          color: contentColor,
          size: metrics.iconSize,
        );
    final Widget iconWidget = AnimatedScale(
      scale: isSelected ? LiquidGlassDockTokens.activeIconScale : 1,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: isSelected ? 1 : 0.84,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: IconTheme(
          data: IconThemeData(color: contentColor, size: metrics.iconSize),
          child: renderedIcon,
        ),
      ),
    );
    final Widget iconSlot = tourKey != null
        ? KeyedSubtree(key: tourKey, child: iconWidget)
        : iconWidget;
    final Widget tapTarget = OptimizedButton(
      key: switch (index) {
        0 => QaKeys.bottomNavHome,
        1 => QaKeys.bottomNavNetwork,
        _ => null,
      },
      buttonId: 'nav_$index',
      onPressed: () => _handleTap(index),
      enableHaptic: false,
      child: Padding(
        padding: EdgeInsets.all(metrics.itemPadding),
        child: SizedBox.square(
          dimension: metrics.tapTargetSize,
          child: Center(child: iconSlot),
        ),
      ),
    );
    return Semantics(
      label: label,
      hint: isSelected ? 'Selected tab' : 'Tap to switch to $label tab',
      selected: isSelected,
      button: true,
      child: tapTarget,
    );
  }

  Widget _buildInboxNavItem({
    required ColorScheme colorScheme,
    required bool isLight,
    required Color on,
    required _NavMetrics metrics,
  }) {
    const int index = 3;
    final bool isSelected = widget.currentIndex == index;
    final Color activeColor = isLight ? colorScheme.primary : Colors.white;
    final Color inactiveColor = isLight
        ? colorScheme.onSurfaceVariant.withValues(
            alpha: LiquidGlassDockTokens.inactiveIconOpacity,
          )
        : on.withValues(alpha: LiquidGlassDockTokens.inactiveIconOpacity);
    final Color contentColor = isSelected ? activeColor : inactiveColor;
    final int messageUnreadCount = ref.watch(unreadMessagesProvider).maybeWhen(
          data: (int count) => count,
          orElse: () => 0,
        );
    return Semantics(
      label: 'Inbox',
      hint: isSelected ? 'Selected inbox tab' : 'Tap to open inbox',
      selected: isSelected,
      button: true,
      child: OptimizedButton(
        buttonId: 'nav_inbox',
        onPressed: () => _handleTap(index),
        enableHaptic: false,
        child: Padding(
          padding: EdgeInsets.all(metrics.itemPadding),
          child: SizedBox.square(
            dimension: metrics.tapTargetSize,
            child: Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  AnimatedScale(
                    scale:
                        isSelected ? LiquidGlassDockTokens.activeIconScale : 1,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: AnimatedOpacity(
                      opacity: isSelected ? 1 : 0.84,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      child: Icon(
                        Icons.mail_outline,
                        color: contentColor,
                        size: metrics.iconSize,
                      ),
                    ),
                  ),
                  if (messageUnreadCount > 0)
                    Positioned(
                      right: -7,
                      top: -7,
                      child: Semantics(
                        label: '$messageUnreadCount unread messages',
                        child: Container(
                          padding: EdgeInsets.all(metrics.badgePadding),
                          decoration: BoxDecoration(
                            color: colorScheme.error,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                          constraints: BoxConstraints(
                            minWidth: metrics.badgeMinSize,
                            minHeight: metrics.badgeMinSize,
                          ),
                          child: Text(
                            messageUnreadCount > 99
                                ? '99+'
                                : '$messageUnreadCount',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: colorScheme.onError,
                              fontSize: metrics.badgeFontSize,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCreateButton({
    required ColorScheme colorScheme,
    required bool isLight,
    required Color on,
    required _NavMetrics metrics,
  }) {
    final bool isSelected = widget.currentIndex == _createIndex;
    final Color activeColor = isLight ? colorScheme.primary : Colors.white;
    final Color inactiveColor = isLight
        ? colorScheme.onSurfaceVariant.withValues(
            alpha: LiquidGlassDockTokens.inactiveIconOpacity,
          )
        : on.withValues(alpha: LiquidGlassDockTokens.inactiveIconOpacity);
    final Color iconColor = isSelected ? activeColor : inactiveColor;
    return KeyedSubtree(
      child: Semantics(
        label: 'Create content',
        hint: 'Tap to open camera and create new content',
        button: true,
        child: OptimizedButton(
          buttonId: 'nav_add',
          onPressed: () => _handleTap(_createIndex),
          enableHaptic: false,
          child: Padding(
            padding: EdgeInsets.all(metrics.itemPadding),
            child: SizedBox.square(
              dimension: metrics.tapTargetSize,
              child: Center(
                child: AnimatedScale(
                  scale: isSelected ? LiquidGlassDockTokens.activeIconScale : 1,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  child: Icon(
                    Icons.add,
                    color: iconColor,
                    size: metrics.createIconSize,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileAvatarNavIcon({
    required ColorScheme colorScheme,
    required bool isLight,
    required _NavMetrics metrics,
  }) {
    final Map<String, dynamic>? userData =
        ref.watch(currentUserStreamProvider).valueOrNull;
    final String? resolvedAvatarUrl = resolveAvatarUrl(userData) ??
        normalizeAvatarPhotoUrl(
          firebase_auth.FirebaseAuth.instance.currentUser?.photoURL,
        );
    final bool isSelected = widget.currentIndex == 4;
    final Color borderColor = isSelected
        ? Colors.white.withValues(alpha: isLight ? 0.92 : 0.84)
        : Colors.white.withValues(alpha: isLight ? 0.58 : 0.24);
    final double avatarSize = metrics.avatarSize;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: avatarSize,
      height: avatarSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isLight
            ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.82)
            : Colors.black.withValues(alpha: 0.62),
        border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
        boxShadow: <BoxShadow>[
          if (isSelected)
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.18),
              blurRadius: 14,
              spreadRadius: 1,
            ),
        ],
        image: resolvedAvatarUrl != null && resolvedAvatarUrl.isNotEmpty
            ? DecorationImage(
                image: NetworkImage(resolvedAvatarUrl),
                fit: BoxFit.cover,
                onError: (_, __) {},
              )
            : null,
      ),
      child: resolvedAvatarUrl == null || resolvedAvatarUrl.isEmpty
          ? Icon(
              Icons.person,
              color: isLight
                  ? colorScheme.onSurfaceVariant.withValues(alpha: 0.78)
                  : Colors.white.withValues(alpha: 0.82),
              size: avatarSize * 0.58,
            )
          : null,
    );
  }
}

class _NavMetrics {
  const _NavMetrics({
    required this.height,
    required this.horizontalMargin,
    required this.outerBottomGap,
    required this.radius,
    required this.contentPadding,
    required this.itemPadding,
    required this.iconSize,
    required this.createIconSize,
    required this.tapTargetSize,
    required this.avatarSize,
    required this.badgePadding,
    required this.badgeMinSize,
    required this.badgeFontSize,
    required this.indicatorMinWidth,
    required this.indicatorMaxWidth,
    required this.indicatorWidthFactor,
    required this.indicatorHeight,
    required this.indicatorTop,
    required this.shadowBlur,
    required this.glowBlur,
    required this.shadowOffset,
  });

  final double height;
  final double horizontalMargin;
  final double outerBottomGap;
  final double radius;
  final EdgeInsets contentPadding;
  final double itemPadding;
  final double iconSize;
  final double createIconSize;
  final double tapTargetSize;
  final double avatarSize;
  final double badgePadding;
  final double badgeMinSize;
  final double badgeFontSize;
  final double indicatorMinWidth;
  final double indicatorMaxWidth;
  final double indicatorWidthFactor;
  final double indicatorHeight;
  final double indicatorTop;
  final double shadowBlur;
  final double glowBlur;
  final double shadowOffset;

  factory _NavMetrics.from({
    required double availableWidth,
    required AppResponsive responsive,
    required bool hasSystemNavBar,
  }) {
    final bool compact = responsive.isCompactPhone || availableWidth < 360;
    final bool small = responsive.isSmallPhone || availableWidth < 390;
    final bool tight = availableWidth / 5 < 58;
    return _NavMetrics(
      height: compact ? 64 : (small ? 68 : 70),
      horizontalMargin: compact ? 10 : (small ? 14 : 18),
      outerBottomGap: hasSystemNavBar ? 8 : 12,
      radius: responsive.radius(40),
      contentPadding: EdgeInsets.fromLTRB(
        tight ? 6 : (compact ? 8 : 12),
        compact ? 7 : 8,
        tight ? 6 : (compact ? 8 : 12),
        compact ? 7 : 8,
      ),
      itemPadding: 0,
      iconSize: tight ? 27 : (compact ? 29 : 31),
      createIconSize: compact ? 34 : 36,
      tapTargetSize: compact ? 46 : 48,
      avatarSize: compact ? 34 : 38,
      badgePadding: compact ? 3 : 4,
      badgeMinSize: compact ? 15 : 16,
      badgeFontSize: compact ? 9 : 10,
      indicatorMinWidth: compact ? 50 : 54,
      indicatorMaxWidth: compact ? 62 : 68,
      indicatorWidthFactor: compact ? 0.82 : 0.78,
      indicatorHeight: compact ? 50 : 54,
      indicatorTop: compact ? 0 : 0,
      shadowBlur: compact ? 28 : 34,
      glowBlur: compact ? 14 : 18,
      shadowOffset: compact ? 9 : 12,
    );
  }
}

class _SlidingGlassIndicator extends StatelessWidget {
  const _SlidingGlassIndicator({
    required this.width,
    required this.height,
  });

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(height / 2),
              gradient: RadialGradient(
                center: const Alignment(-0.35, -0.45),
                radius: 1.25,
                colors: <Color>[
                  Colors.white.withValues(alpha: 0.32),
                  LiquidGlassDockTokens.orbGradientStart.withValues(alpha: 0.3),
                  LiquidGlassDockTokens.orbGradientEnd.withValues(alpha: 0.18),
                  Colors.white.withValues(alpha: 0.06),
                ],
                stops: const <double>[0, 0.42, 0.72, 1],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.22),
                width: 1,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: LiquidGlassDockTokens.orbGradientStart.withValues(
                    alpha: 0.22,
                  ),
                  blurRadius: 18,
                  spreadRadius: -6,
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.12),
                  blurRadius: 10,
                  spreadRadius: -5,
                ),
              ],
            ),
            child: SizedBox(
              width: width,
              height: height,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(height / 2),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      Colors.white.withValues(alpha: 0.18),
                      Colors.white.withValues(alpha: 0.02),
                      Colors.white.withValues(alpha: 0.1),
                    ],
                    stops: const <double>[0, 0.52, 1],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
