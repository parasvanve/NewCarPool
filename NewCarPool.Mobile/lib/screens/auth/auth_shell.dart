import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/widgets/app_design_system.dart';

class AuthShell extends StatelessWidget {
  const AuthShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 980;
    final content = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 540),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        shrinkWrap: true,
        children: [
          const SizedBox(height: 28),
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppDesignTokens.brandStart, AppDesignTokens.brandEnd],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.route, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Text(
                AppConstants.appName,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 40),
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 28),
          ...children,
        ],
      ),
    );

    return Scaffold(
      body: SafeArea(
        child: isWide
            ? Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppDesignTokens.brandStart, AppDesignTokens.brandEnd],
                        ),
                      ),
                      child: const Center(
                        child: Icon(Icons.local_taxi, size: 120, color: Colors.white70),
                      ),
                    ),
                  ),
                  Expanded(child: Center(child: content)),
                ],
              )
            : Center(child: content),
      ),
    );
  }
}
