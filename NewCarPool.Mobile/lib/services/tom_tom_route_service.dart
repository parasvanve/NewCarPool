import 'package:dio/dio.dart';

import '../core/config/app_config.dart';
import '../core/utils/coordinate_utils.dart';

class TomTomRouteService {
  TomTomRouteService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: 'https://api.tomtom.com',
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
            ));

  final Dio _dio;

  Future<Map<String, dynamic>> route({
    required double fromLatitude,
    required double fromLongitude,
    required double toLatitude,
    required double toLongitude,
  }) async {
    if (AppConfig.tomTomApiKey.isEmpty) {
      throw StateError('TomTom API key is not configured.');
    }

    final path =
        '/routing/1/calculateRoute/$fromLatitude,$fromLongitude:$toLatitude,$toLongitude/json';

    final response = await _dio.get(
      path,
      queryParameters: {
        'key': AppConfig.tomTomApiKey,
        'routeType': 'fastest',
        'travelMode': 'car',
        'traffic': true,
        'computeTravelTimeFor': 'all',
      },
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    final routes = data['routes'] as List<dynamic>? ?? const [];
    if (routes.isEmpty) {
      throw StateError('No route found.');
    }

    final route = Map<String, dynamic>.from(routes.first as Map);
    final summary = Map<String, dynamic>.from(route['summary'] as Map? ?? {});
    final legs = route['legs'] as List<dynamic>? ?? const [];
    final points = <_RoutePoint>[];
    for (final leg in legs) {
      final legMap = Map<String, dynamic>.from(leg as Map);
      final legPoints = legMap['points'] as List<dynamic>? ?? const [];
      for (final point in legPoints) {
        final pointMap = Map<String, dynamic>.from(point as Map);
        final latitude = (pointMap['latitude'] as num?)?.toDouble();
        final longitude = (pointMap['longitude'] as num?)?.toDouble();
        if (latitude != null &&
            longitude != null &&
            CoordinateUtils.isValid(
              latitude: latitude,
              longitude: longitude,
            )) {
          points.add(_RoutePoint(latitude, longitude));
        }
      }
    }

    final lengthMeters = (summary['lengthInMeters'] as num?)?.toDouble();
    final travelSeconds = (summary['travelTimeInSeconds'] as num?)?.toDouble();

    return {
      'distanceKm': lengthMeters == null ? null : lengthMeters / 1000,
      'etaMinutes': travelSeconds == null ? null : (travelSeconds / 60).round(),
      'encodedPolyline': _encodePolyline(points),
      'points': points
          .map((point) => {
                'latitude': point.latitude,
                'longitude': point.longitude,
              })
          .toList(growable: false),
    };
  }

  String _encodePolyline(List<_RoutePoint> points) {
    var previousLatitude = 0;
    var previousLongitude = 0;
    final buffer = StringBuffer();

    for (final point in points) {
      final latitude = (point.latitude * 1e5).round();
      final longitude = (point.longitude * 1e5).round();
      _encodeValue(latitude - previousLatitude, buffer);
      _encodeValue(longitude - previousLongitude, buffer);
      previousLatitude = latitude;
      previousLongitude = longitude;
    }

    return buffer.toString();
  }

  void _encodeValue(int value, StringBuffer buffer) {
    var encoded = value < 0 ? ~(value << 1) : value << 1;
    while (encoded >= 0x20) {
      buffer.writeCharCode((0x20 | (encoded & 0x1f)) + 63);
      encoded >>= 5;
    }
    buffer.writeCharCode(encoded + 63);
  }
}

class _RoutePoint {
  const _RoutePoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}
