import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/constants/app_constants.dart';
import 'core/di/app_dependencies.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/ride_provider.dart';
import 'providers/vehicle_provider.dart';

void main() {
  final dependencies = AppDependencies();
  runApp(NewCarPoolApp(dependencies: dependencies));
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
        Provider.value(value: dependencies.vehicleService),
        Provider.value(value: dependencies.bookingService),
        Provider.value(value: dependencies.paymentService),
        Provider.value(value: dependencies.notificationService),
        Provider.value(value: dependencies.profileService),
        Provider.value(value: dependencies.mapService),
        Provider.value(value: dependencies.trackingService),
        ChangeNotifierProvider(create: (_) => AuthProvider(dependencies.authService, dependencies.tokenStore)),
        ChangeNotifierProvider(create: (_) => RideProvider(dependencies.rideService)),
        ChangeNotifierProvider(create: (_) => VehicleProvider(dependencies.vehicleService)),
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
