import 'package:flutter/foundation.dart';
import '../models/ride_models.dart';
import '../services/ride_service.dart';

class RideProvider extends ChangeNotifier {
  RideProvider(this._rideService);

  final RideService _rideService;
  List<RideOffer> rides = [];
  bool isLoading = false;

  Future<void> search(GeoPoint origin, GeoPoint destination, int seats) async {
    isLoading = true;
    notifyListeners();
    try {
      rides = await _rideService.search(origin: origin, destination: destination, seats: seats);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<RideOffer> offerRide({
    required String vehicleId,
    required GeoPoint origin,
    required GeoPoint destination,
    required DateTime departureTimeUtc,
    required int seats,
    required num pricePerSeat,
    String? vehicleName,
    String? vehicleNumber,
  }) async {
    final ride = await _rideService.offerRide(
      origin: origin,
      vehicleId: vehicleId,
      destination: destination,
      departureTimeUtc: departureTimeUtc,
      seats: seats,
      pricePerSeat: pricePerSeat,
      vehicleName: vehicleName,
      vehicleNumber: vehicleNumber,
    );
    rides = [ride, ...rides];
    notifyListeners();
    return ride;
  }

  Future<void> bookRide(String rideOfferId, int seats) async {
    await _rideService.bookRide(rideOfferId, seats);
  }
}
