import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat.dart';
import '../providers/chat_provider.dart';
import '../models/message.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class ChatViewNew extends ConsumerStatefulWidget {
  final Chat chat;
  final String otherUserName;
  final String? otherUserAvatarURL;
  final bool otherUserIsOnline;
  final Object authService;

  const ChatViewNew({
    super.key,
    required this.chat,
    required this.otherUserName,
    this.otherUserAvatarURL,
    required this.otherUserIsOnline,
    required this.authService,
  });

  @override
  ConsumerState<ChatViewNew> createState() => _ChatViewNewState();
}

class _ChatViewNewState extends ConsumerState<ChatViewNew> {
  late ChatNotifier chatNotifier;
  late TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    // print("🔍 ChatViewNew init - Chat ID: ${widget.chat.id ?? "nil"}");

    // Create the chat notifier
    chatNotifier = ChatNotifier(widget.chat, ref.read(authServiceProvider));
    _textController = TextEditingController();
  }

  @override
  void dispose() {
    chatNotifier.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.black,
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  Expanded(
                    child: Text(
                      widget.otherUserName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 48), // Balance the back button
                ],
              ),
            ),

            // Debug info
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "🔍 DEBUG INFO",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDebugRow("Auth",
                      FirebaseAuth.instance.currentUser != null ? "✅" : "❌"),
                  _buildDebugRow("Chat ID", widget.chat.id ?? "nil"),
                  _buildDebugRow(
                      "Participants", "${widget.chat.participants.length}"),
                  _buildDebugRow("Messages",
                      "${ref.watch(chatProvider(widget.chat)).messages.length}"),
                  _buildDebugRow(
                      "Loading",
                      ref.watch(chatProvider(widget.chat)).isLoading
                          ? "Yes"
                          : "No"),
                  _buildDebugRow("Other User", widget.otherUserName),
                ],
              ),
            ),

            // Messages list
            Expanded(
              child: Consumer(
                builder: (context, ref, child) {
                  final chatState = ref.watch(chatProvider(widget.chat));

                  if (chatState.isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  }

                  if (chatState.error != null) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          "Error: ${chatState.error}",
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  if (chatState.messages.isEmpty) {
                    return const Center(
                      child: Text(
                        "No messages yet. Start the conversation!",
                        style: TextStyle(color: Colors.white70),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: chatState.messages.length,
                    itemBuilder: (context, index) {
                      final message = chatState.messages[index];
                      final isFromCurrentUser =
                          chatNotifier.isFromCurrentUser(message);

                      return _buildMessageBubble(message, isFromCurrentUser);
                    },
                  );
                },
              ),
            ),

            // Input area
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.black,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      onChanged: (value) {
                        chatNotifier.updateComposedText(value);
                      },
                      decoration: const InputDecoration(
                        hintText: "Type a message...",
                        hintStyle: TextStyle(color: Colors.white70),
                        filled: true,
                        fillColor: Colors.white10,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      chatNotifier.send();
                      _textController.clear();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text("Send"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDebugRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            "$label: ",
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message message, bool isFromCurrentUser) {
    return Align(
      alignment:
          isFromCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isFromCurrentUser ? Colors.blue : Colors.white10,
          borderRadius: BorderRadius.circular(16),
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: isFromCurrentUser ? Colors.white : Colors.white,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTimestamp(message.timestamp ?? DateTime.now()),
              style: TextStyle(
                color: isFromCurrentUser ? Colors.white70 : Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final messageTime = timestamp;
    final difference = now.difference(messageTime);

    if (difference.inMinutes < 1) {
      return "Just now";
    } else if (difference.inHours < 1) {
      return "${difference.inMinutes}m ago";
    } else if (difference.inDays < 1) {
      return "${difference.inHours}h ago";
    } else {
      return "${difference.inDays}d ago";
    }
  }
}
