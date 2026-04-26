import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class TippyMessageContent extends StatelessWidget {
  const TippyMessageContent({
    super.key,
    required this.text,
    required this.style,
  });

  final String text;
  final TextStyle style;

  static final RegExp _urlPattern = RegExp(
    r'(https?:\/\/[^\s]+)',
    caseSensitive: false,
  );

  @override
  Widget build(BuildContext context) {
    final Iterable<RegExpMatch> matches = _urlPattern.allMatches(text);
    if (matches.isEmpty) {
      return SelectableText(text, style: style);
    }
    final List<InlineSpan> spans = <InlineSpan>[];
    int start = 0;
    for (final RegExpMatch match in matches) {
      if (match.start > start) {
        spans.add(TextSpan(text: text.substring(start, match.start), style: style));
      }
      final String link = text.substring(match.start, match.end);
      final Uri? uri = Uri.tryParse(link);
      final bool allowed = uri != null && _isInternalHost(uri.host);
      if (!allowed) {
        spans.add(TextSpan(text: link, style: style));
      } else {
        spans.add(
          TextSpan(
            text: link,
            style: style.copyWith(
              color: const Color(0xFF93C5FD),
              decoration: TextDecoration.underline,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () => launchUrl(
                    uri,
                    mode: LaunchMode.externalApplication,
                  ),
          ),
        );
      }
      start = match.end;
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: style));
    }
    return SelectableText.rich(TextSpan(children: spans));
  }

  bool _isInternalHost(String host) {
    final String h = host.toLowerCase();
    return h == 'streamerstip.com' || h.endsWith('.streamerstip.com');
  }
}
