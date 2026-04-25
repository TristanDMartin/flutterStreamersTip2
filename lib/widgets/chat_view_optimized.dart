import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_colors.dart';
import '../models/chat.dart' as app_chat;
import '../models/message.dart' as app_message;
import '../services/unified_avatar_service.dart';
import '../providers/status_provider.dart';
import 'chat_view_controller.dart';
import 'online_status_indicator.dart';

class ChatViewOptimized extends ConsumerStatefulWidget {
  final app_chat.Chat chat;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserAvatarURL;
  final bool otherUserIsOnline;
  final Map<String, dynamic>? draftToSend;

  const ChatViewOptimized({
    super.key,
    required this.chat,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserAvatarURL,
    this.otherUserIsOnline = false,
    this.draftToSend,
  });

  @override
  ConsumerState<ChatViewOptimized> createState() => _ChatViewOptimizedState();
}

class _ChatViewOptimizedState extends ConsumerState<ChatViewOptimized> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final ChatViewController _controller;
  int _previousMessageCount = 0;

  @override
  void initState() {
    super.initState();
    _controller = ChatViewController(
      chat: widget.chat,
      otherUserId: widget.otherUserId,
      otherUserName: widget.otherUserName,
      otherUserAvatarURL: widget.otherUserAvatarURL,
    )..addListener(_handleControllerChanged);
    unawaited(_controller.initialize());
  }

  @override
  void didUpdateWidget(covariant ChatViewOptimized oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chat.id != widget.chat.id ||
        oldWidget.otherUserId != widget.otherUserId ||
        oldWidget.otherUserName != widget.otherUserName ||
        oldWidget.otherUserAvatarURL != widget.otherUserAvatarURL) {
      unawaited(
        _controller.bind(
          chat: widget.chat,
          otherUserId: widget.otherUserId,
          otherUserName: widget.otherUserName,
          otherUserAvatarURL: widget.otherUserAvatarURL,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleControllerChanged)
      ..dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    final messageCount = _controller.state.messages.length;
    if (messageCount != _previousMessageCount) {
      _previousMessageCount = messageCount;
      _scheduleScrollToBottom();
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _scheduleScrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _controller.state.isSending) return;

    try {
      final result = await _controller.submitComposerText(text);
      if (result == ChatComposerResult.sent) {
        _textController.clear();
        _scheduleScrollToBottom();
      } else if (result == ChatComposerResult.failed && mounted) {
        _showSnackBar('Failed to send message', isError: true);
      }
    } catch (_) {
      _showSnackBar('Error sending message', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;

    return Scaffold(
      backgroundColor: AppColors.supportBackground,
      body: SafeArea(
        child: Column(
          children: [
            _ChatHeader(
              otherUserId: _controller.otherUserId,
              otherUserName: _controller.otherUserName,
              otherUserAvatarURL: state.otherUserAvatarURL,
              onBack: () => Navigator.of(context).pop(),
              onMore: _showChatSettings,
            ),
            Expanded(
              child: _ChatMessagesPane(
                isLoading: state.isLoading,
                error: state.error,
                messages: state.messages,
                scrollController: _scrollController,
                currentUserId: _controller.currentUserId,
                currentUserAvatarURL: state.currentUserAvatarURL,
                currentUserDisplayName: state.currentUserDisplayName,
                otherUserName: _controller.otherUserName,
                otherUserAvatarURL: state.otherUserAvatarURL,
                onRetry: _controller.retry,
                formatMessageClock: _formatMessageClock,
              ),
            ),
            _ChatComposer(
              controller: _textController,
              isSending: state.isSending,
              onSend: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }

  void _showChatSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.supportBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            for (final option in ChatViewController.settingsActions)
              _buildSettingsOption(
                option.icon,
                option.title,
                option.subtitle,
                () async {
                  final feedback = await _runSettingsAction(option.action);
                  if (!mounted) return;
                  await _handleSettingsFeedback(feedback);
                },
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<ChatActionFeedback> _runSettingsAction(
    ChatSettingsAction action,
  ) async {
    switch (action) {
      case ChatSettingsAction.mute:
        final confirmed = await _showConfirmationDialog(
          title: 'Mute conversation?',
          description:
              'You will stop receiving notifications from this chat until you unmute it.',
          confirmLabel: 'Mute',
          destructive: false,
        );
        if (confirmed != true) {
          return const ChatActionFeedback(message: 'Mute canceled.');
        }
        return _controller.handleSettingsAction(action);
      case ChatSettingsAction.report:
        final reportDetails = await _showReportReasonSheet();
        if (reportDetails == null) {
          return const ChatActionFeedback(message: 'Report canceled.');
        }
        return _controller.handleSettingsAction(
          action,
          reportReason: reportDetails.reason,
          additionalDetails: reportDetails.additionalDetails,
        );
      case ChatSettingsAction.block:
        final confirmed = await _showConfirmationDialog(
          title: 'Block ${_controller.otherUserName}?',
          description:
              'They will no longer be able to message you, and you will be removed from each other’s reachable chat surfaces.',
          confirmLabel: 'Block user',
          destructive: true,
        );
        if (confirmed != true) {
          return const ChatActionFeedback(message: 'Block canceled.');
        }
        return _controller.handleSettingsAction(action);
    }
  }

  Future<void> _handleSettingsFeedback(ChatActionFeedback feedback) async {
    _showSnackBar(feedback.message, isError: feedback.isError);

    if (!feedback.shouldExitChat || feedback.isError || !mounted) {
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (mounted) {
      Navigator.of(context).maybePop();
    }
  }

  Future<bool?> _showConfirmationDialog({
    required String title,
    required String description,
    required String confirmLabel,
    required bool destructive,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.supportBackground,
        title: Text(
          title,
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          description,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor:
                  destructive ? Colors.redAccent : AppColors.primary,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  Future<_ReportSelection?> _showReportReasonSheet() {
    return showModalBottomSheet<_ReportSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _ChatReportReasonSheet(),
    );
  }

  Widget _buildSettingsOption(
      IconData icon, String title, String subtitle, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.56),
            fontSize: 12,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: Colors.white.withValues(alpha: 0.44),
        ),
        onTap: () {
          Navigator.pop(context);
          onTap();
        },
      ),
    );
  }

  String _formatMessageClock(DateTime timestamp) {
    final hour = timestamp.hour % 12 == 0 ? 12 : timestamp.hour % 12;
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final period = timestamp.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : const Color(0xFF9248D2),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _ReportSelection {
  const _ReportSelection({
    required this.reason,
    this.additionalDetails,
  });

  final ChatReportReason reason;
  final String? additionalDetails;
}

class _ChatReportReasonSheet extends StatefulWidget {
  const _ChatReportReasonSheet();

  @override
  State<_ChatReportReasonSheet> createState() => _ChatReportReasonSheetState();
}

class _ChatReportReasonSheetState extends State<_ChatReportReasonSheet> {
  final TextEditingController _detailsController = TextEditingController();
  ChatReportReason? _selectedReason;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.supportBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.24),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Report conversation',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Choose the reason that best matches what happened.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.68),
              ),
            ),
            const SizedBox(height: 16),
            ...ChatReportReason.values.map(
              (reason) {
                final isSelected = _selectedReason == reason;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      setState(() {
                        _selectedReason = reason;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.20)
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.white.withValues(alpha: 0.10),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              reason.title,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          Icon(
                            isSelected
                                ? Icons.check_circle_rounded
                                : Icons.circle_outlined,
                            color: isSelected
                                ? AppColors.primary
                                : Colors.white.withValues(alpha: 0.55),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _detailsController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Optional details',
                hintStyle:
                    TextStyle(color: Colors.white.withValues(alpha: 0.45)),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.06),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _selectedReason == null
                        ? null
                        : () => Navigator.of(context).pop(
                              _ReportSelection(
                                reason: _selectedReason!,
                                additionalDetails:
                                    _detailsController.text.trim().isEmpty
                                        ? null
                                        : _detailsController.text.trim(),
                              ),
                            ),
                    child: const Text('Submit report'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatHeader extends ConsumerWidget {
  const _ChatHeader({
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserAvatarURL,
    required this.onBack,
    required this.onMore,
  });

  final String otherUserId;
  final String otherUserName;
  final String? otherUserAvatarURL;
  final VoidCallback onBack;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(userStatusProvider(otherUserId));

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.supportSurfaceGradient,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          _HeaderIconButton(
            icon: Icons.arrow_back_rounded,
            onPressed: onBack,
          ),
          const SizedBox(width: 12),
          _ChatMessageAvatar(
            imageUrl: otherUserAvatarURL,
            displayName: otherUserName,
            size: 44,
            borderWidth: 0,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  otherUserName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OnlineStatusDot(
                        userId: otherUserId,
                        size: 8,
                        backgroundColor: const Color(0xFF00D4AA),
                      ),
                      const SizedBox(width: 6),
                      statusAsync.when(
                        data: (presence) => Text(
                          presence.status.displayName,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.82),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        loading: () => Text(
                          'Loading...',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.56),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        error: (error, stackTrace) => Text(
                          'Offline',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.56),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _HeaderIconButton(
            icon: Icons.more_horiz_rounded,
            onPressed: onMore,
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
        ),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
      ),
    );
  }
}

class _ChatMessagesPane extends StatelessWidget {
  const _ChatMessagesPane({
    required this.isLoading,
    required this.error,
    required this.messages,
    required this.scrollController,
    required this.currentUserId,
    required this.currentUserAvatarURL,
    required this.currentUserDisplayName,
    required this.otherUserName,
    required this.otherUserAvatarURL,
    required this.onRetry,
    required this.formatMessageClock,
  });

  final bool isLoading;
  final String? error;
  final List<app_message.Message> messages;
  final ScrollController scrollController;
  final String? currentUserId;
  final String? currentUserAvatarURL;
  final String currentUserDisplayName;
  final String otherUserName;
  final String? otherUserAvatarURL;
  final VoidCallback onRetry;
  final String Function(DateTime timestamp) formatMessageClock;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const _ChatStateCard(
        stateKey: ValueKey('chat-loading'),
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.supportAccent),
        ),
      );
    }

    if (error != null) {
      return _ChatStateCard(
        stateKey: const ValueKey('chat-error'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            const Text(
              'We couldn’t load this chat',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error ?? 'Unknown error',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.62),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: AppColors.supportAccentGradient,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Retry'),
              ),
            ),
          ],
        ),
      );
    }

    if (messages.isEmpty) {
      return const _ChatStateCard(
        stateKey: ValueKey('chat-empty'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Colors.white70,
            ),
            SizedBox(height: 16),
            Text(
              'No messages yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Start the conversation and say hello.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: ListView.builder(
        key: ValueKey('chat-messages-${messages.length}'),
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        itemCount: messages.length,
        itemBuilder: (context, index) {
          final message = messages[index];
          return _ChatMessageBubble(
            message: message,
            isMe: message.from == currentUserId,
            timestampLabel:
                formatMessageClock(message.timestamp ?? DateTime.now()),
            currentUserAvatarURL: currentUserAvatarURL,
            currentUserDisplayName: currentUserDisplayName,
            otherUserName: otherUserName,
            otherUserAvatarURL: otherUserAvatarURL,
          );
        },
      ),
    );
  }
}

class _ChatStateCard extends StatelessWidget {
  const _ChatStateCard({
    required this.stateKey,
    required this.child,
  });

  final Key stateKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        key: stateKey,
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 30),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.10),
          ),
        ),
        child: child,
      ),
    );
  }
}

class _ChatMessageBubble extends StatelessWidget {
  const _ChatMessageBubble({
    required this.message,
    required this.isMe,
    required this.timestampLabel,
    required this.currentUserAvatarURL,
    required this.currentUserDisplayName,
    required this.otherUserName,
    required this.otherUserAvatarURL,
  });

  final app_message.Message message;
  final bool isMe;
  final String timestampLabel;
  final String? currentUserAvatarURL;
  final String currentUserDisplayName;
  final String otherUserName;
  final String? otherUserAvatarURL;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.8 + (0.2 * value),
          child: Opacity(
            opacity: value,
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment:
                    isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _ChatMessageAvatar(
                        imageUrl: otherUserAvatarURL,
                        displayName: otherUserName,
                      ),
                    ),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        gradient: isMe
                            ? const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: AppColors.supportAccentGradient,
                              )
                            : null,
                        color:
                            isMe ? null : Colors.white.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(24),
                          topRight: const Radius.circular(24),
                          bottomLeft: isMe
                              ? const Radius.circular(24)
                              : const Radius.circular(8),
                          bottomRight: isMe
                              ? const Radius.circular(8)
                              : const Radius.circular(24),
                        ),
                        border: Border.all(
                          color: Colors.white
                              .withValues(alpha: isMe ? 0.16 : 0.12),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isMe
                                ? AppColors.primary.withValues(alpha: 0.24)
                                : Colors.black.withValues(alpha: 0.08),
                            blurRadius: isMe ? 14 : 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (message.messageType == 'gif' &&
                              message.gifUrl != null)
                            _GifMessageContent(message: message)
                          else
                            Text(
                              message.text,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight:
                                    isMe ? FontWeight.w600 : FontWeight.w500,
                                height: 1.4,
                              ),
                            ),
                          const SizedBox(height: 8),
                          Text(
                            timestampLabel,
                            style: TextStyle(
                              color: Colors.white
                                  .withValues(alpha: isMe ? 0.68 : 0.46),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isMe)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _ChatMessageAvatar(
                        imageUrl: currentUserAvatarURL,
                        displayName: currentUserDisplayName,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GifMessageContent extends StatelessWidget {
  const _GifMessageContent({
    required this.message,
  });

  final app_message.Message message;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            children: [
              Image.network(
                message.gifUrl!,
                width: 208,
                height: 156,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 208,
                    height: 156,
                    color: Colors.grey.withValues(alpha: 0.24),
                    child: const Center(
                      child: Text(
                        'GIF',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  );
                },
              ),
              Positioned(
                left: 10,
                bottom: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.36),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: const Text(
                    'GIF',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              if (message.isDeviceGif)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: AppColors.supportAccentGradient,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.24),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.phone_android,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message.isDeviceGif ? 'Shared from device' : 'Animated image',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.54),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _ChatComposer extends StatelessWidget {
  const _ChatComposer({
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: EdgeInsets.fromLTRB(20, 0, 20, 20 + (bottomInset > 0 ? 8 : 0)),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
        ),
      ),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, child) {
          final hasText = value.text.trim().isNotEmpty;

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.22),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          color: Colors.white,
                          size: 13,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Message',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    isSending
                        ? 'Sending...'
                        : hasText
                            ? 'Ready to send'
                            : 'Say something thoughtful',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.56),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      textInputAction: TextInputAction.send,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.54),
                        ),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
                      maxLines: null,
                      onSubmitted: (_) => onSend(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: hasText && !isSending
                          ? const LinearGradient(
                              colors: AppColors.supportAccentGradient,
                            )
                          : null,
                      color: hasText && !isSending
                          ? null
                          : Colors.white.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: IconButton(
                      onPressed: isSending ? null : onSend,
                      icon: isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Icon(
                              Icons.send_rounded,
                              color: hasText
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.38),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ChatMessageAvatar extends StatelessWidget {
  static const Color _avatarPrimaryColor = Color(0xFF9248D2);
  static const Color _avatarSecondaryColor = Color(0xFF7B2CBF);

  const _ChatMessageAvatar({
    required this.imageUrl,
    required this.displayName,
    this.size = 32,
    this.borderWidth = 2,
  });

  final String? imageUrl;
  final String displayName;
  final double size;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: !hasImage
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _avatarPrimaryColor.withValues(alpha: 0.8),
                  _avatarSecondaryColor.withValues(alpha: 0.8),
                ],
              )
            : null,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: borderWidth,
        ),
        boxShadow: [
          BoxShadow(
            color: _avatarPrimaryColor.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: hasImage
            ? UnifiedAvatarService().getAvatar(
                imageUrl: imageUrl!,
                radius: size / 2,
                useProfileViewStyling: false,
                showLoadingIndicator: false,
                errorWidget: _ChatAvatarFallback(
                  initial: initial,
                  size: size,
                ),
              )
            : _ChatAvatarFallback(
                initial: initial,
                size: size,
              ),
      ),
    );
  }
}

class _ChatAvatarFallback extends StatelessWidget {
  const _ChatAvatarFallback({
    required this.initial,
    required this.size,
  });

  final String initial;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.42,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
