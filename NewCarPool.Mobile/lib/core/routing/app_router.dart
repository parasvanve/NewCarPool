import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_routes.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/register_screen.dart';
import '../../screens/auth/onboarding_screen.dart';
import '../../screens/auth/forgot_password_screen.dart';
import '../../screens/auth/splash_screen.dart';
import '../../screens/dashboard/dashboard_screen.dart';
import '../../screens/notifications/notification_screen.dart';
import '../../screens/payments/payment_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../screens/profile/settings_screen.dart';
import '../../screens/profile/help_support_screen.dart';
import '../../screens/rides/booking_flow_screen.dart';
import '../../screens/rides/driver_requests_screen.dart';
import '../../screens/rides/live_tracking_screen.dart';
import '../../screens/rides/offer_ride_form_screen.dart';
import '../../screens/rides/ride_details_screen.dart';
import '../../screens/rides/search_ride_form_screen.dart';
import '../../screens/trips/trips_screen.dart';
import '../../screens/vehicles/vehicle_screens.dart';

//new code
import '../../screens/rides/shared_ride_preview_screen.dart';

class AppRouter {
  static CustomTransitionPage<void> _fadeSlidePage(Widget child) {
    return CustomTransitionPage<void>(
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final fade =
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        final slide = Tween<Offset>(
          begin: const Offset(0.04, 0),
          end: Offset.zero,
        ).animate(fade);
        return FadeTransition(
          opacity: fade,
          child: SlideTransition(position: slide, child: child),
        );
      },
    );
  }

  static final router = GoRouter(
    initialLocation: AppRoutes.splash,
    routes: [
      GoRoute(
          path: AppRoutes.splash,
          pageBuilder: (_, __) => _fadeSlidePage(const SplashScreen())),
      GoRoute(
          path: AppRoutes.login,
          pageBuilder: (_, __) => _fadeSlidePage(const LoginScreen())),
      GoRoute(
          path: AppRoutes.register,
          pageBuilder: (_, __) => _fadeSlidePage(const RegisterScreen())),
      GoRoute(
          path: AppRoutes.onboarding,
          pageBuilder: (_, __) => _fadeSlidePage(const OnboardingScreen())),
      GoRoute(
          path: AppRoutes.forgotPassword,
          pageBuilder: (_, __) => _fadeSlidePage(const ForgotPasswordScreen())),
      GoRoute(
          path: AppRoutes.dashboard,
          pageBuilder: (_, __) => _fadeSlidePage(const DashboardScreen())),
      GoRoute(
          path: AppRoutes.offerRide,
          pageBuilder: (_, __) => _fadeSlidePage(const OfferRideFormScreen())),
      GoRoute(
          path: AppRoutes.searchRides,
          pageBuilder: (_, __) => _fadeSlidePage(const SearchRideFormScreen())),
      GoRoute(
          path: AppRoutes.vehicles,
          pageBuilder: (_, __) => _fadeSlidePage(const MyVehiclesScreen())),
      GoRoute(
          path: AppRoutes.trips,
          pageBuilder: (_, __) => _fadeSlidePage(const TripsScreen())),
      GoRoute(
          path: AppRoutes.notifications,
          pageBuilder: (_, __) =>
              _fadeSlidePage(const NotificationScreen(showAppBar: false))),
      GoRoute(
          path: AppRoutes.profile,
          pageBuilder: (_, __) => _fadeSlidePage(const ProfileScreen())),
      GoRoute(
          path: AppRoutes.payments,
          pageBuilder: (_, __) => _fadeSlidePage(const PaymentScreen())),
      GoRoute(
          path: AppRoutes.settings,
          pageBuilder: (_, __) => _fadeSlidePage(const SettingsScreen())),
      GoRoute(
          path: AppRoutes.helpSupport,
          pageBuilder: (_, __) => _fadeSlidePage(const HelpSupportScreen())),
      GoRoute(
          path: AppRoutes.booking,
          pageBuilder: (_, state) =>
              _fadeSlidePage(BookingFlowScreen(extra: state.extra))),
      GoRoute(
          path: AppRoutes.driverRequests,
          pageBuilder: (_, __) => _fadeSlidePage(const DriverRequestsScreen())),
      GoRoute(
          path: AppRoutes.tracking,
          pageBuilder: (_, __) => _fadeSlidePage(const LiveTrackingScreen())),
      //   GoRoute(
      //       path: AppRoutes.rideDetails,
      //       pageBuilder: (_, state) => _fadeSlidePage(RideDetailsScreen(extra: state.extra))),
      // ],

      //new code
      GoRoute(
          path: AppRoutes.rideDetails,
          pageBuilder: (_, state) =>
              _fadeSlidePage(RideDetailsScreen(extra: state.extra))),
      GoRoute(
          path: AppRoutes.sharedRide,
          pageBuilder: (_, state) => _fadeSlidePage(
              SharedRidePreviewScreen(rideId: state.pathParameters['id']!))),
    ],
    errorBuilder: (_, __) =>
        const Scaffold(body: Center(child: Text('Page not found'))),
  );
}
