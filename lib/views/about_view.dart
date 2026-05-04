import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_colors.dart';
import '../core/theme/support_shell_style.dart';
import 'contact_support_view.dart';
import 'terms_and_privacy_view.dart';

class AboutView extends StatelessWidget {
  const AboutView({super.key});

  static const String version = '1.0.0';
  static const String buildNumber = '1';

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: shell.scaffold,
      appBar: AppBar(
        backgroundColor: shell.panelSurface,
        title: Text(
          'About',
          style: TextStyle(color: shell.onChrome),
        ),
        iconTheme: IconThemeData(color: shell.onChrome),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 24),
            Image.asset(
              'assets/logo.png',
              width: 80,
              height: 80,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.videocam,
                size: 80,
                color: AppColors.supportAccent,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'StreamersTip',
              style: TextStyle(
                color: shell.onChrome,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Version $version ($buildNumber)',
              style: TextStyle(
                color: shell.mutedStrong,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Connect • Create • Share',
              style: TextStyle(
                color: shell.muted,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 32),
            _buildExternalLink(
              'Website',
              'https://www.streamerstip.com',
              scheme.primary,
            ),
            _buildRouteLink(
              context,
              'Support',
              const ContactSupportView(),
              scheme.primary,
            ),
            _buildRouteLink(
              context,
              'Privacy Policy',
              const TermsAndPrivacyView(),
              scheme.primary,
            ),
            _buildRouteLink(
              context,
              'Terms of Service',
              const TermsAndPrivacyView(),
              scheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExternalLink(String label, String url, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => launchUrl(Uri.parse(url)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 16,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteLink(
    BuildContext context,
    String label,
    Widget page,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => page,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 16,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
