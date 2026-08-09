// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/notification_provider.dart';

// class AppDesignTokens {
//   static const brandStart = Color(0xFF5B5DFF);
//   static const brandEnd = Color(0xFF7A7CFF);
//   static const pageBg = Color(0xFFF7F8FF);
// }

// class AppGradientHeroCard extends StatelessWidget {
//   const AppGradientHeroCard({
//     super.key,
//     required this.title,
//     required this.subtitle,
//     required this.icon,
//   });

//   final String title;
//   final String subtitle;
//   final IconData icon;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(18),
//       decoration: BoxDecoration(
//         gradient: const LinearGradient(
//           colors: [AppDesignTokens.brandStart, AppDesignTokens.brandEnd],
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//         ),
//         borderRadius: BorderRadius.circular(20),
//         boxShadow: const [
//           BoxShadow(
//             color: Color(0x305B5DFF),
//             blurRadius: 20,
//             offset: Offset(0, 8),
//           ),
//         ],
//       ),
//       child: Row(
//         children: [
//           Container(
//             width: 42,
//             height: 42,
//             decoration: BoxDecoration(
//               color: Colors.white.withOpacity(0.2),
//               borderRadius: BorderRadius.circular(12),
//             ),
//             child: Icon(icon, color: Colors.white),
//           ),
//           const SizedBox(width: 12),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   title,
//                   style: Theme.of(context).textTheme.titleLarge?.copyWith(
//                         color: Colors.white,
//                         fontWeight: FontWeight.w800,
//                       ),
//                 ),
//                 const SizedBox(height: 2),
//                 Text(
//                   subtitle,
//                   style: Theme.of(context).textTheme.bodySmall?.copyWith(
//                         color: Colors.white.withOpacity(0.9),
//                       ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class AppSectionHeader extends StatelessWidget {
//   const AppSectionHeader({
//     super.key,
//     required this.title,
//     this.actionText,
//     this.onAction,
//   });

//   final String title;
//   final String? actionText;
//   final VoidCallback? onAction;

//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//       children: [
//         Text(
//           title,
//           style: Theme.of(context).textTheme.titleLarge?.copyWith(
//                 fontWeight: FontWeight.w700,
//               ),
//         ),
//         if (actionText != null)
//           TextButton(onPressed: onAction, child: Text(actionText!)),
//       ],
//     );
//   }
// }

// class AppQuickActionTile extends StatelessWidget {
//   const AppQuickActionTile({
//     super.key,
//     required this.icon,
//     required this.label,
//     required this.onTap,
//   });

//   final IconData icon;
//   final String label;
//   final VoidCallback onTap;

//   @override
//   Widget build(BuildContext context) {
//     return InkWell(
//       onTap: onTap,
//       borderRadius: BorderRadius.circular(14),
//       child: Ink(
//         padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(14),
//           border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
//         ),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Container(
//               width: 36,
//               height: 36,
//               decoration: BoxDecoration(
//                 color: const Color(0xFFEEF0FF),
//                 borderRadius: BorderRadius.circular(10),
//               ),
//               child: Icon(icon, color: AppDesignTokens.brandStart, size: 20),
//             ),
//             const SizedBox(height: 8),
//             Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class AppBottomNav extends StatelessWidget {
//   const AppBottomNav({
//     super.key,
//     required this.index,
//     required this.onChanged,
//   });

//   final int index;
//   final ValueChanged<int> onChanged;

//   @override
//   Widget build(BuildContext context) {
//     final unread = context.watch<NotificationProvider>().unreadCountValue;
//     return NavigationBar(
//       selectedIndex: index,
//       onDestinationSelected: onChanged,
//       height: 68,
//       backgroundColor: Colors.white,
//       destinations: [
//         const NavigationDestination(
//           icon: Icon(Icons.home_outlined),
//           selectedIcon: Icon(Icons.home),
//           label: 'Home',
//         ),
//         const NavigationDestination(
//           icon: Icon(Icons.route_outlined),
//           selectedIcon: Icon(Icons.route),
//           label: 'Trips',
//         ),
//         NavigationDestination(
//           icon: Stack(
//             clipBehavior: Clip.none,
//             children: [
//               const Icon(Icons.notifications_outlined),
//               if (unread > 0)
//                 Positioned(
//                   right: -5,
//                   top: -4,
//                   child: Container(
//                     padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
//                     decoration: BoxDecoration(
//                       color: Colors.red,
//                       borderRadius: BorderRadius.circular(10),
//                     ),
//                     constraints: const BoxConstraints(minWidth: 14),
//                     child: Text(
//                       unread > 99 ? '99+' : '$unread',
//                       style: const TextStyle(
//                         color: Colors.white,
//                         fontSize: 9,
//                         fontWeight: FontWeight.w700,
//                       ),
//                       textAlign: TextAlign.center,
//                     ),
//                   ),
//                 ),
//             ],
//           ),
//           selectedIcon: const Icon(Icons.notifications),
//           label: 'Alerts',
//         ),
//         const NavigationDestination(
//           icon: Icon(Icons.person_outline),
//           selectedIcon: Icon(Icons.person),
//           label: 'Profile',
//         ),
//       ],
//     );
//   }
// }

// class AppMapControls extends StatelessWidget {
//   const AppMapControls({
//     super.key,
//     required this.onZoomIn,
//     required this.onZoomOut,
//     required this.onRecenter,
//   });

//   final VoidCallback onZoomIn;
//   final VoidCallback onZoomOut;
//   final VoidCallback onRecenter;

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         _MapActionFab(icon: Icons.add, onTap: onZoomIn),
//         const SizedBox(height: 8),
//         _MapActionFab(
//           icon: Icons.remove,
//           onTap: onZoomOut,
//           outlined: true,
//         ),
//         const SizedBox(height: 8),
//         _MapActionFab(icon: Icons.gps_fixed, onTap: onRecenter),
//       ],
//     );
//   }
// }

// class AppSkeletonBox extends StatefulWidget {
//   const AppSkeletonBox({
//     super.key,
//     this.height = 16,
//     this.width,
//     this.radius = 10,
//     this.margin,
//   });

//   final double height;
//   final double? width;
//   final double radius;
//   final EdgeInsetsGeometry? margin;

//   @override
//   State<AppSkeletonBox> createState() => _AppSkeletonBoxState();
// }

// class _AppSkeletonBoxState extends State<AppSkeletonBox>
//     with SingleTickerProviderStateMixin {
//   late final AnimationController _controller;

//   @override
//   void initState() {
//     super.initState();
//     _controller = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 1200),
//     )..repeat(reverse: true);
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return AnimatedBuilder(
//       animation: _controller,
//       builder: (context, _) {
//         final t = _controller.value;
//         final color = Color.lerp(
//           const Color(0xFFE8ECFF),
//           const Color(0xFFF5F7FF),
//           t,
//         )!;
//         return Container(
//           width: widget.width,
//           height: widget.height,
//           margin: widget.margin,
//           decoration: BoxDecoration(
//             color: color,
//             borderRadius: BorderRadius.circular(widget.radius),
//           ),
//         );
//       },
//     );
//   }
// }

// class AppRetryState extends StatelessWidget {
//   const AppRetryState({
//     super.key,
//     required this.title,
//     required this.subtitle,
//     required this.onRetry,
//   });

//   final String title;
//   final String subtitle;
//   final VoidCallback onRetry;

//   @override
//   Widget build(BuildContext context) {
//     return Center(
//       child: Padding(
//         padding: const EdgeInsets.all(24),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             const Icon(Icons.cloud_off_rounded, size: 50, color: Colors.grey),
//             const SizedBox(height: 12),
//             Text(title, style: Theme.of(context).textTheme.titleMedium),
//             const SizedBox(height: 4),
//             Text(subtitle, textAlign: TextAlign.center),
//             const SizedBox(height: 12),
//             FilledButton.icon(
//               onPressed: onRetry,
//               icon: const Icon(Icons.refresh),
//               label: const Text('Retry'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class _MapActionFab extends StatelessWidget {
//   const _MapActionFab({
//     required this.icon,
//     required this.onTap,
//     this.outlined = false,
//   });

//   final IconData icon;
//   final VoidCallback onTap;
//   final bool outlined;

//   @override
//   Widget build(BuildContext context) {
//     return FloatingActionButton.small(
//       heroTag: null,
//       onPressed: onTap,
//       backgroundColor: outlined ? Colors.white : AppDesignTokens.brandStart,
//       foregroundColor: outlined ? AppDesignTokens.brandStart : Colors.white,
//       child: Icon(icon),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/notification_provider.dart';

class AppDesignTokens {
  static const brandStart = Color(0xFF5B5DFF);
  static const brandEnd = Color(0xFF7A7CFF);
  static const pageBg = Color(0xFFF7F8FF);

  // ---- Adaptive tokens (use these instead of hardcoded Colors.white etc) ----
  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Page/scaffold background
  static Color pageBackground(BuildContext context) =>
      _isDark(context) ? const Color(0xFF121212) : const Color(0xFFF7F8FC);

  /// Card / sidebar / raised surface background
  static Color surface(BuildContext context) =>
      _isDark(context) ? const Color(0xFF1E1E1E) : Colors.white;

  /// Muted/secondary surface (e.g. info boxes)
  static Color surfaceMuted(BuildContext context) =>
      _isDark(context) ? const Color(0xFF262626) : const Color(0xFFF8FAFF);

  /// Hairline border color
  static Color borderColor(BuildContext context) =>
      _isDark(context) ? const Color(0xFF333333) : const Color(0xFFE2E8F0);

  /// Primary text color
  static Color textPrimary(BuildContext context) =>
      _isDark(context) ? Colors.white : const Color(0xFF0F172A);

  /// Secondary/muted text color
  static Color textSecondary(BuildContext context) =>
      _isDark(context) ? const Color(0xFFA0A0A0) : const Color(0xFF64748B);

  /// Selected/highlighted chip background (nav items, filters)
  static Color chipSelectedBg(BuildContext context) =>
      _isDark(context) ? const Color(0xFF2A2A55) : const Color(0xFFE7EAFE);
}

class AppGradientHeroCard extends StatelessWidget {
  const AppGradientHeroCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppDesignTokens.brandStart, AppDesignTokens.brandEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x305B5DFF),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withOpacity(0.9),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    this.actionText,
    this.onAction,
  });

  final String title;
  final String? actionText;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        if (actionText != null)
          TextButton(onPressed: onAction, child: Text(actionText!)),
      ],
    );
  }
}

class AppQuickActionTile extends StatelessWidget {
  const AppQuickActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFEEF0FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppDesignTokens.brandStart, size: 20),
            ),
            const SizedBox(height: 8),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.index,
    required this.onChanged,
  });

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final unread = context.watch<NotificationProvider>().unreadCountValue;
    return NavigationBar(
      selectedIndex: index,
      onDestinationSelected: onChanged,
      height: 68,
      backgroundColor: Colors.white,
      destinations: [
        const NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Home',
        ),
        const NavigationDestination(
          icon: Icon(Icons.route_outlined),
          selectedIcon: Icon(Icons.route),
          label: 'Trips',
        ),
        NavigationDestination(
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_outlined),
              if (unread > 0)
                Positioned(
                  right: -5,
                  top: -4,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(minWidth: 14),
                    child: Text(
                      unread > 99 ? '99+' : '$unread',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          selectedIcon: const Icon(Icons.notifications),
          label: 'Alerts',
        ),
        const NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }
}

class AppMapControls extends StatelessWidget {
  const AppMapControls({
    super.key,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onRecenter,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onRecenter;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MapActionFab(icon: Icons.add, onTap: onZoomIn),
        const SizedBox(height: 8),
        _MapActionFab(
          icon: Icons.remove,
          onTap: onZoomOut,
          outlined: true,
        ),
        const SizedBox(height: 8),
        _MapActionFab(icon: Icons.gps_fixed, onTap: onRecenter),
      ],
    );
  }
}

class AppSkeletonBox extends StatefulWidget {
  const AppSkeletonBox({
    super.key,
    this.height = 16,
    this.width,
    this.radius = 10,
    this.margin,
  });

  final double height;
  final double? width;
  final double radius;
  final EdgeInsetsGeometry? margin;

  @override
  State<AppSkeletonBox> createState() => _AppSkeletonBoxState();
}

class _AppSkeletonBoxState extends State<AppSkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final color = Color.lerp(
          const Color(0xFFE8ECFF),
          const Color(0xFFF5F7FF),
          t,
        )!;
        return Container(
          width: widget.width,
          height: widget.height,
          margin: widget.margin,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        );
      },
    );
  }
}

class AppRetryState extends StatelessWidget {
  const AppRetryState({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onRetry,
  });

  final String title;
  final String subtitle;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 50, color: Colors.grey),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(subtitle, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapActionFab extends StatelessWidget {
  const _MapActionFab({
    required this.icon,
    required this.onTap,
    this.outlined = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      heroTag: null,
      onPressed: onTap,
      backgroundColor: outlined ? Colors.white : AppDesignTokens.brandStart,
      foregroundColor: outlined ? AppDesignTokens.brandStart : Colors.white,
      child: Icon(icon),
    );
  }
}
