import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'gif_pasteboard_channel.dart';

/// Copies a remote GIF to the system clipboard (animated on iOS when possible).
Future<void> copyNetworkGifToClipboard(
  BuildContext context,
  String gifUrl, {
  int maxBytes = 12000000,
}) async {
  final Uri? uri = Uri.tryParse(gifUrl);
  if (uri == null || !uri.hasScheme) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid GIF link.')),
      );
    }
    return;
  }
  try {
    final http.Response response =
        await http.get(uri).timeout(const Duration(seconds: 25));
    if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not download GIF.')),
        );
      }
      return;
    }
    final Uint8List bytes = response.bodyBytes;
    if (bytes.length > maxBytes) {
      await Clipboard.setData(ClipboardData(text: gifUrl));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('GIF is large; copied link instead.')),
        );
      }
      return;
    }
    await GifPasteboardChannel.writeGifBytes(bytes);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('GIF copied — paste in iMessage or chat.')),
      );
    }
  } catch (_) {
    await Clipboard.setData(ClipboardData(text: gifUrl));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copied GIF link.')),
      );
    }
  }
}
