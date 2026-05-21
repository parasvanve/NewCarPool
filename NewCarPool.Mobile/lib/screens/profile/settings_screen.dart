import 'package:flutter/material.dart';

import '../../core/widgets/app_design_system.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _darkModePlaceholder = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignTokens.pageBg,
      appBar: AppBar(title: const Text('Settings')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              const AppGradientHeroCard(
                title: 'App Settings',
                subtitle: 'Preferences, privacy and account controls',
                icon: Icons.settings,
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      value: _darkModePlaceholder,
                      onChanged: (v) => setState(() => _darkModePlaceholder = v),
                      title: const Text('Dark Mode (Placeholder)'),
                      subtitle: const Text('Theme switching will be enabled soon'),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      value: _notificationsEnabled,
                      onChanged: (v) => setState(() => _notificationsEnabled = v),
                      title: const Text('Notifications'),
                      subtitle: const Text('Ride alerts and booking updates'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Card(
                child: Column(
                  children: const [
                    _SettingsTile(icon: Icons.privacy_tip_outlined, title: 'Privacy & Security'),
                    Divider(height: 1),
                    _SettingsTile(icon: Icons.info_outline, title: 'About Us'),
                    Divider(height: 1),
                    _SettingsTile(icon: Icons.logout, title: 'Logout', danger: true),
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

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? Colors.red : null;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color)),
      trailing: Icon(Icons.chevron_right, color: color),
    );
  }
}
