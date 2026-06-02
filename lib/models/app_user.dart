import 'online_status.dart';

class AppUser {
  final String id;
  final String displayName;
  final String username;
  final String? avatarURL;
  final OnlineStatus onlineStatus;

  const AppUser({
    required this.id,
    required this.displayName,
    required this.username,
    this.avatarURL,
    this.onlineStatus = OnlineStatus.invisible,
  });
}
