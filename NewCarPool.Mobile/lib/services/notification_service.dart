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
        .map((item) =>
            AppNotification.fromJson(Map<String, dynamic>.from(item as Map)))
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

  Future<void> markAllRead() async {
    await _apiClient.dio.post('/notifications/read-all');
  }

  Future<int> unreadCount() async {
    final response = await _apiClient.dio.get('/notifications/unread-count');
    final value = response.data;
    if (value is num) return value.toInt();
    if (value is Map<String, dynamic>) {
      return (value['count'] as num?)?.toInt() ?? 0;
    }
    return 0;
  }

  Future<void> connect(
      String userId, void Function(AppNotification) onNotification) async {
    final token = await _tokenStore.accessToken;
    if (token == null) return;

    // _connection = HubConnectionBuilder()
    //     .withUrl(
    //       '${AppConfig.apiBaseUrl}/hubs/notifications',
    //       options: HttpConnectionOptions(accessTokenFactory: () async => token),
    //     )
    //     .withAutomaticReconnect()
    //     .build();

    //new code
    _connection = HubConnectionBuilder()
        .withUrl(
          '${AppConfig.apiBaseUrl}/hubs/notifications',
          options: HttpConnectionOptions(
            accessTokenFactory: () async => await _tokenStore.accessToken ?? '',
          ),
        )
        .withAutomaticReconnect()
        .build();

    void handleNotificationPayload(List<Object?>? args) {
      if (args == null || args.isEmpty) return;
      final payload = Map<String, dynamic>.from(args.first as Map);
      onNotification(AppNotification.fromJson(payload));
    }

    _connection!.on('notificationReceived', handleNotificationPayload);
    _connection!.on('NotificationCreated', handleNotificationPayload);

    await _connection!.start();
    await _connection!.invoke('JoinUserGroup', args: [userId]);
  }

  void onUnreadCountChanged(void Function(int count) onChanged) {
    _connection?.on('UnreadCountChanged', (args) {
      if (args == null || args.isEmpty) return;
      final raw = args.first;
      if (raw is num) {
        onChanged(raw.toInt());
      }
    });
  }

  Future<void> disconnect() async {
    await _connection?.stop();
  }
}
