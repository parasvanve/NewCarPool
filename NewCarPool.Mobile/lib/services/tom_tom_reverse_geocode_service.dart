import 'package:dio/dio.dart';

import '../core/config/app_config.dart';

class TomTomReverseGeocodeService {
  TomTomReverseGeocodeService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: 'https://api.tomtom.com',
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
            ));

  final Dio _dio;

  Future<String> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    if (AppConfig.tomTomApiKey.isEmpty) {
      return 'Current location';
    }

    try {
      final response = await _dio.get(
        '/search/2/reverseGeocode/$latitude,$longitude.json',
        queryParameters: {
          'key': AppConfig.tomTomApiKey,
        },
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      final addresses = data['addresses'] as List<dynamic>? ?? const [];
      if (addresses.isEmpty) return 'Current location';

      final first = Map<String, dynamic>.from(addresses.first as Map);
      final address = first['address'] as Map?;
      final label = _firstNonEmpty([
        address?['freeformAddress']?.toString(),
        address?['streetName']?.toString(),
        address?['municipalitySubdivision']?.toString(),
        address?['municipality']?.toString(),
      ]);
      return label ?? 'Current location';
    } catch (_) {
      return 'Current location';
    }
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
