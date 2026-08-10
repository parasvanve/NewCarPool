import 'package:flutter/material.dart';

import '../../core/widgets/app_design_system.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignTokens.pageBackground(context),
      appBar: AppBar(title: const Text('About Us')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              const AppGradientHeroCard(
                title: 'About NewCarPool',
                subtitle: 'Ride sharing made simple',
                icon: Icons.info_outline,
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'NewCarPool connects drivers and riders heading the '
                        'same way, making everyday commutes cheaper, greener '
                        'and more social.',
                      ),
                      const SizedBox(height: 12),
                      const Text('App version: 1.0.0',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.description_outlined),
                      title: const Text('Terms of Service'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {},
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.language),
                      title: const Text('Visit our website'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
