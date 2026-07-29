import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_routes.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _routeNext();
  }

  Future<void> _routeNext() async {
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    context.go(AppRoutes.login);

    final authProvider = context.read<AuthProvider>();
    final hasStoredSession = await authProvider.restoreSessionFromStorage();
    if (!mounted) return;
    if (!hasStoredSession) {
      context.go(AppRoutes.login);
      return;
    }

    try {
      await context.read<ProfileProvider>().loadProfile();
      final profile = context.read<ProfileProvider>().profile;
      if (profile != null) {
        authProvider.syncFromProfile(profile);
      }
      if (!mounted) return;
      context.go(AppRoutes.dashboard);
    } catch (_) {
      await authProvider.logout();
      if (!mounted) return;
      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.route, color: Colors.white, size: 34),
            ),
            const SizedBox(height: 16),
            const Text(AppConstants.appName,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const SizedBox(width: 120, child: LinearProgressIndicator()),
          ],
        ),
      ),
    );
  }
}
