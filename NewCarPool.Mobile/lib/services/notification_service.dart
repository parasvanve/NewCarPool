import 'package:signalr_netcore/signalr_client.dart';

import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../core/network/token_store.dart';
import '../models/notification_models.dart';

class NotificationService {
  NotificationService(this._apiClient, this._tokenStore);

  final ApiClient _apiClient;
  final TokenStore _tokenStore;
  HubConnection? _connection;

  Future<List<AppNotification>> getMine() async {
    final response = await _apiClient.dio.get('/notifications');
    final items = response.data as List<dynamic>;
    return items
        .map((item) => AppNotification.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<AppNotification> sendToMe(String title, String message) async {
    final response = await _apiClient.dio.post('/notifications', data: {
      'title': title,
      'message': message,
    });
    return AppNotification.fromJson(Map<String, dynamic>.from(response.data));
  }

  Future<void> markRead(String notificationId) async {
    await _apiClient.dio.post('/notifications/$notificationId/read');
  }

  Future<void> connect(String userId, void Function(AppNotification) onNotification) async {
    final token = await _tokenStore.accessToken;
    if (token == null) return;

    _connection = HubConnectionBuilder()
        .withUrl(
          '${AppConfig.apiBaseUrl}/hubs/notifications',
          options: HttpConnectionOptions(accessTokenFactory: () async => token),
        )
        .withAutomaticReconnect()
        .build();

    _connection!.on('notificationReceived', (args) {
      if (args == null || args.isEmpty) return;
      final payload = Map<String, dynamic>.from(args.first as Map);
      onNotification(AppNotification.fromJson(payload));
    });

    await _connection!.start();
    await _connection!.invoke('JoinUserGroup', args: [userId]);
  }

  Future<void> disconnect() async {
    await _connection?.stop();
  }
}
