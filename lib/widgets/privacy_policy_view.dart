import 'package:flutter/material.dart';

class PrivacyPolicyView extends StatelessWidget {
  const PrivacyPolicyView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Privacy Policy',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildSection(
              '1. Information We Collect',
              [
                _buildSubsection(
                  'A. Personal Information',
                  'We collect personal data that you voluntarily provide when creating an account, customizing your profile, or interacting with our services. This may include:\n\n• Full name and email address\n• Username, profile photo, and bio information\n• Social media links and content you upload or share\n• Communication preferences and account settings',
                ),
                _buildSubsection(
                  'B. Automatically Collected Information',
                  'When you use StreamersTip, we automatically collect certain data to improve performance and user experience:\n\n• Device type, operating system, and browser\n• IP address and approximate location\n• Usage data such as session duration, clicks, and page views\n• Referring URLs and traffic sources\n• Cookies and tracking technologies (for analytics and preferences)',
                ),
                _buildSubsection(
                  'C. Third-Party Data',
                  'If you link accounts (e.g., Twitch, YouTube, Kick, or TikTok), we may collect publicly available information or data you authorize from those platforms, including:\n\n• Channel name, follower count, stream metrics, and profile details\n• Engagement or performance analytics',
                ),
              ],
            ),
            _buildSection(
              '2. How We Use Your Information',
              [
                _buildParagraph(
                  'We process collected information to:\n\n• Provide, maintain, and improve our Platform\n• Personalize your experience and recommend relevant content\n• Enable community and networking features (comments, follows, messages, etc.)\n• Send important updates, newsletters, and promotional messages\n• Monitor platform integrity and prevent fraud or misuse\n• Comply with applicable legal, safety, and regulatory requirements\n\nWe may also anonymize or aggregate data for research, performance insights, or internal analytics.',
                ),
              ],
            ),
            _buildSection(
              '3. Information Sharing',
              [
                _buildParagraph(
                  'We respect your privacy — we do not sell your personal information.\n\nWe only share information in the following cases:\n\n• Service Providers: With trusted vendors who assist in operating our Platform (e.g., hosting, analytics, email delivery).\n• Legal Requirements: When required by law, court order, or government authority.\n• With Your Consent: If you explicitly authorize sharing (e.g., displaying your profile publicly or connecting third-party apps).\n\nAll partners and service providers are contractually bound to maintain strict confidentiality and data protection standards.',
                ),
              ],
            ),
            _buildSection(
              '4. Data Retention',
              [
                _buildParagraph(
                  'We retain your personal data only as long as necessary to fulfill the purposes described in this Policy or as required by law.\n\nYou may request deletion of your account and associated data at any time (see Section 7).',
                ),
              ],
            ),
            _buildSection(
              '5. Cookies and Tracking Technologies',
              [
                _buildParagraph(
                  'StreamersTip uses cookies, pixels, and similar technologies to:\n\n• Keep you logged in securely\n• Remember your preferences\n• Analyze site traffic and app performance\n• Deliver relevant recommendations\n\nYou can manage or disable cookies in your browser settings. Please note that disabling cookies may limit certain features.',
                ),
              ],
            ),
            _buildSection(
              '6. Data Security',
              [
                _buildParagraph(
                  'We use industry-standard safeguards to protect your information from unauthorized access, alteration, disclosure, or destruction. These include:\n\n• Secure SSL/TLS encryption\n• Regular security audits and updates\n• Access controls and authentication measures\n\nHowever, no online platform is 100% secure. By using StreamersTip, you acknowledge and accept this inherent risk.',
                ),
              ],
            ),
            _buildSection(
              '7. Your Rights',
              [
                _buildParagraph(
                  'Depending on your location, you may have the following rights:\n\n• Access: Request a copy of your personal data\n• Correction: Update or correct inaccurate information\n• Deletion: Request account and data deletion ("Right to be Forgotten")\n• Portability: Request data in a structured, machine-readable format\n• Opt-Out: Manage communication preferences and unsubscribe from non-essential messages\n\nTo exercise these rights, contact us at contact@streamerstip.com',
                ),
              ],
            ),
            _buildSection(
              '8. International Data Transfers',
              [
                _buildParagraph(
                  'If you are located outside the United States, please note that your data may be transferred and processed in the U.S. or other regions where our servers or partners operate. We take steps to ensure your data receives adequate protection consistent with applicable laws.',
                ),
              ],
            ),
            _buildSection(
              '9. Children\'s Privacy',
              [
                _buildParagraph(
                  'StreamersTip is not directed toward individuals under the age of 13 (or the age of digital consent in your jurisdiction).\n\nWe do not knowingly collect personal information from minors. If we learn that we have inadvertently collected such data, we will promptly delete it.',
                ),
              ],
            ),
            _buildSection(
              '10. Updates to This Policy',
              [
                _buildParagraph(
                  'We may update this Privacy Policy periodically to reflect changes in our practices or legal requirements.\n\nAll updates will be posted on this page with the revised "Last Updated" date.',
                ),
              ],
            ),
            _buildSection(
              '11. Contact Us',
              [
                _buildParagraph(
                  'For questions, requests, or concerns regarding this Privacy Policy, contact us at:\n\nStreamersTip\n📧 contact@streamerstip.com\n🌐 https://www.streamerstip.com',
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'StreamersTip Privacy Policy',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Last Updated: July 25, 2025',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Welcome to StreamersTip ("we," "our," or "us"). This Privacy Policy explains how we collect, use, and safeguard your information when you access or use our website, mobile application, and any related services (collectively, the "Platform").\n\nBy using StreamersTip, you agree to the terms outlined in this Privacy Policy.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 16,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildSection(String title, List<Widget> content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF9248D2),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...content,
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSubsection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
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
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 15,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParagraph(String content) {
    return Text(
      content,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.8),
        fontSize: 15,
        height: 1.6,
      ),
    );
  }
}
