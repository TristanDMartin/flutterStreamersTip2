import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:streamers_tip/models/chat.dart' as app_chat;
import 'package:streamers_tip/models/message.dart' as app_message;
import 'package:streamers_tip/widgets/chat_view_controller.dart';

class _FakeChatViewService implements ChatViewService {
  final StreamController<List<app_message.Message>> _messagesController =
      StreamController<List<app_message.Message>>.broadcast();

  final Map<String, Map<String, dynamic>> userInfoById;
  final List<String> markedReadChatIds = <String>[];
  final List<String> sentMessages = <String>[];
  final List<String> mutedChatIds = <String>[];
  final List<String> reportedUserIds = <String>[];
  final List<String> blockedUserIds = <String>[];

  @override
  final String? currentUserId;

  @override
  final String? currentUserDisplayName;

  bool sendShouldSucceed;

  _FakeChatViewService({
    required this.userInfoById,
  })  : currentUserId = 'current-user',
        currentUserDisplayName = 'Current User',
        sendShouldSucceed = true;

  void emitMessages(List<app_message.Message> messages) {
    _messagesController.add(messages);
  }

  @override
  Future<Map<String, dynamic>?> getUserInfo(String userId) async {
    return userInfoById[userId];
  }

  @override
  Stream<List<app_message.Message>> listenToMessages(String chatId) =>
      _messagesController.stream;

  @override
  Future<bool> markMessagesAsRead(String chatId) async {
    markedReadChatIds.add(chatId);
    return true;
  }

  @override
  Future<bool> sendMessage(String chatId, String text) async {
    sentMessages.add('$chatId::$text');
    return sendShouldSucceed;
  }

  @override
  Future<void> muteChat(String chatId, String userId) async {
    mutedChatIds.add('$chatId::$userId');
  }

  @override
  Future<void> reportUser({
    required String userId,
    required String reason,
    String? additionalDetails,
  }) async {
    reportedUserIds.add('$userId::$reason');
  }

  @override
  Future<void> blockUser({
    required String targetUserId,
    String? reason,
  }) async {
    blockedUserIds.add('$targetUserId::$reason');
  }

  Future<void> dispose() => _messagesController.close();
}

void main() {
  group('ChatViewController', () {
    late _FakeChatViewService service;
    late ChatViewController controller;
    final chat = app_chat.Chat(
      id: 'chat-1',
      participants: <String>['current-user', 'other-user'],
      lastTimestamp: DateTime(2026, 4, 4),
    );

    setUp(() {
      service = _FakeChatViewService(
        userInfoById: <String, Map<String, dynamic>>{
          'current-user': <String, dynamic>{
            'displayName': 'You',
            'avatarURL': 'https://example.com/current.png',
          },
          'other-user': <String, dynamic>{
            'displayName': 'Other User',
            'avatarURL': 'https://example.com/other.png',
          },
        },
      );

      controller = ChatViewController(
        chat: chat,
        otherUserId: 'other-user',
        otherUserName: 'Other User',
        chatService: service,
      );
    });

    tearDown(() async {
      controller.dispose();
      await service.dispose();
    });

    test('initializes messages, marks chat read, and loads avatars', () async {
      final message = app_message.Message(
        id: 'm1',
        chatId: 'chat-1',
        text: 'hello',
        from: 'other-user',
        to: 'current-user',
        timestamp: DateTime(2026, 4, 4, 8, 0),
      );

      final initializeFuture = controller.initialize();
      service.emitMessages(<app_message.Message>[message]);

      await initializeFuture;
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.isLoading, isFalse);
      expect(controller.state.error, isNull);
      expect(controller.state.messages, hasLength(1));
      expect(controller.state.currentUserAvatarURL,
          'https://example.com/current.png');
      expect(
          controller.state.otherUserAvatarURL, 'https://example.com/other.png');
      expect(service.markedReadChatIds, contains('chat-1'));
    });

    test('submitComposerText trims text and updates sending state', () async {
      final states = <bool>[];
      controller.addListener(() {
        states.add(controller.state.isSending);
      });

      final result = await controller.submitComposerText('  hi there  ');

      expect(result, ChatComposerResult.sent);
      expect(service.sentMessages, contains('chat-1::hi there'));
      expect(states, containsAllInOrder(<bool>[true, false]));
    });

    test('settings actions execute real service intents', () async {
      final muteFeedback =
          await controller.handleSettingsAction(ChatSettingsAction.mute);
      final reportFeedback =
          await controller.handleSettingsAction(
        ChatSettingsAction.report,
        reportReason: ChatReportReason.spam,
        additionalDetails: 'Repeated phishing links',
      );
      final blockFeedback =
          await controller.handleSettingsAction(ChatSettingsAction.block);

      expect(muteFeedback.isError, isFalse);
      expect(muteFeedback.message, contains('muted'));
      expect(service.mutedChatIds, contains('chat-1::current-user'));

      expect(reportFeedback.isError, isFalse);
      expect(reportFeedback.message, contains('Report submitted'));
      expect(service.reportedUserIds.single, contains('other-user::Spam or scam'));

      expect(blockFeedback.isError, isFalse);
      expect(blockFeedback.message, contains('blocked'));
      expect(blockFeedback.shouldExitChat, isTrue);
      expect(service.blockedUserIds.single, contains('other-user::'));
    });
  });
}
