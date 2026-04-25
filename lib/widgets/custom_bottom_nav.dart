import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = _NavMetrics.from(
          availableWidth: constraints.maxWidth,
          responsive: responsive,
          bottomInset: bottomInset,
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
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: metrics.shadowBlur,
                    spreadRadius: 0,
                    offset: Offset(0, metrics.shadowOffset),
                  ),
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.1),
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
                        colors: [
                          Colors.white.withValues(alpha: 0.25),
                          Colors.white.withValues(alpha: 0.15),
                          Colors.white.withValues(alpha: 0.05),
                          Colors.black.withValues(alpha: 0.3),
                        ],
                        stops: const [0.0, 0.3, 0.7, 1.0],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    padding: metrics.contentPadding,
                    child: Row(
                      children: [
                        Expanded(
                          child: Center(
                            child:
                                _buildNavItem(0, Icons.home, 'Home', metrics),
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: _buildNavItem(
                              1,
                              Icons.people,
                              'Network',
                              metrics,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Center(child: _buildAddButton(metrics)),
                        ),
                        Expanded(
                          child: Center(
                            child: _buildInboxNavItem(ref, metrics),
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: _buildNavItem(
                              4,
                              Icons.account_circle_outlined,
                              'Profile',
                              metrics,
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
    int index,
    IconData icon,
    String label,
    _NavMetrics metrics,
  ) {
    final isSelected = currentIndex == index;

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
            children: [
              Container(
                padding: EdgeInsets.all(metrics.iconPadding),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.2)
                      : Colors.transparent,
                  border: isSelected
                      ? Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 1,
                        )
                      : null,
                ),
                child: Icon(
                  icon,
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.4),
                  size: metrics.iconSize,
                ),
              ),
              SizedBox(height: metrics.labelGap),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.4),
                  fontSize: metrics.labelFontSize,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInboxNavItem(WidgetRef ref, _NavMetrics metrics) {
    final isSelected = currentIndex == 3;
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
            children: [
              Stack(
                children: [
                  Container(
                    padding: EdgeInsets.all(metrics.iconPadding),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.2)
                          : Colors.transparent,
                      border: isSelected
                          ? Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1,
                            )
                          : null,
                    ),
                    child: Icon(
                      Icons.mail_outline,
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.4),
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
                          decoration: const BoxDecoration(
                            color: Colors.red,
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
                            style: TextStyle(
                              color: Colors.white,
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.4),
                  fontSize: metrics.labelFontSize,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddButton(_NavMetrics metrics) {
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
                    colors: [
                      Color(0xFF9248D2),
                      Color(0xFF7768DF),
                      Color(0xFF1670DE),
                    ],
                    stops: [0.0, 0.5, 1.0],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF9248D2).withValues(alpha: 0.4),
                      blurRadius: metrics.addShadowBlur,
                      spreadRadius: 0,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.add,
                  color: Colors.white,
                  size: metrics.iconSize,
                ),
              ),
              SizedBox(height: metrics.labelGap),
              Text(
                'Create',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: metrics.labelFontSize,
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
  }) {
    final compact = responsive.isCompactPhone || availableWidth < 360;
    final small = responsive.isSmallPhone || availableWidth < 390;
    final scale = responsive.scale;
    final safeLift = bottomInset > 0 ? bottomInset + 6.0 : 8.0;

    return _NavMetrics(
      height: compact ? 76 : (small ? 80 : 84),
      horizontalMargin: compact ? 10 : 16,
      bottomMargin: safeLift,
      radius: responsive.radius(compact ? 24 : 28),
      contentPadding: EdgeInsets.fromLTRB(
        compact ? 10 : 16,
        compact ? 8 : 10,
        compact ? 10 : 16,
        compact ? 8 : 10,
      ),
      itemPadding: compact ? 2 : 3,
      iconPadding: compact ? 6 : 7,
      iconSize: (compact ? 21 : 23) * scale,
      labelFontSize: compact ? 10.5 : 11.5,
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
