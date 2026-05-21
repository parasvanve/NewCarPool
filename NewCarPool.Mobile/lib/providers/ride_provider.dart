import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/ride_models.dart';
import '../models/booking_models.dart';
import '../services/ride_service.dart';

class RideProvider extends ChangeNotifier {
  RideProvider(this._rideService);

  final RideService _rideService;
  List<RideOffer> rides = [];
  bool isLoading = false;
  String? errorMessage;
  Timer? _refreshTimer;
  GeoPoint? _lastOrigin;
  GeoPoint? _lastDestination;
  int _lastSeats = 1;
  DateTime? _lastDepartureDateUtc;

  Future<void> search(GeoPoint origin, GeoPoint destination, int seats, {DateTime? departureDateUtc}) async {
    isLoading = true;
    errorMessage = null;
    _lastOrigin = origin;
    _lastDestination = destination;
    _lastSeats = seats;
    _lastDepartureDateUtc = departureDateUtc;
    notifyListeners();
    try {
      rides = await _rideService.search(
        origin: origin,
        destination: destination,
        seats: seats,
        departureDateUtc: departureDateUtc,
      );
    } catch (error) {
      errorMessage = error.toString();
      rethrow;
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
    List<RideStop> intermediateStops = const [],
    String? notes,
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
      intermediateStops: intermediateStops,
      notes: notes,
      vehicleName: vehicleName,
      vehicleNumber: vehicleNumber,
    );
    rides = [ride, ...rides.where((x) => x.id != ride.id)];
    notifyListeners();
    return ride;
  }

  Future<void> bookRide(String rideOfferId, int seats) async {
    await _rideService.bookRide(rideOfferId, seats);
  }

  Future<List<RideBooking>> participants(String rideOfferId) {
    return _rideService.participants(rideOfferId);
  }

  Future<void> startRide(String rideOfferId) async {
    final updated = await _rideService.startRide(rideOfferId);
    _upsertRide(updated);
  }

  Future<void> completeRide(String rideOfferId) async {
    final updated = await _rideService.completeRide(rideOfferId);
    _upsertRide(updated);
  }

  Future<void> cancelRide(String rideOfferId) async {
    final updated = await _rideService.cancelRide(rideOfferId);
    _upsertRide(updated);
  }

  Future<void> refreshNearby() async {
    if (_lastOrigin == null || _lastDestination == null || isLoading) return;
    try {
      final items = await _rideService.search(
        origin: _lastOrigin!,
        destination: _lastDestination!,
        seats: _lastSeats,
        departureDateUtc: _lastDepartureDateUtc,
      );
      rides = items;
      errorMessage = null;
      notifyListeners();
    } catch (_) {
      // Keep previous list for better UX on flaky connections.
    }
  }

  void startAutoRefresh({Duration interval = const Duration(seconds: 20)}) {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(interval, (_) => refreshNearby());
  }

  void stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  void _upsertRide(RideOffer ride) {
    final index = rides.indexWhere((x) => x.id == ride.id);
    if (index >= 0) {
      rides[index] = ride;
    } else {
      rides = [ride, ...rides];
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}
