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
    
    // Platform-specific padding adjustments - increased to prevent overflow
    final extraBottomPadding = isIOS ? 12.0 : 8.0;
    final totalBottomPadding = bottomPadding + extraBottomPadding;
    
    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: 60 + totalBottomPadding, // Minimum height to prevent overflow
        maxHeight: 100 + totalBottomPadding, // Maximum height to prevent overflow
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(25),
            topRight: Radius.circular(25),
          ),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(25),
            topRight: Radius.circular(25),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25), // Stronger blur for liquid glass
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(25),
                  topRight: Radius.circular(25),
                ),
                // Enhanced liquid glass effect with better contrast
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.15), // Brighter top glass layer
                    Colors.white.withValues(alpha: 0.08), // Middle glass layer
                    Colors.black.withValues(alpha: 0.4), // Darker bottom glass layer
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
                // Enhanced glass border effect
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1.5,
                ),
                // Enhanced shadows for more depth
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 40,
                    spreadRadius: 0,
                    offset: const Offset(0, -15),
                  ),
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.15),
                    blurRadius: 25,
                    spreadRadius: 0,
                    offset: const Offset(0, 8),
                  ),
                  // Inner glow effect
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.1),
                    blurRadius: 15,
                    spreadRadius: -5,
                    offset: const Offset(0, 0),
                  ),
                ],
              ),
              child: Container(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 15,
                  bottom: totalBottomPadding,
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected 
                  ? Colors.white.withValues(alpha: 0.2) // More visible selected background
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
                  : Colors.white.withValues(alpha: 0.4), // More visible when not selected
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected 
                  ? Colors.white 
                  : Colors.white.withValues(alpha: 0.4), // More visible when not selected
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInboxNavItem(WidgetRef ref) {
    final isSelected = currentIndex == 3;
    final unreadCountAsync = ref.watch(unreadMessagesProvider);
    final activityState = ref.watch(activityProvider);
    
    // Calculate total unread count (messages + activity notifications)
    int totalUnreadCount = 0;
    unreadCountAsync.whenOrNull(
      data: (unreadCount) => totalUnreadCount += unreadCount,
    );
    
    // Add activity notification count
    for (final notifications in activityState.grouped.values) {
      for (final notification in notifications) {
        if (notification.status == 'pending') {
          totalUnreadCount++;
        }
      }
    }
    
    return Semantics(
      label: 'Inbox',
      hint: isSelected ? 'Selected inbox tab' : 'Tap to open inbox',
      selected: isSelected,
      button: true,
      child: OptimizedButton(
        buttonId: 'nav_inbox',
        onPressed: () => onTap(3),
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
                          totalUnreadCount > 99 ? '99+' : totalUnreadCount.toString(),
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
    );
  }

  Widget _buildAddButton() {
    return Semantics(
      label: 'Create content',
      hint: 'Tap to open camera and create new content',
      button: true,
      child: GestureDetector(
        onTap: () => onTap(2),
        child: Container(
          padding: const EdgeInsets.all(12),
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
            size: 28,
          ),
        ),
      ),
    );
  }
}
