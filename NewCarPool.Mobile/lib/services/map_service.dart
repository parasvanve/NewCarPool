import 'package:flutter/foundation.dart';

import 'tom_tom_reverse_geocode_service.dart';
import 'tom_tom_route_service.dart';
import 'tom_tom_search_service.dart';

class MapService {
  MapService({
    TomTomSearchService? searchService,
    TomTomReverseGeocodeService? reverseGeocodeService,
    TomTomRouteService? routeService,
  })  : _searchService = searchService ?? TomTomSearchService(),
        _reverseGeocodeService =
            reverseGeocodeService ?? TomTomReverseGeocodeService(),
        _routeService = routeService ?? TomTomRouteService();

  final TomTomSearchService _searchService;
  final TomTomReverseGeocodeService _reverseGeocodeService;
  final TomTomRouteService _routeService;
  static const Duration _ttl = Duration(minutes: 5);
  final Map<String, _CacheItem<Map<String, dynamic>>> _routeCache = {};
  final Map<String, _CacheItem<List<Map<String, dynamic>>>> _geocodeCache = {};
  final Map<String, _CacheItem<String>> _reverseGeocodeCache = {};

  Future<Map<String, dynamic>> route({
    required double fromLatitude,
    required double fromLongitude,
    required double toLatitude,
    required double toLongitude,
  }) async {
    final key =
        '${fromLatitude.toStringAsFixed(5)},${fromLongitude.toStringAsFixed(5)}->${toLatitude.toStringAsFixed(5)},${toLongitude.toStringAsFixed(5)}';
    final cached = _routeCache[key];
    if (cached != null && cached.isValid) {
      return cached.value;
    }

    debugPrint(
      'MapService.route request from=($fromLatitude,$fromLongitude) to=($toLatitude,$toLongitude)',
    );
    final data = await _routeService.route(
      fromLatitude: fromLatitude,
      fromLongitude: fromLongitude,
      toLatitude: toLatitude,
      toLongitude: toLongitude,
    );
    debugPrint(
      'MapService.route response keys=${data.keys.toList()} '
      'distanceKm=${data['distanceKm']} etaMinutes=${data['etaMinutes']} '
      'polyline=${(data['encodedPolyline'] ?? data['geometry'] ?? data['polyline'])?.toString().isNotEmpty}',
    );
    _routeCache[key] = _CacheItem(data, DateTime.now().add(_ttl));
    return data;
  }

  Future<List<Map<String, dynamic>>> geocode(
    String query, {
    double? latitude,
    double? longitude,
  }) async {
    final key =
        '${query.trim().toLowerCase()}@${latitude?.toStringAsFixed(3) ?? ''},${longitude?.toStringAsFixed(3) ?? ''}';
    final cached = _geocodeCache[key];
    if (cached != null && cached.isValid) {
      return cached.value;
    }

    final data = await _searchService.search(
      query,
      latitude: latitude,
      longitude: longitude,
    );
    _geocodeCache[key] = _CacheItem(data, DateTime.now().add(_ttl));
    return data;
  }

  Future<String> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    final key =
        '${latitude.toStringAsFixed(5)},${longitude.toStringAsFixed(5)}';
    final cached = _reverseGeocodeCache[key];
    if (cached != null && cached.isValid) {
      return cached.value;
    }

    final label = await _reverseGeocodeService.reverseGeocode(
      latitude: latitude,
      longitude: longitude,
    );
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
