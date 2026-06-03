import 'package:flutter/material.dart';

/// 18+ confirmation before opening Patreon / OnlyFans external links.
Future<bool> showAdultExternalLinkDialog(BuildContext context) async {
  final bool? confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      final ColorScheme cs = Theme.of(dialogContext).colorScheme;
      return AlertDialog(
        title: const Text('18+ External Link'),
        content: Text(
          'This link may lead to mature or subscription-based content '
          'outside StreamersTip.\n\n'
          'StreamersTip does not host, preview, or verify content from '
          'this platform.\n\n'
          'Are you 18 or older and want to continue?',
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 15,
            height: 1.4,
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('I am 18+ — Continue'),
          ),
        ],
      );
    },
  );
  return confirmed == true;
}
