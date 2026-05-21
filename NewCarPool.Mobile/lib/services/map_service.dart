import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';

class MapService {
  MapService(this._apiClient);

  final ApiClient _apiClient;
  static const Duration _ttl = Duration(minutes: 5);
  final Map<String, _CacheItem<Map<String, dynamic>>> _routeCache = {};
  final Map<String, _CacheItem<List<dynamic>>> _geocodeCache = {};
  final Map<String, _CacheItem<String>> _reverseGeocodeCache = {};

  Future<Map<String, dynamic>> route({
    required double fromLatitude,
    required double fromLongitude,
    required double toLatitude,
    required double toLongitude,
  }) async {
    final key = '${fromLatitude.toStringAsFixed(5)},${fromLongitude.toStringAsFixed(5)}->${toLatitude.toStringAsFixed(5)},${toLongitude.toStringAsFixed(5)}';
    final cached = _routeCache[key];
    if (cached != null && cached.isValid) {
      return cached.value;
    }

    debugPrint(
      'MapService.route request from=($fromLatitude,$fromLongitude) to=($toLatitude,$toLongitude)',
    );
    final response = await _apiClient.dio.post('/maps/route', data: {
      'fromLatitude': fromLatitude,
      'fromLongitude': fromLongitude,
      'toLatitude': toLatitude,
      'toLongitude': toLongitude,
    });
    final data = Map<String, dynamic>.from(response.data);
    debugPrint(
      'MapService.route response keys=${data.keys.toList()} '
      'distanceKm=${data['distanceKm']} etaMinutes=${data['etaMinutes']} '
      'polyline=${(data['encodedPolyline'] ?? data['geometry'] ?? data['polyline'])?.toString().isNotEmpty}',
    );
    _routeCache[key] = _CacheItem(data, DateTime.now().add(_ttl));
    return data;
  }

  Future<List<dynamic>> geocode(String query) async {
    final key = query.trim().toLowerCase();
    final cached = _geocodeCache[key];
    if (cached != null && cached.isValid) {
      return cached.value;
    }

    final response = await _apiClient.dio.get('/maps/geocode', queryParameters: {'query': query});
    final data = response.data as List<dynamic>;
    _geocodeCache[key] = _CacheItem(data, DateTime.now().add(_ttl));
    return data;
  }

  Future<String> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    final key = '${latitude.toStringAsFixed(5)},${longitude.toStringAsFixed(5)}';
    final cached = _reverseGeocodeCache[key];
    if (cached != null && cached.isValid) {
      return cached.value;
    }

    final response = await _apiClient.dio.get(
      '/maps/reverse-geocode',
      queryParameters: {
        'latitude': latitude,
        'longitude': longitude,
      },
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    final value = (data['displayName'] ?? data['address'] ?? '').toString().trim();
    final label = value.isEmpty ? 'Current location' : value;
    _reverseGeocodeCache[key] = _CacheItem(label, DateTime.now().add(_ttl));
    return label;
  }
}

class _CacheItem<T> {
  _CacheItem(this.value, this.expiresAt);

  final T value;
  final DateTime expiresAt;

  bool get isValid => DateTime.now().isBefore(expiresAt);
}
