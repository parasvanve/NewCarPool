import 'package:flutter/material.dart';

import '../../core/widgets/app_design_system.dart';

class PrivacySecurityScreen extends StatelessWidget {
  const PrivacySecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignTokens.pageBackground(context),
      appBar: AppBar(title: const Text('Privacy & Security')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              const AppGradientHeroCard(
                title: 'Privacy & Security',
                subtitle: 'How we protect your data',
                icon: Icons.privacy_tip_outlined,
              ),
              const SizedBox(height: 12),
              const _InfoCard(
                title: 'Data We Collect',
                body: 'We collect your name, contact details, ride history and '
                    'location data only while you are using ride or tracking '
                    'features, to match drivers and riders and keep trips safe.',
              ),
              const _InfoCard(
                title: 'How We Use It',
                body: 'Your data is used to run bookings, send ride alerts, '
                    'process payments and improve safety features such as '
                    'live tracking.',
              ),
              const _InfoCard(
                title: 'Account Security',
                body: 'Your session is protected with encrypted tokens. Use a '
                    'strong password and avoid sharing OTPs with anyone.',
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.mail_outline),
                  title: const Text('Privacy Questions'),
                  subtitle: const Text('privacy@carpool.com'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(body),
          ],
        ),
      ),
    );
  }
}
