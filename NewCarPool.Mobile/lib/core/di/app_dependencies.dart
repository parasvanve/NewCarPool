import '../../services/auth_service.dart';
import '../../services/booking_service.dart';
import '../../services/map_service.dart';
import '../../services/notification_service.dart';
import '../../services/payment_service.dart';
import '../../services/profile_service.dart';
import '../../services/ride_service.dart';
import '../../services/tracking_service.dart';
import '../../services/vehicle_service.dart';
import '../network/api_client.dart';
import '../network/token_store.dart';

class AppDependencies {
  AppDependencies() {
    tokenStore = TokenStore();
    apiClient = ApiClient(tokenStore);
    authService = AuthService(apiClient);
    rideService = RideService(apiClient);
    vehicleService = VehicleService(apiClient);
    bookingService = BookingService(apiClient);
    paymentService = PaymentService(apiClient);
    notificationService = NotificationService(apiClient, tokenStore);
    profileService = ProfileService(apiClient);
    mapService = MapService();
    trackingService = TrackingService(apiClient, tokenStore);
  }

  late final TokenStore tokenStore;
  late final ApiClient apiClient;
  late final AuthService authService;
  late final RideService rideService;
  late final VehicleService vehicleService;
  late final BookingService bookingService;
  late final PaymentService paymentService;
  late final NotificationService notificationService;
  late final ProfileService profileService;
  late final MapService mapService;
  late final TrackingService trackingService;
}
