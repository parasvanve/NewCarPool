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
    final isWide = MediaQuery.of(context).size.width > 1024;
    final content = Container(
      constraints: const BoxConstraints(maxWidth: 560),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Color(0x16000000), blurRadius: 24, offset: Offset(0, 8))],
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
        shrinkWrap: true,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF335BFF), Color(0xFF5C4AF5)]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.local_taxi, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Text(
                AppConstants.appName,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(subtitle, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: const Color(0xFF5A647A))),
          const SizedBox(height: 20),
          ...children,
          const SizedBox(height: 14),
          Text(
            'By continuing, you agree to our Terms of Service and Privacy Policy.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B)),
          ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF1F4FF),
      body: SafeArea(
        child: isWide
            ? Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF325BFF), Color(0xFF5C4AF5)],
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(34),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.verified_user_outlined, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text('Trusted rides.\nGreat connections.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                                ],
                              ),
                              const Spacer(),
                              const Text(
                                'Your ride,\nyour way.',
                                style: TextStyle(color: Colors.white, fontSize: 56, fontWeight: FontWeight.w800, height: 1.08),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'Book rides or offer seats and\ntravel together, for less.',
                                style: TextStyle(color: Color(0xFFDDE5FF), fontSize: 29, height: 1.3),
                              ),
                              const Spacer(),
                              Wrap(
                                spacing: 24,
                                runSpacing: 10,
                                children: const [
                                  _HeroPill(icon: Icons.group_outlined, label: 'Share the ride'),
                                  _HeroPill(icon: Icons.savings_outlined, label: 'Save more'),
                                  _HeroPill(icon: Icons.shield_outlined, label: 'Travel safe'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(child: Center(child: content)),
                  ],
                ),
              )
            : Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(14),
                  child: content,
                ),
              ),
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0x22FFFFFF),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(icon, size: 18, color: Colors.white),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
