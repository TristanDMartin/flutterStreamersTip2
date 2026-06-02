import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.onSurface.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  displayName.isEmpty ? 'Connected' : displayName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              _OptionTile(
                icon: Icons.chat_bubble_outline,
                label: 'Message',
                onTap: () {
                  HapticFeedback.lightImpact();
                  onMessage();
                },
              ),
              _OptionTile(
                icon: Icons.person_remove_outlined,
                label: 'Unfollow',
                onTap: () {
                  HapticFeedback.lightImpact();
                  onUnfollow();
                },
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
              const SizedBox(height: 8),
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
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.onSurface;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w500),
      ),
      onTap: onTap,
    );
  }
}
