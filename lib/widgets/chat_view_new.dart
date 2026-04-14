import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/chat.dart';
import 'chat_view_optimized.dart';

@Deprecated('Use ChatViewOptimized directly for new chat surfaces.')
class ChatViewNew extends StatelessWidget {
  const ChatViewNew({
    super.key,
    required this.chat,
    required this.otherUserName,
    this.otherUserAvatarURL,
    required this.otherUserIsOnline,
    required this.authService,
  });

  final Chat chat;
  final String otherUserName;
  final String? otherUserAvatarURL;
  final bool otherUserIsOnline;
  final Object authService;

  String _resolveOtherUserId() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    return chat.participants.firstWhere(
      (participantId) => participantId != currentUserId,
      orElse: () => '',
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChatViewOptimized(
      chat: chat,
      otherUserId: _resolveOtherUserId(),
      otherUserName: otherUserName,
      otherUserAvatarURL: otherUserAvatarURL,
      otherUserIsOnline: otherUserIsOnline,
    );
  }
}
