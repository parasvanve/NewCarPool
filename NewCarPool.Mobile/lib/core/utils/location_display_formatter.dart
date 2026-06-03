import '../../models/ride_models.dart';

class LocationDisplayFormatter {
  static const Set<String> _genericParts = {
    'india',
    'united states',
    'usa',
    'bharat',
    'madhya pradesh',
    'maharashtra',
    'gujarat',
    'karnataka',
  };

  static String title(dynamic location) {
    final map = _asMap(location);
    final direct = _firstNonEmpty([
      map?['mainText']?.toString(),
      map?['main_text']?.toString(),
      map?['name']?.toString(),
    ]);
    if (direct != null && !_isGeneric(direct)) return direct;

    final display = _firstNonEmpty([
      map?['secondaryText']?.toString(),
      map?['secondary_text']?.toString(),
      map?['displayName']?.toString(),
      map?['address']?.toString(),
    ]);
    if (display == null) return 'Location';
    final parts = _splitAddress(display);
    if (parts.isEmpty) return 'Location';
    for (final part in parts) {
      if (!_isGeneric(part)) return part;
    }
    return parts.first;
  }

  static String subtitle(dynamic location) {
    final map = _asMap(location);
    final direct = _firstNonEmpty([
      map?['secondaryText']?.toString(),
      map?['secondary_text']?.toString(),
    ]);
    if (direct != null) return direct;
    final compact = compactAddress(location);
    return compact == title(location) ? '' : compact;
  }

  static String routeTitle(dynamic origin, dynamic destination) {
    return '${title(origin)} -> ${title(destination)}';
  }

  static String compactAddress(dynamic location) {
    final map = _asMap(location);
    final raw = _firstNonEmpty([
      map?['address']?.toString(),
      map?['displayName']?.toString(),
      map?['display_name']?.toString(),
      map?['secondaryText']?.toString(),
    ]);
    if (raw == null) return title(location);
    final parts = _splitAddress(raw);
    if (parts.length <= 2) return parts.join(', ');
    return '${parts[1]}, ${parts[2]}';
  }

  static Map<String, dynamic> fromSearchSuggestion(Map<String, dynamic> raw) {
    final displayName = raw['displayName']?.toString() ??
        raw['display_name']?.toString() ??
        raw['formattedAddress']?.toString() ??
        '';
    final main = _firstNonEmpty([
          raw['mainText']?.toString(),
          raw['main_text']?.toString(),
          raw['name']?.toString(),
        ]) ??
        (displayName.isEmpty ? 'Place' : _splitAddress(displayName).first);
    final secondary = _firstNonEmpty([
          raw['secondaryText']?.toString(),
          raw['secondary_text']?.toString(),
        ]) ??
        _secondaryFromDisplay(displayName);
    return {
      ...raw,
      'displayName': displayName,
      'formattedAddress': raw['formattedAddress']?.toString() ?? displayName,
      'name': main,
      'mainText': main,
      'secondaryText': secondary,
      'placeId': raw['placeId'] ?? raw['place_id'],
      'distanceKm': raw['distanceKm'] ?? raw['distance_km'],
    };
  }

  static String subtitleWithDistance(dynamic location) {
    final base = subtitle(location);
    final distance = distanceText(location);
    if (distance == null) return base;
    return base.isEmpty ? distance : '$base • $distance';
  }

  static String? distanceText(dynamic location) {
    final map = _asMap(location);
    final raw = map?['distanceKm'] ?? map?['distance_km'];
    final distance =
        raw is num ? raw.toDouble() : double.tryParse(raw?.toString() ?? '');
    if (distance == null) return null;
    if (distance < 1) return '${(distance * 1000).round()} m away';
    return '${distance.toStringAsFixed(distance < 10 ? 1 : 0)} km away';
  }

  static Map<String, dynamic>? _asMap(dynamic location) {
    if (location == null) return null;
    if (location is GeoPoint) {
      return {
        'name': location.name,
        'address': location.address,
      };
    }
    if (location is Map<String, dynamic>) return location;
    return null;
  }

  static List<String> _splitAddress(String value) => value
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList(growable: false);

  static String _secondaryFromDisplay(String displayName) {
    final parts = _splitAddress(displayName);
    if (parts.length <= 1) return '';
    if (parts.length == 2) return parts[1];
    return '${parts[1]}, ${parts[2]}';
  }

  static String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  static bool _isGeneric(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    if (_genericParts.contains(normalized)) return true;
    if (normalized.length <= 2) return true;
    return false;
  }
}
