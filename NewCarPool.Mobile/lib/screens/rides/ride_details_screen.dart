import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/utils/departure_time_utils.dart';
import '../../core/utils/location_display_formatter.dart';
import '../../models/booking_models.dart';
import '../../models/ride_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../services/map_service.dart';
import '../../services/ride_service.dart';
import '../../services/tracking_service.dart';
import 'ride_chat_screen.dart';

class RideDetailsScreen extends StatefulWidget {
  const RideDetailsScreen({super.key, this.extra});
  final Object? extra;

  @override
  State<RideDetailsScreen> createState() => _RideDetailsScreenState();
}

class _RideDetailsScreenState extends State<RideDetailsScreen> {
  final Completer<gmap.GoogleMapController> _mapController = Completer();
  final Distance _distance = const Distance();
  RideOffer? _ride;
  List<gmap.LatLng> _routePoints = const [];
  gmap.LatLng? _driverLivePoint;
  String? _trackingMessage;
  bool _routeLoading = false;
  bool _mapMovedByUser = false;
  Timer? _driverTimer;
  Timer? _passengerPollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final bookingProvider = context.read<BookingProvider>();
      if (bookingProvider.bookings.isEmpty && !bookingProvider.isLoading) {
        await bookingProvider.loadHistory();
      }
      final ride = widget.extra is RideOffer ? widget.extra as RideOffer : null;
      if (ride == null) return;
      setState(() => _ride = ride);
      await _loadRoutePolyline(ride);
      await _syncTracking(ride);
    });
  }

  @override
  void dispose() {
    _driverTimer?.cancel();
    _passengerPollTimer?.cancel();
    context.read<TrackingService>().disconnect();
    super.dispose();
  }

  Future<void> _loadRoutePolyline(RideOffer ride) async {
    setState(() => _routeLoading = true);
    try {
      final chain = <GeoPoint>[
        ride.origin,
        ...ride.intermediateStops.map((s) => GeoPoint(name: s.name, latitude: s.latitude, longitude: s.longitude)),
        ride.destination,
      ];
      final built = <gmap.LatLng>[];
      for (var i = 0; i < chain.length - 1; i++) {
        final seg = await context.read<MapService>().route(
              fromLatitude: chain[i].latitude,
              fromLongitude: chain[i].longitude,
              toLatitude: chain[i + 1].latitude,
              toLongitude: chain[i + 1].longitude,
            );
        final decoded = _extractRoutePoints(seg);
        if (decoded.isEmpty) continue;
        if (built.isNotEmpty) {
          built.addAll(decoded.skip(1));
        } else {
          built.addAll(decoded);
        }
      }
      if (!mounted) return;
      final fallback = _fallbackRoutePoints(ride);
      final cleaned = _sanitizeRoutePoints(built);
      setState(() => _routePoints = cleaned.length >= 2 ? cleaned : fallback);
      await _fitCamera();
    } catch (_) {
      if (!mounted) return;
      setState(() => _routePoints = _fallbackRoutePoints(ride));
    } finally {
      if (mounted) setState(() => _routeLoading = false);
    }
  }

  List<gmap.LatLng> _fallbackRoutePoints(RideOffer ride) {
    final routePoints = <gmap.LatLng>[
      gmap.LatLng(ride.origin.latitude, ride.origin.longitude),
      ...ride.intermediateStops.map((s) => gmap.LatLng(s.latitude, s.longitude)),
      gmap.LatLng(ride.destination.latitude, ride.destination.longitude),
    ];
    return _sanitizeRoutePoints(routePoints);
  }

  List<gmap.LatLng> _extractRoutePoints(Map<String, dynamic> seg) {
    final fromEncoded = <String>[
      seg['encodedPolyline']?.toString() ?? '',
      seg['geometry']?.toString() ?? '',
      seg['polyline']?.toString() ?? '',
    ];
    for (final encoded in fromEncoded) {
      if (encoded.isEmpty) continue;
      final decoded = _sanitizeRoutePoints(_decodePolyline(encoded));
      if (decoded.length >= 2) return decoded;
    }

    final coordinates = seg['coordinates'];
    if (coordinates is List) {
      final points = <gmap.LatLng>[];
      for (final item in coordinates) {
        if (item is! List || item.length < 2) continue;
        final first = (item[0] as num?)?.toDouble();
        final second = (item[1] as num?)?.toDouble();
        if (first == null || second == null) continue;
        // Backend coordinate arrays are usually [longitude, latitude].
        points.add(gmap.LatLng(second, first));
      }
      final cleaned = _sanitizeRoutePoints(points);
      if (cleaned.length >= 2) return cleaned;
    }
    return const [];
  }

  List<gmap.LatLng> _decodePolyline(String encoded) {
    if (encoded.isEmpty) return const [];
    var index = 0;
    var lat = 0;
    var lng = 0;
    final points = <gmap.LatLng>[];
    while (index < encoded.length) {
      var b = 0;
      var shift = 0;
      var result = 0;
      do {
        if (index >= encoded.length) return _sanitizeRoutePoints(points);
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      shift = 0;
      result = 0;
      do {
        if (index >= encoded.length) return _sanitizeRoutePoints(points);
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      points.add(gmap.LatLng(lat / 1e5, lng / 1e5));
    }
    return _sanitizeRoutePoints(points);
  }

  List<gmap.LatLng> _sanitizeRoutePoints(List<gmap.LatLng> input) {
    final cleaned = <gmap.LatLng>[];
    for (final p in input) {
      if (!_isValidCoordinate(p.latitude, p.longitude)) continue;
      if (cleaned.isNotEmpty) {
        final prev = cleaned.last;
        final isDup = (prev.latitude - p.latitude).abs() < 0.000001 && (prev.longitude - p.longitude).abs() < 0.000001;
        if (isDup) continue;
      }
      cleaned.add(gmap.LatLng(p.latitude, p.longitude));
    }
    return cleaned;
  }

  bool _isValidCoordinate(double lat, double lng) {
    return lat.isFinite && lng.isFinite && lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }

  Future<void> _syncTracking(RideOffer ride) async {
    _driverTimer?.cancel();
    _passengerPollTimer?.cancel();
    await context.read<TrackingService>().disconnect();
    if (ride.status != 3) {
      setState(() => _trackingMessage = null);
      return;
    }

    final myUserId = context.read<AuthProvider>().session?.userId;
    final isDriver = myUserId != null && ride.driverId == myUserId;
    final myBooking = _latestBooking(ride.id);
    final isBookedPassenger = myBooking != null && myBooking.bookingStatus == BookingStatus.accepted;

    if (isDriver) {
      await _startDriverTracking(ride);
      return;
    }
    if (isBookedPassenger) {
      await _startPassengerTracking(ride);
      return;
    }
    setState(() => _trackingMessage = 'Waiting for driver location...');
  }

  RideBooking? _latestBooking(String rideId) {
    final myUserId = context.read<AuthProvider>().session?.userId;
    final list = context.read<BookingProvider>().bookings.where((b) => b.rideOfferId == rideId && b.passengerId == myUserId).toList()
      ..sort((a, b) => b.createdAtUtc.compareTo(a.createdAtUtc));
    return list.isEmpty ? null : list.first;
  }

  Future<void> _startDriverTracking(RideOffer ride) async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (!enabled || permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      setState(() => _trackingMessage = 'Location permission is required for live tracking.');
      return;
    }

    if (mounted) {
      setState(() => _trackingMessage = 'Your live location is being shared with passengers.');
    }

    Future<void> tick() async {
      try {
        final pos = await Geolocator.getCurrentPosition();
        if (!mounted) return;
        final next = gmap.LatLng(pos.latitude, pos.longitude);
        setState(() => _driverLivePoint = next);
        await context.read<TrackingService>().publishLocation(
              rideOfferId: ride.id,
              latitude: pos.latitude,
              longitude: pos.longitude,
              heading: pos.heading.isFinite ? pos.heading : null,
              speedKph: pos.speed.isFinite ? pos.speed * 3.6 : null,
            );
        await _fitCamera();
      } catch (_) {}
    }

    await tick();
    _driverTimer = Timer.periodic(const Duration(seconds: 8), (_) => tick());
  }

  Future<void> _startPassengerTracking(RideOffer ride) async {
    Future<void> fetchLatest() async {
      final data = await context.read<TrackingService>().latestLocation(ride.id);
      if (!mounted) return;
      if (data == null) {
        setState(() => _trackingMessage = 'Waiting for driver location...');
        return;
      }
      final lat = (data['latitude'] as num?)?.toDouble();
      final lng = (data['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) return;
      setState(() {
        _driverLivePoint = gmap.LatLng(lat, lng);
        _trackingMessage = 'Driver is on the way';
      });
      await _fitCamera();
    }

    await fetchLatest();
    _passengerPollTimer = Timer.periodic(const Duration(seconds: 10), (_) => fetchLatest());
    try {
      await context.read<TrackingService>().connect(ride.id, (payload) async {
        final lat = (payload['latitude'] as num?)?.toDouble();
        final lng = (payload['longitude'] as num?)?.toDouble();
        if (!mounted || lat == null || lng == null) return;
        setState(() {
          _driverLivePoint = gmap.LatLng(lat, lng);
          _trackingMessage = 'Driver is on the way';
        });
        await _fitCamera();
      });
    } catch (_) {}
  }

  Future<void> _fitCamera() async {
    if (_mapMovedByUser) return;
    if (!_mapController.isCompleted) return;
    final ride = _ride;
    if (ride == null) return;

    final pts = _sanitizeRoutePoints([
      ..._fallbackRoutePoints(ride),
      ..._routePoints,
      if (_driverLivePoint != null) _driverLivePoint!,
    ]);
    if (pts.length < 2) return;
    var minLat = pts.first.latitude;
    var maxLat = pts.first.latitude;
    var minLng = pts.first.longitude;
    var maxLng = pts.first.longitude;
    for (final p in pts.skip(1)) {
      minLat = p.latitude < minLat ? p.latitude : minLat;
      maxLat = p.latitude > maxLat ? p.latitude : maxLat;
      minLng = p.longitude < minLng ? p.longitude : minLng;
      maxLng = p.longitude > maxLng ? p.longitude : maxLng;
    }
    final controller = await _mapController.future;
    await controller.animateCamera(
      gmap.CameraUpdate.newLatLngBounds(
        gmap.LatLngBounds(
          southwest: gmap.LatLng(minLat, minLng),
          northeast: gmap.LatLng(maxLat, maxLng),
        ),
        80,
      ),
    );
  }

  Future<void> _completeRide() async {
    final ride = _ride;
    if (ride == null) return;
    final updated = await context.read<RideService>().completeRide(ride.id);
    if (!mounted) return;
    setState(() => _ride = updated);
    await _syncTracking(updated);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ride completed')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ride = _ride;
    if (ride == null) return const Scaffold(body: Center(child: Text('Ride details unavailable')));
    final myUserId = context.watch<AuthProvider>().session?.userId;
    final isDriver = myUserId != null && ride.driverId == myUserId;
    final isStarted = ride.status == 3;
    final myBooking = _latestBooking(ride.id);
    final distanceKm = _driverDistanceKm(myBooking);
    final etaMin = _etaMinutes(myBooking);
    final isDesktop = MediaQuery.of(context).size.width >= 1100;

    final markers = _buildMarkers(ride, myBooking);

    final mapCard = _MapCard(
      ride: ride,
      isStarted: isStarted,
      trackingMessage: _trackingMessage,
      driverLivePoint: _driverLivePoint,
      distanceKm: distanceKm,
      etaMin: etaMin,
      markers: markers,
      routePoints: _routePoints,
      mapController: _mapController,
      routeLoading: _routeLoading,
      onUserMove: () => _mapMovedByUser = true,
      onMyLocation: () async {
        if (!_mapController.isCompleted) return;
        final c = await _mapController.future;
        final fallback = gmap.LatLng(ride.origin.latitude, ride.origin.longitude);
        await c.animateCamera(gmap.CameraUpdate.newLatLngZoom(_driverLivePoint ?? fallback, 14));
      },
    );

    final rightPanel = _RightPanel(
      ride: ride,
      myBooking: myBooking,
      isDriver: isDriver,
      trackingMessage: _trackingMessage,
      onChat: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RideChatScreen(ride: ride))),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).maybePop()),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ride Details'),
            Text(
              'Ride ID: #${ride.id.substring(0, 8).toUpperCase()}',
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          if (isDesktop)
            const Padding(
              padding: EdgeInsets.only(right: 10),
              child: Row(
                children: [
                  Icon(Icons.flutter_dash, color: Color(0xFF4F46E5)),
                  SizedBox(width: 6),
                  Text('NewCarPool', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1D4ED8))),
                ],
              ),
            ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RideChatScreen(ride: ride))),
          ),
          IconButton(icon: const Icon(Icons.call_outlined), onPressed: () {}),
        ],
      ),
      body: SafeArea(
        child: isDesktop
            ? Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 8,
                      child: Column(
                        children: [
                          Expanded(child: mapCard),
                          const SizedBox(height: 10),
                          _VehicleFooterCard(ride: ride),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RideChatScreen(ride: ride))),
                                  icon: const Icon(Icons.chat_bubble_outline),
                                  label: const Text('Chat with Driver'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    if (!_mapController.isCompleted) return;
                                    final c = await _mapController.future;
                                    final fallback = gmap.LatLng(ride.origin.latitude, ride.origin.longitude);
                                    await c.animateCamera(gmap.CameraUpdate.newLatLngZoom(_driverLivePoint ?? fallback, 14));
                                  },
                                  icon: const Icon(Icons.map_outlined),
                                  label: const Text('View on Map'),
                                ),
                              ),
                              if (isDriver && isStarted) ...[
                                const SizedBox(width: 10),
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: _completeRide,
                                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
                                    icon: const Icon(Icons.check_circle_outline),
                                    label: const Text('Complete Ride'),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(flex: 5, child: SingleChildScrollView(child: rightPanel)),
                  ],
                ),
              )
            : Column(
                children: [
                  SizedBox(height: 360, child: mapCard),
                  Expanded(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                        boxShadow: [BoxShadow(color: Color(0x19000000), blurRadius: 14, offset: Offset(0, -4))],
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 120),
                        child: Column(
                          children: [
                            Container(
                              width: 42,
                              height: 5,
                              decoration: BoxDecoration(color: const Color(0xFFD1D5DB), borderRadius: BorderRadius.circular(99)),
                            ),
                            const SizedBox(height: 12),
                            rightPanel,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
      bottomNavigationBar: isDesktop
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RideChatScreen(ride: ride))),
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('Chat with Driver'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: isDriver && isStarted
                          ? _completeRide
                          : () async {
                              if (!_mapController.isCompleted) return;
                              final c = await _mapController.future;
                              final fallback = gmap.LatLng(ride.origin.latitude, ride.origin.longitude);
                              await c.animateCamera(gmap.CameraUpdate.newLatLngZoom(_driverLivePoint ?? fallback, 14));
                            },
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
                      icon: Icon(isDriver && isStarted ? Icons.check_circle_outline : Icons.near_me_outlined),
                      label: Text(isDriver && isStarted ? 'Complete Ride' : 'View on Map'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Set<gmap.Marker> _buildMarkers(RideOffer ride, RideBooking? myBooking) {
    return {
      gmap.Marker(
        markerId: const gmap.MarkerId('origin'),
        position: gmap.LatLng(ride.origin.latitude, ride.origin.longitude),
        icon: gmap.BitmapDescriptor.defaultMarkerWithHue(gmap.BitmapDescriptor.hueGreen),
        infoWindow: gmap.InfoWindow(title: 'Pickup', snippet: LocationDisplayFormatter.title(ride.origin)),
      ),
      gmap.Marker(
        markerId: const gmap.MarkerId('destination'),
        position: gmap.LatLng(ride.destination.latitude, ride.destination.longitude),
        icon: gmap.BitmapDescriptor.defaultMarkerWithHue(gmap.BitmapDescriptor.hueRed),
        infoWindow: gmap.InfoWindow(title: 'Drop', snippet: LocationDisplayFormatter.title(ride.destination)),
      ),
      ...ride.intermediateStops.asMap().entries.map(
            (e) => gmap.Marker(
              markerId: gmap.MarkerId('stop-${e.key}'),
              position: gmap.LatLng(e.value.latitude, e.value.longitude),
              icon: gmap.BitmapDescriptor.defaultMarkerWithHue(gmap.BitmapDescriptor.hueAzure),
              infoWindow: gmap.InfoWindow(title: 'Stop ${e.key + 1}', snippet: e.value.name),
            ),
          ),
      if (_driverLivePoint != null)
        gmap.Marker(
          markerId: const gmap.MarkerId('driver'),
          position: _driverLivePoint!,
          icon: gmap.BitmapDescriptor.defaultMarkerWithHue(gmap.BitmapDescriptor.hueBlue),
          infoWindow: const gmap.InfoWindow(title: 'Driver'),
        ),
      if (myBooking?.passengerPickup != null)
        gmap.Marker(
          markerId: const gmap.MarkerId('my-pickup'),
          position: gmap.LatLng(myBooking!.passengerPickup!.latitude, myBooking.passengerPickup!.longitude),
          icon: gmap.BitmapDescriptor.defaultMarkerWithHue(gmap.BitmapDescriptor.hueGreen),
          infoWindow: gmap.InfoWindow(title: 'Your Pickup', snippet: LocationDisplayFormatter.title(myBooking.passengerPickup)),
        ),
      if (myBooking?.passengerDrop != null)
        gmap.Marker(
          markerId: const gmap.MarkerId('my-drop'),
          position: gmap.LatLng(myBooking!.passengerDrop!.latitude, myBooking.passengerDrop!.longitude),
          icon: gmap.BitmapDescriptor.defaultMarkerWithHue(gmap.BitmapDescriptor.hueRed),
          infoWindow: gmap.InfoWindow(title: 'Your Drop', snippet: LocationDisplayFormatter.title(myBooking.passengerDrop)),
        ),
    };
  }

  double _driverDistanceKm(RideBooking? booking) {
    if (_driverLivePoint == null || booking?.passengerPickup == null) return 2.4;
    return _distance.as(
          LengthUnit.Kilometer,
          LatLng(_driverLivePoint!.latitude, _driverLivePoint!.longitude),
          LatLng(booking!.passengerPickup!.latitude, booking.passengerPickup!.longitude),
        ) +
        0.0001;
  }

  int _etaMinutes(RideBooking? booking) {
    if (_driverLivePoint == null || booking?.passengerPickup == null) return 8;
    final meters = _distance.as(
      LengthUnit.Meter,
      LatLng(_driverLivePoint!.latitude, _driverLivePoint!.longitude),
      LatLng(booking!.passengerPickup!.latitude, booking.passengerPickup!.longitude),
    );
    return (meters / 350).ceil().clamp(3, 50);
  }
}

class _MapCard extends StatelessWidget {
  const _MapCard({
    required this.ride,
    required this.isStarted,
    required this.trackingMessage,
    required this.driverLivePoint,
    required this.distanceKm,
    required this.etaMin,
    required this.markers,
    required this.routePoints,
    required this.mapController,
    required this.routeLoading,
    required this.onUserMove,
    required this.onMyLocation,
  });

  final RideOffer ride;
  final bool isStarted;
  final String? trackingMessage;
  final gmap.LatLng? driverLivePoint;
  final double distanceKm;
  final int etaMin;
  final Set<gmap.Marker> markers;
  final List<gmap.LatLng> routePoints;
  final Completer<gmap.GoogleMapController> mapController;
  final bool routeLoading;
  final VoidCallback onUserMove;
  final VoidCallback onMyLocation;

  @override
  Widget build(BuildContext context) {
    final center = driverLivePoint ?? gmap.LatLng(ride.origin.latitude, ride.origin.longitude);
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          gmap.GoogleMap(
            initialCameraPosition: gmap.CameraPosition(target: center, zoom: 12),
            onMapCreated: (c) {
              if (!mapController.isCompleted) mapController.complete(c);
            },
            onCameraMoveStarted: onUserMove,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            markers: markers,
            polylines: {
              if (routePoints.length > 1)
                gmap.Polyline(
                  polylineId: const gmap.PolylineId('route'),
                  width: 6,
                  color: const Color(0xFF4F46E5),
                  points: routePoints,
                  geodesic: true,
                ),
            },
          ),
          if (routeLoading) const Positioned(left: 12, right: 12, top: 12, child: LinearProgressIndicator()),
          if (isStarted)
            Positioned(
              left: 14,
              top: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF6D28D9), Color(0xFF2563EB)]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Ride Started\n${trackingMessage == null || trackingMessage!.isEmpty ? 'Driver is on the way' : trackingMessage!}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          Positioned(
            right: 14,
            top: 14,
            child: FilledButton.tonalIcon(
              onPressed: () {},
              icon: const Icon(Icons.share_outlined),
              label: const Text('Share Live Trip'),
            ),
          ),
          Positioned(
            right: 14,
            bottom: 14,
            child: Column(
              children: [
                _MapControlButton(icon: Icons.my_location, onTap: onMyLocation),
                const SizedBox(height: 8),
                _MapControlButton(
                  icon: Icons.add,
                  onTap: () async {
                    if (!mapController.isCompleted) return;
                    final c = await mapController.future;
                    await c.animateCamera(gmap.CameraUpdate.zoomIn());
                  },
                ),
                const SizedBox(height: 8),
                _MapControlButton(
                  icon: Icons.remove,
                  onTap: () async {
                    if (!mapController.isCompleted) return;
                    final c = await mapController.future;
                    await c.animateCamera(gmap.CameraUpdate.zoomOut());
                  },
                ),
              ],
            ),
          ),
          Positioned(
            left: 14,
            bottom: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: const [
                BoxShadow(color: Color(0x22000000), blurRadius: 8, offset: Offset(0, 3)),
              ]),
              child: Text('ETA $etaMin min'),
            ),
          ),
          if (driverLivePoint != null)
            Positioned(
              left: 180,
              top: 180,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: const [
                  BoxShadow(color: Color(0x22000000), blurRadius: 8, offset: Offset(0, 3)),
                ]),
                child: Text('Driver on the way\n${distanceKm.toStringAsFixed(1)} km'),
              ),
            ),
        ],
      ),
    );
  }
}

class _MapControlButton extends StatelessWidget {
  const _MapControlButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(width: 42, height: 42, child: Icon(icon)),
      ),
    );
  }
}

class _RightPanel extends StatelessWidget {
  const _RightPanel({
    required this.ride,
    required this.myBooking,
    required this.isDriver,
    required this.trackingMessage,
    required this.onChat,
  });

  final RideOffer ride;
  final RideBooking? myBooking;
  final bool isDriver;
  final String? trackingMessage;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    final started = ride.status == 3;
    final timeline = [
      ('Pickup Point', LocationDisplayFormatter.title(myBooking?.passengerPickup ?? ride.origin), const Color(0xFF16A34A)),
      ...ride.intermediateStops.take(1).map((s) => ('Stop Point (En-route)', s.name, const Color(0xFF4F46E5))),
      ('Drop Point', LocationDisplayFormatter.title(myBooking?.passengerDrop ?? ride.destination), const Color(0xFFDC2626)),
    ];
    return Column(
      children: [
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Trip Summary', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 26)),
              const SizedBox(height: 10),
              _KVRow('Date & Time', DepartureTimeUtils.formatFriendly(ride.departureTimeUtc, context: 'Ride Details Summary')),
              _KVRow('Seat(s) Booked', '${myBooking?.seatsBooked ?? 1} Seat'),
              _KVRow('Booking Status', _statusLabel(ride.status)),
            ],
          ),
        ),
        if (started)
          _Card(
            child: Row(
              children: [
                const Icon(Icons.sensors, color: Color(0xFF1D4ED8)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    trackingMessage ?? (isDriver ? 'Your live location is being shared with passengers.' : 'Live tracking has started. You can see driver’s real-time location.'),
                    style: const TextStyle(color: Color(0xFF1D4ED8), fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        _Card(
          child: Row(
            children: [
              const CircleAvatar(radius: 28, child: Icon(Icons.person)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ride.driverName.isEmpty ? 'Driver' : ride.driverName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 24)),
                    const SizedBox(height: 4),
                    Text('★ 4.8  •  56 rides', style: TextStyle(color: Colors.grey.shade600)),
                    const SizedBox(height: 4),
                    Text('${ride.vehicleName ?? 'Vehicle'} • ${ride.vehicleNumber ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    const Text('Black', style: TextStyle(color: Color(0xFF6B7280))),
                  ],
                ),
              ),
              IconButton(onPressed: onChat, icon: const Icon(Icons.chat_bubble_outline)),
              IconButton(onPressed: () {}, icon: const Icon(Icons.call_outlined)),
            ],
          ),
        ),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Trip Route', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 24)),
              const SizedBox(height: 10),
              ...timeline.map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        CircleAvatar(radius: 6, backgroundColor: t.$3),
                        const SizedBox(width: 10),
                        Expanded(child: Text('${t.$1}\n${t.$2}')),
                      ],
                    ),
                  )),
            ],
          ),
        ),
      ],
    );
  }

  String _statusLabel(int status) {
    return switch (status) {
      1 => 'Open',
      2 => 'Full',
      3 => 'Ride Started',
      4 => 'Completed',
      5 => 'Cancelled',
      _ => 'Booked',
    };
  }
}

class _VehicleFooterCard extends StatelessWidget {
  const _VehicleFooterCard({required this.ride});
  final RideOffer ride;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Row(
        children: [
          const Icon(Icons.directions_car_filled, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Vehicle Details', style: TextStyle(fontWeight: FontWeight.w700)),
                Text('${ride.vehicleName ?? 'Vehicle'} • ${ride.vehicleNumber ?? ''}'),
                const Text('Black • Luxury', style: TextStyle(color: Color(0xFF6B7280))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: child,
    );
  }
}

class _KVRow extends StatelessWidget {
  const _KVRow(this.k, this.v);
  final String k;
  final String v;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(k, style: const TextStyle(color: Color(0xFF6B7280)))),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
