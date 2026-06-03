import 'package:geolocator/geolocator.dart';

class LocationPoint {
  const LocationPoint({
    required this.latitude,
    required this.longitude,
    this.message,
    this.isFallback = false,
    this.isDefaultFallback = false,
    this.hasPermission = false,
  });

  final double latitude;
  final double longitude;
  final String? message;
  final bool isFallback;
  final bool isDefaultFallback;
  final bool hasPermission;
}

class LocationPermissionCheck {
  const LocationPermissionCheck._({
    required this.isGranted,
    this.message,
  });

  final bool isGranted;
  final String? message;

  static const granted = LocationPermissionCheck._(isGranted: true);

  static LocationPermissionCheck denied(String message) =>
      LocationPermissionCheck._(isGranted: false, message: message);
}

class LocationPermissionHelper {
  static const indoreLatitude = 22.7196;
  static const indoreLongitude = 75.8577;
  static const liveTrackingRequiredMessage =
      'Location permission is required for live tracking.';
  static const showCurrentLocationMessage =
      'Location permission is required to show your current location.';
  static const settingsMessage =
      'Please enable location permission from app settings.';

  static Future<LocationPermissionCheck> request({
    String deniedMessage = liveTrackingRequiredMessage,
  }) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationPermissionCheck.denied(deniedMessage);
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      return LocationPermissionCheck.denied(settingsMessage);
    }

    if (permission == LocationPermission.denied) {
      return LocationPermissionCheck.denied(deniedMessage);
    }

    return LocationPermissionCheck.granted;
  }

  static Future<LocationPoint> currentOrFallback({
    String deniedMessage = showCurrentLocationMessage,
  }) async {
    final permission = await request(deniedMessage: deniedMessage);
    if (permission.isGranted) {
      try {
        final current = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.high),
        );
        return LocationPoint(
          latitude: current.latitude,
          longitude: current.longitude,
          hasPermission: true,
        );
      } catch (_) {
        final last = await _lastKnown(hasPermission: true);
        if (last != null) return last;
      }
    }

    final last = await _lastKnown();
    if (last != null) {
      return LocationPoint(
        latitude: last.latitude,
        longitude: last.longitude,
        message: permission.message,
        isFallback: true,
        hasPermission: false,
      );
    }

    return LocationPoint(
      latitude: indoreLatitude,
      longitude: indoreLongitude,
      message: permission.message,
      isFallback: true,
      isDefaultFallback: true,
      hasPermission: false,
    );
  }

  static Future<LocationPoint?> _lastKnown({bool hasPermission = false}) async {
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last == null) return null;
      return LocationPoint(
        latitude: last.latitude,
        longitude: last.longitude,
        isFallback: true,
        hasPermission: hasPermission,
      );
    } catch (_) {
      return null;
    }
  }
}
