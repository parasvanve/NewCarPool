import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, this.showAppBar = true});

  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: showAppBar ? AppBar(title: const Text('Profile')) : null,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const CircleAvatar(radius: 42, child: Icon(Icons.person, size: 42)),
          const SizedBox(height: 16),
          const ListTile(leading: Icon(Icons.star), title: Text('Ratings'), subtitle: Text('Average rating appears here')),
          ListTile(leading: const Icon(Icons.garage), title: const Text('My Vehicles'), onTap: () => context.push('/vehicles')),
          ListTile(leading: const Icon(Icons.payment), title: const Text('Payments'), onTap: () => context.push('/payments')),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () async {
              await context.read<AuthProvider>().logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
    );
  }
}
