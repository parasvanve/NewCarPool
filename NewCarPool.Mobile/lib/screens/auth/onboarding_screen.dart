import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/app_routes.dart';
import '../../providers/auth_provider.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  bool get _isLast => _index == 2;

  Future<void> _finish() async {
    await context.read<AuthProvider>().markOnboardingSeen();
    if (!mounted) return;
    context.go(AppRoutes.dashboard);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            final illustrationHeight = (c.maxHeight * 0.47).clamp(300.0, 430.0);
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 2),
                  child: Row(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: const LinearGradient(colors: [Color(0xFF2F5BFF), Color(0xFF6A4BF7)]),
                            ),
                            child: const Icon(Icons.local_taxi, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            AppConstants.appName,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 31),
                          ),
                        ],
                      ),
                      const Spacer(),
                      TextButton(onPressed: _finish, child: const Text('Skip', style: TextStyle(fontSize: 18))),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _controller,
                    onPageChanged: (v) => setState(() => _index = v),
                    children: [
                      _PageFrame(
                        illustrationHeight: illustrationHeight,
                        title: 'Search and Book Rides',
                        subtitle: 'Find rides that match your route and book in a few taps.',
                        illustration: const _SearchRideIllustration(),
                      ),
                      _PageFrame(
                        illustrationHeight: illustrationHeight,
                        title: 'Offer Your Own Ride',
                        subtitle: 'Add pickup, destination, stop points, seats, and price.',
                        illustration: const _OfferRideIllustration(),
                      ),
                      _PageFrame(
                        illustrationHeight: illustrationHeight,
                        title: 'Chat, Live Tracking,\nand Notifications',
                        subtitle: 'Chat with driver or passenger, track rides live, and get booking or cancellation alerts.',
                        illustration: const _ChatTrackIllustration(),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      3,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _index == i ? 22 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _index == i ? const Color(0xFF315CFF) : const Color(0xFFD6DDF8),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
                  child: SizedBox(
                    height: 60,
                    width: double.infinity,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: const LinearGradient(colors: [Color(0xFF2F5BFF), Color(0xFF5D4AF5)]),
                        boxShadow: const [BoxShadow(color: Color(0x2A3F58C7), blurRadius: 18, offset: Offset(0, 8))],
                      ),
                      child: FilledButton.icon(
                        onPressed: () async {
                          if (_isLast) {
                            await _finish();
                          } else {
                            await _controller.nextPage(duration: const Duration(milliseconds: 220), curve: Curves.easeOutCubic);
                          }
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        ),
                        icon: const Icon(Icons.arrow_forward, color: Colors.white),
                        label: Text(
                          _isLast ? 'Get Started' : (_index == 0 ? 'Continue' : 'Next'),
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PageFrame extends StatelessWidget {
  const _PageFrame({
    required this.illustrationHeight,
    required this.title,
    required this.subtitle,
    required this.illustration,
  });

  final double illustrationHeight;
  final String title;
  final String subtitle;
  final Widget illustration;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Column(
        children: [
          SizedBox(height: illustrationHeight, child: illustration),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 39, fontWeight: FontWeight.w800, height: 1.08),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, color: Color(0xFF5D6881), height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchRideIllustration extends StatelessWidget {
  const _SearchRideIllustration();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF2F6FF), Color(0xFFE5EDFF)],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _MapGridPainter()),
          ),
          Positioned(
            top: 28,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Color(0x17000000), blurRadius: 16, offset: Offset(0, 6))],
              ),
              child: const Row(
                children: [
                  Icon(Icons.alt_route, color: Color(0xFF315CFF)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Downtown → Airport', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        SizedBox(height: 2),
                        Text('Today, 9:30 AM • 3 seats left', style: TextStyle(color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                  Text('₹120', style: TextStyle(color: Color(0xFF2F5BFF), fontWeight: FontWeight.w800, fontSize: 18)),
                ],
              ),
            ),
          ),
          Positioned(
            top: 122,
            left: 28,
            right: 26,
            bottom: 26,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Container(
                color: Colors.white.withValues(alpha: 0.75),
                child: Stack(
                  children: [
                    Positioned.fill(child: CustomPaint(painter: _RoutePainter())),
                    const Positioned(left: 34, bottom: 52, child: _Pin(color: Color(0xFF16A34A), icon: Icons.trip_origin)),
                    const Positioned(right: 38, top: 58, child: _Pin(color: Color(0xFFEF4444), icon: Icons.location_on)),
                    Positioned(
                      bottom: 8,
                      right: 18,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: const [BoxShadow(color: Color(0x16000000), blurRadius: 10)],
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.directions_car, color: Color(0xFF315CFF)),
                            SizedBox(width: 6),
                            Text('Ride found'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfferRideIllustration extends StatelessWidget {
  const _OfferRideIllustration();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF1F4FF), Color(0xFFE0E9FF)],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _MapGridPainter())),
          Positioned.fill(child: CustomPaint(painter: _OfferRoutePainter())),
          const Positioned(left: 36, bottom: 60, child: _Pin(color: Color(0xFF16A34A), icon: Icons.trip_origin)),
          const Positioned(left: 148, top: 130, child: _Pin(color: Color(0xFF6366F1), icon: Icons.radio_button_checked)),
          const Positioned(right: 94, top: 90, child: _Pin(color: Color(0xFF6366F1), icon: Icons.radio_button_checked)),
          const Positioned(right: 32, top: 40, child: _Pin(color: Color(0xFFEF4444), icon: Icons.location_on)),
          const Positioned(top: 24, left: 24, child: _ChipLabel('Pickup')),
          const Positioned(top: 24, right: 26, child: _ChipLabel('Destination')),
          const Positioned(bottom: 86, left: 24, child: _ChipLabel('Add stop')),
          const Positioned(bottom: 22, left: 20, child: _ChipLabel('3 seats available')),
          const Positioned(bottom: 22, right: 20, child: _ChipLabel('Your price ₹100')),
          Positioned(
            left: 0,
            right: 0,
            bottom: 6,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: const [BoxShadow(color: Color(0x15000000), blurRadius: 12)],
                ),
                child: const Icon(Icons.directions_car, color: Color(0xFF315CFF), size: 28),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatTrackIllustration extends StatelessWidget {
  const _ChatTrackIllustration();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF2F5FF), Color(0xFFE8EEFF)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 22,
            right: 22,
            top: 26,
            bottom: 24,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Stack(
                children: [
                  Positioned.fill(child: CustomPaint(painter: _MapGridPainter())),
                  Positioned.fill(child: CustomPaint(painter: _RoutePainter())),
                  const Positioned(left: 28, top: 22, child: _ChatBubble(text: 'Hi, I’m on my way.', alignEnd: false)),
                  const Positioned(right: 20, top: 72, child: _ChatBubble(text: 'Great! See you soon.', alignEnd: true)),
                  Positioned(
                    top: 130,
                    left: 38,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [BoxShadow(color: Color(0x16000000), blurRadius: 10)],
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.notifications_active, color: Color(0xFF325BFF), size: 18),
                          SizedBox(width: 6),
                          Text('Booking Confirmed', style: TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 22,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF315CFF), Color(0xFF6A4BF7)]),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.route, color: Colors.white, size: 16),
                          SizedBox(width: 6),
                          Text('2.4 km • 7 min', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 58,
                    child: Center(
                      child: _Pin(color: Color(0xFF315CFF), icon: Icons.directions_car),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFFDDE5FB)
      ..strokeWidth = 1.2;
    const step = 34.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.18, size.height * 0.76)
      ..quadraticBezierTo(size.width * 0.32, size.height * 0.72, size.width * 0.42, size.height * 0.58)
      ..quadraticBezierTo(size.width * 0.54, size.height * 0.40, size.width * 0.62, size.height * 0.33)
      ..quadraticBezierTo(size.width * 0.76, size.height * 0.22, size.width * 0.83, size.height * 0.15);
    final paint = Paint()
      ..shader = const LinearGradient(colors: [Color(0xFF325BFF), Color(0xFF6A4BF7)]).createShader(Offset.zero & size)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 7;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _OfferRoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFF355BFF)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 6;
    final path = Path()
      ..moveTo(size.width * 0.16, size.height * 0.78)
      ..lineTo(size.width * 0.30, size.height * 0.68)
      ..lineTo(size.width * 0.40, size.height * 0.54)
      ..lineTo(size.width * 0.58, size.height * 0.42)
      ..lineTo(size.width * 0.70, size.height * 0.30)
      ..lineTo(size.width * 0.86, size.height * 0.20);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Pin extends StatelessWidget {
  const _Pin({required this.color, required this.icon});
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 6)],
      ),
      child: Icon(icon, size: 16, color: Colors.white),
    );
  }
}

class _ChipLabel extends StatelessWidget {
  const _ChipLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Color(0x16000000), blurRadius: 10)],
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.text, required this.alignEnd});
  final String text;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: alignEnd ? const Color(0xFFEEF2FF) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 8)],
      ),
      child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}

