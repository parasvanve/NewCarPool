import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/constants/app_constants.dart';
import 'core/di/app_dependencies.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/booking_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/offer_ride_provider.dart';
import 'providers/payment_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/ride_chat_provider.dart';
import 'providers/ride_provider.dart';
import 'providers/vehicle_provider.dart';
import 'services/ride_chat_service.dart';

import 'services/deep_link_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final dependencies = AppDependencies();

  final initialUri = await DeepLinkService.instance.getInitialLink();

  runApp(NewCarPoolApp(dependencies: dependencies));

  DeepLinkService.instance.initialize((uri) {
    AppRouter.router.go(uri.path);
  });

  if (initialUri != null) {
    AppRouter.router.go(initialUri.path);
  }
}

class NewCarPoolApp extends StatelessWidget {
  const NewCarPoolApp({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: dependencies.apiClient),
        Provider.value(value: dependencies.tokenStore),
        Provider.value(value: dependencies.rideService),
        Provider.value(value: dependencies.vehicleService),
        Provider.value(value: dependencies.bookingService),
        Provider.value(value: dependencies.paymentService),
        Provider.value(value: dependencies.notificationService),
        Provider.value(value: dependencies.profileService),
        Provider.value(value: dependencies.mapService),
        Provider.value(value: dependencies.trackingService),
        Provider(
            create: (context) =>
                RideChatService(context.read(), context.read())),
        ChangeNotifierProvider(
            create: (_) => AuthProvider(
                dependencies.authService, dependencies.tokenStore)),
        ChangeNotifierProvider(
            create: (_) => RideProvider(
                dependencies.rideService, dependencies.tokenStore)),
        ChangeNotifierProvider(
            create: (_) => VehicleProvider(dependencies.vehicleService)),
        ChangeNotifierProvider(
            create: (_) => BookingProvider(dependencies.bookingService)),
        ChangeNotifierProvider(
            create: (_) =>
                NotificationProvider(dependencies.notificationService)),
        ChangeNotifierProvider(
            create: (_) => PaymentProvider(dependencies.paymentService)),
        ChangeNotifierProvider(
            create: (_) => ProfileProvider(dependencies.profileService)),
        ChangeNotifierProvider(
            create: (_) => OfferRideProvider(dependencies.mapService)),
        ChangeNotifierProvider(
            create: (context) => RideChatProvider(context.read())),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: AppConstants.appName,
        theme: AppTheme.light(),
        routerConfig: AppRouter.router,
      ),
    );
  }
}
