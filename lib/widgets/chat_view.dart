import 'package:flutter/material.dart';

import '../models/chat.dart';
import 'chat_view_optimized.dart';

@Deprecated('Use ChatViewOptimized directly for new chat surfaces.')
class ChatView extends StatelessWidget {
  const ChatView({
    super.key,
    required this.chat,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserAvatarURL,
    required this.otherUserIsOnline,
    this.draftToSend,
  });

  final Chat chat;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserAvatarURL;
  final bool otherUserIsOnline;
  final Map<String, dynamic>? draftToSend;

  @override
  Widget build(BuildContext context) {
    return ChatViewOptimized(
      chat: chat,
      otherUserId: otherUserId,
      otherUserName: otherUserName,
      otherUserAvatarURL: otherUserAvatarURL,
      otherUserIsOnline: otherUserIsOnline,
      draftToSend: draftToSend,
    );
  }
}
