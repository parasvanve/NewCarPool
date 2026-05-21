import '../core/network/api_client.dart';
import '../models/booking_models.dart';

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

  Future<RideBooking> cancel(String bookingId) async {
    final response = await _apiClient.dio.post('/bookings/$bookingId/cancel');
    return RideBooking.fromJson(Map<String, dynamic>.from(response.data));
  }

  Future<RideBooking> request({
    required String rideOfferId,
    required int seatsBooked,
    String? boardingPoint,
    String? dropPoint,
  }) async {
    final response = await _apiClient.dio.post('/rides/book', data: {
      'rideOfferId': rideOfferId,
      'seatsBooked': seatsBooked,
      if (boardingPoint != null && boardingPoint.isNotEmpty) 'boardingPoint': boardingPoint,
      if (dropPoint != null && dropPoint.isNotEmpty) 'dropPoint': dropPoint,
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
