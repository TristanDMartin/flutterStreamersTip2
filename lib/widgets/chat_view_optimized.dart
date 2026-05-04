import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_colors.dart';
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
    final Uint8List? optimistic =
        _controller.state.optimisticOutgoingGifBytes;
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

  Future<void> _deleteSelectedMessages() async {
    final List<app_message.Message> selectedMessages = _controller.state.messages
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

    return Scaffold(
      backgroundColor: shell.scaffold,
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
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                ),
              ],
            )
          : null,
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
                onMessageLongPress: _toggleMessageSelection,
                onMessageTapWhenSelecting: _toggleMessageSelection,
                onOpenSharedVideo: _openSharedVideoFromMessage,
              ),
            ),
            if (state.isOtherUserTyping)
              _TypingIndicatorBanner(
                userName: _controller.otherUserName,
              ),
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
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.72)),
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
          child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 18),
        ),
        title: Text(title, style: TextStyle(color: StSupportShellStyle.of(context).onChrome)),
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
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
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
                hintStyle:
                    TextStyle(color: shell.mutedStrong),
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
    final StSupportShellStyle shell = StSupportShellStyle.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: shell.heroGradient,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: shell.heroBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: shell.shadowSoft,
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
          StatusAwareAvatar(
            userId: otherUserId,
            avatarURL: otherUserAvatarURL,
            radius: 22,
            showOnlineIndicator: false,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  otherUserName,
                  style: TextStyle(
                    color: shell.onChrome,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: shell.chipUnselectedBg,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: shell.chipUnselectedBorder,
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
                            color: shell.onChrome.withValues(alpha: 0.82),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        loading: () => Text(
                          'Loading...',
                          style: TextStyle(
                            color: StSupportShellStyle.of(context).muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        error: (error, stackTrace) => Text(
                          'Offline',
                          style: TextStyle(
                            color: StSupportShellStyle.of(context).muted,
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
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: shell.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: shell.surfaceCardBorder,
        ),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: shell.onChrome),
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
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: AppColors.supportAccentGradient,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(8),
              ),
              border: Border.all(
                color: scheme.onPrimary.withValues(alpha: 0.18),
              ),
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
    required this.onMessageLongPress,
    required this.onMessageTapWhenSelecting,
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
  final ValueChanged<app_message.Message> onMessageLongPress;
  final ValueChanged<app_message.Message> onMessageTapWhenSelecting;
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
    final bool hasOptimistic =
        optimistic != null && optimistic.isNotEmpty;

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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        itemCount: messages.length + (hasOptimistic ? 1 : 0),
        itemBuilder: (context, index) {
          if (hasOptimistic && index == messages.length) {
            return _OptimisticOutgoingGifBubble(
              bytes: optimistic,
              currentUserId: currentUserId,
              currentUserAvatarURL: currentUserAvatarURL,
            );
          }
          final message = messages[index];
          return _ChatMessageBubble(
            message: message,
            isMe: message.from == currentUserId,
            timestampLabel:
                formatMessageClock(message.timestamp ?? DateTime.now()),
            currentUserId: currentUserId,
            otherUserId: otherUserId,
            currentUserAvatarURL: currentUserAvatarURL,
            otherUserAvatarURL: otherUserAvatarURL,
            isSelected: selectedMessageIds.contains(message.id),
            canSelect: currentUserIdForSelection != null &&
                message.from == currentUserIdForSelection,
            hasSelection: selectedMessageIds.isNotEmpty,
            onLongPress: () => onMessageLongPress(message),
            onTapWhenSelecting: () => onMessageTapWhenSelecting(message),
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
    required this.timestampLabel,
    required this.currentUserId,
    required this.otherUserId,
    required this.currentUserAvatarURL,
    required this.otherUserAvatarURL,
    required this.isSelected,
    required this.canSelect,
    required this.hasSelection,
    required this.onLongPress,
    required this.onTapWhenSelecting,
    required this.onOpenSharedVideo,
  });

  final app_message.Message message;
  final bool isMe;
  final String timestampLabel;
  final String? currentUserId;
  final String otherUserId;
  final String? currentUserAvatarURL;
  final String? otherUserAvatarURL;
  final bool isSelected;
  final bool canSelect;
  final bool hasSelection;
  final VoidCallback onLongPress;
  final VoidCallback onTapWhenSelecting;
  final Future<void> Function(BuildContext, app_message.Message)
      onOpenSharedVideo;

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color incomingBubble = shell.isLight
        ? scheme.surfaceContainerLow
        : Colors.white.withValues(alpha: 0.09);
    final Color incomingBorder = shell.isLight
        ? scheme.outline.withValues(alpha: 0.35)
        : Colors.white.withValues(alpha: 0.12);
    final Color incomingText = shell.isLight ? scheme.onSurface : shell.onChrome;
    final Color incomingTime = shell.isLight
        ? scheme.onSurface.withValues(alpha: 0.62)
        : Colors.white.withValues(alpha: 0.46);
    final Color outgoingText = scheme.onPrimary;
    final Color outgoingTime = scheme.onPrimary.withValues(alpha: 0.74);
    final bool isDeleted = message.deletedForEveryone;
    final bool isSharedContent = message.messageType == 'video_share' ||
        message.messageType == 'content_share';
    final bool isReplyMessage = message.messageType == 'reply';
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
              foregroundDecoration: hasSelection && !isSelected
                  ? BoxDecoration(
                      color: scheme.scrim.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(22),
                    )
                  : null,
              child: Row(
                mainAxisAlignment:
                    isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: StatusAwareAvatar(
                        userId: otherUserId,
                        avatarURL: otherUserAvatarURL,
                        radius: 16,
                        showOnlineIndicator: false,
                      ),
                    ),
                  Flexible(
                    child: GestureDetector(
                      onLongPress: canSelect ? onLongPress : null,
                      onTap: hasSelection && canSelect ? onTapWhenSelecting : null,
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
                        color: isMe ? null : incomingBubble,
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
                          color: isSelected
                              ? Colors.transparent
                              : (isMe
                                  ? scheme.onPrimary.withValues(alpha: 0.18)
                                  : incomingBorder),
                          width: isSelected ? 0 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isMe
                                ? AppColors.primary.withValues(alpha: 0.24)
                                : Colors.black.withValues(alpha: 0.08),
                            blurRadius: isMe ? 14 : 10,
                            offset: const Offset(0, 5),
                          ),
                          if (isSelected)
                            BoxShadow(
                              color: const Color(0xFF9248D2).withValues(alpha: 0.42),
                              blurRadius: 14,
                              spreadRadius: 1,
                            ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isSelected)
                            Align(
                              alignment: Alignment.centerRight,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                width: 20,
                                height: 20,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: <Color>[
                                      Color(0xFF9248D2),
                                      Color(0xFF4897D2),
                                    ],
                                  ),
                                ),
                                child: const Icon(
                                  Icons.check_rounded,
                                  size: 13,
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
                                color: (isMe ? outgoingText : incomingText)
                                    .withValues(alpha: 0.82),
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w500,
                              ),
                            )
                          else if (isSharedContent)
                            _SharedVideoPreviewCard(
                              message: message,
                              isMe: isMe,
                              onTap: () => onOpenSharedVideo(context, message),
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
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          else
                            Text(
                              message.text,
                              style: TextStyle(
                                color: isMe ? outgoingText : incomingText,
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
                              color: isMe ? outgoingTime : incomingTime,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      ),
                    ),
                  ),
                  if (isMe && (currentUserId ?? '').isNotEmpty)
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
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: child,
    );
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
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: shell.surfaceCard,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: shell.surfaceCardBorder,
          ),
        ),
        child: Row(
          children: <Widget>[
            IconButton(
              tooltip: 'Paste GIF or image from clipboard',
              onPressed: isSending ? null : onPasteMediaFromClipboard,
              icon: Icon(
                Icons.content_paste_go_rounded,
                color: isSending ? shell.iconDim : shell.muted,
              ),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                textInputAction: TextInputAction.send,
                onChanged: onChanged,
                contentInsertionConfiguration: ContentInsertionConfiguration(
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
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(
                    color: shell.mutedStrong,
                  ),
                  filled: true,
                  fillColor: scheme.surfaceContainerHigh,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                ),
                style: TextStyle(
                  color: scheme.onSurface,
                ),
                maxLines: null,
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: 12),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (BuildContext context, TextEditingValue value, _) {
                final bool hasText = value.text.trim().isNotEmpty;
                return AnimatedContainer(
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
                        : scheme.surfaceContainerHigh,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: shell.surfaceCardBorder,
                    ),
                  ),
                  child: IconButton(
                    onPressed: isSending ? null : onSend,
                    icon: isSending
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                scheme.onPrimary,
                              ),
                            ),
                          )
                        : Icon(
                            Icons.send_rounded,
                            color: hasText ? scheme.onPrimary : shell.iconDim,
                          ),
                  ),
                );
              },
            ),
          ],
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
    required this.onTap,
  });

  final app_message.Message message;
  final bool isMe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color textColor = isMe ? scheme.onPrimary : scheme.onSurface;
    final String title = (message.videoTitle ?? '').trim().isEmpty
        ? 'Shared video'
        : message.videoTitle!;
    final String subtitle = message.text.trim().isEmpty
        ? 'Tap to watch'
        : message.text;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: shell.isLight
                ? scheme.surfaceContainerLow
                : scheme.scrim.withValues(alpha: isMe ? 0.16 : 0.24),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isMe
                  ? scheme.onPrimary.withValues(alpha: 0.18)
                  : scheme.outline.withValues(alpha: 0.28),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
                child: SizedBox(
                  width: 220,
                  height: 136,
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
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: scheme.scrim.withValues(alpha: 0.48),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: textColor.withValues(alpha: 0.82),
                        fontSize: 12,
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
      ),
    );
  }

  Widget _buildUnavailablePreview() {
    return Container(
      color: const Color(0xFF0F172A).withValues(alpha: 0.75),
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

