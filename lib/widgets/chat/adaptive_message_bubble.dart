import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/design/apple_material_design_system.dart';

/// Adaptive message bubble for chat
/// iOS: iMessage-style bubbles with tail
/// Android: Material Design chat bubbles
class AdaptiveMessageBubble extends StatelessWidget {
  const AdaptiveMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.timestamp,
    this.showAvatar = false,
    this.avatarUrl,
  });

  final String message;
  final bool isMe;
  final String? timestamp;
  final bool showAvatar;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    if (AppleMaterialDesign.isIOS) {
      return _buildIOSBubble(context);
    }
    return _buildAndroidBubble(context);
  }

  Widget _buildIOSBubble(BuildContext context) {
    final bubbleColor = isMe
        ? CupertinoTheme.of(context).primaryColor
        : CupertinoColors.systemGrey5.resolveFrom(context);

    final textColor = isMe
        ? CupertinoColors.white
        : CupertinoColors.label.resolveFrom(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppleMaterialDesign.paddingMedium,
        vertical: 4,
      ),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe && showAvatar) _buildAvatar(),
          if (!isMe && showAvatar)
            const SizedBox(width: AppleMaterialDesign.space8),
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isMe ? 18 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 18),
                    ),
                  ),
                  child: Text(
                    message,
                    style: TextStyle(
                      color: textColor,
                      fontSize: AppleMaterialDesign.iosBody,
                    ),
                  ),
                ),
                if (timestamp != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    timestamp!,
                    style: TextStyle(
                      fontSize: AppleMaterialDesign.iosCaption2,
                      color: CupertinoColors.secondaryLabel.resolveFrom(context),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (isMe && showAvatar)
            const SizedBox(width: AppleMaterialDesign.space8),
          if (isMe && showAvatar) _buildAvatar(),
        ],
      ),
    );
  }

  Widget _buildAndroidBubble(BuildContext context) {
    final theme = Theme.of(context);
    final bubbleColor = isMe
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceVariant;

    final textColor = isMe
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppleMaterialDesign.paddingMedium,
        vertical: 6,
      ),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe && showAvatar) _buildAvatar(),
          if (!isMe && showAvatar)
            const SizedBox(width: AppleMaterialDesign.space8),
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    message,
                    style: TextStyle(
                      color: textColor,
                      fontSize: AppleMaterialDesign.androidBodyMedium,
                    ),
                  ),
                ),
                if (timestamp != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    timestamp!,
                    style: TextStyle(
                      fontSize: AppleMaterialDesign.androidLabelSmall,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (isMe && showAvatar)
            const SizedBox(width: AppleMaterialDesign.space8),
          if (isMe && showAvatar) _buildAvatar(),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return CircleAvatar(
      radius: 16,
      backgroundImage:
          avatarUrl != null ? NetworkImage(avatarUrl!) : null,
      backgroundColor: Colors.grey[300],
      child: avatarUrl == null
          ? Icon(
              AppleMaterialDesign.isIOS
                  ? CupertinoIcons.person_fill
                  : Icons.person,
              size: 20,
              color: Colors.grey[600],
            )
          : null,
    );
  }
}

/// Adaptive chat input bar
class AdaptiveChatInput extends StatelessWidget {
  const AdaptiveChatInput({
    super.key,
    required this.controller,
    required this.onSend,
    this.placeholder = 'Message',
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    if (AppleMaterialDesign.isIOS) {
      return _buildIOSInput(context);
    }
    return _buildAndroidInput(context);
  }

  Widget _buildIOSInput(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: AppleMaterialDesign.paddingMedium,
        right: AppleMaterialDesign.paddingMedium,
        top: AppleMaterialDesign.paddingSmall,
        bottom: AppleMaterialDesign.safeAreaBottom(context) +
            AppleMaterialDesign.paddingSmall,
      ),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        border: Border(
          top: BorderSide(
            color: CupertinoColors.separator.resolveFrom(context),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6.resolveFrom(context),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoTextField(
                      controller: controller,
                      placeholder: placeholder,
                      decoration: null,
                      style: TextStyle(
                        fontSize: AppleMaterialDesign.iosBody,
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => onSend(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppleMaterialDesign.space8),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: onSend,
            child: Icon(
              CupertinoIcons.arrow_up_circle_fill,
              size: 32,
              color: CupertinoTheme.of(context).primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAndroidInput(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.only(
        left: AppleMaterialDesign.paddingMedium,
        right: AppleMaterialDesign.paddingMedium,
        top: AppleMaterialDesign.paddingMedium,
        bottom: AppleMaterialDesign.safeAreaBottom(context) +
            AppleMaterialDesign.paddingMedium,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Colors.grey[300]!,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.emoji_emotions_outlined),
            onPressed: () {},
            color: theme.colorScheme.onSurfaceVariant,
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: placeholder,
                  border: InputBorder.none,
                  isDense: true,
                ),
                style: TextStyle(
                  fontSize: AppleMaterialDesign.androidBodyMedium,
                ),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.send,
              color: theme.colorScheme.primary,
            ),
            onPressed: onSend,
          ),
        ],
      ),
    );
  }
}
