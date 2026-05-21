import '../core/network/api_client.dart';
import '../models/booking_models.dart';
import '../models/ride_models.dart';

class RideService {
  RideService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<RideOffer>> search({
    required GeoPoint origin,
    required GeoPoint destination,
    required int seats,
    DateTime? departureDateUtc,
  }) async {
    final Map<String, dynamic> query = {
      'originLatitude': origin.latitude,
      'originLongitude': origin.longitude,
      'destinationLatitude': destination.latitude,
      'destinationLongitude': destination.longitude,
      'seats': seats,
      'page': 1,
      'pageSize': 20,
    };
    if (departureDateUtc != null) {
      query['departureDateUtc'] = departureDateUtc.toIso8601String();
    }

    final response = await _apiClient.dio.get('/rides/search', queryParameters: query);
    final items = response.data['items'] as List<dynamic>;
    return items.map((x) => RideOffer.fromJson(Map<String, dynamic>.from(x as Map))).toList();
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
    final response = await _apiClient.dio.post('/rides/offer', data: {
      'origin': origin.toJson(),
      'vehicleId': vehicleId,
      'destination': destination.toJson(),
      'departureTimeUtc': departureTimeUtc.toUtc().toIso8601String(),
      'availableSeats': seats,
      'pricePerSeat': pricePerSeat,
      'intermediateStops': intermediateStops
          .asMap()
          .entries
          .map(
            (entry) => RideStop(
              name: entry.value.name,
              latitude: entry.value.latitude,
              longitude: entry.value.longitude,
              order: entry.key + 1,
            ).toJson(),
          )
          .toList(),
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      'vehicleName': vehicleName,
      'vehicleNumber': vehicleNumber,
    });
    return RideOffer.fromJson(Map<String, dynamic>.from(response.data));
  }

  Future<void> bookRide(String rideOfferId, int seats) async {
    await _apiClient.dio.post('/rides/book', data: {
      'rideOfferId': rideOfferId,
      'seatsBooked': seats,
    });
  }

  Future<List<RideBooking>> participants(String rideOfferId) async {
    final response = await _apiClient.dio.get('/rides/$rideOfferId/participants');
    final items = response.data as List<dynamic>;
    return items
        .map((item) => RideBooking.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<RideOffer> startRide(String rideOfferId) async {
    final response = await _apiClient.dio.post('/rides/$rideOfferId/start');
    return RideOffer.fromJson(Map<String, dynamic>.from(response.data));
  }

  Future<RideOffer> completeRide(String rideOfferId) async {
    final response = await _apiClient.dio.post('/rides/$rideOfferId/complete');
    return RideOffer.fromJson(Map<String, dynamic>.from(response.data));
  }

  Future<RideOffer> cancelRide(String rideOfferId) async {
    final response = await _apiClient.dio.post('/rides/$rideOfferId/cancel');
    return RideOffer.fromJson(Map<String, dynamic>.from(response.data));
  }
}
