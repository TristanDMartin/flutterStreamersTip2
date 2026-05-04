import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme/support_shell_style.dart';

class TermsAndPrivacyView extends StatelessWidget {
  const TermsAndPrivacyView({super.key});

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Scaffold(
      backgroundColor: shell.scaffold,
      appBar: AppBar(
        backgroundColor: shell.panelSurface,
        title: Text(
          'Terms & Privacy',
          style: TextStyle(color: shell.onChrome),
        ),
        iconTheme: IconThemeData(color: shell.onChrome),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOption(
              context,
              'Privacy Policy',
              'How we collect, use, and protect your data.',
              () => launchUrl(Uri.parse(
                'https://www.streamerstip.com/privacy',
              )),
            ),
            const SizedBox(height: 16),
            _buildOption(
              context,
              'Terms of Service',
              'Terms and conditions for using StreamersTip.',
              () => launchUrl(Uri.parse(
                'https://www.streamerstip.com/terms',
              )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(
    BuildContext context,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: shell.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: shell.surfaceCardBorder,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: shell.onChrome,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: shell.muted,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: shell.mutedStrong,
            ),
          ],
        ),
      ),
    );
  }
}
