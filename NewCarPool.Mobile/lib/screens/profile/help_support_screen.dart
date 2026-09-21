import 'package:flutter/material.dart';

import '../../core/widgets/app_design_system.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_constants.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignTokens.pageBackground(context),
      appBar: AppBar(title: const Text('Help & Support')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              const AppGradientHeroCard(
                title: 'Need Help?',
                subtitle: 'Find quick answers and contact support',
                icon: Icons.support_agent,
              ),
              const SizedBox(height: 12),
              const _FaqCard(
                question: 'How to cancel a booking?',
                answer: 'Open My Trips > select booking > Cancel.',
              ),
              const _FaqCard(
                question: 'How to add a vehicle?',
                answer: 'Go to Profile > My Vehicles > Add Vehicle.',
              ),
              const _FaqCard(
                question: 'When do I get ride confirmation?',
                answer: 'You will receive a realtime notification.',
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.email_outlined),
                  title: const Text('Contact Support'),
                  subtitle: const Text('support@carpool.com'),
                  trailing: const Icon(Icons.chevron_right),
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.call_outlined),
                  title: const Text('Call Us (Toll-Free)'),
                  subtitle: const Text(AppConstants.tollFreeSupportNumber),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => launchUrl(Uri(
                      scheme: 'tel', path: AppConstants.tollFreeSupportNumber)),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.report_gmailerrorred),
                label: const Text('Report an Issue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FaqCard extends StatelessWidget {
  const _FaqCard({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.help_outline),
        title: Text(question),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Text(answer),
          ),
        ],
      ),
    );
  }
}
