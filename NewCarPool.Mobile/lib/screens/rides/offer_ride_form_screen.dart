import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_routes.dart';
import '../../core/utils/location_display_formatter.dart';
import '../../core/utils/coordinate_utils.dart';
import '../../core/errors/app_exception.dart';
import '../../core/widgets/app_design_system.dart';
import '../../models/ride_models.dart';
import '../../providers/offer_ride_provider.dart';
import '../../providers/ride_provider.dart';
import '../../providers/vehicle_provider.dart';
import '../../services/map_service.dart';
import '../vehicles/vehicle_screens.dart';
import 'widgets/ride_form_shared_widgets.dart';

class OfferRideFormScreen extends StatefulWidget {
  const OfferRideFormScreen({super.key});

  @override
  State<OfferRideFormScreen> createState() => _OfferRideFormScreenState();
}

enum _OfferMapPickMode { pickup, destination, stop }

class _OfferRideFormScreenState extends State<OfferRideFormScreen> {
  static const _accent = AppDesignTokens.brandStart;

  final _formKey = GlobalKey<FormState>();
  final _pickupCtrl = TextEditingController();
  final _destCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _mapCtrl = Completer<gmap.GoogleMapController>();

  DateTime? _date;
  TimeOfDay? _time;
  String? _vehicleId;
  int _seats = 3;
  LatLng _center = const LatLng(22.7196, 75.8577);
  bool _isMapReady = false;
  bool _isSubmitting = false;
  Timer? _searchDebounce;
  String? _destinationAddress;
  Map<String, dynamic>? _pickupSelection;
  Map<String, dynamic>? _destinationSelection;
  bool _pickupLockedFromSelection = false;
  bool _destinationLockedFromSelection = false;
  _OfferMapPickMode _mapPickMode = _OfferMapPickMode.pickup;
  String? _vehicleError;

  @override
  void initState() {
    super.initState();
    context.read<VehicleProvider>().loadMine();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final route = context.read<OfferRideProvider>();
      await route.detectCurrentLocation();
      if (!mounted) return;
      if (_pickupLockedFromSelection && _pickupSelection != null) {
        final lockedPoint = _pointFromSuggestion(
          _pickupSelection!,
          expectedType: 'pickup',
        );
        if (lockedPoint != null) {
          await route.setPickup(lockedPoint);
          _logProviderPoint(
            type: 'pickup',
            name: LocationDisplayFormatter.title(_pickupSelection),
            point: lockedPoint,
          );
        }
        return;
      }
      if (route.routeError != null) {
        _showInlineWarning(route.routeError!);
      }
      if (route.pickup != null) {
        _center = route.pickup!;
        _pickupCtrl.text = route.pickupAddress;
        _pickupSelection = LocationDisplayFormatter.fromSearchSuggestion({
          'displayName': route.pickupAddress,
          'formattedAddress': route.pickupAddress,
          'latitude': route.pickup!.latitude,
          'longitude': route.pickup!.longitude,
        });
        _moveMap(route.pickup!, 14.3);
      }
    });
  }

  @override
  void dispose() {
    _pickupCtrl.dispose();
    _destCtrl.dispose();
    _notesCtrl.dispose();
    _priceCtrl.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _moveMap(LatLng p, double z) {
    if (!_isMapReady) return;
    _mapCtrl.future.then((c) {
      CoordinateUtils.logCameraPoint(
        type: _mapPickMode.name,
        latitude: p.latitude,
        longitude: p.longitude,
        zoom: z,
      );
      c.animateCamera(gmap.CameraUpdate.newLatLngZoom(
          gmap.LatLng(p.latitude, p.longitude), z));
    });
  }

  Future<Map<String, dynamic>?> _openLocationPicker({
    required String title,
    required bool allowCurrentLocation,
  }) async {
    final searchCtrl = TextEditingController();
    final localSuggestions = <Map<String, dynamic>>[];
    bool isLoading = false;
    String? error;

    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setInner) {
            Future<void> doSearch(String value) async {
              final q = value.trim();
              if (q.length < 3) {
                setInner(() {
                  localSuggestions.clear();
                  error = null;
                });
                return;
              }
              setInner(() {
                isLoading = true;
                error = null;
              });
              try {
                final bias =
                    context.read<OfferRideProvider>().pickup ?? _center;
                final results = await context.read<MapService>().geocode(
                      q,
                      latitude: bias.latitude,
                      longitude: bias.longitude,
                    );
                final mapped = results
                    .take(5)
                    .map((e) => LocationDisplayFormatter.fromSearchSuggestion(
                          Map<String, dynamic>.from(e as Map),
                        ))
                    .toList(growable: false);
                setInner(() {
                  localSuggestions
                    ..clear()
                    ..addAll(mapped);
                });
              } catch (_) {
                setInner(() => error = 'Failed to load suggestions.');
              } finally {
                setInner(() => isLoading = false);
              }
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                  16, 14, 16, MediaQuery.of(context).viewInsets.bottom + 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(title,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w700)),
                      ),
                      IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close)),
                    ],
                  ),
                  TextField(
                    controller: searchCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Search location',
                        prefixIcon: Icon(Icons.search)),
                    onChanged: (v) {
                      _searchDebounce?.cancel();
                      _searchDebounce = Timer(
                          const Duration(milliseconds: 600), () => doSearch(v));
                    },
                  ),
                  const SizedBox(height: 8),
                  if (allowCurrentLocation)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () async {
                          final p = context.read<OfferRideProvider>();
                          await p.detectCurrentLocation();
                          if (!context.mounted || p.pickup == null) return;
                          Navigator.pop(context, {
                            'selectionType': 'current',
                            'displayName': p.pickupAddress,
                            'latitude': p.pickup!.latitude,
                            'longitude': p.pickup!.longitude,
                          });
                        },
                        icon: const Icon(Icons.my_location),
                        label: const Text('Use current location'),
                      ),
                    ),
                  if (isLoading) const LinearProgressIndicator(),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(error!,
                          style: const TextStyle(color: Colors.red)),
                    ),
                  if (localSuggestions.isNotEmpty)
                    SizedBox(
                      height: 240,
                      child: ListView.builder(
                        itemCount: localSuggestions.length,
                        itemBuilder: (_, i) {
                          final s = localSuggestions[i];
                          return ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            leading: const Icon(Icons.place_outlined),
                            title: Text(
                              LocationDisplayFormatter.title(s),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              LocationDisplayFormatter.subtitleWithDistance(s),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => Navigator.pop(context, s),
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
    );
  }

  Future<void> _pickPickup() async {
    final selected = await _openLocationPicker(
        title: 'Select Pickup Location', allowCurrentLocation: true);
    if (selected == null) return;
    if (!mounted) return;
    final point = _pointFromSuggestion(selected, expectedType: 'pickup');
    if (point == null) return;
    final route = context.read<OfferRideProvider>();
    await route.setPickup(point);
    _pickupSelection = selected;
    _pickupLockedFromSelection = true;
    _pickupCtrl.text =
        selected['formattedAddress']?.toString() ?? route.pickupAddress;
    _logProviderPoint(
      type: selected['selectionType']?.toString() ?? 'pickup',
      name: LocationDisplayFormatter.title(selected),
      point: route.pickup ?? point,
    );
    _moveMap(point, 14.3);
    setState(() => _mapPickMode = _OfferMapPickMode.pickup);
  }

  Future<void> _pickDestination() async {
    final selected = await _openLocationPicker(
        title: 'Select Final Destination', allowCurrentLocation: false);
    if (selected == null) return;
    if (!mounted) return;
    final point = _pointFromSuggestion(selected, expectedType: 'destination');
    if (point == null) return;
    final route = context.read<OfferRideProvider>();
    await route.setDestination(point);
    _destinationSelection = selected;
    _destinationLockedFromSelection = true;
    _destCtrl.text = selected['formattedAddress']?.toString() ?? 'Destination';
    _destinationAddress = _destCtrl.text;
    _logProviderPoint(
      type: 'destination',
      name: LocationDisplayFormatter.title(selected),
      point: route.destination ?? point,
    );
    _moveMap(point, 14.3);
    setState(() => _mapPickMode = _OfferMapPickMode.destination);
  }

  Future<void> _pickStop({int? index}) async {
    final selected = await _openLocationPicker(
        title: index == null ? 'Add Drop Point' : 'Edit Drop Point',
        allowCurrentLocation: false);
    if (selected == null) return;
    if (!mounted) return;
    final route = context.read<OfferRideProvider>();
    final point = _pointFromSuggestion(selected, expectedType: 'stop');
    if (point == null) return;
    if (route.pickup != null && _isSamePoint(point, route.pickup!)) {
      _showInlineWarning('Drop point cannot be same as pickup.');
      return;
    }
    if (route.destination != null && _isSamePoint(point, route.destination!)) {
      _showInlineWarning('Drop point cannot be same as destination.');
      return;
    }
    final duplicateStop = route.stops.asMap().entries.any((entry) {
      if (index != null && entry.key == index) return false;
      return _isSamePoint(
        point,
        LatLng(entry.value.latitude, entry.value.longitude),
      );
    });
    if (duplicateStop) {
      _showInlineWarning('Duplicate drop point is not allowed.');
      return;
    }
    final name = LocationDisplayFormatter.title(selected);
    final address = selected['formattedAddress']?.toString() ?? name;
    final stop = RideStop(
        name: name,
        address: address,
        latitude: point.latitude,
        longitude: point.longitude,
        order: (index ?? route.stops.length) + 1);
    final message = index == null
        ? await route.addStop(stop)
        : await route.updateStop(index, stop);
    if (message != null) _showInlineWarning(message);
    if (message == null && mounted) {
      _logProviderPoint(
        type: 'stop',
        name: name,
        point: point,
      );
      _moveMap(point, 14.3);
      setState(() => _mapPickMode = _OfferMapPickMode.stop);
    }
  }

  Future<void> _applyMapSelection(LatLng point) async {
    if (!CoordinateUtils.isValid(
      latitude: point.latitude,
      longitude: point.longitude,
    )) {
      _showInlineWarning('Invalid location coordinates.');
      return;
    }

    final route = context.read<OfferRideProvider>();
    switch (_mapPickMode) {
      case _OfferMapPickMode.pickup:
        if (_pickupLockedFromSelection) {
          _showInlineWarning(
            'Pickup is locked to the selected location. Search again to edit it.',
          );
          return;
        }
        if (route.destination != null &&
            _isSamePoint(point, route.destination!)) {
          _showInlineWarning('Pickup and destination cannot be same.');
          return;
        }
        await route.setPickup(point);
        final suggestion = await _reverseSuggestion(point);
        _pickupSelection = suggestion;
        _pickupCtrl.text =
            suggestion['formattedAddress']?.toString() ?? route.pickupAddress;
        _logProviderPoint(
          type: 'pickup',
          name: LocationDisplayFormatter.title(suggestion),
          point: route.pickup ?? point,
        );
        break;
      case _OfferMapPickMode.destination:
        if (_destinationLockedFromSelection) {
          _showInlineWarning(
            'Destination is locked to the selected location. Search again to edit it.',
          );
          return;
        }
        if (route.pickup != null && _isSamePoint(point, route.pickup!)) {
          _showInlineWarning('Pickup and destination cannot be same.');
          return;
        }
        await route.setDestination(point);
        final suggestion = await _reverseSuggestion(point);
        _destinationSelection = suggestion;
        _destCtrl.text =
            suggestion['formattedAddress']?.toString() ?? 'Destination';
        _destinationAddress = _destCtrl.text;
        _logProviderPoint(
          type: 'destination',
          name: LocationDisplayFormatter.title(suggestion),
          point: route.destination ?? point,
        );
        break;
      case _OfferMapPickMode.stop:
        if (route.pickup != null && _isSamePoint(point, route.pickup!)) {
          _showInlineWarning('Drop point cannot be same as pickup.');
          return;
        }
        if (route.destination != null &&
            _isSamePoint(point, route.destination!)) {
          _showInlineWarning('Drop point cannot be same as destination.');
          return;
        }
        if (route.stops.any((stop) =>
            _isSamePoint(point, LatLng(stop.latitude, stop.longitude)))) {
          _showInlineWarning('Duplicate drop point is not allowed.');
          return;
        }
        final suggestion = await _reverseSuggestion(point);
        final stopName = LocationDisplayFormatter.title(suggestion);
        final stopAddress =
            suggestion['formattedAddress']?.toString() ?? stopName;
        final stop = RideStop(
          name: stopName,
          address: stopAddress,
          latitude: point.latitude,
          longitude: point.longitude,
          order: route.stops.length + 1,
        );
        final message = await route.addStop(stop);
        if (message != null) {
          _showInlineWarning(message);
          return;
        }
        _logProviderPoint(
          type: 'stop',
          name: stopName,
          point: point,
        );
        break;
    }
    if (!mounted) return;
    setState(() {});
  }

  LatLng? _pointFromSuggestion(
    Map<String, dynamic> suggestion, {
    required String expectedType,
  }) {
    final latitude = (suggestion['latitude'] as num?)?.toDouble();
    final longitude = (suggestion['longitude'] as num?)?.toDouble();
    final name = LocationDisplayFormatter.title(suggestion);
    final selectedType =
        suggestion['selectionType']?.toString() ?? expectedType;
    if (latitude == null ||
        longitude == null ||
        !CoordinateUtils.isValid(
          latitude: latitude,
          longitude: longitude,
        )) {
      _showInlineWarning('Invalid location coordinates.');
      return null;
    }

    CoordinateUtils.logSelectedSuggestion(
      type: selectedType,
      name: name,
      latitude: latitude,
      longitude: longitude,
    );
    return LatLng(latitude, longitude);
  }

  void _logProviderPoint({
    required String type,
    required String name,
    required LatLng point,
  }) {
    CoordinateUtils.logStatePoint(
      step: 'provider-state',
      type: type,
      name: name,
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

  Future<Map<String, dynamic>> _reverseSuggestion(LatLng point) async {
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

  bool _isSamePoint(LatLng a, LatLng b) {
    return (a.latitude - b.latitude).abs() < 0.0001 &&
        (a.longitude - b.longitude).abs() < 0.0001;
  }

  Future<void> _useCurrentLocationAsPickup() async {
    final route = context.read<OfferRideProvider>();
    await route.detectCurrentLocation();
    if (!mounted) return;
    if (route.routeError != null) {
      _showInlineWarning(route.routeError!);
    }
    if (route.pickup == null) return;

    _pickupSelection = LocationDisplayFormatter.fromSearchSuggestion({
      'selectionType': 'current',
      'displayName': route.pickupAddress,
      'formattedAddress': route.pickupAddress,
      'latitude': route.pickup!.latitude,
      'longitude': route.pickup!.longitude,
    });
    _pickupCtrl.text = route.pickupAddress;
    _pickupLockedFromSelection = true;
    _logProviderPoint(
      type: 'current',
      name: LocationDisplayFormatter.title(_pickupSelection),
      point: route.pickup!,
    );
    setState(() => _mapPickMode = _OfferMapPickMode.pickup);
    _moveMap(route.pickup!, 15);
  }

  void _clearPickup() {
    final route = context.read<OfferRideProvider>();
    route.pickup = null;
    route.pickupAddress = '';
    route.routePoints = const [];
    route.distanceKm = null;
    route.etaMinutes = null;
    setState(() {
      _pickupCtrl.clear();
      _pickupSelection = null;
      _pickupLockedFromSelection = false;
      _mapPickMode = _OfferMapPickMode.pickup;
    });
  }

  void _clearDestination() {
    final route = context.read<OfferRideProvider>();
    route.destination = null;
    route.routePoints = const [];
    route.distanceKm = null;
    route.etaMinutes = null;
    setState(() {
      _destCtrl.clear();
      _destinationAddress = null;
      _destinationSelection = null;
      _destinationLockedFromSelection = false;
      _mapPickMode = _OfferMapPickMode.destination;
    });
  }

  List<LatLng> _visibleRoutePoints(OfferRideProvider route) {
    if (route.routePoints.length > 1) return route.routePoints;
    final points = <LatLng>[
      if (route.pickup != null) route.pickup!,
      ...route.stops.map((s) => LatLng(s.latitude, s.longitude)),
      if (route.destination != null) route.destination!,
    ];
    return points.length > 1 ? points : const [];
  }

  Future<void> _openStopsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) {
        return Consumer<OfferRideProvider>(
          builder: (context, route, __) => Padding(
            padding: EdgeInsets.fromLTRB(
                16, 14, 16, MediaQuery.of(context).viewInsets.bottom + 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  const Expanded(
                      child: Text('Manage Drop Points',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 18))),
                  IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close)),
                ]),
                TextButton.icon(
                  onPressed: (route.pickup == null || route.destination == null)
                      ? null
                      : () async {
                          Navigator.pop(context);
                          await _pickStop();
                        },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Drop Point'),
                ),
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: route.stops.length,
                  onReorder: (oldI, newI) async =>
                      route.reorderStops(oldI, newI),
                  itemBuilder: (_, i) {
                    final stop = route.stops[i];
                    return ListTile(
                      key: ValueKey(
                          'stop-$i-${stop.latitude}-${stop.longitude}'),
                      leading: CircleAvatar(
                          radius: 12,
                          child: Text('${i + 1}',
                              style: const TextStyle(fontSize: 12))),
                      title: Text(stop.name),
                      subtitle: Text(
                          '${stop.latitude.toStringAsFixed(4)}, ${stop.longitude.toStringAsFixed(4)}'),
                      onTap: () async {
                        Navigator.pop(context);
                        await _pickStop(index: i);
                      },
                      trailing: IconButton(
                          onPressed: () => route.removeStop(i),
                          icon: const Icon(Icons.delete_outline)),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openAddVehicle() async {
    final vehicleProvider = context.read<VehicleProvider>();
    final existingIds = vehicleProvider.vehicles.map((v) => v.id).toSet();

    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const VehicleFormScreen()));
    if (!mounted) return;

    try {
      await vehicleProvider.loadMine();
      if (!mounted) return;
      String? newVehicleId;
      for (final vehicle in vehicleProvider.vehicles) {
        if (!existingIds.contains(vehicle.id)) {
          newVehicleId = vehicle.id;
          break;
        }
      }
      setState(() {
        _vehicleId = newVehicleId ??
            (vehicleProvider.vehicles.isNotEmpty
                ? vehicleProvider.vehicles.first.id
                : null);
        _vehicleError = null;
      });
    } catch (_) {
      _showInlineWarning('Could not reload vehicles.');
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final route = context.read<OfferRideProvider>();
    if (route.pickup == null) {
      _showInlineWarning('Pickup location required');
      return;
    }
    if (route.destination == null || _destCtrl.text.trim().isEmpty) {
      _showInlineWarning('Destination required');
      return;
    }

    final vehicles = context.read<VehicleProvider>().vehicles;
    final vId = _vehicleId ?? (vehicles.isNotEmpty ? vehicles.first.id : null);
    if (vId == null || !vehicles.any((x) => x.id == vId)) {
      const message =
          'Please add or select a vehicle before publishing a ride.';
      setState(() => _vehicleError = message);
      _showInlineWarning(message);
      return;
    }
    setState(() => _vehicleError = null);

    if (_date == null) {
      _showInlineWarning('Date required');
      return;
    }
    if (_time == null) {
      _showInlineWarning('Time required');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_seats < 1) {
      _showInlineWarning('Seats required and at least 1');
      return;
    }

    final v = vehicles.firstWhere((x) => x.id == vId);
    // Prevent offering more seats than the vehicle capacity
    if (_seats > v.seats) {
      _showInlineWarning(
        'You can offer a maximum of ${v.seats} seats for this vehicle.',
      );
      return;
    }
    final selectedLocalDeparture = DateTime(
      _date!.year,
      _date!.month,
      _date!.day,
      _time!.hour,
      _time!.minute,
    );
    final departure = selectedLocalDeparture.toUtc();
    debugPrint(
      '[DepartureTime][SELECTED_LOCAL] local=${selectedLocalDeparture.toIso8601String()}',
    );
    debugPrint(
      '[DepartureTime][SEND_UTC] utc=${departure.toIso8601String()}',
    );
    final price = double.tryParse(_priceCtrl.text.trim());
    if (price == null || price <= 0) {
      _showInlineWarning('Price per seat required and greater than 0');
      return;
    }

    setState(() => _isSubmitting = true);
    final rideProvider = context.read<RideProvider>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await rideProvider.offerRide(
        vehicleId: v.id,
        origin: GeoPoint(
          name: LocationDisplayFormatter.title(_pickupSelection),
          address: _pickupCtrl.text.trim(),
          latitude: route.pickup!.latitude,
          longitude: route.pickup!.longitude,
        ),
        destination: GeoPoint(
          name: LocationDisplayFormatter.title(_destinationSelection),
          address: _destinationAddress ?? _destCtrl.text.trim(),
          latitude: route.destination!.latitude,
          longitude: route.destination!.longitude,
        ),
        departureTimeUtc: departure,
        seats: _seats,
        pricePerSeat: price,
        intermediateStops: route.stops,
        notes: _notesCtrl.text.trim(),
        vehicleName: v.vehicleName,
        vehicleNumber: v.vehicleNumber,
      );
      if (!mounted) return;
      await rideProvider.loadUpcomingActive();
      messenger.showSnackBar(
        const SnackBar(content: Text('Ride created successfully')),
      );
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;
      context.go(AppRoutes.dashboard);
    } on DioException catch (e) {
      _showInlineWarning(AppException.fromDio(e).message);
    } catch (e) {
      _showInlineWarning(e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showInlineWarning(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
  }

  Widget _buildPanelContent(OfferRideProvider route, VehicleProvider vehicles) {
    int maxSeats = 8;

    if (vehicles.vehicles.isNotEmpty) {
      final selectedVehicle = vehicles.vehicles.firstWhere(
        (v) => v.id == (_vehicleId ?? vehicles.vehicles.first.id),
      );

      maxSeats = selectedVehicle.seats;
    }
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x15000000),
                      blurRadius: 16,
                      offset: Offset(0, 8))
                ]),
            child: Column(
              children: [
                InkWell(
                  onTap: _pickPickup,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                        labelText: 'Pickup',
                        prefixIcon:
                            Icon(Icons.trip_origin, color: Colors.green)),
                    child: _pickupCtrl.text.trim().isEmpty
                        ? const Text('Select pickup location')
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                LocationDisplayFormatter.title(
                                    _pickupSelection),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                LocationDisplayFormatter.subtitle(
                                    _pickupSelection),
                                style: Theme.of(context).textTheme.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _pickDestination,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                        labelText: 'Final Destination',
                        prefixIcon: Icon(Icons.location_on, color: Colors.red)),
                    child: _destCtrl.text.trim().isEmpty
                        ? const Text('Select final destination')
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                LocationDisplayFormatter.title(
                                    _destinationSelection),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                LocationDisplayFormatter.subtitle(
                                    _destinationSelection),
                                style: Theme.of(context).textTheme.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(18)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(
                children: [
                  const Expanded(
                      child: Text('Route Timeline',
                          style: TextStyle(fontWeight: FontWeight.w700))),
                  TextButton.icon(
                      onPressed: _openStopsSheet,
                      icon: const Icon(Icons.add),
                      label: const Text('Stops')),
                ],
              ),
              RideTimeline(
                pickup: _pickupCtrl.text.trim().isEmpty
                    ? 'Pickup'
                    : LocationDisplayFormatter.title(_pickupSelection),
                stops: route.stops.map((s) => s.name).toList(),
                destination: _destCtrl.text.trim().isEmpty
                    ? 'Final destination'
                    : LocationDisplayFormatter.title(_destinationSelection),
              ),
            ]),
          ),
          const SizedBox(height: 8),
          _buildVehicleSection(vehicles),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: RidePickField(
                label: _date == null
                    ? 'Select Date'
                    : '${_date!.day}/${_date!.month}/${_date!.year}',
                icon: Icons.calendar_today,
                onTap: () async {
                  final d = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 90)));
                  if (d != null) setState(() => _date = d);
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: RidePickField(
                label: _time == null ? 'Select Time' : _time!.format(context),
                icon: Icons.access_time,
                onTap: () async {
                  final t = await showTimePicker(
                      context: context, initialTime: TimeOfDay.now());
                  if (t != null) setState(() => _time = t);
                },
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: _priceCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Price / Seat',
                    prefixIcon: Icon(Icons.currency_rupee)),
                validator: (v) => (double.tryParse(v?.trim() ?? '') ?? 0) > 0
                    ? null
                    : 'Price per seat required and greater than 0',
              ),
            ),
            const SizedBox(width: 8),
            RideSeatSelector(
              seats: _seats,
              onDec: _seats > 1 ? () => setState(() => _seats--) : null,
              onInc: _seats < maxSeats ? () => setState(() => _seats++) : null,
            ),
          ]),
          const SizedBox(height: 8),
          TextFormField(
            controller: _notesCtrl,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                prefixIcon: Icon(Icons.sticky_note_2_outlined)),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _isSubmitting ? null : _submit,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.publish),
            label: Text(_isSubmitting ? 'Publishing...' : 'Publish Ride'),
            style: FilledButton.styleFrom(
                backgroundColor: _accent,
                minimumSize: const Size.fromHeight(50)),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleSection(VehicleProvider vehicles) {
    if (vehicles.isLoading && vehicles.vehicles.isEmpty) {
      return const InputDecorator(
        decoration: InputDecoration(
            labelText: 'Vehicle', prefixIcon: Icon(Icons.directions_car)),
        child: LinearProgressIndicator(),
      );
    }

    if (vehicles.vehicles.isEmpty) {
      final hasError = _vehicleError != null;
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasError ? Colors.red : const Color(0xFFE2E8F0),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.directions_car, color: _accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('No vehicle added',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text('Add your vehicle to publish a ride',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            if (hasError) ...[
              const SizedBox(height: 8),
              Text(_vehicleError!,
                  style: const TextStyle(color: Colors.red, fontSize: 12)),
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _openAddVehicle,
              style: FilledButton.styleFrom(backgroundColor: _accent),
              child: const Text('+ Add Vehicle'),
            ),
          ],
        ),
      );
    }

    final selectedVehicleId = vehicles.vehicles.any((v) => v.id == _vehicleId)
        ? _vehicleId
        : vehicles.vehicles.first.id;

    return DropdownButtonFormField<String>(
      initialValue: selectedVehicleId,
      items: vehicles.vehicles
          .map((v) => DropdownMenuItem(
              value: v.id,
              child: Text('${v.vehicleName} (${v.vehicleNumber})')))
          .toList(),
      onChanged: (v) => setState(() {
        _vehicleId = v;
        _vehicleError = null;
      }),
      validator: (v) => v == null
          ? 'Please add or select a vehicle before publishing a ride.'
          : null,
      decoration: const InputDecoration(
          labelText: 'Vehicle', prefixIcon: Icon(Icons.directions_car)),
    );
  }

  Widget _buildMap(
    OfferRideProvider route, {
    bool showRouteLine = false,
    bool recenterUsesCurrentLocation = false,
  }) {
    final routeLine =
        showRouteLine ? _visibleRoutePoints(route) : const <LatLng>[];
    return Stack(
      children: [
        gmap.GoogleMap(
          initialCameraPosition: gmap.CameraPosition(
              target: gmap.LatLng(_center.latitude, _center.longitude),
              zoom: 12.5),
          onMapCreated: (c) {
            if (!_mapCtrl.isCompleted) _mapCtrl.complete(c);
            _isMapReady = true;
          },
          myLocationEnabled: route.canShowMyLocation,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          markers: {
            if (route.pickup != null)
              _marker(
                id: 'pickup',
                type: 'pickup',
                latitude: route.pickup!.latitude,
                longitude: route.pickup!.longitude,
                hue: gmap.BitmapDescriptor.hueGreen,
                zIndexInt: _mapPickMode == _OfferMapPickMode.pickup ? 3 : 1,
              ),
            if (route.destination != null)
              _marker(
                id: 'destination',
                type: 'destination',
                latitude: route.destination!.latitude,
                longitude: route.destination!.longitude,
                hue: gmap.BitmapDescriptor.hueRed,
                zIndexInt:
                    _mapPickMode == _OfferMapPickMode.destination ? 3 : 1,
              ),
            ...route.stops.asMap().entries.map((e) => _marker(
                  id: 'stop-${e.key}',
                  type: 'stop-${e.key + 1}',
                  latitude: e.value.latitude,
                  longitude: e.value.longitude,
                  hue: gmap.BitmapDescriptor.hueBlue,
                  infoWindow: gmap.InfoWindow(
                      title: 'Drop ${e.key + 1}', snippet: e.value.name),
                  zIndexInt: _mapPickMode == _OfferMapPickMode.stop ? 3 : 1,
                )),
          },
          onTap: (p) => _applyMapSelection(LatLng(p.latitude, p.longitude)),
          polylines: routeLine.length < 2
              ? const {}
              : {
                  gmap.Polyline(
                    polylineId: const gmap.PolylineId('offer-route'),
                    points: routeLine
                        .map((p) => gmap.LatLng(p.latitude, p.longitude))
                        .toList(growable: false),
                    color: _accent,
                    width: 5,
                    geodesic: true,
                  ),
                },
        ),
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Pickup'),
                selected: _mapPickMode == _OfferMapPickMode.pickup,
                onSelected: (_) =>
                    setState(() => _mapPickMode = _OfferMapPickMode.pickup),
              ),
              ChoiceChip(
                label: const Text('Destination'),
                selected: _mapPickMode == _OfferMapPickMode.destination,
                onSelected: (_) => setState(
                    () => _mapPickMode = _OfferMapPickMode.destination),
              ),
              ChoiceChip(
                label: const Text('Stop'),
                selected: _mapPickMode == _OfferMapPickMode.stop,
                onSelected: (_) =>
                    setState(() => _mapPickMode = _OfferMapPickMode.stop),
              ),
            ],
          ),
        ),
        Positioned(
          right: 12,
          bottom: 12,
          child: AppMapControls(
            onZoomIn: () =>
                _moveMap(route.destination ?? route.pickup ?? _center, 15.5),
            onZoomOut: () =>
                _moveMap(route.destination ?? route.pickup ?? _center, 11),
            onRecenter: recenterUsesCurrentLocation
                ? () => _useCurrentLocationAsPickup()
                : () => _moveMap(route.pickup ?? _center, 15),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileBody(OfferRideProvider route, VehicleProvider vehicles) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 104),
        children: [
          _buildMobileSearchCard(route),
          const SizedBox(height: 14),
          _buildMobileMapCard(route),
          const SizedBox(height: 14),
          _buildMobileTimelineCard(route),
          const SizedBox(height: 14),
          _buildMobileDetailsCard(vehicles),
        ],
      ),
    );
  }

  Widget _buildMobileSearchCard(OfferRideProvider route) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _mobileCardDecoration(),
      child: Column(
        children: [
          _MobileLocationRow(
            title: 'Pickup location',
            value: route.pickup == null
                ? 'Select pickup location'
                : LocationDisplayFormatter.title(_pickupSelection),
            subtitle: route.pickup == null
                ? null
                : LocationDisplayFormatter.subtitle(_pickupSelection),
            icon: Icons.location_on,
            color: Colors.green,
            onTap: _pickPickup,
            onClear: route.pickup == null ? null : _clearPickup,
          ),
          const SizedBox(height: 10),
          _MobileLocationRow(
            title: 'Destination',
            value: route.destination == null
                ? 'Select destination'
                : LocationDisplayFormatter.title(_destinationSelection),
            subtitle: route.destination == null
                ? null
                : LocationDisplayFormatter.subtitle(_destinationSelection),
            icon: Icons.location_on,
            color: Colors.redAccent,
            onTap: _pickDestination,
            onClear: route.destination == null ? null : _clearDestination,
          ),
          const SizedBox(height: 10),
          _MobileLocationRow(
            title: route.stops.isEmpty ? 'Add stop' : 'Add another stop',
            value: route.stops.isEmpty
                ? 'Optional drop point'
                : '${route.stops.length} stop${route.stops.length == 1 ? '' : 's'} added',
            icon: Icons.add,
            color: _accent,
            onTap: _pickStop,
            trailing: const Icon(Icons.keyboard_arrow_down_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileMapCard(OfferRideProvider route) {
    return Container(
      height: 330,
      decoration: _mobileCardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: _buildMap(
        route,
        showRouteLine: true,
        recenterUsesCurrentLocation: true,
      ),
    );
  }

  Widget _buildMobileTimelineCard(OfferRideProvider route) {
    final hasPickup = route.pickup != null;
    final hasDestination = route.destination != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _mobileCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Route Summary',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
              TextButton.icon(
                onPressed: _openStopsSheet,
                icon: const Icon(Icons.tune, size: 18),
                label: const Text('Stops'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _MobileTimelineItem(
            label: 'Pickup',
            value: hasPickup
                ? LocationDisplayFormatter.title(_pickupSelection)
                : 'Select pickup location',
            color: Colors.green,
            icon: Icons.trip_origin,
          ),
          ...route.stops.asMap().entries.map((entry) {
            final stop = entry.value;
            return _MobileTimelineItem(
              label: 'Stop ${entry.key + 1}',
              value: stop.name,
              color: _accent,
              icon: Icons.circle,
              trailing: IconButton(
                tooltip: 'Remove stop',
                onPressed: () => route.removeStop(entry.key),
                icon: const Icon(Icons.close, size: 18),
              ),
            );
          }),
          _MobileTimelineItem(
            label: 'Destination',
            value: hasDestination
                ? LocationDisplayFormatter.title(_destinationSelection)
                : 'Select destination',
            color: Colors.redAccent,
            icon: Icons.location_on,
            showConnector: false,
          ),
        ],
      ),
    );
  }

  Widget _buildMobileDetailsCard(VehicleProvider vehicles) {
    int maxSeats = 8;
    if (vehicles.vehicles.isNotEmpty) {
      final selectedVehicle = vehicles.vehicles.firstWhere(
        (v) => v.id == (_vehicleId ?? vehicles.vehicles.first.id),
      );

      maxSeats = selectedVehicle.seats;
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _mobileCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ride Details',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          _buildVehicleSection(vehicles),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: RidePickField(
                label: _date == null
                    ? 'Date'
                    : '${_date!.day}/${_date!.month}/${_date!.year}',
                icon: Icons.calendar_today,
                onTap: () async {
                  final d = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 90)));
                  if (d != null) setState(() => _date = d);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: RidePickField(
                label: _time == null ? 'Time' : _time!.format(context),
                icon: Icons.access_time,
                onTap: () async {
                  final t = await showTimePicker(
                      context: context, initialTime: TimeOfDay.now());
                  if (t != null) setState(() => _time = t);
                },
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: _priceCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Price / Seat',
                    prefixIcon: Icon(Icons.currency_rupee)),
                validator: (v) => (double.tryParse(v?.trim() ?? '') ?? 0) > 0
                    ? null
                    : 'Price per seat required and greater than 0',
              ),
            ),
            const SizedBox(width: 10),
            RideSeatSelector(
              seats: _seats,
              onDec: _seats > 1 ? () => setState(() => _seats--) : null,
              onInc: _seats < maxSeats ? () => setState(() => _seats++) : null,
            ),
          ]),
          const SizedBox(height: 10),
          TextFormField(
            controller: _notesCtrl,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                prefixIcon: Icon(Icons.sticky_note_2_outlined)),
          ),
        ],
      ),
    );
  }

  Widget _buildMobilePublishBar() {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: FilledButton.icon(
        onPressed: _isSubmitting ? null : _submit,
        icon: _isSubmitting
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.near_me),
        label: Text(_isSubmitting ? 'Publishing...' : 'Publish Ride'),
        style: FilledButton.styleFrom(
          backgroundColor: _accent,
          minimumSize: const Size.fromHeight(54),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
    );
  }

  BoxDecoration _mobileCardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFFE7EAF3)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x12000000),
          blurRadius: 18,
          offset: Offset(0, 8),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final route = context.watch<OfferRideProvider>();
    final vehicles = context.watch<VehicleProvider>();
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 980;

    if (!_pickupLockedFromSelection) {
      _pickupCtrl.text = route.pickupAddress;
    }

    if (isDesktop) {
      return Scaffold(
        backgroundColor: AppDesignTokens.pageBackground(context),
        appBar: AppBar(title: const Text('Offer a Ride')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: _buildMap(route)),
              ),
              const SizedBox(width: 16),
              Container(
                width: 440,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F5FF),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x18000000),
                        blurRadius: 24,
                        offset: Offset(0, 12))
                  ],
                ),
                child: _buildPanelContent(route, vehicles),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F7FC),
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('New CarPool',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
            Text('Offer a Ride', style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
      body: _buildMobileBody(route, vehicles),
      bottomNavigationBar: _buildMobilePublishBar(),
    );
  }
}

class _MobileLocationRow extends StatelessWidget {
  const _MobileLocationRow({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
    this.subtitle,
    this.onClear,
    this.trailing,
  });

  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFBFCFF),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE1E6F0)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: color.withAlpha(31),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                      ),
                    ),
                    if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              if (onClear != null)
                IconButton(
                  tooltip: 'Clear',
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded),
                )
              else
                trailing ?? const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileTimelineItem extends StatelessWidget {
  const _MobileTimelineItem({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.trailing,
    this.showConnector = true,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final Widget? trailing;
  final bool showConnector;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: color,
                  child: Icon(icon, size: 13, color: Colors.white),
                ),
                if (showConnector)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      color: const Color(0xFFD7DDEA),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
