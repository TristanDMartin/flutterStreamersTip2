import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'community_guidelines_view.dart';
import 'contact_support_view.dart';

class SafetyCenterView extends StatelessWidget {
  const SafetyCenterView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.supportBackground,
      appBar: AppBar(
        backgroundColor: AppColors.supportTopSurface,
        title: const Text(
          'Safety Center',
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

  Widget _buildSection(String title, String body) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.supportAccent, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.supportAccent,
            fontSize: 16,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }
}
