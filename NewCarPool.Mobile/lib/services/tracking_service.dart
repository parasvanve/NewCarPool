import 'package:signalr_netcore/signalr_client.dart';
import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../core/network/token_store.dart';

class TrackingService {
  TrackingService(this._apiClient, this._tokenStore);

  final ApiClient _apiClient;
  final TokenStore _tokenStore;
  HubConnection? _connection;

  Future<void> connect(String rideOfferId, void Function(Map<String, dynamic>) onLocation) async {
    final token = await _tokenStore.accessToken;
    _connection = HubConnectionBuilder()
        .withUrl(
          '${AppConfig.apiBaseUrl}/hubs/tracking',
          options: HttpConnectionOptions(accessTokenFactory: () async => token ?? ''),
        )
        .withAutomaticReconnect()
        .build();

    void handleLocationPayload(List<Object?>? args) {
      if (args != null && args.isNotEmpty) {
        onLocation(Map<String, dynamic>.from(args.first as Map));
      }
    }
    _connection!.on('locationUpdated', handleLocationPayload);
    _connection!.on('DriverLocationUpdated', handleLocationPayload);

    await _connection!.start();
    await _connection!.invoke('JoinRide', args: [rideOfferId]);
  }

  Future<void> publishLocation({
    required String rideOfferId,
    required double latitude,
    required double longitude,
    double? heading,
    double? speedKph,
  }) async {
    await _apiClient.dio.post('/rides/$rideOfferId/location', data: {
      'rideOfferId': rideOfferId,
      'latitude': latitude,
      'longitude': longitude,
      'heading': heading,
      'speedKph': speedKph,
    });
  }

  Future<Map<String, dynamic>?> latestLocation(String rideOfferId) async {
    try {
      final response = await _apiClient.dio.get('/rides/$rideOfferId/location/latest');
      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> disconnect() async {
    await _connection?.stop();
  }
}
