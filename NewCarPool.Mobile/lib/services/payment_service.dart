import '../core/network/api_client.dart';
import '../models/payment_models.dart';

class PaymentService {
  PaymentService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<PaymentRecord>> history() async {
    final response = await _apiClient.dio.get('/payments/history');
    final items = response.data as List<dynamic>;
    return items
        .map((item) => PaymentRecord.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<PaymentRecord> create({
    required String bookingId,
    required double amount,
    required String transactionId,
    required int paymentMethod,
  }) async {
    final response = await _apiClient.dio.post('/payments', data: {
      'bookingId': bookingId,
      'amount': amount,
      'transactionId': transactionId,
      'paymentMethod': paymentMethod,
    });
    return PaymentRecord.fromJson(Map<String, dynamic>.from(response.data));
  }

  Future<PaymentRecord> verify(String transactionId) async {
    final response = await _apiClient.dio.post('/payments/verify', data: {
      'transactionId': transactionId,
    });
    return PaymentRecord.fromJson(Map<String, dynamic>.from(response.data));
  }
}
