import 'package:flutter/foundation.dart';

class CoordinateUtils {
  static bool isValid({
    required double latitude,
    required double longitude,
  }) =>
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;

  static void logSelectedSuggestion({
    String type = 'suggestion',
    required String name,
    required double latitude,
    required double longitude,
  }) {
    debugPrint(
      '[MapCoordinateTrace] selected type=$type name="$name" latitude=$latitude longitude=$longitude',
    );
  }

  static void logStatePoint({
    required String step,
    required String type,
    required String name,
    required double latitude,
    required double longitude,
  }) {
    debugPrint(
      '[MapCoordinateTrace] $step type=$type name="$name" latitude=$latitude longitude=$longitude',
    );
  }

  static void logMarkerPoint({
    required String type,
    required double latitude,
    required double longitude,
  }) {
    debugPrint(
      '[MapCoordinateTrace] marker type=$type finalLatitude=$latitude finalLongitude=$longitude',
    );
  }

  static void logCameraPoint({
    required String type,
    required double latitude,
    required double longitude,
    required double zoom,
  }) {
    debugPrint(
      '[MapCoordinateTrace] camera type=$type latitude=$latitude longitude=$longitude zoom=$zoom',
    );
  }
}
