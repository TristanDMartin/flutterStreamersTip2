import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/chat.dart';
import '../models/message.dart';

class ChatNotifier extends StateNotifier<ChatState> {
  final Chat chat;
  final Object authService;
  StreamSubscription<QuerySnapshot>? _messageListener; // kept for API compatibility

  // Persistence key
  String get _messagesKey => "ChatNotifier_messages_${chat.id ?? "unknown"}";

  ChatNotifier(this.chat, this.authService) : super(ChatState.initial()) {
    _loadPersistedMessages();
    _setupChat();
  }

  @override
  void dispose() {
    _messageListener?.cancel();
    super.dispose();
  }

  void _setupChat() {
    if (!validateChat()) return;
    _setupMessageListener(chatId: chat.id!);
  }
  Future<void> _createChatInFirestore() async {} // ignore: unused_element
  void _subscribe() {} // ignore: unused_element
  Future<bool> _ensureChatExists({required String chatId}) async => true; // ignore: unused_element
  Future<bool> _createChatDocument({required String chatId}) async => true; // ignore: unused_element

  void _setupMessageListener({required String chatId}) {
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
          final parsed = Message.fromJson(data);
          return parsed.copyWith(id: d.id);
        }).toList();
        state = state.copyWith(messages: firebaseMessages, isLoading: false, error: null);
        await _saveMessages();
      },
      onError: (e) {
        state = state.copyWith(isLoading: false, error: e.toString());
      },
    );
  }

  void _checkChatDocumentPermissions({required String chatId}) {} // ignore: unused_element

  Future<void> send() async {
    final trimmedText = state.composedText.trim();
    if (trimmedText.isEmpty) return;
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      state = state.copyWith(error: "You need to be signed in to send messages");
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
        "recipients": [otherId], // Only the recipient (not sender) needs to read this
        "readBy": [currentUser.uid], // Sender has "read" their own message
      });

      await FirebaseFirestore.instance.collection("chats").doc(chatId).update({
        "lastMessage": trimmedText,
        "lastTimestamp": FieldValue.serverTimestamp(),
      });

      state = state.copyWith(composedText: "");
    } catch (e) {
      state = state.copyWith(error: "Failed to send message: ${e.toString()}");
    }
  }

  Future<void> sendGif(String gifUrl) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      state = state.copyWith(error: "You need to be signed in to send messages");
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
    } catch (e) {
      state = state.copyWith(error: "Failed to send GIF: ${e.toString()}");
    }
  }

  Future<void> sendDeviceGif(File gifFile) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      state = state.copyWith(error: "You need to be signed in to send messages");
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

      // Upload GIF to Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('chat_gifs')
          .child('${currentUser.uid}_${DateTime.now().millisecondsSinceEpoch}.gif');
      
      final uploadTask = storageRef.putFile(gifFile);
      final snapshot = await uploadTask;
      final gifUrl = await snapshot.ref.getDownloadURL();

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

      // Clear loading state
      state = state.copyWith(isLoading: false);
    } catch (e) {
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
  }

  Future<void> _loadPersistedMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_messagesKey);
      if (data == null) return;
      final List<dynamic> decoded = jsonDecode(data) as List<dynamic>;
      final messages = decoded.map((e) => Message.fromJson(e as Map<String, dynamic>)).toList();
      state = state.copyWith(messages: messages);
    } catch (_) {}
  }

  Future<void> _saveMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(state.messages.map((m) => m.toJson()).toList());
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

final chatProvider = StateNotifierProvider.family<ChatNotifier, ChatState, Chat>((ref, chat) {
  final authService = Object();
  return ChatNotifier(chat, authService);
});
