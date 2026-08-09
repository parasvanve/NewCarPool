import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/errors/app_exception.dart';
import '../../core/utils/coordinate_utils.dart';
import '../../core/utils/location_permission_helper.dart';
import '../../core/utils/location_display_formatter.dart';
import '../../models/ride_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/ride_provider.dart';
import '../../services/map_service.dart';

//new code
import 'package:go_router/go_router.dart';
import '../../core/constants/app_routes.dart';
import '../../core/network/token_store.dart';
import '../../core/routing/pending_ride_redirect.dart';
import '../../services/auth_service.dart';

// class BookingFlowScreen extends StatefulWidget {
//   const BookingFlowScreen({super.key, this.extra});

//   final Object? extra;

//   @override
//   State<BookingFlowScreen> createState() => _BookingFlowScreenState();
// }

//new code
class BookingFlowScreen extends StatefulWidget {
  const BookingFlowScreen(
      {super.key, this.extra, this.cameFromSharedLink = false});

  final Object? extra;
  final bool cameFromSharedLink;

  @override
  State<BookingFlowScreen> createState() => _BookingFlowScreenState();
}

enum _BookingMapPickMode { pickup, drop }

class _BookingFlowScreenState extends State<BookingFlowScreen> {
  int _seats = 1;
  bool _submitting = false;
  GeoPoint? _pickupPoint;
  GeoPoint? _dropPoint;
  bool _pickupLockedFromSelection = false;
  bool _dropLockedFromSelection = false;
  _BookingMapPickMode _mapPickMode = _BookingMapPickMode.pickup;
  final Completer<gmap.GoogleMapController> _mapController = Completer();
  LatLng _mapCenter = const LatLng(22.7196, 75.8577);
  bool _canShowMyLocation = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeMapCenter());
  }

  Future<void> _initializeMapCenter() async {
    final location = await LocationPermissionHelper.currentOrFallback();
    if (!mounted) return;
    if (_pickupLockedFromSelection) return;
    final point = LatLng(location.latitude, location.longitude);
    setState(() {
      _mapCenter = point;
      _canShowMyLocation = location.hasPermission;
    });
    _moveMap(point, 14.5);
    if (location.message != null) {
      _showError(location.message!);
    }
    if (!location.isDefaultFallback) {
      await _setCurrentLocationPickup(location);
    }
  }

  Future<void> _pickPickupFromSearch() async {
    final selected = await _openSearchSheet(
      title: 'Select Boarding Point',
      type: 'pickup',
    );
    if (selected == null || !mounted) return;
    final point = LatLng(selected.latitude, selected.longitude);
    setState(() {
      _pickupPoint = selected;
      _pickupLockedFromSelection = true;
      _mapCenter = point;
      _mapPickMode = _BookingMapPickMode.pickup;
    });
    _logGeoPoint(
      step: 'provider-state',
      type: 'pickup',
      point: selected,
    );
    _moveMap(point, 14.5, type: 'pickup');
  }

  Future<GeoPoint?> _openSearchSheet({
    required String title,
    required String type,
  }) {
    final searchCtrl = TextEditingController();
    final suggestions = <Map<String, dynamic>>[];
    Timer? searchDebounce;
    bool loading = false;
    String? error;

    return showModalBottomSheet<GeoPoint>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setInnerState) {
            Future<void> search(String value) async {
              final q = value.trim();
              if (q.length < 3) {
                setInnerState(() {
                  suggestions.clear();
                  error = null;
                });
                return;
              }
              setInnerState(() {
                loading = true;
                error = null;
              });
              try {
                final results = await context.read<MapService>().geocode(
                      q,
                      latitude: _mapCenter.latitude,
                      longitude: _mapCenter.longitude,
                    );
                final mapped = results
                    .take(5)
                    .map((e) => LocationDisplayFormatter.fromSearchSuggestion(
                        Map<String, dynamic>.from(e as Map)))
                    .toList(growable: false);
                setInnerState(() {
                  suggestions
                    ..clear()
                    ..addAll(mapped);
                });
              } catch (_) {
                setInnerState(() => error = 'Failed to load suggestions.');
              } finally {
                setInnerState(() => loading = false);
              }
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                14,
                16,
                MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  TextField(
                    controller: searchCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Search location',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) {
                      searchDebounce?.cancel();
                      searchDebounce = Timer(
                        const Duration(milliseconds: 600),
                        () => search(value),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  if (loading) const LinearProgressIndicator(),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(error!,
                          style: const TextStyle(color: Colors.red)),
                    ),
                  if (suggestions.isNotEmpty)
                    SizedBox(
                      height: 280,
                      child: ListView.builder(
                        itemCount: suggestions.length,
                        itemBuilder: (_, i) {
                          final item = suggestions[i];
                          return ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            leading: const Icon(Icons.place_outlined),
                            title: Text(
                              LocationDisplayFormatter.title(item),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              LocationDisplayFormatter.subtitleWithDistance(
                                  item),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () {
                              final selected = _geoPointFromSuggestion(
                                item,
                                type: type,
                              );
                              if (selected == null) return;
                              Navigator.pop(
                                context,
                                selected,
                              );
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() => searchDebounce?.cancel());
  }

  GeoPoint? _geoPointFromSuggestion(
    Map<String, dynamic> item, {
    required String type,
  }) {
    final latitude = (item['latitude'] as num?)?.toDouble();
    final longitude = (item['longitude'] as num?)?.toDouble();
    final name = LocationDisplayFormatter.title(item);
    if (latitude == null ||
        longitude == null ||
        !CoordinateUtils.isValid(
          latitude: latitude,
          longitude: longitude,
        )) {
      _showError('Invalid location coordinates.');
      return null;
    }

    CoordinateUtils.logSelectedSuggestion(
      type: type,
      name: name,
      latitude: latitude,
      longitude: longitude,
    );
    return GeoPoint(
      name: name,
      address: item['formattedAddress']?.toString() ??
          item['displayName']?.toString(),
      latitude: latitude,
      longitude: longitude,
    );
  }

  Future<void> _useCurrentLocation() async {
    try {
      final location = await LocationPermissionHelper.currentOrFallback();
      if (location.message != null) {
        _showError(location.message!);
      }
      if (location.isDefaultFallback) return;
      await _setCurrentLocationPickup(location);
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _setCurrentLocationPickup(LocationPoint location) async {
    if (!CoordinateUtils.isValid(
      latitude: location.latitude,
      longitude: location.longitude,
    )) {
      _showError('Invalid location coordinates.');
      return;
    }

    final point = LatLng(location.latitude, location.longitude);
    String address = 'Current location';
    try {
      address = await context.read<MapService>().reverseGeocode(
            latitude: location.latitude,
            longitude: location.longitude,
          );
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _pickupPoint = GeoPoint(
        name: LocationDisplayFormatter.title({
          'displayName': address,
          'formattedAddress': address,
        }),
        address: address,
        latitude: location.latitude,
        longitude: location.longitude,
      );
      _pickupLockedFromSelection = true;
      _mapCenter = point;
      _mapPickMode = _BookingMapPickMode.pickup;
      _canShowMyLocation = location.hasPermission;
    });
    _logGeoPoint(
      step: 'provider-state',
      type: 'current',
      point: _pickupPoint!,
    );
    _moveMap(point, 14.5, type: 'current');
  }

  void _moveMap(
    LatLng point,
    double zoom, {
    String? type,
  }) {
    if (!_mapController.isCompleted) return;
    _mapController.future.then((controller) {
      CoordinateUtils.logCameraPoint(
        type: type ?? _mapPickMode.name,
        latitude: point.latitude,
        longitude: point.longitude,
        zoom: zoom,
      );
      controller.animateCamera(
        gmap.CameraUpdate.newLatLngZoom(
          gmap.LatLng(point.latitude, point.longitude),
          zoom,
        ),
      );
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _setPointFromMap(LatLng point) async {
    if (!CoordinateUtils.isValid(
      latitude: point.latitude,
      longitude: point.longitude,
    )) {
      _showError('Invalid location coordinates.');
      return;
    }

    if (_mapPickMode == _BookingMapPickMode.pickup &&
        _pickupLockedFromSelection) {
      _showError(
        'Pickup is locked to the selected location. Search again to edit it.',
      );
      return;
    }
    if (_mapPickMode == _BookingMapPickMode.drop && _dropLockedFromSelection) {
      _showError(
        'Drop is locked to the selected location. Search again to edit it.',
      );
      return;
    }

    final suggestion = await _reversePoint(point);
    final geo = GeoPoint(
      name: LocationDisplayFormatter.title(suggestion),
      address: suggestion['formattedAddress']?.toString() ??
          suggestion['displayName']?.toString(),
      latitude: point.latitude,
      longitude: point.longitude,
    );
    if (!mounted) return;
    if (_mapPickMode == _BookingMapPickMode.pickup &&
        _dropPoint != null &&
        _isSame(geo, _dropPoint!)) {
      _showError('Pickup and drop cannot be same point.');
      return;
    }
    if (_mapPickMode == _BookingMapPickMode.drop &&
        _pickupPoint != null &&
        _isSame(geo, _pickupPoint!)) {
      _showError('Pickup and drop cannot be same point.');
      return;
    }

    setState(() {
      _mapCenter = point;
      if (_mapPickMode == _BookingMapPickMode.pickup) {
        _pickupPoint = geo;
      } else {
        _dropPoint = geo;
      }
    });
    _logGeoPoint(
      step: 'provider-state',
      type: _mapPickMode.name,
      point: geo,
    );
  }

  Future<Map<String, dynamic>> _reversePoint(LatLng point) async {
    String fullAddress = 'Selected location';
    try {
      fullAddress = await context.read<MapService>().reverseGeocode(
            latitude: point.latitude,
            longitude: point.longitude,
          );
    } catch (_) {}
    return LocationDisplayFormatter.fromSearchSuggestion({
      'displayName': fullAddress,
      'formattedAddress': fullAddress,
      'latitude': point.latitude,
      'longitude': point.longitude,
    });
  }

  bool _isSame(GeoPoint a, GeoPoint b) {
    return (a.latitude - b.latitude).abs() < 0.0001 &&
        (a.longitude - b.longitude).abs() < 0.0001;
  }

  void _logGeoPoint({
    required String step,
    required String type,
    required GeoPoint point,
  }) {
    CoordinateUtils.logStatePoint(
      step: step,
      type: type,
      name: point.name,
      latitude: point.latitude,
      longitude: point.longitude,
    );
    CoordinateUtils.logMarkerPoint(
      type: type,
      latitude: point.latitude,
      longitude: point.longitude,
    );
  }

  gmap.Marker _marker({
    required String id,
    required String type,
    required double latitude,
    required double longitude,
    required double hue,
    int zIndexInt = 1,
    gmap.InfoWindow infoWindow = const gmap.InfoWindow(),
  }) {
    CoordinateUtils.logMarkerPoint(
      type: type,
      latitude: latitude,
      longitude: longitude,
    );
    return gmap.Marker(
      markerId: gmap.MarkerId(id),
      position: gmap.LatLng(latitude, longitude),
      icon: gmap.BitmapDescriptor.defaultMarkerWithHue(hue),
      zIndexInt: zIndexInt,
      infoWindow: infoWindow,
    );
  }

  //new code
  Future<bool> _ensureLoggedIn(BuildContext context, String rideId) async {
    final token = await context.read<TokenStore>().accessToken;
    if (token != null) return true;

    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Enter your email to continue'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.emailAddress,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'you@example.com'),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
    if (email == null || email.trim().isEmpty || !mounted) return false;

    try {
      final exists =
          await context.read<AuthService>().emailExists(email.trim());
      if (!mounted) return false;
      PendingRideRedirect.set(rideId);
      await context.push(exists ? AppRoutes.login : AppRoutes.register);
    } on Object catch (error) {
      if (!mounted) return false;
      _showError(error is AppException
          ? error.message
          : 'Something went wrong. Please try again.');
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final ride = widget.extra is RideOffer ? widget.extra as RideOffer : null;
    final myUserId = context.watch<AuthProvider>().session?.userId;
    final isMyRide =
        ride != null && myUserId != null && myUserId == ride.driverId;

    if (ride == null) {
      return const Scaffold(
        body: Center(child: Text('Ride details unavailable for booking.')),
      );
    }

    if (isMyRide) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'You are the driver of this ride. Booking is disabled.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final routePoints = <GeoPoint>[
      ride.origin,
      ...ride.intermediateStops.map(
        (s) => GeoPoint(
          name: s.name,
          address: s.address,
          latitude: s.latitude,
          longitude: s.longitude,
        ),
      ),
      ride.destination,
    ];

    final dropOptions = <GeoPoint>[
      ...ride.intermediateStops.map(
        (s) => GeoPoint(
          name: s.name,
          address: s.address,
          latitude: s.latitude,
          longitude: s.longitude,
        ),
      ),
      ride.destination,
    ];

    final total = (ride.pricePerSeat * _seats).toStringAsFixed(2);
    final routeLinePoints = <gmap.LatLng>[
      gmap.LatLng(ride.origin.latitude, ride.origin.longitude),
      ...ride.intermediateStops
          .map((s) => gmap.LatLng(s.latitude, s.longitude)),
      gmap.LatLng(ride.destination.latitude, ride.destination.longitude),
    ];

    // return Scaffold(
    //   appBar: AppBar(title: const Text('Confirm Booking')),

    //new code
    return PopScope(
      canPop: !widget.cameFromSharedLink,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) context.go(AppRoutes.dashboard);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Confirm Booking')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      LocationDisplayFormatter.routeTitle(
                        ride.origin,
                        ride.destination,
                      ),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                        'Driver: ${ride.driverName.isEmpty ? 'Driver' : ride.driverName}'),
                    const SizedBox(height: 2),
                    Text('Available seats: ${ride.availableSeats}'),
                    const SizedBox(height: 2),
                    Text('Price per seat: INR ${ride.pricePerSeat}'),
                    const SizedBox(height: 2),
                    Text(
                      'Vehicle: ${ride.vehicleName ?? 'Vehicle'} ${ride.vehicleNumber ?? ''}'
                          .trim(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select on Map',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Pickup'),
                          selected: _mapPickMode == _BookingMapPickMode.pickup,
                          onSelected: (_) => setState(
                              () => _mapPickMode = _BookingMapPickMode.pickup),
                        ),
                        ChoiceChip(
                          label: const Text('Drop'),
                          selected: _mapPickMode == _BookingMapPickMode.drop,
                          onSelected: (_) => setState(
                              () => _mapPickMode = _BookingMapPickMode.drop),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 230,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: gmap.GoogleMap(
                          initialCameraPosition: gmap.CameraPosition(
                            target: gmap.LatLng(
                                _mapCenter.latitude, _mapCenter.longitude),
                            zoom: 12.5,
                          ),
                          onMapCreated: (c) {
                            if (!_mapController.isCompleted) {
                              _mapController.complete(c);
                            }
                          },
                          onTap: (p) =>
                              _setPointFromMap(LatLng(p.latitude, p.longitude)),
                          myLocationEnabled: _canShowMyLocation,
                          myLocationButtonEnabled: false,
                          zoomControlsEnabled: true,
                          markers: {
                            _marker(
                              id: 'ride-origin',
                              type: 'pickup',
                              latitude: ride.origin.latitude,
                              longitude: ride.origin.longitude,
                              hue: gmap.BitmapDescriptor.hueGreen,
                            ),
                            _marker(
                              id: 'ride-destination',
                              type: 'destination',
                              latitude: ride.destination.latitude,
                              longitude: ride.destination.longitude,
                              hue: gmap.BitmapDescriptor.hueRed,
                            ),
                            if (_pickupPoint != null)
                              _marker(
                                id: 'selected-pickup',
                                type: 'pickup',
                                latitude: _pickupPoint!.latitude,
                                longitude: _pickupPoint!.longitude,
                                hue: gmap.BitmapDescriptor.hueGreen,
                                zIndexInt:
                                    _mapPickMode == _BookingMapPickMode.pickup
                                        ? 3
                                        : 1,
                              ),
                            if (_dropPoint != null)
                              _marker(
                                id: 'selected-drop',
                                type: 'drop',
                                latitude: _dropPoint!.latitude,
                                longitude: _dropPoint!.longitude,
                                hue: gmap.BitmapDescriptor.hueBlue,
                                zIndexInt:
                                    _mapPickMode == _BookingMapPickMode.drop
                                        ? 3
                                        : 1,
                              ),
                            ...ride.intermediateStops.asMap().entries.map(
                                  (e) => _marker(
                                    id: 'ride-stop-${e.key}',
                                    type: 'stop-${e.key + 1}',
                                    latitude: e.value.latitude,
                                    longitude: e.value.longitude,
                                    hue: gmap.BitmapDescriptor.hueBlue,
                                    infoWindow: gmap.InfoWindow(
                                      title: 'Stop ${e.key + 1}',
                                      snippet: e.value.name,
                                    ),
                                  ),
                                ),
                          },
                          polylines: {
                            if (routeLinePoints.length > 1)
                              gmap.Polyline(
                                polylineId: const gmap.PolylineId('route'),
                                points: routeLinePoints,
                                width: 4,
                                color: const Color(0xFF4F46E5),
                              ),
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Boarding / Pickup Point',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    if (_pickupPoint != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_pickupPoint!.name),
                            Text(
                              LocationDisplayFormatter.compactAddress(
                                  _pickupPoint),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _useCurrentLocation,
                          icon: const Icon(Icons.my_location),
                          label: const Text('Use Current Location'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _pickPickupFromSearch,
                          icon: const Icon(Icons.search),
                          label: const Text('Search Location'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => setState(
                              () => _mapPickMode = _BookingMapPickMode.pickup),
                          icon: const Icon(Icons.map_outlined),
                          label: const Text('Select on Map'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('Or select from route stops'),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: routePoints
                          .map(
                            (p) => ChoiceChip(
                              label: Text(p.name),
                              selected: _pickupPoint?.name == p.name &&
                                  _pickupPoint?.latitude == p.latitude,
                              onSelected: (_) {
                                final point = LatLng(p.latitude, p.longitude);
                                setState(() {
                                  _pickupPoint = p;
                                  _pickupLockedFromSelection = false;
                                  _mapCenter = point;
                                  _mapPickMode = _BookingMapPickMode.pickup;
                                });
                                _logGeoPoint(
                                  step: 'provider-state',
                                  type: 'pickup',
                                  point: p,
                                );
                                _moveMap(point, 14.5, type: 'pickup');
                              },
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Drop Point',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _dropPoint == null
                          ? null
                          : '${_dropPoint!.name}|${_dropPoint!.latitude}|${_dropPoint!.longitude}',
                      hint: const Text('Select drop point'),
                      items: dropOptions
                          .map(
                            (p) => DropdownMenuItem<String>(
                              value: '${p.name}|${p.latitude}|${p.longitude}',
                              child:
                                  Text(p.name, overflow: TextOverflow.ellipsis),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        final point = dropOptions.firstWhere(
                          (p) =>
                              '${p.name}|${p.latitude}|${p.longitude}' == value,
                        );
                        setState(() {
                          _dropPoint = point;
                          _dropLockedFromSelection = false;
                          _mapCenter = LatLng(point.latitude, point.longitude);
                          _mapPickMode = _BookingMapPickMode.drop;
                        });
                        _logGeoPoint(
                          step: 'provider-state',
                          type: 'drop',
                          point: point,
                        );
                        _moveMap(
                          LatLng(point.latitude, point.longitude),
                          14.5,
                          type: 'drop',
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => setState(
                          () => _mapPickMode = _BookingMapPickMode.drop),
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Select Drop on Map'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Seats',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    Row(
                      children: [
                        IconButton(
                          onPressed: _seats > 1
                              ? () => setState(() => _seats--)
                              : null,
                          icon: const Icon(Icons.remove),
                        ),
                        Text('$_seats',
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        IconButton(
                          onPressed: _seats < ride.availableSeats
                              ? () => setState(() => _seats++)
                              : null,
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text('Total: INR $total',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _submitting
                  ? null
                  // : () async {
                  //     if (_pickupPoint == null) {

                  //new code
                  : () async {
                      final alreadyAuthed =
                          await _ensureLoggedIn(context, ride.id);
                      if (!alreadyAuthed) return;

                      if (_pickupPoint == null) {
                        _showError('Pickup point is required');
                        return;
                      }
                      if (_dropPoint == null) {
                        _showError('Drop point is required');
                        return;
                      }
                      if (_seats < 1) {
                        _showError('Select at least 1 seat');
                        return;
                      }
                      if (_seats > ride.availableSeats) {
                        _showError('Selected seats exceed available seats');
                        return;
                      }

                      final bookingProvider = context.read<BookingProvider>();
                      final rideProvider = context.read<RideProvider>();
                      final notificationProvider =
                          context.read<NotificationProvider>();
                      final messenger = ScaffoldMessenger.of(context);
                      final navigator = Navigator.of(context);
                      setState(() => _submitting = true);
                      try {
                        await bookingProvider.request(
                          rideOfferId: ride.id,
                          seatsBooked: _seats,
                          pickup: _pickupPoint,
                          drop: _dropPoint,
                        );
                        if (!mounted) return;
                        await rideProvider.loadUpcomingActive();
                        await bookingProvider.loadHistory();
                        await notificationProvider.loadMine();
                        await notificationProvider.loadUnreadCount();
                        // messenger.showSnackBar(
                        //   const SnackBar(
                        //       content: Text('Ride booked successfully')),
                        // );
                        // navigator.pop(true);

                        //new code
                        messenger.showSnackBar(
                          const SnackBar(
                              content: Text('Ride booked successfully')),
                        );
                        // if (navigator.canPop()) {
                        //   navigator.pop(true);
                        // } else if (mounted) {
                        //   context.go(AppRoutes.dashboard);
                        // }

                        if (!widget.cameFromSharedLink) {
                          navigator.pop(true);
                        } else if (mounted) {
                          context.go(AppRoutes.dashboard);
                        }
                      } on DioException catch (error) {
                        if (!mounted) return;
                        final message = AppException.fromDio(error).message;
                        messenger.showSnackBar(
                          SnackBar(
                              content: Text(message),
                              backgroundColor: Colors.red),
                        );
                      } catch (error) {
                        if (!mounted) return;
                        messenger.showSnackBar(
                          SnackBar(
                              content: Text(error.toString()),
                              backgroundColor: Colors.red),
                        );
                      } finally {
                        if (mounted) setState(() => _submitting = false);
                      }
                    },
              child: Text(_submitting ? 'Booking...' : 'Confirm Booking'),
            ),
          ],
        ),
      ),
    );
  }
}
