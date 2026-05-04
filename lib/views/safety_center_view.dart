import 'package:flutter/material.dart';
import '../core/theme/support_shell_style.dart';
import 'community_guidelines_view.dart';
import 'contact_support_view.dart';

class SafetyCenterView extends StatelessWidget {
  const SafetyCenterView({super.key});

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Scaffold(
      backgroundColor: shell.scaffold,
      appBar: AppBar(
        backgroundColor: shell.panelSurface,
        title: Text(
          'Safety Center',
          style: TextStyle(color: shell.onChrome),
        ),
        iconTheme: IconThemeData(color: shell.onChrome),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              context,
              'Your Safety Matters',
              'StreamersTip is committed to keeping our community safe. '
                  'Learn about our safety features and how to protect yourself.',
            ),
            const SizedBox(height: 24),
            _buildFeature(
              context,
              Icons.shield,
              'Block & Report',
              'Block users who bother you. Report content that violates our guidelines.',
            ),
            _buildFeature(
              context,
              Icons.visibility_off,
              'Privacy Controls',
              'Control who can see your content, message you, and mention you.',
            ),
            _buildFeature(
              context,
              Icons.family_restroom,
              'Family Safety',
              'Use content preferences to filter what appears in your feed.',
            ),
            const SizedBox(height: 24),
            _buildSection(
              context,
              'Need Help?',
              'If you or someone you know needs support, reach out to our team.',
            ),
            const SizedBox(height: 16),
            _buildLink(
              context,
              'Contact Support',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ContactSupportView(),
                ),
              ),
            ),
            _buildLink(
              context,
              'Community Guidelines',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const CommunityGuidelinesView(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String body) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: shell.onChrome,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          style: TextStyle(
            color: shell.muted,
            fontSize: 16,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildFeature(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
  ) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: scheme.primary, size: 28),
          const SizedBox(width: 16),
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
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLink(
    BuildContext context,
    String label, {
    required VoidCallback onTap,
  }) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        child: Text(
          label,
          style: TextStyle(
            color: scheme.primary,
            fontSize: 16,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }
}
