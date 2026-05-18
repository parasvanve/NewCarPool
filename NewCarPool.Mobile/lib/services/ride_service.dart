import '../core/network/api_client.dart';
import '../models/ride_models.dart';

class RideService {
  RideService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<RideOffer>> search({
    required GeoPoint origin,
    required GeoPoint destination,
    required int seats,
  }) async {
    final response = await _apiClient.dio.get('/rides/search', queryParameters: {
      'originLatitude': origin.latitude,
      'originLongitude': origin.longitude,
      'destinationLatitude': destination.latitude,
      'destinationLongitude': destination.longitude,
      'seats': seats,
      'page': 1,
      'pageSize': 20,
    });
    final items = response.data['items'] as List<dynamic>;
    return items.map((x) => RideOffer.fromJson(x)).toList();
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
    final response = await _apiClient.dio.post('/rides/offer', data: {
      'origin': origin.toJson(),
      'vehicleId': vehicleId,
      'destination': destination.toJson(),
      'departureTimeUtc': departureTimeUtc.toUtc().toIso8601String(),
      'availableSeats': seats,
      'pricePerSeat': pricePerSeat,
      'vehicleName': vehicleName,
      'vehicleNumber': vehicleNumber,
    });
    return RideOffer.fromJson(response.data);
  }

  Future<void> bookRide(String rideOfferId, int seats) async {
    await _apiClient.dio.post('/rides/book', data: {
      'rideOfferId': rideOfferId,
      'seatsBooked': seats,
    });
  }
}
