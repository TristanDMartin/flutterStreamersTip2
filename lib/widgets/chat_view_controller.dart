import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import '../features/messaging/data/messaging_repository.dart';
import '../models/chat.dart' as app_chat;
import '../models/message.dart' as app_message;
import '../services/chat_service.dart';
import '../services/chat_service_optimized.dart';
import '../services/r2_media_service.dart';
import '../services/report_service.dart';
import '../services/user_blocking_service.dart';
import '../utils/swallow_non_fatal.dart';
import '../utils/avatar_url_resolver.dart';
import '../utils/chat_gif_url.dart';

@immutable
class ChatViewUiState {
  const ChatViewUiState({
    this.messages = const <app_message.Message>[],
    this.currentUserAvatarURL,
    this.otherUserAvatarURL,
    this.currentUserDisplayName = 'You',
    this.isLoading = true,
    this.error,
    this.isSending = false,
    this.isOtherUserTyping = false,
    this.optimisticOutgoingGifBytes,
    this.replyingTo,
  });

  final List<app_message.Message> messages;
  final String? currentUserAvatarURL;
  final String? otherUserAvatarURL;
  final String currentUserDisplayName;
  final bool isLoading;
  final String? error;
  final bool isSending;
  final bool isOtherUserTyping;
  final Uint8List? optimisticOutgoingGifBytes;
  final app_message.Message? replyingTo;

  ChatViewUiState copyWith({
    List<app_message.Message>? messages,
    Object? currentUserAvatarURL = _sentinel,
    Object? otherUserAvatarURL = _sentinel,
    String? currentUserDisplayName,
    bool? isLoading,
    Object? error = _sentinel,
    bool? isSending,
    bool? isOtherUserTyping,
    Object? optimisticOutgoingGifBytes = _sentinel,
    Object? replyingTo = _sentinel,
  }) {
    return ChatViewUiState(
      messages: messages ?? this.messages,
      currentUserAvatarURL: identical(currentUserAvatarURL, _sentinel)
          ? this.currentUserAvatarURL
          : currentUserAvatarURL as String?,
      otherUserAvatarURL: identical(otherUserAvatarURL, _sentinel)
          ? this.otherUserAvatarURL
          : otherUserAvatarURL as String?,
      currentUserDisplayName:
          currentUserDisplayName ?? this.currentUserDisplayName,
      isLoading: isLoading ?? this.isLoading,
      error: identical(error, _sentinel) ? this.error : error as String?,
      isSending: isSending ?? this.isSending,
      isOtherUserTyping: isOtherUserTyping ?? this.isOtherUserTyping,
      optimisticOutgoingGifBytes:
          identical(optimisticOutgoingGifBytes, _sentinel)
              ? this.optimisticOutgoingGifBytes
              : optimisticOutgoingGifBytes as Uint8List?,
      replyingTo: identical(replyingTo, _sentinel)
          ? this.replyingTo
          : replyingTo as app_message.Message?,
    );
  }
}

const Object _sentinel = Object();

enum ChatComposerResult {
  sent,
  empty,
  failed,
}

enum ChatSettingsAction {
  mute,
  report,
  block,
}

enum ChatReportReason {
  harassment,
  hateSpeech,
  spam,
  impersonation,
  sexualContent,
  other,
}

@immutable
class ChatSettingsActionItem {
  const ChatSettingsActionItem({
    required this.action,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final ChatSettingsAction action;
  final IconData icon;
  final String title;
  final String subtitle;
}

@immutable
class ChatActionFeedback {
  const ChatActionFeedback({
    required this.message,
    this.isError = false,
    this.shouldExitChat = false,
  });

  final String message;
  final bool isError;
  final bool shouldExitChat;
}

extension ChatReportReasonCopy on ChatReportReason {
  String get title {
    switch (this) {
      case ChatReportReason.harassment:
        return 'Harassment or bullying';
      case ChatReportReason.hateSpeech:
        return 'Hate speech or abusive language';
      case ChatReportReason.spam:
        return 'Spam or scam';
      case ChatReportReason.impersonation:
        return 'Impersonation';
      case ChatReportReason.sexualContent:
        return 'Sexual or explicit content';
      case ChatReportReason.other:
        return 'Other';
    }
  }
}

abstract class ChatViewService {
  String? get currentUserId;
  String? get currentUserDisplayName;
  Stream<List<app_message.Message>> listenToMessages(String chatId);
  Future<bool> markMessagesAsRead(String chatId);
  Future<Map<String, dynamic>?> getUserInfo(String userId);
  Future<bool> sendMessage(String chatId, String text, {String? clientId});
  Future<bool> sendReplyMessage(
    String chatId,
    String text,
    app_message.Message replyTo,
    String replySenderName,
  );
  Future<bool> sendGifMessage(String chatId, String gifUrl);
  Future<bool> sendPastedImageBytes(String chatId, Uint8List bytes);
  Future<bool> deleteMessage(String chatId, String messageId);
  Future<bool> toggleReaction(String chatId, String messageId, String emoji);
  Future<bool> editMessage(String chatId, String messageId, String newText);
  Stream<bool> listenToTypingStatus(String chatId, String userId);
  Future<void> setTypingStatus(String chatId, bool isTyping);
  Future<void> muteChat(String chatId, String userId);
  Future<void> reportUser({
    required String userId,
    required String reason,
    String? additionalDetails,
  });
  Future<void> blockUser({
    required String targetUserId,
    String? reason,
  });
}

class ChatViewServiceAdapter implements ChatViewService {
  ChatViewServiceAdapter({
    ChatServiceOptimized? chatService,
    ChatService? legacyChatService,
    ReportService? reportService,
    UserBlockingService? blockingService,
  })  : _chatService = chatService ?? ChatServiceOptimized(),
        _legacyChatService = legacyChatService ?? ChatService.shared,
        _reportService = reportService ?? ReportService(),
        _blockingService = blockingService ?? UserBlockingService();

  final ChatServiceOptimized _chatService;
  final ChatService _legacyChatService;
  final ReportService _reportService;
  final UserBlockingService _blockingService;

  @override
  String? get currentUserDisplayName =>
      _chatService.auth.currentUser?.displayName;

  @override
  String? get currentUserId => _chatService.auth.currentUser?.uid;

  @override
  Future<Map<String, dynamic>?> getUserInfo(String userId) =>
      _chatService.getUserInfo(userId);

  @override
  Stream<List<app_message.Message>> listenToMessages(String chatId) =>
      _chatService.listenToMessages(chatId);

  @override
  Future<bool> markMessagesAsRead(String chatId) =>
      _chatService.markMessagesAsRead(chatId);

  @override
  @override
  Future<bool> sendMessage(String chatId, String text, {String? clientId}) =>
      _chatService.sendMessage(chatId, text, clientId: clientId);

  @override
  Future<bool> sendReplyMessage(
    String chatId,
    String text,
    app_message.Message replyTo,
    String replySenderName,
  ) =>
      _chatService.sendReplyMessage(chatId, text, replyTo, replySenderName);

  @override
  Future<bool> sendGifMessage(String chatId, String gifUrl) =>
      _chatService.sendGifMessage(chatId, gifUrl);

  @override
  Future<bool> sendPastedImageBytes(String chatId, Uint8List bytes) async {
    if (bytes.isEmpty) {
      return false;
    }
    final Directory dir = await getTemporaryDirectory();
    final String ext = fileExtensionForImageBytes(bytes);
    final File file = File(
      '${dir.path}/chat_clip_${DateTime.now().millisecondsSinceEpoch}$ext',
    );
    await file.writeAsBytes(bytes, flush: true);
    try {
      final String url = await R2MediaService.instance.uploadChatGif(file);
      return _chatService.sendGifMessage(chatId, url);
    } catch (_) {
      return false;
    } finally {
      try {
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e, st) {
        swallowNonFatal('ChatViewController.deleteTempFile', e, st);
      }
    }
  }

  @override
  Future<bool> deleteMessage(String chatId, String messageId) =>
      _chatService.deleteMessage(chatId, messageId);

  @override
  Future<bool> toggleReaction(String chatId, String messageId, String emoji) =>
      _chatService.toggleReaction(chatId, messageId, emoji);

  @override
  Future<bool> editMessage(String chatId, String messageId, String newText) =>
      _chatService.editMessage(chatId, messageId, newText);

  @override
  Stream<bool> listenToTypingStatus(String chatId, String userId) =>
      _chatService.listenToTypingStatus(chatId, userId);

  @override
  Future<void> setTypingStatus(String chatId, bool isTyping) =>
      _chatService.setTypingStatus(chatId, isTyping);

  @override
  Future<void> muteChat(String chatId, String userId) =>
      _legacyChatService.muteChat(chatId, userId);

  @override
  Future<void> reportUser({
    required String userId,
    required String reason,
    String? additionalDetails,
  }) =>
      _reportService.reportUser(
        userId: userId,
        reason: reason,
        additionalDetails: additionalDetails,
      );

  @override
  Future<void> blockUser({
    required String targetUserId,
    String? reason,
  }) =>
      _blockingService.blockUser(
        targetUserId: targetUserId,
        reason: reason,
      );
}

class ChatViewController extends ChangeNotifier {
  ChatViewController({
    required app_chat.Chat chat,
    required String otherUserId,
    required String otherUserName,
    String? otherUserAvatarURL,
    ChatViewService? chatService,
  })  : _chat = chat,
        _otherUserId = otherUserId,
        _otherUserName = otherUserName,
        _chatService = chatService ?? ChatViewServiceAdapter(),
        _state = ChatViewUiState(otherUserAvatarURL: otherUserAvatarURL);

  static const List<ChatSettingsActionItem> settingsActions =
      <ChatSettingsActionItem>[
    ChatSettingsActionItem(
      action: ChatSettingsAction.mute,
      icon: Icons.volume_off_outlined,
      title: 'Mute conversation',
      subtitle: 'Pause notifications from this chat',
    ),
    ChatSettingsActionItem(
      action: ChatSettingsAction.report,
      icon: Icons.flag_outlined,
      title: 'Report user',
      subtitle: 'Let us know if something feels wrong',
    ),
    ChatSettingsActionItem(
      action: ChatSettingsAction.block,
      icon: Icons.block_outlined,
      title: 'Block user',
      subtitle: 'Stop messages from this person',
    ),
  ];

  final ChatViewService _chatService;
  final MessagingRepository _messaging = MessagingRepository.instance;
  StreamSubscription<List<app_message.Message>>? _messagesSubscription;
  StreamSubscription<bool>? _typingSubscription;
  final List<app_message.Message> _pendingOptimistic = <app_message.Message>[];
  final Set<String> _failedClientIds = <String>{};

  app_chat.Chat _chat;
  String _otherUserId;
  String _otherUserName;
  ChatViewUiState _state;

  ChatViewUiState get state => _state;
  String? get currentUserId => _chatService.currentUserId;
  String get otherUserName => _otherUserName;
  String get otherUserId => _otherUserId;

  Future<void> initialize() async {
    _subscribeToMessages();
    _subscribeToTyping();
    await _loadParticipantAvatars();
  }

  Future<void> bind({
    required app_chat.Chat chat,
    required String otherUserId,
    required String otherUserName,
    String? otherUserAvatarURL,
  }) async {
    final chatChanged = _chat.id != chat.id;
    final otherUserChanged = _otherUserId != otherUserId;
    if (!chatChanged && !otherUserChanged) {
      return;
    }

    _chat = chat;
    _otherUserId = otherUserId;
    _otherUserName = otherUserName;
    _messagesSubscription?.cancel();
    _typingSubscription?.cancel();
    _updateState(
      _state.copyWith(
        messages: const <app_message.Message>[],
        otherUserAvatarURL: otherUserAvatarURL,
        isLoading: true,
        error: null,
        optimisticOutgoingGifBytes: null,
        replyingTo: null,
      ),
    );
    await initialize();
  }

  Future<void> retry() async {
    _subscribeToMessages();
    await _loadParticipantAvatars();
  }

  Future<ChatComposerResult> submitComposerText(String text) async {
    final String trimmed = text.trim();
    if (trimmed.isEmpty || _state.isSending) {
      return ChatComposerResult.empty;
    }
    final String chatId = _chat.id ?? '';
    final String? senderId = currentUserId;
    if (chatId.isEmpty || senderId == null) {
      return ChatComposerResult.failed;
    }

    final bool isGif = shouldSendComposerInputAsRemoteGifUrl(trimmed);
    final String clientId = _messaging.createClientId();
    if (!isGif && _state.replyingTo == null) {
      final app_message.Message optimistic = app_message.Message(
        id: clientId,
        chatId: chatId,
        text: trimmed,
        from: senderId,
        to: _otherUserId,
        timestamp: DateTime.now(),
        isRead: false,
        messageType: 'text',
      );
      _pendingOptimistic.add(optimistic);
      _updateState(
        _state.copyWith(
          isSending: true,
          messages: _mergeOptimistic(_state.messages),
        ),
      );
    } else {
      _updateState(_state.copyWith(isSending: true));
    }

    try {
      final bool success = isGif
          ? await _chatService.sendGifMessage(chatId, trimmed)
          : _state.replyingTo == null
              ? await _chatService.sendMessage(
                  chatId,
                  trimmed,
                  clientId: clientId,
                )
              : await _chatService.sendReplyMessage(
                  chatId,
                  trimmed,
                  _state.replyingTo!,
                  _replySenderName(_state.replyingTo!),
                );
      if (success) {
        unawaited(_chatService.setTypingStatus(chatId, false));
        _updateState(_state.copyWith(replyingTo: null));
        _failedClientIds.remove(clientId);
      } else if (!isGif && _state.replyingTo == null) {
        _failedClientIds.add(clientId);
        _updateState(
          _state.copyWith(messages: _mergeOptimistic(_state.messages)),
        );
      }
      return success ? ChatComposerResult.sent : ChatComposerResult.failed;
    } finally {
      _updateState(_state.copyWith(isSending: false));
    }
  }

  List<app_message.Message> _mergeOptimistic(
    List<app_message.Message> serverMessages,
  ) {
    final Set<String> serverIds = serverMessages
        .map((app_message.Message message) => message.id ?? '')
        .where((String id) => id.isNotEmpty)
        .toSet();
    _pendingOptimistic.removeWhere(
      (app_message.Message message) =>
          serverIds.contains(message.id) &&
          !_failedClientIds.contains(message.id),
    );
    final List<app_message.Message> pending = _pendingOptimistic
        .where(
          (app_message.Message message) => !serverIds.contains(message.id),
        )
        .toList();
    if (pending.isEmpty) {
      return serverMessages;
    }
    return <app_message.Message>[...serverMessages, ...pending];
  }

  void startReplyTo(app_message.Message message) {
    if ((message.id ?? '').isEmpty || message.deletedForEveryone) {
      return;
    }
    _updateState(_state.copyWith(replyingTo: message));
  }

  void cancelReply() {
    if (_state.replyingTo == null) {
      return;
    }
    _updateState(_state.copyWith(replyingTo: null));
  }

  String _replySenderName(app_message.Message message) {
    return message.from == currentUserId ? 'You' : _otherUserName;
  }

  Future<ChatComposerResult> submitPastedImageBytes(Uint8List bytes) async {
    if (bytes.isEmpty || _state.isSending) {
      return ChatComposerResult.empty;
    }
    _updateState(
      _state.copyWith(
        isSending: true,
        optimisticOutgoingGifBytes: bytes,
      ),
    );
    try {
      final bool success =
          await _chatService.sendPastedImageBytes(_chat.id ?? '', bytes);
      if (success) {
        unawaited(_chatService.setTypingStatus(_chat.id ?? '', false));
      }
      return success ? ChatComposerResult.sent : ChatComposerResult.failed;
    } finally {
      _updateState(
        _state.copyWith(
          isSending: false,
          optimisticOutgoingGifBytes: null,
        ),
      );
    }
  }

  Future<ChatActionFeedback> deleteOwnMessages(
    List<app_message.Message> messages,
  ) async {
    final String? actorUserId = currentUserId;
    if (actorUserId == null) {
      return const ChatActionFeedback(
        message: 'You need to sign in again to manage messages.',
        isError: true,
      );
    }
    final List<app_message.Message> ownMessages = messages
        .where((app_message.Message message) => message.from == actorUserId)
        .toList();
    if (ownMessages.isEmpty) {
      return const ChatActionFeedback(
        message: 'Select at least one of your own messages.',
        isError: true,
      );
    }
    int deletedCount = 0;
    for (final app_message.Message message in ownMessages) {
      final String? messageId = message.id;
      if (messageId == null || messageId.isEmpty) {
        continue;
      }
      final bool success = await _chatService.deleteMessage(
        _chat.id ?? '',
        messageId,
      );
      if (success) {
        deletedCount++;
      }
    }
    if (deletedCount == ownMessages.length) {
      return ChatActionFeedback(
        message: deletedCount == 1
            ? 'Message unsent.'
            : '$deletedCount messages unsent.',
      );
    }
    return ChatActionFeedback(
      message: deletedCount == 0
          ? 'We couldn’t unsend selected messages.'
          : '$deletedCount of ${ownMessages.length} messages unsent.',
      isError: deletedCount == 0,
    );
  }

  Future<ChatActionFeedback> toggleReactionOnMessage(
    app_message.Message message,
    String emoji,
  ) async {
    final String? messageId = message.id;
    final String chatId = _chat.id ?? '';
    if (messageId == null || messageId.isEmpty || chatId.isEmpty) {
      return const ChatActionFeedback(
        message: 'Unable to react to this message.',
        isError: true,
      );
    }
    final bool success =
        await _chatService.toggleReaction(chatId, messageId, emoji);
    if (success) {
      return const ChatActionFeedback(message: '');
    }
    return const ChatActionFeedback(
      message: 'Couldn’t update reaction.',
      isError: true,
    );
  }

  Future<ChatActionFeedback> editOwnMessage(
    app_message.Message message,
    String newText,
  ) async {
    final String? actorUserId = currentUserId;
    final String? messageId = message.id;
    final String chatId = _chat.id ?? '';
    if (actorUserId == null ||
        messageId == null ||
        messageId.isEmpty ||
        chatId.isEmpty) {
      return const ChatActionFeedback(
        message: 'Unable to edit this message.',
        isError: true,
      );
    }
    if (message.from != actorUserId) {
      return const ChatActionFeedback(
        message: 'You can only edit your own messages.',
        isError: true,
      );
    }
    final bool success =
        await _chatService.editMessage(chatId, messageId, newText);
    if (success) {
      return const ChatActionFeedback(message: 'Message edited.');
    }
    return const ChatActionFeedback(
      message: 'Couldn’t edit message.',
      isError: true,
    );
  }

  Future<ChatActionFeedback> handleSettingsAction(
    ChatSettingsAction action, {
    ChatReportReason? reportReason,
    String? additionalDetails,
  }) async {
    final actorUserId = currentUserId;
    if (actorUserId == null) {
      return const ChatActionFeedback(
        message: 'You need to sign in again to manage this chat.',
        isError: true,
      );
    }

    switch (action) {
      case ChatSettingsAction.mute:
        try {
          await _chatService.muteChat(_chat.id ?? '', actorUserId);
          _chat = _chat.copyWith(
            mutedBy: <String>{..._chat.mutedBy, actorUserId}.toList(),
          );
          return const ChatActionFeedback(
            message: 'Conversation muted.',
          );
        } catch (_) {
          return const ChatActionFeedback(
            message: 'We couldn’t mute this conversation.',
            isError: true,
          );
        }
      case ChatSettingsAction.report:
        try {
          final resolvedReason = reportReason ?? ChatReportReason.other;
          await _chatService.reportUser(
            userId: _otherUserId,
            reason: resolvedReason.title,
            additionalDetails:
                additionalDetails ?? 'Reported from direct message settings.',
          );
          return const ChatActionFeedback(
            message: 'Report submitted. Thanks for letting us know.',
          );
        } catch (_) {
          return const ChatActionFeedback(
            message: 'We couldn’t submit this report.',
            isError: true,
          );
        }
      case ChatSettingsAction.block:
        try {
          await _chatService.blockUser(
            targetUserId: _otherUserId,
            reason: 'Blocked from chat settings',
          );
          return const ChatActionFeedback(
            message: 'User blocked successfully.',
            shouldExitChat: true,
          );
        } catch (_) {
          return const ChatActionFeedback(
            message: 'We couldn’t block this user.',
            isError: true,
          );
        }
    }
  }

  void _subscribeToMessages() {
    _updateState(_state.copyWith(isLoading: true, error: null));

    _messagesSubscription?.cancel();
    _messagesSubscription =
        _chatService.listenToMessages(_chat.id ?? '').listen(
      (messages) {
        _updateState(
          _state.copyWith(
            messages: _mergeOptimistic(messages),
            isLoading: false,
            error: null,
          ),
        );
      },
      onError: (Object error, StackTrace stackTrace) {
        _updateState(
          _state.copyWith(
            isLoading: false,
            error: error.toString(),
          ),
        );
      },
    );

    unawaited(_chatService.markMessagesAsRead(_chat.id ?? ''));
  }

  void _subscribeToTyping() {
    _typingSubscription?.cancel();
    final String chatId = _chat.id ?? '';
    if (chatId.isEmpty || _otherUserId.isEmpty) {
      _updateState(_state.copyWith(isOtherUserTyping: false));
      return;
    }
    _typingSubscription =
        _chatService.listenToTypingStatus(chatId, _otherUserId).listen(
      (bool isTyping) {
        _updateState(_state.copyWith(isOtherUserTyping: isTyping));
      },
      onError: (Object error, StackTrace stackTrace) {
        _updateState(_state.copyWith(isOtherUserTyping: false));
      },
    );
  }

  Future<void> setTypingStatus(bool isTyping) async {
    final String chatId = _chat.id ?? '';
    if (chatId.isEmpty) {
      return;
    }
    await _chatService.setTypingStatus(chatId, isTyping);
  }

  Future<void> _loadParticipantAvatars() async {
    final resolvedCurrentUserId = currentUserId;
    firebase_auth.User? authUser;
    try {
      authUser = firebase_auth.FirebaseAuth.instance.currentUser;
    } catch (_) {
      authUser = null;
    }
    try {
      if (resolvedCurrentUserId != null) {
        final currentUserData =
            await _chatService.getUserInfo(resolvedCurrentUserId);
        final String? currentUserAvatar =
            resolveAvatarUrl(currentUserData) ?? authUser?.photoURL;
        final currentUserDisplayName =
            currentUserData?['displayName'] as String? ??
                authUser?.displayName ??
                _chatService.currentUserDisplayName ??
                'You';

        _updateState(
          _state.copyWith(
            currentUserAvatarURL: currentUserAvatar,
            currentUserDisplayName: currentUserDisplayName,
          ),
        );
      }

      if ((_state.otherUserAvatarURL == null ||
              _state.otherUserAvatarURL!.isEmpty) &&
          _otherUserId.isNotEmpty) {
        final otherUserData = await _chatService.getUserInfo(_otherUserId);
        final String? otherUserAvatar = resolveAvatarUrl(otherUserData);
        final String resolvedOtherUserName =
            otherUserData?['displayName'] as String? ??
                otherUserData?['username'] as String? ??
                _otherUserName;

        _otherUserName = resolvedOtherUserName;
        _updateState(
          _state.copyWith(otherUserAvatarURL: otherUserAvatar),
        );
      }
    } catch (_) {
      // Avatar fallback is non-critical.
    }
  }

  void _updateState(ChatViewUiState nextState) {
    _state = nextState;
    notifyListeners();
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    unawaited(_chatService.setTypingStatus(_chat.id ?? '', false));
    _typingSubscription?.cancel();
    super.dispose();
  }
}
