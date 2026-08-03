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

//new code
import 'core/routing/deep_link_service.dart';

void main() {
  final dependencies = AppDependencies();
  runApp(NewCarPoolApp(dependencies: dependencies));
}

// class NewCarPoolApp extends StatelessWidget {
//   const NewCarPoolApp({super.key, required this.dependencies});

//   final AppDependencies dependencies;

//   @override
//   Widget build(BuildContext context) {
//     return MultiProvider(

//new code

class NewCarPoolApp extends StatefulWidget {
  const NewCarPoolApp({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  State<NewCarPoolApp> createState() => _NewCarPoolAppState();
}

class _NewCarPoolAppState extends State<NewCarPoolApp> {
  final _deepLinkService = DeepLinkService();

  @override
  void initState() {
    super.initState();
    _deepLinkService.init();
  }

  @override
  void dispose() {
    _deepLinkService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dependencies = widget.dependencies;
    return MultiProvider(
      providers: [
        Provider.value(value: dependencies.apiClient),
        // Provider.value(value: dependencies.tokenStore),
        // Provider.value(value: dependencies.rideService),

        //new code
        Provider.value(value: dependencies.tokenStore),
        Provider.value(value: dependencies.authService),
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
