import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_colors.dart';
import '../core/feature_flags.dart';
import '../core/theme/support_shell_style.dart';
import '../models/chat.dart' as app_chat;
import '../models/message.dart' as app_message;
import '../models/home_video.dart';
import '../providers/status_provider.dart';
import 'status_aware_avatar.dart';
import '../routing/app_navigator.dart';
import '../services/gif_clipboard_actions.dart';
import '../services/gif_pasteboard_channel.dart';
import '../utils/chat_gif_url.dart';
import '../utils/home_video_from_firestore.dart';
import '../widgets/player_screen.dart';
import 'chat/chat_ui_tokens.dart';
import 'chat_view_controller.dart';
import '../utils/system_account.dart';

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
  late final FocusNode _composerFocusNode;
  Timer? _typingDebounceTimer;
  bool _isCurrentUserTyping = false;
  int _previousMessageCount = 0;
  bool _hasAppliedInitialBottomScroll = false;
  final Set<String> _selectedMessageIds = <String>{};
  Uint8List? _lastOptimisticGifBytes;

  @override
  void initState() {
    super.initState();
    _composerFocusNode = FocusNode();
    _composerFocusNode.addListener(_onComposerFocusChanged);
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
    _composerFocusNode.removeListener(_onComposerFocusChanged);
    _composerFocusNode.dispose();
    _typingDebounceTimer?.cancel();
    _controller
      ..removeListener(_handleControllerChanged)
      ..dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    final Uint8List? optimistic = _controller.state.optimisticOutgoingGifBytes;
    if (optimistic != null && optimistic.isNotEmpty) {
      if (!identical(optimistic, _lastOptimisticGifBytes)) {
        _scheduleScrollToBottom();
      }
    }
    _lastOptimisticGifBytes = optimistic;

    final messageCount = _controller.state.messages.length;
    if (messageCount != _previousMessageCount) {
      final bool isInitialLoad =
          !_hasAppliedInitialBottomScroll && messageCount > 0;
      _previousMessageCount = messageCount;
      if (isInitialLoad) {
        _hasAppliedInitialBottomScroll = true;
        _scheduleScrollToBottom(forceJump: true);
      } else {
        _scheduleScrollToBottom();
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _scheduleScrollToBottom({bool forceJump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottomWithRetries(
        forceJump: forceJump,
      );
    });
  }

  void _onComposerFocusChanged() {
    if (!_composerFocusNode.hasFocus) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _scrollToBottomWithRetries(forceJump: true, attempt: 0);
    });
  }

  void _scrollToBottomWithRetries({
    required bool forceJump,
    int attempt = 0,
  }) {
    if (!mounted || !_scrollController.hasClients) {
      if (attempt >= 8) {
        return;
      }
      Future<void>.delayed(
        const Duration(milliseconds: 32),
        () => _scrollToBottomWithRetries(
          forceJump: forceJump,
          attempt: attempt + 1,
        ),
      );
      return;
    }
    final ScrollPosition position = _scrollController.position;
    if (!position.hasContentDimensions) {
      if (attempt >= 8) {
        return;
      }
      Future<void>.delayed(
        const Duration(milliseconds: 32),
        () => _scrollToBottomWithRetries(
          forceJump: forceJump,
          attempt: attempt + 1,
        ),
      );
      return;
    }
    final double targetOffset = position.maxScrollExtent;
    if (forceJump) {
      _scrollController.jumpTo(targetOffset);
      Future<void>.delayed(
        const Duration(milliseconds: 180),
        () {
          if (!mounted || !_scrollController.hasClients) {
            return;
          }
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        },
      );
      return;
    }
    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _controller.state.isSending) return;

    try {
      final result = await _controller.submitComposerText(text);
      if (result == ChatComposerResult.sent) {
        _textController.clear();
        _handleTypingChanged('');
        _scheduleScrollToBottom();
      } else if (result == ChatComposerResult.failed && mounted) {
        _showSnackBar('Failed to send message', isError: true);
      }
    } catch (_) {
      _showSnackBar('Error sending message', isError: true);
    }
  }

  Future<void> _pasteChatMediaFromClipboard() async {
    if (_controller.state.isSending) {
      return;
    }
    final Uint8List? nativeGif = await GifPasteboardChannel.readGifBytes();
    if (nativeGif != null && nativeGif.isNotEmpty) {
      final ChatComposerResult result =
          await _controller.submitPastedImageBytes(nativeGif);
      if (!mounted) {
        return;
      }
      if (result == ChatComposerResult.sent) {
        _handleTypingChanged('');
        _scheduleScrollToBottom();
      } else {
        _showSnackBar('Could not send pasted GIF', isError: true);
      }
      return;
    }
    final Uint8List? imageBytes = await Pasteboard.image;
    if (imageBytes != null && imageBytes.isNotEmpty) {
      final ChatComposerResult result =
          await _controller.submitPastedImageBytes(imageBytes);
      if (!mounted) {
        return;
      }
      if (result == ChatComposerResult.sent) {
        _handleTypingChanged('');
        _scheduleScrollToBottom();
      } else {
        _showSnackBar('Could not send pasted image', isError: true);
      }
      return;
    }
    final String? clipText = await Pasteboard.text;
    final String? url = clipText?.trim();
    if (url != null &&
        url.isNotEmpty &&
        !url.contains(' ') &&
        !url.contains('\n')) {
      if (!shouldSendComposerInputAsRemoteGifUrl(url)) {
        if (mounted) {
          _showSnackBar(
            'Copy a direct .gif or Giphy/Tenor media link, or an image.',
            isError: true,
          );
        }
        return;
      }
      final ChatComposerResult result =
          await _controller.submitComposerText(url);
      if (!mounted) {
        return;
      }
      if (result == ChatComposerResult.sent) {
        _handleTypingChanged('');
        _scheduleScrollToBottom();
      } else {
        _showSnackBar('Could not send GIF from link', isError: true);
      }
      return;
    }
    if (mounted) {
      _showSnackBar('Nothing to paste from clipboard.', isError: false);
    }
  }

  void _onKeyboardInsertedMedia(KeyboardInsertedContent content) {
    if (!content.hasData || content.data == null) {
      return;
    }
    unawaited(_handleKeyboardInsertedImage(content.data!));
  }

  Future<void> _handleKeyboardInsertedImage(Uint8List bytes) async {
    if (_controller.state.isSending) {
      return;
    }
    final ChatComposerResult result =
        await _controller.submitPastedImageBytes(bytes);
    if (!mounted) {
      return;
    }
    if (result == ChatComposerResult.sent) {
      _handleTypingChanged('');
      _scheduleScrollToBottom();
    } else {
      _showSnackBar('Could not send inserted image', isError: true);
    }
  }

  void _handleTypingChanged(String text) {
    final bool hasText = text.trim().isNotEmpty;
    _typingDebounceTimer?.cancel();
    if (hasText != _isCurrentUserTyping) {
      _isCurrentUserTyping = hasText;
      unawaited(_controller.setTypingStatus(hasText));
    }
    if (!hasText) {
      return;
    }
    _typingDebounceTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) {
        return;
      }
      if (_textController.text.trim().isNotEmpty) {
        _isCurrentUserTyping = false;
        unawaited(_controller.setTypingStatus(false));
      }
    });
  }

  bool get _isSelectingMessages => _selectedMessageIds.isNotEmpty;

  void _toggleMessageSelection(app_message.Message message) {
    final String? currentUserId = _controller.currentUserId;
    final String? messageId = message.id;
    if (currentUserId == null || messageId == null || messageId.isEmpty) {
      return;
    }
    if (message.from != currentUserId) {
      return;
    }
    setState(() {
      if (_selectedMessageIds.contains(messageId)) {
        _selectedMessageIds.remove(messageId);
      } else {
        _selectedMessageIds.add(messageId);
        HapticFeedback.selectionClick();
      }
    });
  }

  void _clearMessageSelection() {
    if (_selectedMessageIds.isEmpty) {
      return;
    }
    setState(() {
      _selectedMessageIds.clear();
    });
  }

  Future<void> _showMessageActions(app_message.Message message) async {
    if (_isSelectingMessages) {
      return;
    }
    final bool isMe = message.from == _controller.currentUserId;
    HapticFeedback.mediumImpact();
    final String? action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext context) {
        final StSupportShellStyle shell = StSupportShellStyle.of(context);
        final double maxHeight = MediaQuery.sizeOf(context).height * 0.72;
        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            constraints: BoxConstraints(maxHeight: maxHeight),
            decoration: BoxDecoration(
              color: shell.panelSurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: shell.panelBorder),
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const SizedBox(height: 10),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: shell.mutedStrong.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (FeatureFlags.chatReplies && !message.deletedForEveryone)
                    _messageActionTile(
                      context,
                      icon: Icons.reply_rounded,
                      label: 'Reply',
                      value: 'reply',
                    ),
                  if (message.text.trim().isNotEmpty &&
                      !message.deletedForEveryone)
                    _messageActionTile(
                      context,
                      icon: Icons.copy_rounded,
                      label: 'Copy',
                      value: 'copy',
                    ),
                  if (isMe && !message.deletedForEveryone)
                    _messageActionTile(
                      context,
                      icon: Icons.delete_outline_rounded,
                      label: 'Delete',
                      value: 'delete',
                      destructive: true,
                    ),
                  if (!isMe)
                    _messageActionTile(
                      context,
                      icon: Icons.flag_outlined,
                      label: 'Report',
                      value: 'report',
                    ),
                  if (isMe)
                    _messageActionTile(
                      context,
                      icon: Icons.checklist_rounded,
                      label: 'Select messages',
                      value: 'select',
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (!mounted || action == null) {
      return;
    }
    switch (action) {
      case 'copy':
        await Clipboard.setData(ClipboardData(text: message.text));
        if (mounted) {
          _showSnackBar('Copied to clipboard');
        }
      case 'delete':
        final ChatActionFeedback feedback =
            await _controller.deleteOwnMessages(<app_message.Message>[message]);
        if (mounted) {
          _showSnackBar(feedback.message, isError: feedback.isError);
        }
      case 'report':
        final _ReportSelection? report = await _showReportReasonSheet();
        if (report == null || !mounted) {
          return;
        }
        final ChatActionFeedback feedback =
            await _controller.handleSettingsAction(
          ChatSettingsAction.report,
          reportReason: report.reason,
          additionalDetails: report.additionalDetails,
        );
        if (mounted) {
          _showSnackBar(feedback.message, isError: feedback.isError);
        }
      case 'reply':
        _controller.startReplyTo(message);
        _composerFocusNode.requestFocus();
        return;
      case 'select':
        _toggleMessageSelection(message);
    }
  }

  Widget _messageActionTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    bool destructive = false,
    bool enabled = true,
  }) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return ListTile(
      enabled: enabled,
      leading: Icon(
        icon,
        color: destructive
            ? Colors.redAccent
            : (enabled ? shell.onChrome : shell.muted),
        size: 22,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: destructive
              ? Colors.redAccent
              : (enabled ? shell.onChrome : shell.muted),
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: enabled ? () => Navigator.pop(context, value) : null,
    );
  }

  Future<void> _deleteSelectedMessages() async {
    final List<app_message.Message> selectedMessages =
        _controller.state.messages
            .where(
              (app_message.Message message) =>
                  _selectedMessageIds.contains(message.id),
            )
            .toList();
    if (selectedMessages.isEmpty) {
      return;
    }
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        final ColorScheme scheme = Theme.of(context).colorScheme;
        return AlertDialog(
          backgroundColor: scheme.surfaceContainerHigh,
          title: Text(
            'Delete selected messages?',
            style: TextStyle(color: scheme.onSurface),
          ),
          content: Text(
            'This deletes ${selectedMessages.length} message${selectedMessages.length == 1 ? '' : 's'} for everyone in this chat.',
            style: TextStyle(
              color: scheme.onSurface.withValues(alpha: 0.75),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (shouldDelete != true) {
      return;
    }
    final ChatActionFeedback feedback =
        await _controller.deleteOwnMessages(selectedMessages);
    if (!mounted) {
      return;
    }
    _showSnackBar(feedback.message, isError: feedback.isError);
    _clearMessageSelection();
  }

  Future<void> _openSharedVideoFromMessage(
    BuildContext context,
    app_message.Message message,
  ) async {
    final String? videoId = message.videoId;
    if (videoId == null || videoId.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This video is no longer available.'),
        ),
      );
      return;
    }
    final HomeVideo? homeVideo = await loadHomeVideoForPlayback(videoId);
    if (!context.mounted) {
      return;
    }
    if (homeVideo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This video is no longer available.'),
        ),
      );
      return;
    }
    AppNavigator.openPlayer(
      context,
      mode: PlayerMode.homeFeed,
      initialIndex: 0,
      videoIds: <String>[videoId],
      videos: <HomeVideo>[homeVideo],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;

    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color pageBg =
        dark ? AppColors.profileViewBackground : shell.scaffold;
    return Scaffold(
      backgroundColor: pageBg,
      resizeToAvoidBottomInset: false,
      appBar: _isSelectingMessages
          ? AppBar(
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              title: Text(
                '${_selectedMessageIds.length} selected',
                style: TextStyle(color: scheme.onSurface),
              ),
              leading: IconButton(
                onPressed: _clearMessageSelection,
                icon: Icon(Icons.close, color: scheme.onSurface),
              ),
              actions: <Widget>[
                IconButton(
                  onPressed: _deleteSelectedMessages,
                  icon:
                      const Icon(Icons.delete_outline, color: Colors.redAccent),
                ),
              ],
            )
          : null,
      body: ColoredBox(
        color: pageBg,
        child: SafeArea(
          bottom: true,
          child: Column(
            children: [
              _ChatHeader(
                otherUserId: _controller.otherUserId,
                otherUserName: _controller.otherUserName,
                otherUserAvatarURL: state.otherUserAvatarURL,
                isSystemChat: isSystemAccount(_controller.otherUserId),
                onBack: () => Navigator.of(context).pop(),
                onMore: _showChatSettings,
                onOpenProfile: () {
                  AppNavigator.openStreamerCard(
                    context,
                    userId: _controller.otherUserId,
                  );
                },
              ),
              Expanded(
                child: _ChatMessagesPane(
                  isLoading: state.isLoading,
                  error: state.error,
                  messages: state.messages,
                  optimisticOutgoingGifBytes: state.optimisticOutgoingGifBytes,
                  scrollController: _scrollController,
                  currentUserId: _controller.currentUserId,
                  otherUserId: _controller.otherUserId,
                  currentUserAvatarURL: state.currentUserAvatarURL,
                  currentUserDisplayName: state.currentUserDisplayName,
                  otherUserName: _controller.otherUserName,
                  otherUserAvatarURL: state.otherUserAvatarURL,
                  onRetry: _controller.retry,
                  formatMessageClock: _formatMessageClock,
                  selectedMessageIds: _selectedMessageIds,
                  currentUserIdForSelection: _controller.currentUserId,
                  hasSelection: _isSelectingMessages,
                  onMessageLongPress: _toggleMessageSelection,
                  onMessageTapWhenSelecting: _toggleMessageSelection,
                  onMessageActions: _showMessageActions,
                  onOpenSharedVideo: _openSharedVideoFromMessage,
                ),
              ),
              if (state.isOtherUserTyping)
                _TypingIndicatorBanner(
                  userName: _controller.otherUserName,
                ),
              if (state.replyingTo != null)
                _ComposerReplyBanner(
                  message: state.replyingTo!,
                  currentUserId: _controller.currentUserId,
                  otherUserName: _controller.otherUserName,
                  onCancel: _controller.cancelReply,
                ),
              if (isSystemAccount(_controller.otherUserId))
                const _SystemReadOnlyBanner()
              else
                _KeyboardComposerPadding(
                  child: _ChatComposer(
                    controller: _textController,
                    focusNode: _composerFocusNode,
                    isSending: state.isSending,
                    onSend: _sendMessage,
                    onChanged: _handleTypingChanged,
                    onPasteMediaFromClipboard: _pasteChatMediaFromClipboard,
                    onKeyboardMediaInserted: _onKeyboardInsertedMedia,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showChatSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final StSupportShellStyle shell = StSupportShellStyle.of(context);
        return Container(
          decoration: BoxDecoration(
            color: shell.panelSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: shell.panelBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: shell.mutedStrong.withValues(alpha: 0.35),
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
        );
      },
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
        backgroundColor: StSupportShellStyle.of(context).scaffold,
        title: Text(
          title,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: Text(
          description,
          style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.72)),
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
        color: StSupportShellStyle.of(context).surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: StSupportShellStyle.of(context).surfaceCardBorder,
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
          child: Icon(icon,
              color: Theme.of(context).colorScheme.primary, size: 18),
        ),
        title: Text(title,
            style: TextStyle(color: StSupportShellStyle.of(context).onChrome)),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: StSupportShellStyle.of(context).muted,
            fontSize: 12,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: StSupportShellStyle.of(context).mutedStrong,
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
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      decoration: BoxDecoration(
        color: shell.panelSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: shell.panelBorder),
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
                  color: shell.mutedStrong,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Report conversation',
              style: TextStyle(
                color: shell.onChrome,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Choose the reason that best matches what happened.',
              style: TextStyle(
                color: shell.muted,
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
                            : shell.surfaceCard,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : shell.surfaceCardBorder,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              reason.title,
                              style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onSurface),
                            ),
                          ),
                          Icon(
                            isSelected
                                ? Icons.check_circle_rounded
                                : Icons.circle_outlined,
                            color: isSelected
                                ? AppColors.primary
                                : shell.mutedStrong,
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
                hintStyle: TextStyle(color: shell.mutedStrong),
                filled: true,
                fillColor: shell.surfaceCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
              style: TextStyle(color: scheme.onSurface),
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
    required this.isSystemChat,
    required this.onBack,
    required this.onMore,
    required this.onOpenProfile,
  });

  final String otherUserId;
  final String otherUserName;
  final String? otherUserAvatarURL;
  final bool isSystemChat;
  final VoidCallback onBack;
  final VoidCallback onMore;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(userStatusProvider(otherUserId));
    final StSupportShellStyle shell = StSupportShellStyle.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Colors.white.withValues(alpha: 0.09),
            Colors.white.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ChatUiTokens.glassBorder),
      ),
      child: Row(
        children: <Widget>[
          _HeaderIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onPressed: onBack,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: isSystemChat ? null : onOpenProfile,
                borderRadius: BorderRadius.circular(18),
                child: Ink(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.045),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      StatusAwareAvatar(
                        userId: otherUserId,
                        avatarURL: otherUserAvatarURL,
                        radius: ChatUiTokens.headerAvatarRadius,
                        showOnlineIndicator: false,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              otherUserName,
                              style: TextStyle(
                                color: shell.onChrome,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            if (isSystemChat)
                              Text(
                                'OFFICIAL',
                                style: TextStyle(
                                  color: shell.mutedStrong,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.6,
                                ),
                              )
                            else
                              statusAsync.when(
                                data: (presence) {
                                  final bool online =
                                      presence.status.displayName == 'Online';
                                  return Text(
                                    online ? 'ONLINE' : 'OFFLINE',
                                    style: TextStyle(
                                      color: shell.mutedStrong,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.6,
                                    ),
                                  );
                                },
                                loading: () => Text(
                                  '…',
                                  style: TextStyle(
                                    color: shell.muted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                error: (Object error, StackTrace stackTrace) =>
                                    Text(
                                  'OFFLINE',
                                  style: TextStyle(
                                    color: shell.mutedStrong,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (!isSystemChat) ...<Widget>[
            const SizedBox(width: 8),
            _HeaderIconButton(
              icon: Icons.more_horiz_rounded,
              onPressed: onMore,
            ),
          ],
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
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return SizedBox(
      width: ChatUiTokens.headerButtonSize,
      height: ChatUiTokens.headerButtonSize,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: shell.onChrome, size: 18),
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.08),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
          shape: const CircleBorder(),
        ),
      ),
    );
  }
}

class _SystemReadOnlyBanner extends StatelessWidget {
  const _SystemReadOnlyBanner();

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ChatUiTokens.glassBorder),
      ),
      child: Text(
        'This is an official StreamersTip announcement thread. Replies are disabled.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: shell.mutedStrong,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          height: 1.35,
        ),
      ),
    );
  }
}

class _OptimisticOutgoingGifBubble extends StatelessWidget {
  const _OptimisticOutgoingGifBubble({
    required this.bytes,
    required this.currentUserId,
    required this.currentUserAvatarURL,
  });

  final Uint8List bytes;
  final String? currentUserId;
  final String? currentUserAvatarURL;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        Flexible(
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: ChatUiTokens.bubblePadding,
            decoration: BoxDecoration(
              gradient: ChatUiTokens.outgoingGradient,
              borderRadius: ChatUiTokens.outgoingBubbleRadius,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.10),
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: ChatUiTokens.outgoingStart.withValues(alpha: 0.12),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.memory(
                    bytes,
                    width: 208,
                    height: 156,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sending…',
                  style: TextStyle(
                    color: scheme.onPrimary.withValues(alpha: 0.82),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        if ((currentUserId ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: StatusAwareAvatar(
              userId: currentUserId!,
              avatarURL: currentUserAvatarURL,
              radius: 16,
              showOnlineIndicator: false,
            ),
          ),
      ],
    );
  }
}

class _ChatMessagesPane extends StatelessWidget {
  const _ChatMessagesPane({
    required this.isLoading,
    required this.error,
    required this.messages,
    required this.optimisticOutgoingGifBytes,
    required this.scrollController,
    required this.currentUserId,
    required this.otherUserId,
    required this.currentUserAvatarURL,
    required this.currentUserDisplayName,
    required this.otherUserName,
    required this.otherUserAvatarURL,
    required this.onRetry,
    required this.formatMessageClock,
    required this.selectedMessageIds,
    required this.currentUserIdForSelection,
    required this.hasSelection,
    required this.onMessageLongPress,
    required this.onMessageTapWhenSelecting,
    required this.onMessageActions,
    required this.onOpenSharedVideo,
  });

  final bool isLoading;
  final String? error;
  final List<app_message.Message> messages;
  final Uint8List? optimisticOutgoingGifBytes;
  final ScrollController scrollController;
  final String? currentUserId;
  final String otherUserId;
  final String? currentUserAvatarURL;
  final String currentUserDisplayName;
  final String otherUserName;
  final String? otherUserAvatarURL;
  final VoidCallback onRetry;
  final String Function(DateTime timestamp) formatMessageClock;
  final Set<String> selectedMessageIds;
  final String? currentUserIdForSelection;
  final bool hasSelection;
  final ValueChanged<app_message.Message> onMessageLongPress;
  final ValueChanged<app_message.Message> onMessageTapWhenSelecting;
  final ValueChanged<app_message.Message> onMessageActions;
  final Future<void> Function(BuildContext, app_message.Message)
      onOpenSharedVideo;

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
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
            Text(
              'We couldn’t load this chat',
              style: TextStyle(
                color: StSupportShellStyle.of(context).onChrome,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error ?? 'Unknown error',
              style: TextStyle(
                color: shell.muted,
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

    final Uint8List? optimistic = optimisticOutgoingGifBytes;
    final bool hasOptimistic = optimistic != null && optimistic.isNotEmpty;

    if (messages.isEmpty && !hasOptimistic) {
      return _ChatStateCard(
        stateKey: ValueKey('chat-empty'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: shell.mutedStrong,
            ),
            SizedBox(height: 16),
            Text(
              'No messages yet',
              style: TextStyle(
                color: StSupportShellStyle.of(context).onChrome,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Start the conversation and say hello.',
              style: TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.72),
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
        key: const ValueKey('chat-message-list'),
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
        itemCount: messages.length + (hasOptimistic ? 1 : 0),
        itemBuilder: (context, index) {
          if (hasOptimistic && index == messages.length) {
            return _OptimisticOutgoingGifBubble(
              bytes: optimistic,
              currentUserId: currentUserId,
              currentUserAvatarURL: currentUserAvatarURL,
            );
          }
          final app_message.Message message = messages[index];
          final bool isMe = message.from == currentUserId;
          final bool prevSame =
              index > 0 && messages[index - 1].from == message.from;
          final bool nextSame = index < messages.length - 1 &&
              messages[index + 1].from == message.from;
          final bool isLastInGroup = !nextSame;
          return _ChatMessageBubble(
            message: message,
            isMe: isMe,
            otherUserName: otherUserName,
            timestampLabel:
                formatMessageClock(message.timestamp ?? DateTime.now()),
            currentUserId: currentUserId,
            otherUserId: otherUserId,
            currentUserAvatarURL: currentUserAvatarURL,
            otherUserAvatarURL: otherUserAvatarURL,
            isSelected: selectedMessageIds.contains(message.id),
            canSelect: currentUserIdForSelection != null &&
                message.from == currentUserIdForSelection,
            hasSelection: hasSelection,
            showAvatar: !isMe && isLastInGroup,
            showTimestamp: isLastInGroup,
            isGroupedWithPrevious: prevSame,
            onLongPressForSelection: () => onMessageLongPress(message),
            onTapWhenSelecting: () => onMessageTapWhenSelecting(message),
            onShowActions: () => onMessageActions(message),
            onOpenSharedVideo: onOpenSharedVideo,
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
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Center(
      child: Container(
        key: stateKey,
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 30),
        decoration: BoxDecoration(
          color: shell.surfaceCard,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: shell.surfaceCardBorder,
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
    required this.otherUserName,
    required this.timestampLabel,
    required this.currentUserId,
    required this.otherUserId,
    required this.currentUserAvatarURL,
    required this.otherUserAvatarURL,
    required this.isSelected,
    required this.canSelect,
    required this.hasSelection,
    required this.showAvatar,
    required this.showTimestamp,
    required this.isGroupedWithPrevious,
    required this.onLongPressForSelection,
    required this.onTapWhenSelecting,
    required this.onShowActions,
    required this.onOpenSharedVideo,
  });

  final app_message.Message message;
  final bool isMe;
  final String otherUserName;
  final String timestampLabel;
  final String? currentUserId;
  final String otherUserId;
  final String? currentUserAvatarURL;
  final String? otherUserAvatarURL;
  final bool isSelected;
  final bool canSelect;
  final bool hasSelection;
  final bool showAvatar;
  final bool showTimestamp;
  final bool isGroupedWithPrevious;
  final VoidCallback onLongPressForSelection;
  final VoidCallback onTapWhenSelecting;
  final VoidCallback onShowActions;
  final Future<void> Function(BuildContext, app_message.Message)
      onOpenSharedVideo;

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final double maxBubbleWidth =
        MediaQuery.sizeOf(context).width * ChatUiTokens.bubbleMaxWidthFactor;
    final Color incomingText =
        shell.isLight ? scheme.onSurface : Colors.white.withValues(alpha: 0.92);
    final Color outgoingText = Colors.white.withValues(alpha: 0.96);
    final bool isDeleted = message.deletedForEveryone;
    final bool isSharedContent = message.messageType == 'video_share' ||
        message.messageType == 'content_share';
    final bool isReplyMessage = message.messageType == 'reply';
    final double bottomMargin = showTimestamp ? 10 : 3;
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 240),
      tween: Tween<double>(begin: 0, end: 1),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double value, Widget? child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 6),
            child: child,
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: bottomMargin),
        foregroundDecoration: hasSelection && !isSelected
            ? BoxDecoration(
                color: scheme.scrim.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(20),
              )
            : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment:
              isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: <Widget>[
            if (!isMe)
              SizedBox(
                width: ChatUiTokens.messageAvatarRadius * 2 + 8,
                child: showAvatar
                    ? Padding(
                        padding: const EdgeInsets.only(right: 8, bottom: 2),
                        child: StatusAwareAvatar(
                          userId: otherUserId,
                          avatarURL: otherUserAvatarURL,
                          radius: ChatUiTokens.messageAvatarRadius,
                          showOnlineIndicator: false,
                        ),
                      )
                    : null,
              ),
            Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: <Widget>[
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                  child: _PressableBubble(
                    onLongPress: () {
                      if (hasSelection && canSelect) {
                        onLongPressForSelection();
                      } else if (!hasSelection) {
                        onShowActions();
                      }
                    },
                    onTap:
                        hasSelection && canSelect ? onTapWhenSelecting : null,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: isMe ? ChatUiTokens.outgoingGradient : null,
                        color: isMe
                            ? null
                            : (shell.isLight
                                ? scheme.surfaceContainerLow
                                : ChatUiTokens.incomingFill),
                        borderRadius: isMe
                            ? ChatUiTokens.outgoingBubbleRadius
                            : ChatUiTokens.incomingBubbleRadius,
                        border: Border.all(
                          color: isSelected
                              ? ChatUiTokens.outgoingEnd.withValues(alpha: 0.65)
                              : (isMe
                                  ? Colors.white.withValues(alpha: 0.10)
                                  : ChatUiTokens.incomingBorder),
                        ),
                        boxShadow: <BoxShadow>[
                          if (isMe)
                            BoxShadow(
                              color: ChatUiTokens.outgoingStart
                                  .withValues(alpha: 0.12),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          if (isSelected)
                            BoxShadow(
                              color: ChatUiTokens.outgoingStart
                                  .withValues(alpha: 0.28),
                              blurRadius: 10,
                            ),
                        ],
                      ),
                      child: Stack(
                        children: <Widget>[
                          if (isMe)
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: isMe
                                      ? ChatUiTokens.outgoingBubbleRadius
                                      : ChatUiTokens.incomingBubbleRadius,
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: <Color>[
                                      Colors.white.withValues(alpha: 0.14),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          Padding(
                            padding: ChatUiTokens.bubblePadding,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                if (isSelected)
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 6),
                                      width: 18,
                                      height: 18,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: ChatUiTokens.outgoingGradient,
                                      ),
                                      child: const Icon(
                                        Icons.check_rounded,
                                        size: 12,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                if (message.replyToMessageId != null &&
                                    message.replyToMessageId!.isNotEmpty)
                                  _ReplyPreview(
                                    previewText: message.replyPreviewText,
                                    thumbnailUrl: message.replyThumbnailUrl,
                                    senderName: message.replyToSenderName,
                                    type: message.replyToType ?? 'text',
                                    isMe: isMe,
                                  ),
                                if (isDeleted)
                                  Text(
                                    'This message was deleted.',
                                    style: TextStyle(
                                      color:
                                          (isMe ? outgoingText : incomingText)
                                              .withValues(alpha: 0.82),
                                      fontSize: 13.5,
                                      fontStyle: FontStyle.italic,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  )
                                else if (isSharedContent)
                                  _SharedVideoPreviewCard(
                                    message: message,
                                    isMe: isMe,
                                    peerName: otherUserName,
                                    onTap: () =>
                                        onOpenSharedVideo(context, message),
                                  )
                                else if (message.messageType == 'gif' &&
                                    message.gifUrl != null)
                                  _GifMessageContent(message: message)
                                else if (isReplyMessage &&
                                    message.text.trim().isEmpty)
                                  Text(
                                    'Reply',
                                    style: TextStyle(
                                      color: isMe ? outgoingText : incomingText,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  )
                                else
                                  Text(
                                    message.text,
                                    style: TextStyle(
                                      color: isMe ? outgoingText : incomingText,
                                      fontSize: 14,
                                      fontWeight: isMe
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      height: 1.3,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (showTimestamp)
                  _BubbleTimestamp(label: timestampLabel, isMe: isMe),
              ],
            ),
            if (isMe) const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }
}

class _PressableBubble extends StatefulWidget {
  const _PressableBubble({
    required this.child,
    this.onTap,
    this.onLongPress,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  State<_PressableBubble> createState() => _PressableBubbleState();
}

class _PressableBubbleState extends State<_PressableBubble> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

class _BubbleTimestamp extends StatelessWidget {
  const _BubbleTimestamp({
    required this.label,
    required this.isMe,
  });

  final String label;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: 4,
        left: isMe ? 0 : 4,
        right: isMe ? 4 : 0,
        bottom: 2,
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.62),
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
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
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onLongPress: () {
            unawaited(
              copyNetworkGifToClipboard(context, message.gifUrl!),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              children: [
                Image.network(
                  message.gifUrl!,
                  width: 208,
                  height: 156,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
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
                      color: scheme.scrim.withValues(alpha: 0.36),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: shell.onChrome.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Text(
                      'GIF',
                      style: TextStyle(
                        color: StSupportShellStyle.of(context).onChrome,
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
                      child: Icon(
                        Icons.phone_android,
                        color: StSupportShellStyle.of(context).onChrome,
                        size: 14,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message.isDeviceGif ? 'Shared from device' : 'Animated image',
          style: TextStyle(
            color: shell.muted,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _KeyboardComposerPadding extends StatelessWidget {
  const _KeyboardComposerPadding({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final double keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final double gestureInset = MediaQuery.viewPaddingOf(context).bottom;
    final double bottomPad =
        keyboardInset > 0 ? keyboardInset : (gestureInset > 0 ? 4.0 : 8.0);
    return Padding(
      padding: EdgeInsets.only(bottom: bottomPad),
      child: child,
    );
  }
}

class _ComposerReplyBanner extends StatelessWidget {
  const _ComposerReplyBanner({
    required this.message,
    required this.currentUserId,
    required this.otherUserName,
    required this.onCancel,
  });

  final app_message.Message message;
  final String? currentUserId;
  final String otherUserName;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String senderName =
        message.from == currentUserId ? 'yourself' : otherUserName;
    final String preview = _replyPreviewText(message);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: shell.panelSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: shell.panelBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
          child: Row(
            children: <Widget>[
              Container(
                width: 3,
                height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: const LinearGradient(
                    colors: <Color>[Color(0xFF9248D2), Color(0xFF4897D2)],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'Replying to $senderName',
                      style: TextStyle(
                        color: shell.onChrome,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      preview,
                      style: TextStyle(
                        color: shell.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Cancel reply',
                onPressed: onCancel,
                icon: Icon(
                  Icons.close_rounded,
                  color: scheme.onSurface.withValues(alpha: 0.72),
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _replyPreviewText(app_message.Message message) {
    if (message.deletedForEveryone) return 'Deleted message';
    if (message.text.trim().isNotEmpty) return message.text.trim();
    if ((message.videoTitle ?? '').trim().isNotEmpty) {
      return message.videoTitle!.trim();
    }
    if ((message.gifUrl ?? '').trim().isNotEmpty) return 'GIF';
    if (message.messageType == 'video_share' ||
        message.messageType == 'content_share') {
      return 'Shared video';
    }
    return 'Message';
  }
}

class _ChatComposer extends StatelessWidget {
  const _ChatComposer({
    required this.controller,
    required this.focusNode,
    required this.isSending,
    required this.onSend,
    required this.onChanged,
    required this.onPasteMediaFromClipboard,
    required this.onKeyboardMediaInserted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSending;
  final VoidCallback onSend;
  final ValueChanged<String> onChanged;
  final VoidCallback onPasteMediaFromClipboard;
  final ValueChanged<KeyboardInsertedContent> onKeyboardMediaInserted;

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.fromLTRB(4, 5, 4, 5),
            decoration: BoxDecoration(
              color: ChatUiTokens.glassFill,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: ChatUiTokens.glassBorder),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                IconButton(
                  tooltip: 'Add attachment',
                  onPressed: isSending ? null : onPasteMediaFromClipboard,
                  iconSize: 22,
                  icon: Icon(
                    Icons.add_circle_outline_rounded,
                    color: isSending ? shell.iconDim : shell.onChrome,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    textInputAction: TextInputAction.send,
                    onChanged: onChanged,
                    minLines: 1,
                    maxLines: 4,
                    contentInsertionConfiguration:
                        ContentInsertionConfiguration(
                      allowedMimeTypes: const <String>[
                        'image/gif',
                        'image/png',
                        'image/jpeg',
                        'image/jpg',
                        'image/webp',
                      ],
                      onContentInserted: onKeyboardMediaInserted,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Message',
                      hintStyle: TextStyle(
                        color: shell.mutedStrong,
                        fontSize: 15,
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.06),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      isDense: true,
                    ),
                    style: TextStyle(
                      color: shell.onChrome,
                      fontSize: 15,
                    ),
                    onSubmitted: (_) => onSend(),
                  ),
                ),
                const SizedBox(width: 4),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (BuildContext context, TextEditingValue value, _) {
                    final bool hasText = value.text.trim().isNotEmpty;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: hasText && !isSending
                            ? ChatUiTokens.outgoingGradient
                            : null,
                        color: hasText && !isSending
                            ? null
                            : Colors.white.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: ChatUiTokens.glassBorder,
                        ),
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        onPressed: isSending ? null : onSend,
                        icon: isSending
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                Icons.send_rounded,
                                size: 17,
                                color: hasText ? Colors.white : shell.iconDim,
                              ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TypingIndicatorBanner extends StatelessWidget {
  const _TypingIndicatorBanner({
    required this.userName,
  });

  final String userName;

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: shell.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: shell.surfaceCardBorder,
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.edit_rounded,
            size: 14,
            color: scheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            '$userName is typing...',
            style: TextStyle(
              color: scheme.onSurface.withValues(alpha: 0.84),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SharedVideoPreviewCard extends StatelessWidget {
  const _SharedVideoPreviewCard({
    required this.message,
    required this.isMe,
    required this.peerName,
    required this.onTap,
  });

  final app_message.Message message;
  final bool isMe;
  final String peerName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color textColor = isMe
        ? Colors.white.withValues(alpha: 0.95)
        : Colors.white.withValues(alpha: 0.9);
    final String title = 'Shared a video';
    final String subtitle = (message.videoTitle ?? '').trim().isNotEmpty
        ? message.videoTitle!.trim()
        : (message.text.trim().isNotEmpty ? message.text.trim() : peerName);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.10),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(11),
              ),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    if ((message.videoThumbnailUrl ?? '').isNotEmpty)
                      Image.network(
                        message.videoThumbnailUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (
                          BuildContext context,
                          Object error,
                          StackTrace? stackTrace,
                        ) =>
                            _buildUnavailablePreview(),
                      )
                    else
                      _buildUnavailablePreview(),
                    Center(
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.78),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnavailablePreview() {
    return Container(
      color: AppColors.profileViewBackground.withValues(alpha: 0.75),
      alignment: Alignment.center,
      child: const Text(
        'This video is no longer available.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ReplyPreview extends StatelessWidget {
  const _ReplyPreview({
    required this.previewText,
    required this.thumbnailUrl,
    required this.senderName,
    required this.type,
    required this.isMe,
  });

  final String? previewText;
  final String? thumbnailUrl;
  final String? senderName;
  final String type;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color textColor = isMe ? scheme.onPrimary : scheme.onSurface;
    final bool hasThumbnail = (thumbnailUrl ?? '').isNotEmpty &&
        (type == 'video_share' || type == 'content_share');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: shell.isLight
            ? scheme.surfaceContainerLow.withValues(alpha: 0.92)
            : scheme.scrim.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMe
              ? scheme.onPrimary.withValues(alpha: 0.16)
              : scheme.outline.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 3,
            height: 30,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: const LinearGradient(
                colors: <Color>[Color(0xFF9248D2), Color(0xFF4897D2)],
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (hasThumbnail) ...<Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                thumbnailUrl!,
                width: 26,
                height: 26,
                fit: BoxFit.cover,
                errorBuilder: (
                  BuildContext context,
                  Object error,
                  StackTrace? stackTrace,
                ) =>
                    const SizedBox(width: 26, height: 26),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              '${senderName ?? 'Reply'} · ${previewText ?? 'Message'}',
              style: TextStyle(
                color: textColor.withValues(alpha: 0.92),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
