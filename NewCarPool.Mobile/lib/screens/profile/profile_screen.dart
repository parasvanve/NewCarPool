import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_routes.dart';
import '../../core/widgets/app_design_system.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../providers/profile_provider.dart';

//new code
import 'widgets/edit_profile_dialog.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.showAppBar = true});

  final bool showAppBar;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProfileProvider>().loadProfile();
    });
  }

  // Future<void> _editProfile() async {
  //   final provider = context.read<ProfileProvider>();
  //   final profile = provider.profile;
  //   if (profile == null) return;

  //   final nameCtrl = TextEditingController(text: profile.fullName);
  //   final phoneCtrl = TextEditingController(text: profile.phoneNumber);
  //   final result = await showDialog<bool>(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       title: const Text('Edit Profile'),
  //       content: Column(
  //         mainAxisSize: MainAxisSize.min,
  //         children: [
  //           TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Name')),
  //           const SizedBox(height: 8),
  //           TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone Number')),
  //         ],
  //       ),
  //       actions: [
  //         TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
  //         FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
  //       ],
  //     ),
  //   );

  //   if (result == true) {
  //     await provider.update(nameCtrl.text.trim(), phoneCtrl.text.trim());
  //   }
  // }

  //new code
  Future<void> _editProfile() async {
    final provider = context.read<ProfileProvider>();
    final profile = provider.profile;
    if (profile == null) return;

    final result = await showDialog<EditProfileResult>(
      context: context,
      builder: (_) => EditProfileDialog(
        initialName: profile.fullName,
        initialPhone: profile.phoneNumber,
      ),
    );

    if (result == null) return;

    try {
      await provider.update(result.fullName, result.phoneNumber);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
      if (context.mounted && provider.profile != null) {
        context.read<AuthProvider>().syncFromProfile(provider.profile!);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Could not update profile: ${provider.errorMessage ?? error.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProfileProvider>();
    final bookingCount = context.watch<BookingProvider>().bookings.length;
    final profile = provider.profile;

    return Scaffold(
      backgroundColor: AppDesignTokens.pageBg,
      appBar: widget.showAppBar ? AppBar(title: const Text('Profile')) : null,
      body: provider.isLoading && profile == null
          ? const Center(child: CircularProgressIndicator())
          : profile == null
              ? Center(
                  child: FilledButton(
                    onPressed: () =>
                        context.read<ProfileProvider>().loadProfile(),
                    child: const Text('Retry'),
                  ),
                )
              : Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        AppGradientHeroCard(
                          title: profile.fullName,
                          subtitle: profile.email,
                          icon: Icons.person,
                        ),
                        const SizedBox(height: 12),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 34,
                                  child: Text(profile.fullName.isEmpty
                                      ? 'U'
                                      : profile.fullName[0].toUpperCase()),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(profile.fullName,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 18)),
                                      Text(profile.phoneNumber),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          const Icon(Icons.star,
                                              size: 16, color: Colors.amber),
                                          const SizedBox(width: 4),
                                          Text(
                                              '${profile.rating.toStringAsFixed(1)}'),
                                          const SizedBox(width: 10),
                                          const Icon(Icons.directions_car,
                                              size: 16),
                                          const SizedBox(width: 4),
                                          Text('$bookingCount rides'),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Card(
                          child: Column(
                            children: [
                              _ProfileTile(
                                  icon: Icons.edit_outlined,
                                  title: 'Edit Profile',
                                  onTap: _editProfile),
                              const Divider(height: 1),
                              _ProfileTile(
                                  icon: Icons.garage_outlined,
                                  title: 'My Vehicles',
                                  onTap: () =>
                                      context.push(AppRoutes.vehicles)),
                              const Divider(height: 1),
                              _ProfileTile(
                                  icon: Icons.payments_outlined,
                                  title: 'Payment Methods',
                                  onTap: () =>
                                      context.push(AppRoutes.payments)),
                              const Divider(height: 1),
                              _ProfileTile(
                                  icon: Icons.settings_outlined,
                                  title: 'Settings',
                                  onTap: () =>
                                      context.push(AppRoutes.settings)),
                              const Divider(height: 1),
                              _ProfileTile(
                                  icon: Icons.help_outline,
                                  title: 'Help & Support',
                                  onTap: () =>
                                      context.push(AppRoutes.helpSupport)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text('Saved Locations',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w700)),
                                SizedBox(height: 8),
                                Chip(label: Text('Home')),
                                SizedBox(height: 8),
                                Chip(label: Text('Work')),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () async {
                            await context.read<AuthProvider>().logout();
                            if (context.mounted) context.go('/login');
                          },
                          icon: const Icon(Icons.logout),
                          label: const Text('Logout'),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
