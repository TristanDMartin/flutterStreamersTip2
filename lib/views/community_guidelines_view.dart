import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class CommunityGuidelinesView extends StatelessWidget {
  const CommunityGuidelinesView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.supportBackground,
      appBar: AppBar(
        backgroundColor: AppColors.supportTopSurface,
        title: const Text(
          'Community Guidelines',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              'Be Respectful',
              'Treat everyone with respect. No harassment, bullying, hate speech, '
              'or discrimination based on race, gender, religion, or identity.',
            ),
            _buildSection(
              'Original Content',
              'Only share content you have the right to use. Do not upload '
              'copyrighted material without permission.',
            ),
            _buildSection(
              'No Harmful Content',
              'Do not post content that promotes violence, self-harm, dangerous '
              'activities, or illegal behavior.',
            ),
            _buildSection(
              'Authentic Identity',
              'Use your real identity. Impersonation and fake accounts are not allowed.',
            ),
            _buildSection(
              'Privacy & Safety',
              'Respect others\' privacy. Do not share personal information without consent.',
            ),
            _buildSection(
              'Reporting',
              'If you see content that violates these guidelines, use the Report '
              'option. We review all reports and take action when needed.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
