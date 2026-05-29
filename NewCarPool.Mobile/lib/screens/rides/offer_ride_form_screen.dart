import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_routes.dart';
import '../../core/utils/location_display_formatter.dart';
import '../../core/errors/app_exception.dart';
import '../../core/widgets/app_design_system.dart';
import '../../models/ride_models.dart';
import '../../providers/offer_ride_provider.dart';
import '../../providers/ride_provider.dart';
import '../../providers/vehicle_provider.dart';
import '../../services/map_service.dart';
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
  _OfferMapPickMode _mapPickMode = _OfferMapPickMode.pickup;

  @override
  void initState() {
    super.initState();
    context.read<VehicleProvider>().loadMine();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final route = context.read<OfferRideProvider>();
      await route.detectCurrentLocation();
      if (!mounted) return;
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
      c.animateCamera(gmap.CameraUpdate.newLatLngZoom(gmap.LatLng(p.latitude, p.longitude), z));
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
                final results = await context.read<MapService>().geocode(q);
                final mapped = results
                    .take(8)
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
              padding: EdgeInsets.fromLTRB(16, 14, 16, MediaQuery.of(context).viewInsets.bottom + 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      ),
                      IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                    ],
                  ),
                  TextField(
                    controller: searchCtrl,
                    decoration: const InputDecoration(labelText: 'Search location', prefixIcon: Icon(Icons.search)),
                    onChanged: (v) {
                      _searchDebounce?.cancel();
                      _searchDebounce = Timer(const Duration(milliseconds: 450), () => doSearch(v));
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
                          if (!mounted || p.pickup == null) return;
                          Navigator.pop(context, {
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
                      child: Text(error!, style: const TextStyle(color: Colors.red)),
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
                              LocationDisplayFormatter.subtitle(s),
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
    final selected = await _openLocationPicker(title: 'Select Pickup Location', allowCurrentLocation: true);
    if (selected == null) return;
    final point = LatLng((selected['latitude'] as num).toDouble(), (selected['longitude'] as num).toDouble());
    final route = context.read<OfferRideProvider>();
    await route.setPickup(point);
    _pickupSelection = selected;
    _pickupCtrl.text =
        selected['formattedAddress']?.toString() ?? route.pickupAddress;
    _moveMap(point, 14.3);
    setState(() => _mapPickMode = _OfferMapPickMode.pickup);
  }

  Future<void> _pickDestination() async {
    final selected = await _openLocationPicker(title: 'Select Final Destination', allowCurrentLocation: false);
    if (selected == null) return;
    final point = LatLng((selected['latitude'] as num).toDouble(), (selected['longitude'] as num).toDouble());
    final route = context.read<OfferRideProvider>();
    await route.setDestination(point);
    _destinationSelection = selected;
    _destCtrl.text = selected['formattedAddress']?.toString() ?? 'Destination';
    _destinationAddress = _destCtrl.text;
    _moveMap(point, 14.3);
    setState(() => _mapPickMode = _OfferMapPickMode.destination);
  }

  Future<void> _pickStop({int? index}) async {
    final selected = await _openLocationPicker(title: index == null ? 'Add Drop Point' : 'Edit Drop Point', allowCurrentLocation: false);
    if (selected == null) return;
    final route = context.read<OfferRideProvider>();
    final point = LatLng((selected['latitude'] as num).toDouble(), (selected['longitude'] as num).toDouble());
    final name = LocationDisplayFormatter.title(selected);
    final address = selected['formattedAddress']?.toString() ?? name;
    final stop = RideStop(name: name, address: address, latitude: point.latitude, longitude: point.longitude, order: (index ?? route.stops.length) + 1);
    final message = index == null ? await route.addStop(stop) : await route.updateStop(index, stop);
    if (message != null) _showInlineWarning(message);
    if (message == null && mounted) {
      setState(() => _mapPickMode = _OfferMapPickMode.stop);
    }
  }

  Future<void> _applyMapSelection(LatLng point) async {
    final route = context.read<OfferRideProvider>();
    switch (_mapPickMode) {
      case _OfferMapPickMode.pickup:
        if (route.destination != null && _isSamePoint(point, route.destination!)) {
          _showInlineWarning('Pickup and destination cannot be same.');
          return;
        }
        await route.setPickup(point);
        final suggestion = await _reverseSuggestion(point);
        _pickupSelection = suggestion;
        _pickupCtrl.text = suggestion['formattedAddress']?.toString() ?? route.pickupAddress;
        break;
      case _OfferMapPickMode.destination:
        if (route.pickup != null && _isSamePoint(point, route.pickup!)) {
          _showInlineWarning('Pickup and destination cannot be same.');
          return;
        }
        await route.setDestination(point);
        final suggestion = await _reverseSuggestion(point);
        _destinationSelection = suggestion;
        _destCtrl.text = suggestion['formattedAddress']?.toString() ?? 'Destination';
        _destinationAddress = _destCtrl.text;
        break;
      case _OfferMapPickMode.stop:
        final suggestion = await _reverseSuggestion(point);
        final stopName = LocationDisplayFormatter.title(suggestion);
        final stopAddress = suggestion['formattedAddress']?.toString() ?? stopName;
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
        break;
    }
    if (!mounted) return;
    setState(() {});
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
    return (a.latitude - b.latitude).abs() < 0.0001 && (a.longitude - b.longitude).abs() < 0.0001;
  }

  Future<void> _openStopsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) {
        return Consumer<OfferRideProvider>(
          builder: (context, route, __) => Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, MediaQuery.of(context).viewInsets.bottom + 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  const Expanded(child: Text('Manage Drop Points', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18))),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
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
                  onReorder: (oldI, newI) async => route.reorderStops(oldI, newI),
                  itemBuilder: (_, i) {
                    final stop = route.stops[i];
                    return ListTile(
                      key: ValueKey('stop-$i-${stop.latitude}-${stop.longitude}'),
                      leading: CircleAvatar(radius: 12, child: Text('${i + 1}', style: const TextStyle(fontSize: 12))),
                      title: Text(stop.name),
                      subtitle: Text('${stop.latitude.toStringAsFixed(4)}, ${stop.longitude.toStringAsFixed(4)}'),
                      onTap: () async {
                        Navigator.pop(context);
                        await _pickStop(index: i);
                      },
                      trailing: IconButton(onPressed: () => route.removeStop(i), icon: const Icon(Icons.delete_outline)),
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

  Future<void> _submit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) return;
    final route = context.read<OfferRideProvider>();
    if (route.pickup == null || route.destination == null) {
      _showInlineWarning('Pickup and destination are required');
      return;
    }
    if (_destCtrl.text.trim().isEmpty) {
      _showInlineWarning('Please select a location from suggestions.');
      return;
    }
    if (_date == null || _time == null) {
      _showInlineWarning('Select departure date and time');
      return;
    }

    final vehicles = context.read<VehicleProvider>().vehicles;
    final vId = _vehicleId ?? (vehicles.isNotEmpty ? vehicles.first.id : null);
    if (vId == null) {
      _showInlineWarning('Please add/select vehicle');
      return;
    }
    final v = vehicles.firstWhere((x) => x.id == vId);
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
      _showInlineWarning('Enter valid price');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await context.read<RideProvider>().offerRide(
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
      await context.read<RideProvider>().loadUpcomingActive();
      ScaffoldMessenger.of(context).showSnackBar(
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
  }

  Widget _buildPanelContent(OfferRideProvider route, VehicleProvider vehicles) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: const [BoxShadow(color: Color(0x15000000), blurRadius: 16, offset: Offset(0, 8))]),
            child: Column(
              children: [
                InkWell(
                  onTap: _pickPickup,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Pickup', prefixIcon: Icon(Icons.trip_origin, color: Colors.green)),
                    child: _pickupCtrl.text.trim().isEmpty
                        ? const Text('Select pickup location')
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                LocationDisplayFormatter.title(_pickupSelection),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                LocationDisplayFormatter.subtitle(_pickupSelection),
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
                    decoration: const InputDecoration(labelText: 'Final Destination', prefixIcon: Icon(Icons.location_on, color: Colors.red)),
                    child: _destCtrl.text.trim().isEmpty
                        ? const Text('Select final destination')
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                LocationDisplayFormatter.title(_destinationSelection),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                LocationDisplayFormatter.subtitle(_destinationSelection),
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
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(
                children: [
                  const Expanded(child: Text('Route Timeline', style: TextStyle(fontWeight: FontWeight.w700))),
                  TextButton.icon(onPressed: _openStopsSheet, icon: const Icon(Icons.add), label: const Text('Stops')),
                ],
              ),
              RideTimeline(
                pickup: _pickupCtrl.text.trim().isEmpty ? 'Pickup' : LocationDisplayFormatter.title(_pickupSelection),
                stops: route.stops.map((s) => s.name).toList(),
                destination: _destCtrl.text.trim().isEmpty ? 'Final destination' : LocationDisplayFormatter.title(_destinationSelection),
              ),
            ]),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _vehicleId ?? (vehicles.vehicles.isNotEmpty ? vehicles.vehicles.first.id : null),
            items: vehicles.vehicles.map((v) => DropdownMenuItem(value: v.id, child: Text('${v.vehicleName} (${v.vehicleNumber})'))).toList(),
            onChanged: (v) => setState(() => _vehicleId = v),
            validator: (v) => v == null ? 'Select vehicle' : null,
            decoration: const InputDecoration(labelText: 'Vehicle', prefixIcon: Icon(Icons.directions_car)),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: RidePickField(
                label: _date == null ? 'Select Date' : '${_date!.day}/${_date!.month}/${_date!.year}',
                icon: Icons.calendar_today,
                onTap: () async {
                  final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 90)));
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
                  final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
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
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Price / Seat', prefixIcon: Icon(Icons.currency_rupee)),
                validator: (v) => (double.tryParse(v?.trim() ?? '') ?? 0) > 0 ? null : 'Enter valid price',
              ),
            ),
            const SizedBox(width: 8),
            RideSeatSelector(
              seats: _seats,
              onDec: _seats > 1 ? () => setState(() => _seats--) : null,
              onInc: _seats < 8 ? () => setState(() => _seats++) : null,
            ),
          ]),
          const SizedBox(height: 8),
          TextFormField(
            controller: _notesCtrl,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Notes (optional)', prefixIcon: Icon(Icons.sticky_note_2_outlined)),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _isSubmitting ? null : _submit,
            icon: _isSubmitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.publish),
            label: Text(_isSubmitting ? 'Publishing...' : 'Publish Ride'),
            style: FilledButton.styleFrom(backgroundColor: _accent, minimumSize: const Size.fromHeight(50)),
          ),
        ],
      ),
    );
  }

  Widget _buildMap(OfferRideProvider route) {
    return Stack(
      children: [
        gmap.GoogleMap(
          initialCameraPosition: gmap.CameraPosition(target: gmap.LatLng(_center.latitude, _center.longitude), zoom: 12.5),
          onMapCreated: (c) {
            if (!_mapCtrl.isCompleted) _mapCtrl.complete(c);
            _isMapReady = true;
          },
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          markers: {
            if (route.pickup != null)
              gmap.Marker(
                markerId: const gmap.MarkerId('pickup'),
                position: gmap.LatLng(route.pickup!.latitude, route.pickup!.longitude),
                icon: gmap.BitmapDescriptor.defaultMarkerWithHue(gmap.BitmapDescriptor.hueGreen),
                zIndexInt: _mapPickMode == _OfferMapPickMode.pickup ? 3 : 1,
              ),
            if (route.destination != null)
              gmap.Marker(
                markerId: const gmap.MarkerId('destination'),
                position: gmap.LatLng(route.destination!.latitude, route.destination!.longitude),
                icon: gmap.BitmapDescriptor.defaultMarkerWithHue(gmap.BitmapDescriptor.hueRed),
                zIndexInt: _mapPickMode == _OfferMapPickMode.destination ? 3 : 1,
              ),
            ...route.stops.asMap().entries.map((e) => gmap.Marker(
                  markerId: gmap.MarkerId('stop-${e.key}'),
                  position: gmap.LatLng(e.value.latitude, e.value.longitude),
                  infoWindow: gmap.InfoWindow(title: 'Drop ${e.key + 1}', snippet: e.value.name),
                  icon: gmap.BitmapDescriptor.defaultMarkerWithHue(gmap.BitmapDescriptor.hueAzure),
                  zIndexInt: _mapPickMode == _OfferMapPickMode.stop ? 3 : 1,
                )),
          },
          onTap: (p) => _applyMapSelection(LatLng(p.latitude, p.longitude)),
          polylines: const {},
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
                onSelected: (_) => setState(() => _mapPickMode = _OfferMapPickMode.pickup),
              ),
              ChoiceChip(
                label: const Text('Destination'),
                selected: _mapPickMode == _OfferMapPickMode.destination,
                onSelected: (_) => setState(() => _mapPickMode = _OfferMapPickMode.destination),
              ),
              ChoiceChip(
                label: const Text('Stop'),
                selected: _mapPickMode == _OfferMapPickMode.stop,
                onSelected: (_) => setState(() => _mapPickMode = _OfferMapPickMode.stop),
              ),
            ],
          ),
        ),
        Positioned(
          right: 12,
          bottom: 12,
          child: AppMapControls(
            onZoomIn: () => _moveMap(route.destination ?? route.pickup ?? _center, 15.5),
            onZoomOut: () => _moveMap(route.destination ?? route.pickup ?? _center, 11),
            onRecenter: () => _moveMap(route.pickup ?? _center, 15),
          ),
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

    _pickupCtrl.text = route.pickupAddress;

    if (isDesktop) {
      return Scaffold(
        backgroundColor: AppDesignTokens.pageBg,
        appBar: AppBar(title: const Text('Offer a Ride')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: ClipRRect(borderRadius: BorderRadius.circular(24), child: _buildMap(route)),
              ),
              const SizedBox(width: 16),
              Container(
                width: 440,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F5FF),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [BoxShadow(color: Color(0x18000000), blurRadius: 24, offset: Offset(0, 12))],
                ),
                child: _buildPanelContent(route, vehicles),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: _buildMap(route)),
          DraggableScrollableSheet(
            initialChildSize: 0.33,
            minChildSize: 0.20,
            maxChildSize: 0.86,
            builder: (_, controller) => Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF8F9FF),
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Container(width: 42, height: 5, decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10))),
                  Expanded(
                    child: PrimaryScrollController(controller: controller, child: _buildPanelContent(route, vehicles)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
