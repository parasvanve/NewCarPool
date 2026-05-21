import '../core/network/api_client.dart';
import '../models/chat_models.dart';

class RideChatService {
  RideChatService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<RideChatMessage>> messages(String rideOfferId) async {
    final response = await _apiClient.dio.get('/rides/$rideOfferId/chat/messages');
    final items = response.data as List<dynamic>;
    return items.map((e) => RideChatMessage.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<RideChatMessage> send({
    required String rideOfferId,
    required String message,
  }) async {
    final response = await _apiClient.dio.post('/rides/$rideOfferId/chat/messages', data: {
      'message': message,
    });
    return RideChatMessage.fromJson(Map<String, dynamic>.from(response.data));
  }
}
