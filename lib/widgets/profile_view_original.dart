import 'package:flutter/material.dart';
import '../models/user.dart';
import 'edit_profile_view.dart';
import 'profile_back_view.dart';
import 'custom_bottom_nav.dart';
import 'camera_view_optimized.dart';
import 'inbox_view_optimized.dart';

class ProfileView extends StatefulWidget {
  final User user;
  final bool isCurrentUser;

  const ProfileView(
      {super.key, required this.user, required this.isCurrentUser});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView>
    with TickerProviderStateMixin {
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  bool _isFront = true;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _flipAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _flipController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _flipCard() {
    if (_isFront) {
      _flipController.forward();
    } else {
      _flipController.reverse();
    }
    _isFront = !_isFront;
  }

  Map<String, dynamic> _toMap(User user) => {
        'id': user.id,
        'username': user.username,
        'displayName': user.displayName,
        'bio': user.bio ?? '',
        'avatarURL': user.avatarURL,
        'onlineStatus': user.onlineStatus,
        'hashtags': user.hashtags,
        'followerCount': user.followerCount,
        'followingCount': user.followingCount,
        'calendarEvents': user.calendarEvents
            .map((e) => {
                  'id': e.id,
                  'title': e.title,
                  'description': e.description,
                  'date': e.date,
                })
            .toList(),
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true, // This allows body to extend behind bottom navigation
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6137EB), Color(0xFF1C135D)],
          ),
        ),
        child: AnimatedBuilder(
          animation: _flipAnimation,
          builder: (context, child) {
            final isShowingFront = _flipAnimation.value < 0.5;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(_flipAnimation.value * 3.14159),
              child: isShowingFront
                  ? EditProfileView(
                      user: _toMap(widget.user),
                      onUserUpdated: (updatedUser) {
                        // Handle user update
                      },
                    )
                  : Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..rotateY(3.14159),
                      child: ProfileBackView(
                        user: _toMap(widget.user),
                        onFlip: _flipCard,
                      ),
                    ),
            );
          },
        ),
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: 4, // Profile tab index
        onTap: (index) => _onTabTapped(context, index),
      ),
    );
  }

  void _onTabTapped(BuildContext context, int index) {
    // Handle navigation for profile view
    if (index == 0) {
      // Home
      Navigator.of(context).pop();
    } else if (index == 1) {
      // Network - could navigate to network view
      Navigator.of(context).pop();
    } else if (index == 2) {
      // Create - navigate directly to camera view
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const CameraViewOptimized(),
        ),
      );
    } else if (index == 3) {
      // Inbox - navigate to inbox view
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const InboxViewOptimized(),
          fullscreenDialog: true,
        ),
      );
    }
    // index == 4 is current profile, no action needed
  }
}
