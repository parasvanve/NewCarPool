import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/utils/location_permission_helper.dart';
import '../../core/widgets/app_design_system.dart';
import '../../services/tracking_service.dart';

class LiveTrackingScreen extends StatefulWidget {
  const LiveTrackingScreen({super.key});

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  final _rideOfferIdController = TextEditingController();
  final Completer<gmap.GoogleMapController> _mapController = Completer();

  LatLng driverLocation = const LatLng(
    LocationPermissionHelper.indoreLatitude,
    LocationPermissionHelper.indoreLongitude,
  );
  final List<LatLng> trailPoints = [];
  bool connected = false;
  bool autoFollow = true;
  double _mapZoom = 13;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeMapCenter());
  }

  Future<void> _initializeMapCenter() async {
    final location = await LocationPermissionHelper.currentOrFallback();
    if (!mounted) return;
    final next = LatLng(location.latitude, location.longitude);
    setState(() => driverLocation = next);
    if (location.message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(location.message!)),
      );
    }
    if (_mapController.isCompleted) {
      final controller = await _mapController.future;
      await controller.animateCamera(
        gmap.CameraUpdate.newLatLngZoom(
          gmap.LatLng(next.latitude, next.longitude),
          14,
        ),
      );
    }
  }

  @override
  void dispose() {
    _rideOfferIdController.dispose();
    context.read<TrackingService>().disconnect();
    super.dispose();
  }

  Future<void> _connect() async {
    final rideId = _rideOfferIdController.text.trim();
    if (rideId.isEmpty) return;

    await context.read<TrackingService>().connect(rideId, (payload) {
      final lat = (payload['latitude'] as num?)?.toDouble();
      final lng = (payload['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null && mounted) {
        final next = LatLng(lat, lng);
        setState(() {
          driverLocation = next;
          trailPoints.add(next);
          if (trailPoints.length > 120) {
            trailPoints.removeAt(0);
          }
        });
        if (autoFollow) {
          _mapController.future.then((controller) {
            controller.animateCamera(
              gmap.CameraUpdate.newLatLngZoom(
                gmap.LatLng(next.latitude, next.longitude),
                15,
              ),
            );
          });
        }
      }
    });

    if (mounted) {
      setState(() {
        connected = true;
        trailPoints
          ..clear()
          ..add(driverLocation);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF0F766E);
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        title: const Text('Live Tracking'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _rideOfferIdController,
                    decoration: const InputDecoration(
                      labelText: 'Ride Offer ID',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: connected ? null : _connect,
                  style: FilledButton.styleFrom(backgroundColor: accent),
                  child: Text(connected ? 'Connected' : 'Connect'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Auto follow driver'),
              value: autoFollow,
              onChanged: (value) => setState(() => autoFollow = value),
            ),
          ),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(18),
                    clipBehavior: Clip.antiAlias,
                    child: SizedBox.expand(
                      child: gmap.GoogleMap(
                        initialCameraPosition: gmap.CameraPosition(
                          target: gmap.LatLng(driverLocation.latitude,
                              driverLocation.longitude),
                          zoom: 13,
                        ),
                        onMapCreated: (controller) {
                          if (!_mapController.isCompleted) {
                            _mapController.complete(controller);
                          }
                        },
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                        mapToolbarEnabled: false,
                        onCameraMove: (position) => _mapZoom = position.zoom,
                        markers: {
                          gmap.Marker(
                            markerId: const gmap.MarkerId('driver'),
                            position: gmap.LatLng(driverLocation.latitude,
                                driverLocation.longitude),
                          ),
                        },
                        polylines: {
                          if (trailPoints.length >= 2)
                            gmap.Polyline(
                              polylineId: const gmap.PolylineId('trail'),
                              points: trailPoints
                                  .map((p) =>
                                      gmap.LatLng(p.latitude, p.longitude))
                                  .toList(),
                              color: Colors.blue,
                              width: 4,
                              geodesic: true,
                              startCap: gmap.Cap.roundCap,
                              endCap: gmap.Cap.roundCap,
                            ),
                        },
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 24,
                  bottom: 24,
                  child: AppMapControls(
                    onZoomIn: () => _mapController.future.then(
                      (c) => c.animateCamera(
                        gmap.CameraUpdate.newLatLngZoom(
                          gmap.LatLng(driverLocation.latitude,
                              driverLocation.longitude),
                          (_mapZoom + 1).clamp(4, 18).toDouble(),
                        ),
                      ),
                    ),
                    onZoomOut: () => _mapController.future.then(
                      (c) => c.animateCamera(
                        gmap.CameraUpdate.newLatLngZoom(
                          gmap.LatLng(driverLocation.latitude,
                              driverLocation.longitude),
                          (_mapZoom - 1).clamp(4, 18).toDouble(),
                        ),
                      ),
                    ),
                    onRecenter: () => _mapController.future.then(
                      (c) => c.animateCamera(
                        gmap.CameraUpdate.newLatLngZoom(
                          gmap.LatLng(driverLocation.latitude,
                              driverLocation.longitude),
                          15,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
