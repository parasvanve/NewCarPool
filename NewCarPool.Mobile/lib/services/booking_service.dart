import '../core/network/api_client.dart';

class BookingService {
  BookingService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<dynamic>> history() async {
    final response = await _apiClient.dio.get('/bookings/history');
    return response.data as List<dynamic>;
  }

  Future<void> accept(String bookingId) => _apiClient.dio.post('/bookings/$bookingId/accept');
  Future<void> reject(String bookingId) => _apiClient.dio.post('/bookings/$bookingId/reject');
  Future<void> cancel(String bookingId) => _apiClient.dio.post('/bookings/$bookingId/cancel');
}
