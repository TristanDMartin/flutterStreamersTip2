import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'streamer_card_sections.dart';

/// Options when the viewer is mutually connected with a creator.
class ConnectedUserOptionsSheet extends StatelessWidget {
  const ConnectedUserOptionsSheet({
    super.key,
    required this.displayName,
    required this.onMessage,
    required this.onUnfollow,
    required this.onReport,
  });

  final String displayName;
  final VoidCallback onMessage;
  final VoidCallback onUnfollow;
  final VoidCallback onReport;

  static Future<void> show(
    BuildContext context, {
    required String displayName,
    required VoidCallback onMessage,
    required VoidCallback onUnfollow,
    required VoidCallback onReport,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => ConnectedUserOptionsSheet(
        displayName: displayName,
        onMessage: () {
          Navigator.pop(ctx);
          onMessage();
        },
        onUnfollow: () {
          Navigator.pop(ctx);
          onUnfollow();
        },
        onReport: () {
          Navigator.pop(ctx);
          onReport();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: StreamerCardBackStyle.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    displayName.isEmpty ? 'Connected' : displayName,
                    style: const TextStyle(
                      color: StreamerCardBackStyle.softText,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: DecoratedBox(
                  decoration: StreamerCardBackStyle.cardDecoration,
                  child: Column(
                    children: <Widget>[
                      _OptionTile(
                        icon: Icons.chat_bubble_outline,
                        label: 'Message',
                        onTap: () {
                          HapticFeedback.lightImpact();
                          onMessage();
                        },
                      ),
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                      _OptionTile(
                        icon: Icons.person_remove_outlined,
                        label: 'Unfollow',
                        onTap: () {
                          HapticFeedback.lightImpact();
                          onUnfollow();
                        },
                      ),
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                      _OptionTile(
                        icon: Icons.flag_outlined,
                        label: 'Report',
                        isDestructive: true,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          onReport();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final Color color = isDestructive
        ? const Color(0xFFF87171)
        : StreamerCardBackStyle.softText;
    final Color iconColor = isDestructive
        ? const Color(0xFFF87171)
        : StreamerCardBackStyle.lavender;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: <Widget>[
            Icon(icon, color: iconColor, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: StreamerCardBackStyle.muted,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
