import '../core/network/api_client.dart';

class NotificationService {
  NotificationService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<dynamic>> getMine() async {
    final response = await _apiClient.dio.get('/notifications');
    return response.data as List<dynamic>;
  }

  Future<void> markRead(String notificationId) async {
    await _apiClient.dio.post('/notifications/$notificationId/read');
  }
}
