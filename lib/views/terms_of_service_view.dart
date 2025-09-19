import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TermsOfServiceView extends StatelessWidget {
  const TermsOfServiceView({super.key});

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
          'Terms of Service',
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
                    'Terms of Service',
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
            
            // Terms Content
            _buildSection(
              'Welcome to StreamersTip',
              'Welcome to StreamersTip ("Company", "we", "us", or "our"). These Terms of Service ("Terms") govern your access to and use of our website, mobile app, and related services (collectively, the "Platform"). By accessing or using StreamersTip, you agree to be bound by these Terms and our Privacy Policy.\n\nIf you do not agree with these Terms, please do not use StreamersTip.',
            ),
            
            _buildSection(
              '1. Eligibility',
              'You must be at least 13 years old to use our services. If you are under 18, you must have permission from a parent or legal guardian. You may not use StreamersTip if your use would violate any applicable laws or regulations.',
            ),
            
            _buildSection(
              '2. Platform Overview',
              'StreamersTip is a resource hub and social media platform for streamers and content creators. We offer:\n\n• Customizable creator profile cards\n• Video and clip sharing\n• Discovery and networking tools\n• Access to guides, templates, and creator resources\n• Collaboration tools, event calendars, and messaging\n\nOur mission is to support creators in expanding their brand, connecting with others, and managing their streaming presence across platforms.',
            ),
            
            _buildSection(
              '3. Account Registration and Security',
              'To use most features of StreamersTip, you must create an account. You agree to:\n\n• Provide accurate and complete information\n• Maintain the security of your login credentials\n• Notify us immediately of any unauthorized access to your account\n\nYou are responsible for all activities conducted under your account.',
            ),
            
            _buildSection(
              '4. User Content',
              'You may upload, share, and post various types of content on StreamersTip, including videos, images, messages, and profile information ("User Content"). You retain ownership of your content. However, by sharing it on our platform, you grant StreamersTip a non-exclusive, worldwide, royalty-free license to use, display, reproduce, and distribute your content in connection with operating and promoting the Platform.\n\nYou affirm that:\n\n• You have the necessary rights to your content\n• Your content complies with our Community Guidelines\n• Your content does not infringe on any third-party rights\n\nWe reserve the right to remove or restrict content that violates these Terms or any related policies.',
            ),
            
            _buildSection(
              '5. Prohibited Conduct',
              'You agree not to:\n\n• Post content that is unlawful, harassing, defamatory, threatening, or obscene\n• Violate the intellectual property rights of others\n• Impersonate others or misrepresent your identity\n• Use automated bots or scripts without authorization\n• Interfere with the functionality or security of StreamersTip\n\nViolations may result in suspension or termination of your account.',
            ),
            
            _buildSection(
              '6. Content Moderation',
              'We may monitor, moderate, or remove content that we believe violates our Terms, Community Guidelines, or applicable law. We may also suspend or terminate user accounts based on repeat violations.',
            ),
            
            _buildSection(
              '7. Intellectual Property',
              'All trademarks, logos, designs, and software on StreamersTip (excluding User Content) are the property of StreamersTip or our licensors. You may not copy, reproduce, distribute, or reverse-engineer any portion of the Platform without our written permission.',
            ),
            
            _buildSection(
              '8. Third-Party Services',
              'StreamersTip may contain integrations with third-party platforms like Twitch, YouTube, and Discord. We are not responsible for the practices, content, or policies of those platforms. Your use of third-party services is subject to their own terms.',
            ),
            
            _buildSection(
              '9. Termination',
              'You may close your account at any time. We may suspend or terminate your access if you violate these Terms, applicable laws, or community guidelines.\n\nTermination may result in loss of your content, profile data, and access to any features or services associated with your account.',
            ),
            
            _buildSection(
              '10. DMCA and Copyright Policy',
              'If you believe your copyrighted content has been used on StreamersTip without authorization, please refer to our DMCA Policy for instructions on how to file a notice.',
            ),
            
            _buildSection(
              '11. Cookie Policy',
              'Our use of cookies, analytics, and tracking tools is explained in our Cookie Policy, which forms part of these Terms.',
            ),
            
            _buildSection(
              '12. Monetization and Payments',
              'StreamersTip may offer features that allow creators to monetize their content or receive tips. Use of these features is subject to our Monetization Terms, which include eligibility criteria, payout rules, and compliance requirements.',
            ),
            
            _buildSection(
              '13. Disclaimers',
              'StreamersTip is provided "as is" and "as available." We do not guarantee that the service will be error-free, secure, or uninterrupted. You use the platform at your own risk.',
            ),
            
            _buildSection(
              '14. Limitation of Liability',
              'To the maximum extent permitted by law, StreamersTip is not liable for any indirect, incidental, special, or consequential damages resulting from your use of the platform, even if we were advised of the possibility of such damages.',
            ),
            
            _buildSection(
              '15. Changes to These Terms',
              'We may modify these Terms from time to time. Any changes will be posted on this page with an updated "Last Updated" date. Your continued use of StreamersTip after any changes means you accept the revised Terms.',
            ),
            
            _buildSection(
              '16. Governing Law',
              'These Terms are governed by the laws of the State of California, without regard to conflict of law principles. All disputes shall be resolved in the courts of California.',
            ),
            
            _buildSection(
              '17. Contact Us',
              'If you have any questions or concerns about these Terms, please contact us at:\n\nEmail: contact@streamerstip.com\n\nBusiness Address: StreamersTip Inc.\n123 Creator Street\nSan Francisco, CA 94105',
            ),
            
            const SizedBox(height: 40),
            
            // Footer
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                children: [
                  Text(
                    'By using StreamersTip, you acknowledge that you have read, understood, and agree to be bound by these Terms of Service.',
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
