import 'package:flutter/material.dart';
import '../core/theme/support_shell_style.dart';

class CommunityGuidelinesView extends StatelessWidget {
  const CommunityGuidelinesView({super.key});

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Scaffold(
      backgroundColor: shell.scaffold,
      appBar: AppBar(
        backgroundColor: shell.panelSurface,
        title: Text(
          'Community Guidelines',
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
              'Be Respectful',
              'Treat everyone with respect. No harassment, bullying, hate speech, '
                  'or discrimination based on race, gender, religion, or identity.',
            ),
            _buildSection(
              context,
              'Original Content',
              'Only share content you have the right to use. Do not upload '
                  'copyrighted material without permission.',
            ),
            _buildSection(
              context,
              'No Harmful Content',
              'Do not post content that promotes violence, self-harm, dangerous '
                  'activities, or illegal behavior.',
            ),
            _buildSection(
              context,
              'Authentic Identity',
              'Use your real identity. Impersonation and fake accounts are not allowed.',
            ),
            _buildSection(
              context,
              'Privacy & Safety',
              'Respect others\' privacy. Do not share personal information without consent.',
            ),
            _buildSection(
              context,
              'Reporting',
              'If you see content that violates these guidelines, use the Report '
                  'option. We review all reports and take action when needed.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String body) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: shell.onChrome,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(
              color: shell.muted,
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
