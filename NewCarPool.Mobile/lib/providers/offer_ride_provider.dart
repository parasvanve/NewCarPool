import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../core/utils/location_permission_helper.dart';
import '../models/ride_models.dart';
import '../services/map_service.dart';

class OfferRideProvider extends ChangeNotifier {
  OfferRideProvider(this._mapService);

  final MapService _mapService;

  LatLng? pickup;
  LatLng? destination;
  String pickupAddress = 'Current location';
  List<RideStop> stops = [];
  List<LatLng> routePoints = const [];
  double? distanceKm;
  int? etaMinutes;
  bool isLoadingLocation = false;
  bool isRouteLoading = false;
  bool canShowMyLocation = false;
  String? routeError;
  String? routeWarning;

  Future<void> detectCurrentLocation() async {
    isLoadingLocation = true;
    notifyListeners();
    try {
      final location = await LocationPermissionHelper.currentOrFallback();
      canShowMyLocation = location.hasPermission;
      if (location.isDefaultFallback) {
        routeError = location.message;
        return;
      }

      pickup = LatLng(location.latitude, location.longitude);
      try {
        pickupAddress = await _mapService.reverseGeocode(
          latitude: location.latitude,
          longitude: location.longitude,
        );
      } catch (_) {
        pickupAddress = 'Current location';
      }
      routeError = location.message;
    } catch (_) {
      routeError = 'Unable to fetch GPS location. Please retry.';
    } finally {
      isLoadingLocation = false;
      notifyListeners();
    }
  }

  Future<void> setPickup(LatLng point) async {
    pickup = point;
    try {
      pickupAddress = await _mapService.reverseGeocode(
        latitude: point.latitude,
        longitude: point.longitude,
      );
    } catch (_) {
      pickupAddress = 'Pickup';
    }
    notifyListeners();
  }

  Future<void> setDestination(LatLng point) async {
    destination = point;
    notifyListeners();
  }

  Future<String?> addStop(RideStop stop) async {
    final validation = _validateStop(stop.latLng);
    if (validation != null) return validation;
    stops = [...stops, stop.copyWith(order: stops.length + 1)];
    notifyListeners();
    return null;
  }

  Future<String?> updateStop(int index, RideStop stop) async {
    if (index < 0 || index >= stops.length) return 'Invalid drop point';
    final ignore = stops[index];
    final validation = _validateStop(stop.latLng, ignore: ignore);
    if (validation != null) return validation;
    final next = [...stops];
    next[index] = stop.copyWith(order: index + 1);
    stops = next;
    notifyListeners();
    return null;
  }

  Future<void> removeStop(int index) async {
    if (index < 0 || index >= stops.length) return;
    final next = [...stops]..removeAt(index);
    stops = _reindex(next);
    notifyListeners();
  }

  Future<void> reorderStops(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final next = [...stops];
    final moved = next.removeAt(oldIndex);
    next.insert(newIndex, moved);
    stops = _reindex(next);
    notifyListeners();
  }

  String? _validateStop(LatLng point, {RideStop? ignore}) {
    if (pickup != null && _same(point, pickup!)) {
      return 'Drop point cannot be same as pickup.';
    }
    if (destination != null && _same(point, destination!)) {
      return 'Drop point cannot be same as final destination.';
    }
    final duplicate = stops.any((s) =>
        (ignore == null || s.order != ignore.order) && _same(s.latLng, point));
    if (duplicate) return 'Duplicate drop points are not allowed.';
    return null;
  }

  List<RideStop> _reindex(List<RideStop> list) {
    return list
        .asMap()
        .entries
        .map((e) => e.value.copyWith(order: e.key + 1))
        .toList(growable: false);
  }

  bool _same(LatLng a, LatLng b) {
    return (a.latitude - b.latitude).abs() < 0.0001 &&
        (a.longitude - b.longitude).abs() < 0.0001;
  }
}

extension on RideStop {
  RideStop copyWith({
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    int? order,
  }) {
    return RideStop(
      name: name ?? this.name,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      order: order ?? this.order,
    );
  }
}
