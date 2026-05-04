import 'package:flutter/material.dart';

class PrivacyPolicyView extends StatelessWidget {
  const PrivacyPolicyView({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color on = cs.onSurface;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: on),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Privacy Policy',
          style: TextStyle(
            color: on,
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
            _buildHeader(context),
            const SizedBox(height: 24),
            _buildSection(
              context,
              '1. Information We Collect',
              [
                _buildSubsection(
                  context,
                  'A. Personal Information',
                  'We collect personal data that you voluntarily provide when creating an account, customizing your profile, or interacting with our services. This may include:\n\n• Full name and email address\n• Username, profile photo, and bio information\n• Social media links and content you upload or share\n• Communication preferences and account settings',
                ),
                _buildSubsection(
                  context,
                  'B. Automatically Collected Information',
                  'When you use StreamersTip, we automatically collect certain data to improve performance and user experience:\n\n• Device type, operating system, and browser\n• IP address and approximate location\n• Usage data such as session duration, clicks, and page views\n• Referring URLs and traffic sources\n• Cookies and tracking technologies (for analytics and preferences)',
                ),
                _buildSubsection(
                  context,
                  'C. Third-Party Data',
                  'If you link accounts (e.g., Twitch, YouTube, Kick, or TikTok), we may collect publicly available information or data you authorize from those platforms, including:\n\n• Channel name, follower count, stream metrics, and profile details\n• Engagement or performance analytics',
                ),
              ],
            ),
            _buildSection(
              context,
              '2. How We Use Your Information',
              [
                _buildParagraph(
                  context,
                  'We process collected information to:\n\n• Provide, maintain, and improve our Platform\n• Personalize your experience and recommend relevant content\n• Enable community and networking features (comments, follows, messages, etc.)\n• Send important updates, newsletters, and promotional messages\n• Monitor platform integrity and prevent fraud or misuse\n• Comply with applicable legal, safety, and regulatory requirements\n\nWe may also anonymize or aggregate data for research, performance insights, or internal analytics.',
                ),
              ],
            ),
            _buildSection(
              context,
              '3. Information Sharing',
              [
                _buildParagraph(
                  context,
                  'We respect your privacy — we do not sell your personal information.\n\nWe only share information in the following cases:\n\n• Service Providers: With trusted vendors who assist in operating our Platform (e.g., hosting, analytics, email delivery).\n• Legal Requirements: When required by law, court order, or government authority.\n• With Your Consent: If you explicitly authorize sharing (e.g., displaying your profile publicly or connecting third-party apps).\n\nAll partners and service providers are contractually bound to maintain strict confidentiality and data protection standards.',
                ),
              ],
            ),
            _buildSection(
              context,
              '4. Data Retention',
              [
                _buildParagraph(
                  context,
                  'We retain your personal data only as long as necessary to fulfill the purposes described in this Policy or as required by law.\n\nYou may request deletion of your account and associated data at any time (see Section 7).',
                ),
              ],
            ),
            _buildSection(
              context,
              '5. Cookies and Tracking Technologies',
              [
                _buildParagraph(
                  context,
                  'StreamersTip uses cookies, pixels, and similar technologies to:\n\n• Keep you logged in securely\n• Remember your preferences\n• Analyze site traffic and app performance\n• Deliver relevant recommendations\n\nYou can manage or disable cookies in your browser settings. Please note that disabling cookies may limit certain features.',
                ),
              ],
            ),
            _buildSection(
              context,
              '6. Data Security',
              [
                _buildParagraph(
                  context,
                  'We use industry-standard safeguards to protect your information from unauthorized access, alteration, disclosure, or destruction. These include:\n\n• Secure SSL/TLS encryption\n• Regular security audits and updates\n• Access controls and authentication measures\n\nHowever, no online platform is 100% secure. By using StreamersTip, you acknowledge and accept this inherent risk.',
                ),
              ],
            ),
            _buildSection(
              context,
              '7. Your Rights',
              [
                _buildParagraph(
                  context,
                  'Depending on your location, you may have the following rights:\n\n• Access: Request a copy of your personal data\n• Correction: Update or correct inaccurate information\n• Deletion: Request account and data deletion ("Right to be Forgotten")\n• Portability: Request data in a structured, machine-readable format\n• Opt-Out: Manage communication preferences and unsubscribe from non-essential messages\n\nTo exercise these rights, contact us at contact@streamerstip.com',
                ),
              ],
            ),
            _buildSection(
              context,
              '8. International Data Transfers',
              [
                _buildParagraph(
                  context,
                  'If you are located outside the United States, please note that your data may be transferred and processed in the U.S. or other regions where our servers or partners operate. We take steps to ensure your data receives adequate protection consistent with applicable laws.',
                ),
              ],
            ),
            _buildSection(
              context,
              '9. Children\'s Privacy',
              [
                _buildParagraph(
                  context,
                  'StreamersTip is not directed toward individuals under the age of 13 (or the age of digital consent in your jurisdiction).\n\nWe do not knowingly collect personal information from minors. If we learn that we have inadvertently collected such data, we will promptly delete it.',
                ),
              ],
            ),
            _buildSection(
              context,
              '10. Updates to This Policy',
              [
                _buildParagraph(
                  context,
                  'We may update this Privacy Policy periodically to reflect changes in our practices or legal requirements.\n\nAll updates will be posted on this page with the revised "Last Updated" date.',
                ),
              ],
            ),
            _buildSection(
              context,
              '11. Contact Us',
              [
                _buildParagraph(
                  context,
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

  Widget _buildHeader(BuildContext context) {
    final Color on = Theme.of(context).colorScheme.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'StreamersTip Privacy Policy',
          style: TextStyle(
            color: on,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Last Updated: July 25, 2025',
          style: TextStyle(
            color: on.withValues(alpha: 0.6),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Welcome to StreamersTip ("we," "our," or "us"). This Privacy Policy explains how we collect, use, and safeguard your information when you access or use our website, mobile application, and any related services (collectively, the "Platform").\n\nBy using StreamersTip, you agree to the terms outlined in this Privacy Policy.',
          style: TextStyle(
            color: on.withValues(alpha: 0.85),
            fontSize: 16,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    List<Widget> content,
  ) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: cs.primary,
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

  Widget _buildSubsection(
    BuildContext context,
    String title,
    String content,
  ) {
    final Color on = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: on,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              color: on.withValues(alpha: 0.85),
              fontSize: 15,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParagraph(BuildContext context, String content) {
    final Color on = Theme.of(context).colorScheme.onSurface;
    return Text(
      content,
      style: TextStyle(
        color: on.withValues(alpha: 0.85),
        fontSize: 15,
        height: 1.6,
      ),
    );
  }
}
