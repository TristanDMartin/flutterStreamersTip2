import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui';
import 'dart:io' show Platform;
import '../providers/unread_messages_provider.dart';
import '../providers/activity_provider.dart';
import '../utils/performance_utils.dart';

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
    // Get safe area padding for platform-specific adjustments
    final mediaQuery = MediaQuery.of(context);
    final bottomPadding = mediaQuery.padding.bottom;
    final isIOS = Platform.isIOS;

    // Increased internal bottom padding to prevent text cutoff
    final internalBottomPadding = isIOS ? 14.0 : 12.0;
    // Bottom margin to lift nav bar above bottom edge, reduced by 3px to move down
    final bottomMargin = 10.0 +
        bottomPadding; // Account for safe area + extra lift (reduced by 3px)

    return Container(
      margin: EdgeInsets.only(
        bottom: bottomMargin,
        left: 16,
        right: 16,
      ),
      child: SizedBox(
        height:
            96, // Fixed height to accommodate icon + text + padding (increased by 1px to prevent overflow)
        child: Container(
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(30), // More rounded for liquid effect
            boxShadow: [
              // Outer shadow for depth
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 30,
                spreadRadius: 0,
                offset: const Offset(0, 10),
              ),
              // Inner glow for glass effect
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.1),
                blurRadius: 20,
                spreadRadius: -5,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                  sigmaX: 40, sigmaY: 40), // Strong blur for liquid glass
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  // Enhanced liquid glass gradient with multiple layers
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.25), // Bright top layer
                      Colors.white.withValues(alpha: 0.15), // Mid-top layer
                      Colors.white.withValues(alpha: 0.05), // Mid layer
                      Colors.black.withValues(alpha: 0.3), // Dark bottom layer
                    ],
                    stops: const [0.0, 0.3, 0.7, 1.0],
                  ),
                  // Enhanced glass border with gradient effect
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 12,
                  bottom: internalBottomPadding,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(0, Icons.home, 'Home'),
                    _buildNavItem(1, Icons.people, 'Network'),
                    _buildAddButton(),
                    _buildInboxNavItem(ref),
                    _buildNavItem(4, Icons.account_circle_outlined, 'Profile'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
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
          padding: const EdgeInsets.only(
            top: 4,
            bottom: 4,
            left: 4,
            right: 4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? Colors.white.withValues(
                          alpha: 0.2) // More visible selected background
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
                      : Colors.white.withValues(
                          alpha: 0.4), // More visible when not selected
                  size: 24,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withValues(
                          alpha: 0.4), // More visible when not selected
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInboxNavItem(WidgetRef ref) {
    final isSelected = currentIndex == 3;
    final unreadCountAsync = ref.watch(unreadMessagesProvider);
    final activityUnreadCount = ref.watch(unreadActivityCountProvider);

    // Calculate total unread count (messages + activity notifications)
    int totalUnreadCount = 0;
    unreadCountAsync.whenOrNull(
      data: (unreadCount) => totalUnreadCount += unreadCount,
    );

    // Add activity notification count (from separate provider)
    totalUnreadCount += activityUnreadCount;

    return Semantics(
      label: 'Inbox',
      hint: isSelected ? 'Selected inbox tab' : 'Tap to open inbox',
      selected: isSelected,
      button: true,
      child: OptimizedButton(
        buttonId: 'nav_inbox',
        onPressed: () => onTap(3),
        child: Padding(
          padding: const EdgeInsets.only(
            top: 4,
            bottom: 4,
            left: 4,
            right: 4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
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
                      size: 24,
                    ),
                  ),
                  // Combined unread badge
                  if (totalUnreadCount > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Semantics(
                        label: '$totalUnreadCount unread notifications',
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            totalUnreadCount > 99
                                ? '99+'
                                : totalUnreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Inbox',
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.4),
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return Semantics(
      label: 'Create content',
      hint: 'Tap to open camera and create new content',
      button: true,
      child: OptimizedButton(
        buttonId: 'nav_add',
        onPressed: () => onTap(2),
        child: Padding(
          padding: const EdgeInsets.only(
            top: 4,
            bottom: 4,
            left: 4,
            right: 4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF9248D2), // AppColors.primary (purple)
                      Color(0xFF7768DF), // AppColors.secondary (purple)
                      Color(0xFF1670DE), // AppColors.tertiary (blue)
                    ],
                    stops: [0.0, 0.5, 1.0],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF9248D2).withValues(alpha: 0.4),
                      blurRadius: 15,
                      spreadRadius: 0,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.add,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Create',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 12,
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
