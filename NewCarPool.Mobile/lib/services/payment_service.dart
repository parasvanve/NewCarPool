import '../core/network/api_client.dart';

class PaymentService {
  PaymentService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<dynamic>> history() async {
    final response = await _apiClient.dio.get('/payments/history');
    return response.data as List<dynamic>;
  }

  Future<void> create(Map<String, dynamic> data) async {
    await _apiClient.dio.post('/payments', data: data);
  }
}
