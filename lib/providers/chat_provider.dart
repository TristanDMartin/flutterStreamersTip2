import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/chat.dart';
import '../models/message.dart';
import '../services/auth_service.dart';
import '../services/r2_media_service.dart';

class ChatNotifier extends StateNotifier<ChatState> {
  final Chat chat;
  final AuthenticationService authService;
  StreamSubscription<QuerySnapshot>?
      _messageListener; // kept for API compatibility
  Timer? _typingDebounce;

  // Persistence key
  String get _messagesKey => "ChatNotifier_messages_${chat.id ?? "unknown"}";

  ChatNotifier(this.chat, this.authService) : super(ChatState.initial()) {
    _loadPersistedMessages();
    _setupChat();
  }

  @override
  void dispose() {
    _typingDebounce?.cancel();
    unawaited(setTyping(false));
    _messageListener?.cancel();
    _messageListener = null;
    super.dispose();
  }

  void _setupChat() {
    if (!validateChat()) return;
    final chatId = chat.id;
    if (chatId == null || chatId.isEmpty) {
      state = state.copyWith(
        error: "Invalid chat ID",
        isLoading: false,
      );
      return;
    }
    _setupMessageListener(chatId: chatId);
  }

  void _setupMessageListener({required String chatId}) {
    if (chatId.isEmpty) {
      state = state.copyWith(
        error: "Chat ID cannot be empty",
        isLoading: false,
      );
      return;
    }

    _messageListener?.cancel();
    state = state.copyWith(isLoading: true, error: null);
    _messageListener = FirebaseFirestore.instance
        .collection("chats")
        .doc(chatId)
        .collection("messages")
        .orderBy("timestamp", descending: false)
        .snapshots()
        .listen(
      (snapshot) async {
        final docs = snapshot.docs;
        final List<Message> firebaseMessages = docs.map((d) {
          final data = d.data();
          debugPrint(
              '📱 ChatNotifier: Converting message ${d.id} - data: $data');
          final parsed = Message.fromJson(data);
          debugPrint(
              '📱 ChatNotifier: Parsed message - videoId: ${parsed.videoId}, videoTitle: "${parsed.videoTitle}", videoThumbnailUrl: "${parsed.videoThumbnailUrl}"');
          return parsed.copyWith(id: d.id);
        }).toList();
        state = state.copyWith(
            messages: firebaseMessages, isLoading: false, error: null);
        await _markIncomingMessagesAsRead(docs);
        await _saveMessages();
      },
      onError: (e) {
        state = state.copyWith(isLoading: false, error: e.toString());
      },
    );
  }

  Future<void> send() async {
    final trimmedText = state.composedText.trim();
    if (trimmedText.isEmpty) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      state =
          state.copyWith(error: "You need to be signed in to send messages");
      return;
    }
    if (chat.id == null || chat.id!.isEmpty) {
      state = state.copyWith(error: "Chat not found. Please try again.");
      return;
    }

    final chatId = chat.id!;
    final otherId = chat.participants.firstWhere(
      (id) => id != currentUser.uid,
      orElse: () => "",
    );

    if (otherId.isEmpty) {
      state =
          state.copyWith(error: "Invalid chat participants. Please try again.");
      return;
    }

    // Set loading state
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Ensure chat document exists with proper participants array
      final chatDocRef =
          FirebaseFirestore.instance.collection("chats").doc(chatId);
      final chatDocSnapshot = await chatDocRef.get();

      if (!chatDocSnapshot.exists) {
        // Create chat document if it doesn't exist
        debugPrint('ChatNotifier: Creating chat document $chatId');
        await chatDocRef.set({
          "participants": [currentUser.uid, otherId],
          "lastMessage": "",
          "lastTimestamp": FieldValue.serverTimestamp(),
          "chatType": "direct",
        });

        // Wait for Firestore to propagate the document
        await Future.delayed(const Duration(milliseconds: 500));
        debugPrint('ChatNotifier: Chat document created and propagated');
      } else {
        // Verify participants array includes both users
        final data = chatDocSnapshot.data();
        final participants = List<String>.from(data?['participants'] ?? []);

        if (!participants.contains(currentUser.uid) ||
            !participants.contains(otherId)) {
          debugPrint('ChatNotifier: Updating participants for chat $chatId');
          await chatDocRef.update({
            "participants": FieldValue.arrayUnion([currentUser.uid, otherId]),
          });

          // Wait for Firestore to propagate the update
          await Future.delayed(const Duration(milliseconds: 300));
          debugPrint('ChatNotifier: Participants updated and propagated');
        }
      }

      // Send message
      await FirebaseFirestore.instance
          .collection("chats")
          .doc(chatId)
          .collection("messages")
          .add({
        "text": trimmedText,
        "from": currentUser.uid,
        "to": otherId,
        "isRead": false,
        "timestamp": FieldValue.serverTimestamp(),
        "chatId": chatId,
        "recipients": [otherId],
        "readBy": [currentUser.uid],
      });

      // Update chat last message
      await FirebaseFirestore.instance.collection("chats").doc(chatId).update({
        "lastMessage": trimmedText,
        "lastTimestamp": FieldValue.serverTimestamp(),
      });
      await setTyping(false);

      // Mark chat as read when opening (reset unread count)
      try {
        await FirebaseFirestore.instance
            .collection("chats")
            .doc(chatId)
            .update({
          "unreadCount_${currentUser.uid}": 0,
        });
        debugPrint('✅ Chat marked as read for current user');
      } catch (e) {
        debugPrint('❌ Error marking chat as read: $e');
      }

      // Clear composed text and loading state
      state = state.copyWith(composedText: "", isLoading: false);
    } catch (e) {
      String errorMessage = "Failed to send message";

      if (e.toString().contains('permission-denied')) {
        errorMessage =
            "You don't have permission to send messages in this chat";
      } else if (e.toString().contains('not-found')) {
        errorMessage = "Chat not found. Please refresh and try again";
      } else if (e.toString().contains('unavailable')) {
        errorMessage = "Service temporarily unavailable. Please try again";
      } else if (e.toString().contains('network')) {
        errorMessage = "Network error. Please check your connection";
      } else {
        errorMessage = "Failed to send message: ${e.toString()}";
      }

      debugPrint('ChatNotifier: Error sending message: $e');
      state = state.copyWith(isLoading: false, error: errorMessage);
    }
  }

  Future<void> sendGif(String gifUrl) async {
    debugPrint('ChatNotifier: sendGif called with URL: $gifUrl');

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      state =
          state.copyWith(error: "You need to be signed in to send messages");
      return;
    }
    if (chat.id == null || chat.id!.isEmpty) {
      state = state.copyWith(error: "Chat not found. Please try again.");
      return;
    }

    final chatId = chat.id!;
    final otherId = chat.participants.firstWhere(
      (id) => id != currentUser.uid,
      orElse: () => "",
    );

    if (otherId.isEmpty) {
      state =
          state.copyWith(error: "Invalid chat participants. Please try again.");
      return;
    }

    // Validate GIF URL
    if (!_isValidGifUrl(gifUrl)) {
      state = state.copyWith(error: "Invalid GIF URL. Please try again.");
      return;
    }

    // Set loading state
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Ensure chat document exists with proper participants array
      final chatDocRef =
          FirebaseFirestore.instance.collection("chats").doc(chatId);
      final chatDocSnapshot = await chatDocRef.get();

      if (!chatDocSnapshot.exists) {
        debugPrint('ChatNotifier: Creating chat document $chatId');
        await chatDocRef.set({
          "participants": [currentUser.uid, otherId],
          "lastMessage": "",
          "lastTimestamp": FieldValue.serverTimestamp(),
          "chatType": "direct",
        });

        // Wait for Firestore to propagate
        await Future.delayed(const Duration(milliseconds: 500));
      } else {
        final data = chatDocSnapshot.data();
        final participants = List<String>.from(data?['participants'] ?? []);

        if (!participants.contains(currentUser.uid) ||
            !participants.contains(otherId)) {
          debugPrint('ChatNotifier: Updating participants for chat $chatId');
          await chatDocRef.update({
            "participants": FieldValue.arrayUnion([currentUser.uid, otherId]),
          });

          // Wait for Firestore to propagate
          await Future.delayed(const Duration(milliseconds: 300));
        }
      }

      await FirebaseFirestore.instance
          .collection("chats")
          .doc(chatId)
          .collection("messages")
          .add({
        "text": "[GIF]",
        "gifUrl": gifUrl,
        "messageType": "gif",
        "from": currentUser.uid,
        "to": otherId,
        "isRead": false,
        "timestamp": FieldValue.serverTimestamp(),
        "chatId": chatId,
        "recipients": [otherId],
        "readBy": [currentUser.uid],
      });

      await FirebaseFirestore.instance.collection("chats").doc(chatId).update({
        "lastMessage": "[GIF]",
        "lastTimestamp": FieldValue.serverTimestamp(),
      });

      await setTyping(false);

      state = state.copyWith(isLoading: false);
      debugPrint('ChatNotifier: GIF sent successfully');
    } catch (e) {
      String errorMessage = "Failed to send GIF";

      if (e.toString().contains('permission-denied')) {
        errorMessage =
            "You don't have permission to send messages in this chat";
      } else if (e.toString().contains('not-found')) {
        errorMessage = "Chat not found. Please refresh and try again";
      } else if (e.toString().contains('unavailable')) {
        errorMessage = "Service temporarily unavailable. Please try again";
      } else if (e.toString().contains('network')) {
        errorMessage = "Network error. Please check your connection";
      } else if (e.toString().contains('invalid-argument')) {
        errorMessage = "Invalid GIF URL. Please try a different GIF";
      } else {
        errorMessage = "Failed to send GIF: ${e.toString()}";
      }

      state = state.copyWith(isLoading: false, error: errorMessage);
      debugPrint('ChatNotifier: Error sending GIF: $e');
    }
  }

  bool _isValidGifUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  Future<void> sendDeviceGif(File gifFile) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      state =
          state.copyWith(error: "You need to be signed in to send messages");
      return;
    }
    if (chat.id == null || chat.id!.isEmpty) {
      state = state.copyWith(error: "Chat not found. Please try again.");
      return;
    }

    final chatId = chat.id!;
    final otherId = chat.participants.firstWhere(
      (id) => id != currentUser.uid,
      orElse: () => "",
    );

    try {
      // Show loading state
      state = state.copyWith(isLoading: true, error: null);

      // Ensure chat document exists with proper participants array
      final chatDocRef =
          FirebaseFirestore.instance.collection("chats").doc(chatId);
      final chatDocSnapshot = await chatDocRef.get();

      if (!chatDocSnapshot.exists) {
        debugPrint('ChatNotifier: Creating chat document $chatId');
        await chatDocRef.set({
          "participants": [currentUser.uid, otherId],
          "lastMessage": "",
          "lastTimestamp": FieldValue.serverTimestamp(),
          "chatType": "direct",
        });

        // Wait for Firestore to propagate
        await Future.delayed(const Duration(milliseconds: 500));
      } else {
        final data = chatDocSnapshot.data();
        final participants = List<String>.from(data?['participants'] ?? []);

        if (!participants.contains(currentUser.uid) ||
            !participants.contains(otherId)) {
          debugPrint('ChatNotifier: Updating participants for chat $chatId');
          await chatDocRef.update({
            "participants": FieldValue.arrayUnion([currentUser.uid, otherId]),
          });

          // Wait for Firestore to propagate
          await Future.delayed(const Duration(milliseconds: 300));
        }
      }

      final gifUrl = await R2MediaService.instance.uploadChatGif(gifFile);

      // Send message with the uploaded GIF URL
      await FirebaseFirestore.instance
          .collection("chats")
          .doc(chatId)
          .collection("messages")
          .add({
        "text": "[Device GIF]",
        "gifUrl": gifUrl,
        "messageType": "gif",
        "isDeviceGif": true, // Flag to distinguish from Giphy GIFs
        "from": currentUser.uid,
        "to": otherId,
        "isRead": false,
        "timestamp": FieldValue.serverTimestamp(),
        "chatId": chatId,
        "recipients": [otherId],
        "readBy": [currentUser.uid],
      });

      await FirebaseFirestore.instance.collection("chats").doc(chatId).update({
        "lastMessage": "[Device GIF]",
        "lastTimestamp": FieldValue.serverTimestamp(),
      });

      await setTyping(false);

      // Clear loading state
      state = state.copyWith(isLoading: false);
    } catch (e) {
      debugPrint('ChatNotifier: Error sending device GIF: $e');
      state = state.copyWith(
        isLoading: false,
        error: "Failed to send device GIF: ${e.toString()}",
      );
    }
  }

  bool isFromCurrentUser(Message message) {
    final currentUser = FirebaseAuth.instance.currentUser;
    return currentUser != null && message.from == currentUser.uid;
  }

  String getOtherParticipant() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return 'Unknown';

    final otherId = chat.participants.firstWhere(
      (id) => id != currentUser.uid,
      orElse: () => "",
    );

    return otherId.isNotEmpty ? 'User $otherId' : 'Unknown';
  }

  void updateAuthService(Object newAuthService) {}

  void updateChatParticipants(String currentUserId) {}

  void updateChatWithRealData(Chat realChat) {}

  void updateChat(Chat newChat) {}

  void updateComposedText(String text) {
    state = state.copyWith(composedText: text);
    unawaited(setTyping(text.trim().isNotEmpty));

    _typingDebounce?.cancel();
    if (text.trim().isNotEmpty) {
      _typingDebounce = Timer(const Duration(seconds: 4), () {
        unawaited(setTyping(false));
      });
    }
  }

  Future<void> setTyping(bool isTyping) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final chatId = chat.id;
    if (currentUser == null || chatId == null || chatId.isEmpty) return;

    try {
      await FirebaseFirestore.instance.collection("chats").doc(chatId).set({
        "typingBy": {currentUser.uid: isTyping},
        "typingUpdatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('ChatNotifier: Error updating typing state: $e');
    }
  }

  Future<void> _markIncomingMessagesAsRead(
    List<QueryDocumentSnapshot<Object?>> docs,
  ) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final chatId = chat.id;
    if (currentUser == null || chatId == null || chatId.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    var hasUpdates = false;

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final from = data['from'] as String? ?? '';
      if (from == currentUser.uid) continue;

      final readBy = List<String>.from(data['readBy'] ?? const []);
      if (readBy.contains(currentUser.uid)) continue;

      batch.update(doc.reference, {
        'readBy': FieldValue.arrayUnion([currentUser.uid]),
        'isRead': true,
      });
      hasUpdates = true;
    }

    if (!hasUpdates) return;

    batch.set(
      FirebaseFirestore.instance.collection("chats").doc(chatId),
      {
        'unreadCount_${currentUser.uid}': 0,
        'lastReadTimestamp': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  Future<void> _loadPersistedMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_messagesKey);
      if (data == null) return;
      final List<dynamic> decoded = jsonDecode(data) as List<dynamic>;
      final messages = decoded
          .map((e) => Message.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(messages: messages);
    } catch (_) {}
  }

  Future<void> _saveMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded =
          jsonEncode(state.messages.map((m) => m.toJson()).toList());
      await prefs.setString(_messagesKey, encoded);
    } catch (_) {}
  }

  Future<void> _syncMessagesWithFirebase() async {} // ignore: unused_element

  bool validateChat() {
    if (chat.id == null || chat.id!.isEmpty) {
      state = state.copyWith(error: "Invalid chat data");
      return false;
    }
    if (chat.participants.isEmpty) {
      state = state.copyWith(error: "Chat has no participants");
      return false;
    }
    return true;
  }

  Future<void> testFirebasePermissions() async {}

  void clearChatData() {
    state = state.copyWith(messages: [], composedText: "", error: null);
  }

  Future<void> ensureMessagesSaved() async {}

  Future<void> saveMessagesOnBackground() async {}
}

class ChatState {
  final List<Message> messages;
  final String composedText;
  final bool isLoading;
  final String? error;

  const ChatState({
    required this.messages,
    required this.composedText,
    required this.isLoading,
    this.error,
  });

  factory ChatState.initial() => const ChatState(
        messages: [],
        composedText: "",
        isLoading: false,
      );

  ChatState copyWith({
    List<Message>? messages,
    String? composedText,
    bool? isLoading,
    String? error,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      composedText: composedText ?? this.composedText,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

// Provider for individual chat state
final chatProvider =
    StateNotifierProvider.family<ChatNotifier, ChatState, Chat>((ref, chat) {
  return ChatNotifier(chat, ref.read(authServiceProvider));
});
