import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_spacing.dart';
import '../../core/theme.dart';

class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'TERMS OF SERVICE',
          style: GoogleFonts.montserrat(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('1. Acceptance of Terms'),
            _bodyText(
              'By accessing and using Minaret, you agree to be bound by these Terms of Service. If you do not agree to these terms, please do not use our application.',
            ),
            const SizedBox(height: 20),
            _sectionTitle('2. Description of Service'),
            _bodyText(
              'Minaret is a comprehensive prayer management application that provides:\n'
              '• Accurate prayer time calculations based on your location\n'
              '• Mosque discovery and management features\n'
              '• Prayer notifications and reminders\n'
              '• Community features for mosque following and engagement\n'
              '• Janaza announcements and community notifications\n'
              '• Islamic content including Hadith and Quran references\n'
              '• Qibla direction and Islamic calendar features',
            ),
            const SizedBox(height: 20),
            _sectionTitle('3. User Accounts and Registration'),
            _bodyText(
              '• You must provide accurate information when creating an account\n'
              '• You are responsible for maintaining the confidentiality of your account credentials\n'
              '• You must be at least 13 years old to use this service\n'
              '• One account per person is permitted\n'
              '• You must notify us immediately of any unauthorized use of your account',
            ),
            const SizedBox(height: 20),
            _sectionTitle('4. User Conduct and Responsibilities'),
            _bodyText(
              'You agree to:\n'
              '• Use the service for lawful purposes only\n'
              '• Not post or share false, misleading, or inappropriate content\n'
              '• Respect other users and community members\n'
              '• Not attempt to harm, disrupt, or interfere with the service\n'
              '• Not use automated tools to access the service excessively\n'
              '• Verify mosque information before submitting\n'
              '• Report inappropriate content or behavior',
            ),
            const SizedBox(height: 20),
            _sectionTitle('5. Content and User-Generated Content'),
            _bodyText(
              '• Users may submit mosque information, prayer times, and community announcements\n'
              '• We reserve the right to review, edit, or remove inappropriate content\n'
              '• You retain ownership of content you submit but grant us license to use it\n'
              '• Content must be accurate, relevant, and respectful\n'
              '• False or malicious submissions may result in account termination',
            ),
            const SizedBox(height: 20),
            _sectionTitle('6. Privacy and Data'),
            _bodyText(
              'Your privacy is important to us. Our collection and use of personal data is governed by our Privacy Policy, which forms part of these terms. By using Minaret, you consent to the collection and use of information as described in our Privacy Policy.',
            ),
            const SizedBox(height: 20),
            _sectionTitle('7. Intellectual Property'),
            _bodyText(
              'The Minaret application, including all content, features, and functionality, is owned by us and is protected by copyright, trademark, and other intellectual property laws. You may not copy, modify, distribute, or create derivative works without our express permission.',
            ),
            const SizedBox(height: 20),
            _sectionTitle('8. Location Services'),
            _bodyText(
              'Minaret requires location access to provide accurate prayer times and nearby mosque information. Location data is used solely for app functionality and is handled according to our Privacy Policy. You can disable location services through your device settings, though this may limit app functionality.',
            ),
            const SizedBox(height: 20),
            _sectionTitle('9. Notifications'),
            _bodyText(
              'With your permission, Minaret may send push notifications for:\n'
              '• Prayer time reminders\n'
              '• Mosque updates and announcements\n'
              '• Important service notifications\n'
              'You can manage notification preferences in the app settings.',
            ),
            const SizedBox(height: 20),
            _sectionTitle('10. Termination'),
            _bodyText(
              'We may terminate or suspend your account immediately if you breach these terms. You may also terminate your account at any time through the app settings. Upon termination, your right to use the service ceases immediately.',
            ),
            const SizedBox(height: 20),
            _sectionTitle('11. Disclaimers and Warranties'),
            _bodyText(
              'Minaret is provided "as is" without warranties of any kind. We do not guarantee:\n'
              '• 100% accuracy of prayer times (though we strive for precision)\n'
              '• Uninterrupted service availability\n'
              '• Complete accuracy of user-submitted mosque information\n'
              '• Compatibility with all devices or operating systems',
            ),
            const SizedBox(height: 20),
            _sectionTitle('12. Limitation of Liability'),
            _bodyText(
              'To the fullest extent permitted by law, Minaret shall not be liable for any indirect, incidental, special, or consequential damages resulting from your use of the service, including but not limited to errors in prayer times or missed prayers.',
            ),
            const SizedBox(height: 20),
            _sectionTitle('13. Governing Law'),
            _bodyText(
              'These terms shall be governed by and construed in accordance with applicable laws. Any disputes arising from these terms shall be resolved through appropriate legal channels.',
            ),
            const SizedBox(height: 20),
            _sectionTitle('14. Changes to Terms'),
            _bodyText(
              'We reserve the right to modify these terms at any time. Changes will be effective immediately upon posting in the app. Your continued use of the service constitutes acceptance of any modified terms.',
            ),
            const SizedBox(height: 20),
            _sectionTitle('15. Contact Information'),
            _bodyText(
              'For questions about these Terms of Service, please contact us through the app\'s support features or help section.',
            ),
            const SizedBox(height: 40),
            Center(
              child: Text(
                'Last Updated: May 2024',
                style: GoogleFonts.montserrat(
                  fontSize: 10,
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.montserrat(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: MinaretTheme.gold,
        ),
      ),
    );
  }

  Widget _bodyText(String text) {
    return Text(
      text,
      style: GoogleFonts.notoNaskhArabic(
        fontSize: 14,
        height: 1.6,
      ),
    );
  }
}
