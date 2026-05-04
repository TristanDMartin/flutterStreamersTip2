import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/st_theme_tokens.dart';

import '../providers/activity_provider.dart';
import '../providers/unread_messages_provider.dart';
import '../utils/performance_utils.dart';
import '../utils/responsive_layout.dart';

class CustomBottomNav extends ConsumerWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final responsive = context.responsive;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final TextScaler navTextScaler = MediaQuery.textScalerOf(
      context,
    ).clamp(minScaleFactor: 0.85, maxScaleFactor: 1.0);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final ColorScheme colorScheme = Theme.of(context).colorScheme;
        final bool isLight = Theme.of(context).brightness == Brightness.light;
        final Color on = colorScheme.onSurface;
        final List<Color> glassColors = isLight
            ? <Color>[
                colorScheme.surface.withValues(alpha: 0.34),
                colorScheme.surface.withValues(alpha: 0.22),
                colorScheme.surfaceContainerLow.withValues(alpha: 0.18),
                colorScheme.surface.withValues(alpha: 0.28),
              ]
            : <Color>[
                on.withValues(alpha: 0.22),
                on.withValues(alpha: 0.12),
                on.withValues(alpha: 0.05),
                on.withValues(alpha: 0.2),
              ];
        final Color borderGlass = isLight
            ? colorScheme.outline.withValues(alpha: 0.28)
            : on.withValues(alpha: 0.35);
        final Color glow = isLight
            ? colorScheme.shadow.withValues(alpha: 0.08)
            : on.withValues(alpha: 0.1);
        const int navSlotCount = 5;
        final metrics = _NavMetrics.from(
          availableWidth: constraints.maxWidth,
          responsive: responsive,
          bottomInset: bottomInset,
          navSlotCount: navSlotCount,
        );
        return Container(
          margin: EdgeInsets.only(
            bottom: metrics.bottomMargin,
            left: metrics.horizontalMargin,
            right: metrics.horizontalMargin,
          ),
          child: SizedBox(
            height: metrics.height,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(metrics.radius),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: colorScheme.shadow,
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
                  filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(metrics.radius),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: glassColors,
                        stops: const <double>[0.0, 0.3, 0.7, 1.0],
                      ),
                      border: Border.all(
                        color: borderGlass,
                        width: 1.5,
                      ),
                    ),
                    padding: metrics.contentPadding,
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: _buildNavItem(
                                colorScheme,
                                isLight,
                                0,
                                Icons.home,
                                'Home',
                                metrics,
                                navTextScaler,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: _buildNavItem(
                                colorScheme,
                                isLight,
                                1,
                                Icons.people,
                                'Network',
                                metrics,
                                navTextScaler,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: _buildAddButton(
                                colorScheme,
                                isLight,
                                on,
                                metrics,
                                navTextScaler,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: _buildInboxNavItem(
                                ref,
                                colorScheme,
                                isLight,
                                on,
                                metrics,
                                navTextScaler,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: _buildNavItem(
                                colorScheme,
                                isLight,
                                4,
                                Icons.account_circle_outlined,
                                'Profile',
                                metrics,
                                navTextScaler,
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
        );
      },
    );
  }

  Widget _buildNavItem(
    ColorScheme colorScheme,
    bool isLight,
    int index,
    IconData icon,
    String label,
    _NavMetrics metrics,
    TextScaler navTextScaler,
  ) {
    final Color on = colorScheme.onSurface;
    final Color muted = isLight
        ? Colors.white.withValues(alpha: 0.72)
        : on.withValues(alpha: 0.4);
    final bool isSelected = currentIndex == index;
    final Color iconAndLabel = isSelected
        ? (isLight ? Colors.white : on)
        : muted;
    final Color? fill = isSelected
        ? (isLight
            ? Colors.white.withValues(alpha: 0.14)
            : on.withValues(alpha: 0.2))
        : null;
    final BoxBorder? ring = isSelected
        ? Border.all(
            color: isLight
                ? Colors.white.withValues(alpha: 0.28)
                : on.withValues(alpha: 0.3),
            width: 1,
          )
        : null;
    return Semantics(
      label: label,
      hint: isSelected ? 'Selected tab' : 'Tap to switch to $label tab',
      selected: isSelected,
      button: true,
      child: OptimizedButton(
        buttonId: 'nav_$index',
        onPressed: () => onTap(index),
        child: Padding(
          padding: EdgeInsets.all(metrics.itemPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                padding: EdgeInsets.all(metrics.iconPadding),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: fill,
                  border: ring,
                ),
                child: Icon(
                  icon,
                  color: iconAndLabel,
                  size: metrics.iconSize,
                ),
              ),
              SizedBox(height: metrics.labelGap),
              Text(
                label,
                textScaler: navTextScaler,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: iconAndLabel,
                  fontSize: metrics.labelFontSize,
                  height: 1.0,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInboxNavItem(
    WidgetRef ref,
    ColorScheme colorScheme,
    bool isLight,
    Color on,
    _NavMetrics metrics,
    TextScaler navTextScaler,
  ) {
    final isSelected = currentIndex == 3;
    final Color muted = isLight
        ? Colors.white.withValues(alpha: 0.72)
        : on.withValues(alpha: 0.4);
    final Color iconAndLabel = isSelected
        ? (isLight ? Colors.white : on)
        : muted;
    final Color? fill = isSelected
        ? (isLight
            ? Colors.white.withValues(alpha: 0.14)
            : on.withValues(alpha: 0.2))
        : null;
    final BoxBorder? ring = isSelected
        ? Border.all(
            color: isLight
                ? Colors.white.withValues(alpha: 0.28)
                : on.withValues(alpha: 0.3),
            width: 1,
          )
        : null;
    final unreadCountAsync = ref.watch(unreadMessagesProvider);
    final activityUnreadCountAsync = ref.watch(unreadActivityCountProvider);

    var totalUnreadCount = 0;
    unreadCountAsync.whenOrNull(
      data: (unreadCount) => totalUnreadCount += unreadCount,
    );
    activityUnreadCountAsync.whenOrNull(
      data: (unreadCount) => totalUnreadCount += unreadCount,
    );

    return Semantics(
      label: 'Inbox',
      hint: isSelected ? 'Selected inbox tab' : 'Tap to open inbox',
      selected: isSelected,
      button: true,
      child: OptimizedButton(
        buttonId: 'nav_inbox',
        onPressed: () => onTap(3),
        child: Padding(
          padding: EdgeInsets.all(metrics.itemPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Stack(
                children: <Widget>[
                  Container(
                    padding: EdgeInsets.all(metrics.iconPadding),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: fill,
                      border: ring,
                    ),
                    child: Icon(
                      Icons.mail_outline,
                      color: iconAndLabel,
                      size: metrics.iconSize,
                    ),
                  ),
                  if (totalUnreadCount > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Semantics(
                        label: '$totalUnreadCount unread notifications',
                        child: Container(
                          padding: EdgeInsets.all(metrics.badgePadding),
                          decoration: BoxDecoration(
                            color: colorScheme.error,
                            shape: BoxShape.circle,
                          ),
                          constraints: BoxConstraints(
                            minWidth: metrics.badgeMinSize,
                            minHeight: metrics.badgeMinSize,
                          ),
                          child: Text(
                            totalUnreadCount > 99
                                ? '99+'
                                : totalUnreadCount.toString(),
                            textScaler: navTextScaler,
                            style: TextStyle(
                              color: colorScheme.onError,
                              fontSize: metrics.badgeFontSize,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: metrics.labelGap),
              Text(
                'Inbox',
                textScaler: navTextScaler,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: iconAndLabel,
                  fontSize: metrics.labelFontSize,
                  height: 1.0,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddButton(
    ColorScheme colorScheme,
    bool isLight,
    Color on,
    _NavMetrics metrics,
    TextScaler navTextScaler,
  ) {
    final Color createMuted = isLight
        ? Colors.white.withValues(alpha: 0.72)
        : on.withValues(alpha: 0.4);
    return Semantics(
      label: 'Create content',
      hint: 'Tap to open camera and create new content',
      button: true,
      child: OptimizedButton(
        buttonId: 'nav_add',
        onPressed: () => onTap(2),
        child: Padding(
          padding: EdgeInsets.all(metrics.itemPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(metrics.iconPadding),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      StThemeColors.brandPurple,
                      StThemeColors.brandBlue,
                    ],
                    stops: <double>[0.0, 1.0],
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: StThemeColors.brandPurple.withValues(alpha: 0.4),
                      blurRadius: metrics.addShadowBlur,
                      spreadRadius: 0,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.add,
                  color: colorScheme.onPrimary,
                  size: metrics.iconSize,
                ),
              ),
              SizedBox(height: metrics.labelGap),
              Text(
                'Create',
                textScaler: navTextScaler,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: createMuted,
                  fontSize: metrics.labelFontSize,
                  height: 1.0,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavMetrics {
  const _NavMetrics({
    required this.height,
    required this.horizontalMargin,
    required this.bottomMargin,
    required this.radius,
    required this.contentPadding,
    required this.itemPadding,
    required this.iconPadding,
    required this.iconSize,
    required this.labelFontSize,
    required this.labelGap,
    required this.badgePadding,
    required this.badgeMinSize,
    required this.badgeFontSize,
    required this.shadowBlur,
    required this.glowBlur,
    required this.shadowOffset,
    required this.addShadowBlur,
  });

  final double height;
  final double horizontalMargin;
  final double bottomMargin;
  final double radius;
  final EdgeInsets contentPadding;
  final double itemPadding;
  final double iconPadding;
  final double iconSize;
  final double labelFontSize;
  final double labelGap;
  final double badgePadding;
  final double badgeMinSize;
  final double badgeFontSize;
  final double shadowBlur;
  final double glowBlur;
  final double shadowOffset;
  final double addShadowBlur;

  factory _NavMetrics.from({
    required double availableWidth,
    required AppResponsive responsive,
    required double bottomInset,
    int navSlotCount = 5,
  }) {
    final compact = responsive.isCompactPhone || availableWidth < 360;
    final small = responsive.isSmallPhone || availableWidth < 390;
    final safeLift = bottomInset > 0 ? bottomInset + 6.0 : 8.0;
    final double perSlot =
        navSlotCount > 0 ? availableWidth / navSlotCount : availableWidth;
    final bool tightSlots = perSlot < 58;

    return _NavMetrics(
      height: compact ? 82 : (small ? 86 : 90),
      horizontalMargin: compact ? 10 : 16,
      bottomMargin: safeLift,
      radius: responsive.radius(compact ? 24 : 28),
      contentPadding: EdgeInsets.fromLTRB(
        tightSlots ? 4 : (compact ? 8 : 14),
        compact ? 7 : 9,
        tightSlots ? 4 : (compact ? 8 : 14),
        compact ? 7 : 9,
      ),
      itemPadding: tightSlots ? 1 : (compact ? 2 : 3),
      iconPadding: tightSlots ? 4 : (compact ? 6 : 7),
      iconSize: tightSlots ? 18 : (compact ? 20 : 22),
      labelFontSize: tightSlots ? 9 : (compact ? 10 : 11),
      labelGap: compact ? 3 : 4,
      badgePadding: compact ? 3 : 4,
      badgeMinSize: compact ? 15 : 16,
      badgeFontSize: compact ? 9 : 10,
      shadowBlur: compact ? 22 : 28,
      glowBlur: compact ? 16 : 20,
      shadowOffset: compact ? 8 : 10,
      addShadowBlur: compact ? 12 : 15,
    );
  }
}
