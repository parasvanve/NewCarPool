import '../core/network/api_client.dart';

class MapService {
  MapService(this._apiClient);

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> route({
    required double fromLatitude,
    required double fromLongitude,
    required double toLatitude,
    required double toLongitude,
  }) async {
    final response = await _apiClient.dio.post('/maps/route', data: {
      'fromLatitude': fromLatitude,
      'fromLongitude': fromLongitude,
      'toLatitude': toLatitude,
      'toLongitude': toLongitude,
    });
    return Map<String, dynamic>.from(response.data);
  }

  Future<List<dynamic>> geocode(String query) async {
    final response = await _apiClient.dio.get('/maps/geocode', queryParameters: {'query': query});
    return response.data as List<dynamic>;
  }
}
