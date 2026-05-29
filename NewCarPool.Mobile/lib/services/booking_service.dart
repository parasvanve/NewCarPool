import '../core/network/api_client.dart';
import '../models/booking_models.dart';
import '../models/ride_models.dart';

class BookingService {
  BookingService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<RideBooking>> history() async {
    final response = await _apiClient.dio.get('/bookings/history');
    final items = response.data as List<dynamic>;
    return items
        .map((item) => RideBooking.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<RideBooking> accept(String bookingId) async {
    final response = await _apiClient.dio.post('/bookings/$bookingId/accept');
    return RideBooking.fromJson(Map<String, dynamic>.from(response.data));
  }

  Future<RideBooking> reject(String bookingId) async {
    final response = await _apiClient.dio.post('/bookings/$bookingId/reject');
    return RideBooking.fromJson(Map<String, dynamic>.from(response.data));
  }

  Future<RideBooking> cancel(String bookingId, {String? reason}) async {
    final response = await _apiClient.dio.post(
      '/rides/bookings/$bookingId/cancel',
      data: {
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
    return RideBooking.fromJson(Map<String, dynamic>.from(response.data));
  }

  Future<RideBooking> request({
    required String rideOfferId,
    required int seatsBooked,
    GeoPoint? pickup,
    GeoPoint? drop,
  }) async {
    final response = await _apiClient.dio.post('/rides/book', data: {
      'rideOfferId': rideOfferId,
      'seatsBooked': seatsBooked,
      if (pickup != null) 'pickup': pickup.toJson(),
      if (drop != null) 'drop': drop.toJson(),
      if (pickup != null && pickup.name.isNotEmpty) 'boardingPoint': pickup.name,
      if (drop != null && drop.name.isNotEmpty) 'dropPoint': drop.name,
    });
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return RideBooking.fromJson(data);
    }
    final fallback = await history();
    if (fallback.isNotEmpty) {
      return fallback.first;
    }
    throw StateError('Booking request sent but response payload missing.');
  }
}
