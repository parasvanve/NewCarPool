import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_routes.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/register_screen.dart';
import '../../screens/auth/forgot_password_screen.dart';
import '../../screens/auth/splash_screen.dart';
import '../../screens/dashboard/dashboard_screen.dart';
import '../../screens/notifications/notification_screen.dart';
import '../../screens/payments/payment_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../screens/rides/booking_flow_screen.dart';
import '../../screens/rides/live_tracking_screen.dart';
import '../../screens/rides/offer_ride_screen.dart';
import '../../screens/rides/ride_details_screen.dart';
import '../../screens/rides/search_rides_screen.dart';
import '../../screens/trips/trips_screen.dart';
import '../../screens/vehicles/vehicle_screens.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: AppRoutes.splash,
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, __) => const SplashScreen()),
      GoRoute(path: AppRoutes.login, builder: (_, __) => const LoginScreen()),
      GoRoute(path: AppRoutes.register, builder: (_, __) => const RegisterScreen()),
      GoRoute(path: AppRoutes.forgotPassword, builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(path: AppRoutes.dashboard, builder: (_, __) => const DashboardScreen()),
      GoRoute(path: AppRoutes.offerRide, builder: (_, __) => const OfferRideScreen()),
      GoRoute(path: AppRoutes.searchRides, builder: (_, __) => const SearchRidesScreen()),
      GoRoute(path: AppRoutes.vehicles, builder: (_, __) => const MyVehiclesScreen()),
      GoRoute(path: AppRoutes.trips, builder: (_, __) => const TripsScreen()),
      GoRoute(path: AppRoutes.notifications, builder: (_, __) => const NotificationScreen()),
      GoRoute(path: AppRoutes.profile, builder: (_, __) => const ProfileScreen()),
      GoRoute(path: AppRoutes.payments, builder: (_, __) => const PaymentScreen()),
      GoRoute(path: AppRoutes.booking, builder: (_, __) => const BookingFlowScreen()),
      GoRoute(path: AppRoutes.tracking, builder: (_, __) => const LiveTrackingScreen()),
      GoRoute(path: AppRoutes.rideDetails, builder: (_, state) => RideDetailsScreen(extra: state.extra)),
    ],
    errorBuilder: (_, __) => const Scaffold(body: Center(child: Text('Page not found'))),
  );
}
