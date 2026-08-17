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

  // New: tracks whether we're still resolving the initial map center,
  // so we can show a loading indicator instead of appearing frozen.
  bool _isLocating = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeMapCenter());
  }

  Future<void> _initializeMapCenter() async {
    if (mounted) setState(() => _isLocating = true);
    try {
      // Guard against a hanging permission/location call so the screen
      // never looks frozen — fall back to the default location instead.
      final location = await LocationPermissionHelper.currentOrFallback()
          .timeout(const Duration(seconds: 8));
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
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Could not fetch your location, showing default area.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Location unavailable, showing default area.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
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
              title: const Text('Auto follow rider'),
              value: autoFollow,
              onChanged: (value) => setState(() => autoFollow = value),
            ),
          ),
          // New: informational banner shown until the user connects a ride,
          // so the screen never reads as blank/broken on first open.
          if (!connected)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Icon(Icons.info_outline,
                        size: 18, color: Color(0xFF2563EB)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Enter a Ride Offer ID above and tap Connect to start live tracking. '
                        'You\'ll see this map update once a ride is connected.',
                        style:
                            TextStyle(fontSize: 12, color: Color(0xFF1E3A8A)),
                      ),
                    ),
                  ],
                ),
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
                // New: lightweight loading overlay while resolving the
                // initial location, instead of an unexplained frozen map.
                if (_isLocating)
                  Positioned(
                    top: 12,
                    left: 24,
                    right: 24,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0x140F172A),
                              blurRadius: 10,
                              offset: Offset(0, 4)),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 10),
                          Text('Locating you...',
                              style: TextStyle(fontSize: 12)),
                        ],
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
