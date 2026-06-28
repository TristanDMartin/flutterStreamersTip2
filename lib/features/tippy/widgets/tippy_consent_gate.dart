import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class TippyConsentGate extends StatelessWidget {
  const TippyConsentGate({
    super.key,
    required this.onAccepted,
    this.busy = false,
  });

  final VoidCallback onAccepted;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF050816),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color(0xFF111827),
              Color(0xFF07111F),
              Color(0xFF050816),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Tippy AI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Before using Tippy, please review how AI works in '
                  'StreamersTip.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _bullet(
                          'Tippy gives creative and growth suggestions — not '
                          'legal, tax, medical, or financial advice.',
                        ),
                        _bullet(
                          'You are responsible for reviewing AI output before '
                          'you publish or act on it.',
                        ),
                        _bullet(
                          'Prompts and responses may be logged for safety, '
                          'abuse prevention, and compliance.',
                        ),
                        _bullet(
                          'You can delete your saved Tippy chat history anytime '
                          'in Privacy Settings.',
                        ),
                      ],
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => launchUrl(
                    Uri.parse('https://www.streamerstip.com/privacy'),
                  ),
                  child: const Text('Privacy Policy'),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: busy ? null : onAccepted,
                    child: busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('I understand — continue'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: busy
                        ? null
                        : () => Navigator.of(context).maybePop(),
                    child: Text(
                      'Not now',
                      style: TextStyle(color: theme.colorScheme.outline),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            '•',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.82),
                fontSize: 14,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
