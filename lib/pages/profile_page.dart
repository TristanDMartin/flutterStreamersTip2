import 'package:flutter/material.dart';
import '../widgets/profile_view.dart';
import '../models/user.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock user data for the current user
    const User currentUser = User(
      id: 'current_user_123',
      username: 'streamerpro',
      displayName: 'Alex Streamer',
      bio:
          'Professional gamer and content creator. Love sharing epic moments with the community! 🎮',
      avatarURL: 'https://via.placeholder.com/200x200/9248D2/FFFFFF?text=AS',
      onlineStatus: 'online',
      hashtags: <String>['gaming', 'streamer', 'esports', 'community'],
      followerCount: 12500,
      followingCount: 850,
      postCount: 45,
    );

    return const ProfileView(
      user: currentUser,
      isCurrentUser: true, // This is the current user's profile
    );
  }
}
