import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class TippyMessageContent extends StatelessWidget {
  const TippyMessageContent({
    super.key,
    required this.text,
    required this.style,
    this.onContentPlanDeepLink,
  });

  final String text;
  final TextStyle style;

  /// Opens `users/{uid}/contentPlans/{planId}` in-app when the assistant message
  /// contains `streamerstip://content-plan/{planId}` (also appended by the API).
  final void Function(String planId)? onContentPlanDeepLink;

  static final RegExp _linkToken = RegExp(
    r'(https?:\/\/[^\s]+)|streamerstip:\/\/content-plan\/([A-Za-z0-9_-]+)',
    caseSensitive: false,
  );

  @override
  Widget build(BuildContext context) {
    final Iterable<RegExpMatch> matches = _linkToken.allMatches(text);
    if (matches.isEmpty) {
      return SelectableText(text, style: style);
    }
    final List<InlineSpan> spans = <InlineSpan>[];
    int start = 0;
    for (final RegExpMatch match in matches) {
      if (match.start > start) {
        spans.add(
          TextSpan(text: text.substring(start, match.start), style: style),
        );
      }
      final String? httpUrl = match.group(1);
      final String? planId = match.group(2);
      if (httpUrl != null) {
        final Uri? uri = Uri.tryParse(httpUrl);
        final bool allowed = uri != null && _isInternalHost(uri.host);
        if (uri == null || !allowed) {
          spans.add(TextSpan(text: httpUrl, style: style));
        } else {
          spans.add(
            TextSpan(
              text: httpUrl,
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
      } else if (planId != null && planId.isNotEmpty) {
        final void Function(String)? handler = onContentPlanDeepLink;
        if (handler == null) {
          spans.add(TextSpan(text: match.group(0)!, style: style));
        } else {
          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: GestureDetector(
                onTap: () => handler(planId),
                child: Text(
                  'Open content plan',
                  style: style.copyWith(
                    color: const Color(0xFF93C5FD),
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          );
        }
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
