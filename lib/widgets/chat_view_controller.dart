import 'dart:async';

import 'package:flutter/material.dart';

import '../models/chat.dart' as app_chat;
import '../models/message.dart' as app_message;
import '../services/chat_service.dart';
import '../services/chat_service_optimized.dart';
import '../services/report_service.dart';
import '../services/user_blocking_service.dart';
import '../utils/avatar_url_resolver.dart';

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
  });

  final List<app_message.Message> messages;
  final String? currentUserAvatarURL;
  final String? otherUserAvatarURL;
  final String currentUserDisplayName;
  final bool isLoading;
  final String? error;
  final bool isSending;

  ChatViewUiState copyWith({
    List<app_message.Message>? messages,
    Object? currentUserAvatarURL = _sentinel,
    Object? otherUserAvatarURL = _sentinel,
    String? currentUserDisplayName,
    bool? isLoading,
    Object? error = _sentinel,
    bool? isSending,
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
  Future<bool> sendMessage(String chatId, String text);
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
  String? get currentUserDisplayName => _chatService.auth.currentUser?.displayName;

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
  Future<bool> sendMessage(String chatId, String text) =>
      _chatService.sendMessage(chatId, text);

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
  StreamSubscription<List<app_message.Message>>? _messagesSubscription;

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
    _updateState(
      _state.copyWith(
        messages: const <app_message.Message>[],
        otherUserAvatarURL: otherUserAvatarURL,
        isLoading: true,
        error: null,
      ),
    );
    await initialize();
  }

  Future<void> retry() async {
    _subscribeToMessages();
    await _loadParticipantAvatars();
  }

  Future<ChatComposerResult> submitComposerText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _state.isSending) {
      return ChatComposerResult.empty;
    }

    _updateState(_state.copyWith(isSending: true));

    try {
      final success = await _chatService.sendMessage(_chat.id ?? '', trimmed);
      return success ? ChatComposerResult.sent : ChatComposerResult.failed;
    } finally {
      _updateState(_state.copyWith(isSending: false));
    }
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
            messages: messages,
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

  Future<void> _loadParticipantAvatars() async {
    final resolvedCurrentUserId = currentUserId;

    try {
      if (resolvedCurrentUserId != null) {
        final currentUserData =
            await _chatService.getUserInfo(resolvedCurrentUserId);
        final currentUserAvatar = resolveAvatarUrl(currentUserData);
        final currentUserDisplayName =
            currentUserData?['displayName'] as String? ??
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
        final otherUserAvatar = resolveAvatarUrl(otherUserData);

        if (otherUserAvatar != null && otherUserAvatar.isNotEmpty) {
          _updateState(
            _state.copyWith(otherUserAvatarURL: otherUserAvatar),
          );
        }
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
    super.dispose();
  }
}
