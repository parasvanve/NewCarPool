import 'package:dio/dio.dart';

import '../core/config/app_config.dart';
import '../core/utils/coordinate_utils.dart';

class TomTomSearchService {
  TomTomSearchService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: 'https://api.tomtom.com',
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
            ));

  final Dio _dio;

  Future<List<Map<String, dynamic>>> search(
    String query, {
    double? latitude,
    double? longitude,
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < 3 || AppConfig.tomTomApiKey.isEmpty) {
      return const [];
    }

    try {
      final response = await _dio.get(
        '/search/2/search/${Uri.encodeComponent(trimmed)}.json',
        queryParameters: {
          'key': AppConfig.tomTomApiKey,
          'countrySet': 'IN',
          'limit': 5,
          'typeahead': true,
          if (latitude != null) 'lat': latitude,
          if (longitude != null) 'lon': longitude,
        },
      );

      final data = Map<String, dynamic>.from(response.data as Map);
      final results = data['results'] as List<dynamic>? ?? const [];
      return results
          .map((item) => _mapResult(Map<String, dynamic>.from(item as Map)))
          .where((item) => item != null)
          .cast<Map<String, dynamic>>()
          .take(5)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Map<String, dynamic>? _mapResult(Map<String, dynamic> item) {
    final position = item['position'] as Map?;
    final latitude = (position?['lat'] as num?)?.toDouble();
    final longitude = (position?['lon'] as num?)?.toDouble();
    if (latitude == null || longitude == null) return null;
    if (!CoordinateUtils.isValid(latitude: latitude, longitude: longitude)) {
      return null;
    }

    final poi = item['poi'] as Map?;
    final address = item['address'] as Map?;
    final name = _firstNonEmpty([
      poi?['name']?.toString(),
      address?['streetName']?.toString(),
      address?['municipalitySubdivision']?.toString(),
      address?['municipality']?.toString(),
    ]);
    final freeformAddress = address?['freeformAddress']?.toString();
    final municipality = address?['municipality']?.toString();
    final countrySubdivision = address?['countrySubdivision']?.toString();
    final secondary = _firstNonEmpty([
      freeformAddress,
      [
        municipality,
        countrySubdivision,
      ].where((part) => part != null && part.trim().isNotEmpty).join(', '),
    ]);
    final distanceMeters = (item['dist'] as num?)?.toDouble();

    return {
      'displayName': secondary ?? name ?? 'Place',
      'formattedAddress': secondary ?? name ?? 'Place',
      'name': name ?? secondary ?? 'Place',
      'mainText': name ?? secondary ?? 'Place',
      'secondaryText': secondary ?? '',
      'latitude': latitude,
      'longitude': longitude,
      'placeId': item['id']?.toString(),
      if (distanceMeters != null) 'distanceKm': distanceMeters / 1000,
    };
  }

  String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }
}
