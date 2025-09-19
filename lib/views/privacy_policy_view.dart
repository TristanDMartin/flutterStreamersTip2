import 'package:flutter/material.dart';

class PrivacyPolicyView extends StatelessWidget {
  const PrivacyPolicyView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Privacy Policy',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6137EB), Color(0xFF1C135D)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF955CFF), Color(0xFF3D99F7)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'StreamersTip Privacy Policy',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Effective Date: January 1, 2025',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Last Updated: January 1, 2025',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Privacy Policy Content
                _buildSection(
                  'Introduction',
                  'Your privacy matters to us. This Privacy Policy describes how StreamersTip ("we", "us", or "our") collects, uses, and protects your personal information when you use our platform.',
                ),
                
                _buildSection(
                  '1. Information We Collect',
                  '• Account Information: Email, username, password\n\n'
                  '• Profile Data: Bio, streaming platforms, avatar\n\n'
                  '• User Content: Videos, messages, posts\n\n'
                  '• Usage Data: IP address, browser/device info, log data\n\n'
                  '• Tracking Technologies: Cookies and analytics (see Cookie Policy)',
                ),
                
                _buildSection(
                  '2. How We Use Your Information',
                  '• To provide and maintain our services\n\n'
                  '• To personalize your experience\n\n'
                  '• To improve functionality and engagement\n\n'
                  '• To communicate updates, features, or support\n\n'
                  '• To ensure platform security and prevent abuse',
                ),
                
                _buildSection(
                  '3. Sharing Your Information',
                  'We do not sell your personal data. We may share your information with:\n\n'
                  '• Service Providers (e.g., cloud storage, analytics tools)\n\n'
                  '• Legal Authorities when required by law\n\n'
                  '• Other Users, if you choose to make your content public',
                ),
                
                _buildSection(
                  '4. Data Retention',
                  'We keep your information:\n\n'
                  '• As long as your account is active\n\n'
                  '• As needed to provide services\n\n'
                  'You can delete your account at any time to remove your data.',
                ),
                
                _buildSection(
                  '5. Your Rights',
                  'You can:\n\n'
                  '• Access your data\n\n'
                  '• Update or correct it\n\n'
                  '• Request deletion\n\n'
                  'To do so, contact us at contact@streamerstip.com',
                ),
                
                _buildSection(
                  '6. Children\'s Privacy',
                  'StreamersTip is not intended for users under 13. We do not knowingly collect data from minors without parental consent.',
                ),
                
                _buildSection(
                  '7. Security',
                  'We use technical and organizational safeguards to protect your data from unauthorized access, disclosure, or misuse.',
                ),
                
                _buildSection(
                  '8. International Users',
                  'If you access StreamersTip from outside the United States, you agree to the transfer and processing of your data in the U.S.',
                ),
                
                _buildSection(
                  '9. Changes to This Policy',
                  'We may update this Privacy Policy over time. Continued use of the platform after changes indicates acceptance of the revised policy.',
                ),
                
                _buildSection(
                  '10. Contact Us',
                  'If you have any questions about this Privacy Policy, reach out to:\n\n'
                  'Email: contact@streamerstip.com',
                ),
                
                const SizedBox(height: 40),
                
                // Footer
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Column(
                    children: [
                      Text(
                        'By using StreamersTip, you acknowledge that you have read, understood, and agree to be bound by this Privacy Policy.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
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
          const SizedBox(height: 12),
          Text(
            content,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
