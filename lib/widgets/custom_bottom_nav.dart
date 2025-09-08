import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui';
import '../providers/unread_messages_provider.dart';

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
    return Container(
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
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
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = currentIndex == index;
    
    return GestureDetector(
      onTap: () => onTap(index),
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
    );
  }

  Widget _buildInboxNavItem(WidgetRef ref) {
    final isSelected = currentIndex == 3;
    final unreadCountAsync = ref.watch(unreadMessagesProvider);
    
    return GestureDetector(
      onTap: () => onTap(3),
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
              // Unread badge
              unreadCountAsync.when(
                data: (unreadCount) {
                  if (unreadCount > 0) {
                    return Positioned(
                      right: 0,
                      top: 0,
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
                          unreadCount > 99 ? '99+' : unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
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
    );
  }

  Widget _buildAddButton() {
    return GestureDetector(
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
    );
  }
}
