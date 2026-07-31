import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/utils/departure_time_utils.dart';
import '../../core/utils/location_permission_helper.dart';
import '../../core/utils/location_display_formatter.dart';
import '../../models/booking_models.dart';
import '../../models/ride_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
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
  gmap.LatLng? _driverLivePoint;
  String? _trackingMessage;
  bool _mapMovedByUser = false;
  gmap.BitmapDescriptor? _pickupMarkerIcon;
  gmap.BitmapDescriptor? _stopMarkerIcon;
  gmap.BitmapDescriptor? _destinationMarkerIcon;
  gmap.BitmapDescriptor? _driverMarkerIcon;
  Timer? _passengerPollTimer;
  gmap.LatLng _fallbackMapCenter = const gmap.LatLng(
    LocationPermissionHelper.indoreLatitude,
    LocationPermissionHelper.indoreLongitude,
  );

  // New: covers the brief async setup (marker icons, fallback location,
  // booking history, camera fit, tracking sync) with a shimmer instead of
  // flashing content or the "unavailable" message.
  bool _detailsLoading = true;

  @override
  void initState() {
    super.initState();
    // Extract the ride synchronously — widget.extra is already available
    // right away, no need to wait for a post-frame callback to read it.
    _ride = widget.extra is RideOffer ? widget.extra as RideOffer : null;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ride = _ride;
      if (ride == null) {
        // Genuinely nothing to show — stop "loading" and let build()
        // render the unavailable state.
        if (mounted) setState(() => _detailsLoading = false);
        return;
      }

      final bookingProvider = context.read<BookingProvider>();
      await _prepareMarkerIcons();
      await _initializeFallbackMapCenter();
      if (!mounted) return;
      if (bookingProvider.bookings.isEmpty && !bookingProvider.isLoading) {
        await bookingProvider.loadHistory();
      }
      if (!mounted) return;

      await _fitCamera();
      await _syncTracking(ride);
      if (!mounted) return;
      setState(() => _detailsLoading = false);
    });
  }

  Future<void> _initializeFallbackMapCenter() async {
    final location = await LocationPermissionHelper.currentOrFallback();
    if (!mounted) return;
    setState(() {
      _fallbackMapCenter = gmap.LatLng(location.latitude, location.longitude);
    });
  }

  Future<void> _prepareMarkerIcons() async {
    try {
      final pixelRatio = WidgetsBinding
          .instance.platformDispatcher.views.first.devicePixelRatio;
      final pickup = await _buildMarkerIconBytes(
        const Color(0xFF16A34A),
        pixelRatio: pixelRatio,
      );
      final stop = await _buildMarkerIconBytes(
        const Color(0xFF2563EB),
        pixelRatio: pixelRatio,
      );
      final destination = await _buildMarkerIconBytes(
        const Color(0xFFDC2626),
        pixelRatio: pixelRatio,
      );
      final driver = await _buildDriverMarkerIconBytes(pixelRatio: pixelRatio);
      if (!mounted) return;
      setState(() {
        _pickupMarkerIcon = gmap.BitmapDescriptor.bytes(pickup);
        _stopMarkerIcon = gmap.BitmapDescriptor.bytes(stop);
        _destinationMarkerIcon = gmap.BitmapDescriptor.bytes(destination);
        _driverMarkerIcon = gmap.BitmapDescriptor.bytes(driver);
      });
    } catch (_) {
      // Keep hue-based fallback markers if custom icon generation fails.
    }
  }

  Future<Uint8List> _buildMarkerIconBytes(
    Color color, {
    required double pixelRatio,
  }) async {
    final scale = pixelRatio.clamp(1.0, 3.0);
    final width = 44.0 * scale;
    final height = 54.0 * scale;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));

    final fill = Paint()..color = color;
    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4 * scale;
    final shadow = Paint()..color = Colors.black.withValues(alpha: 0.2);

    final circleCenter = Offset(width / 2, 18.0 * scale);
    final radius = 12.0 * scale;
    final tail = ui.Path()
      ..moveTo(width / 2, 46.0 * scale)
      ..lineTo((width / 2) - 7.0 * scale, 28.0 * scale)
      ..lineTo((width / 2) + 7.0 * scale, 28.0 * scale)
      ..close();

    canvas.drawCircle(circleCenter + Offset(0, 1.5 * scale), radius, shadow);
    canvas.drawPath(tail.shift(Offset(0, 1.5 * scale)), shadow);
    canvas.drawCircle(circleCenter, radius, fill);
    canvas.drawPath(tail, fill);
    canvas.drawCircle(circleCenter, radius, stroke);
    canvas.drawPath(tail, stroke);

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.ceil(), height.ceil());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  Future<Uint8List> _buildDriverMarkerIconBytes({
    required double pixelRatio,
  }) async {
    final scale = pixelRatio.clamp(1.0, 3.0);
    final width = 58.0 * scale;
    final height = 58.0 * scale;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));
    final center = Offset(width / 2, height / 2);
    final shadow = Paint()..color = Colors.black.withValues(alpha: 0.22);
    final fill = Paint()..color = const Color(0xFF2563EB);
    final glass = Paint()..color = Colors.white.withValues(alpha: 0.92);
    final wheel = Paint()..color = const Color(0xFF0F172A);

    canvas.drawCircle(center + Offset(0, 2 * scale), 22 * scale, shadow);
    canvas.drawCircle(center, 22 * scale, fill);

    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: 30 * scale, height: 22 * scale),
      Radius.circular(7 * scale),
    );
    canvas.drawRRect(body, glass);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center.translate(0, -3 * scale),
          width: 18 * scale,
          height: 8 * scale,
        ),
        Radius.circular(4 * scale),
      ),
      fill,
    );
    canvas.drawCircle(
        center.translate(-11 * scale, 9 * scale), 3 * scale, wheel);
    canvas.drawCircle(
        center.translate(11 * scale, 9 * scale), 3 * scale, wheel);

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.ceil(), height.ceil());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  @override
  void dispose() {
    _passengerPollTimer?.cancel();
    context.read<TrackingService>().stopAll();
    super.dispose();
  }

  List<gmap.LatLng> _fallbackRoutePoints(RideOffer ride) {
    final routePoints = <gmap.LatLng>[
      gmap.LatLng(ride.origin.latitude, ride.origin.longitude),
      ...ride.intermediateStops
          .map((s) => gmap.LatLng(s.latitude, s.longitude)),
      gmap.LatLng(ride.destination.latitude, ride.destination.longitude),
    ];
    return _sanitizeRoutePoints(routePoints);
  }

  List<gmap.LatLng> _sanitizeRoutePoints(List<gmap.LatLng> input) {
    final cleaned = <gmap.LatLng>[];
    for (final p in input) {
      if (!_isValidCoordinate(p.latitude, p.longitude)) continue;
      if (cleaned.isNotEmpty) {
        final prev = cleaned.last;
        final isDup = (prev.latitude - p.latitude).abs() < 0.000001 &&
            (prev.longitude - p.longitude).abs() < 0.000001;
        if (isDup) continue;
      }
      cleaned.add(gmap.LatLng(p.latitude, p.longitude));
    }
    return cleaned;
  }

  bool _isValidCoordinate(double lat, double lng) {
    return lat.isFinite &&
        lng.isFinite &&
        lat >= -90 &&
        lat <= 90 &&
        lng >= -180 &&
        lng <= 180;
  }

  Future<void> _syncTracking(RideOffer ride) async {
    final authProvider = context.read<AuthProvider>();
    final bookingProvider = context.read<BookingProvider>();
    final trackingService = context.read<TrackingService>();
    _passengerPollTimer?.cancel();
    await trackingService.stopAll();
    if (ride.status != 3) {
      setState(() {
        _trackingMessage = null;
        _driverLivePoint = null;
      });
      return;
    }

    final myUserId = authProvider.session?.userId;
    final isDriver = myUserId != null && ride.driverId == myUserId;
    final myBooking = _latestBookingFrom(bookingProvider, ride.id, myUserId);
    final isBookedPassenger =
        myBooking != null && myBooking.bookingStatus == BookingStatus.accepted;

    if (isDriver) {
      await _startDriverTracking(ride, trackingService);
      return;
    }
    if (isBookedPassenger) {
      await _startPassengerTracking(ride, trackingService);
      return;
    }
    setState(() => _trackingMessage = 'Waiting for driver location...');
  }

  RideBooking? _latestBooking(String rideId) {
    final myUserId = context.read<AuthProvider>().session?.userId;
    return _latestBookingFrom(
        context.read<BookingProvider>(), rideId, myUserId);
  }

  RideBooking? _latestBookingFrom(
      BookingProvider bookingProvider, String rideId, String? myUserId) {
    final list = bookingProvider.bookings
        .where((b) => b.rideOfferId == rideId && b.passengerId == myUserId)
        .toList()
      ..sort((a, b) => b.createdAtUtc.compareTo(a.createdAtUtc));
    return list.isEmpty ? null : list.first;
  }

  Future<void> _startDriverTracking(
      RideOffer ride, TrackingService trackingService) async {
    if (mounted) {
      setState(() => _trackingMessage =
          'Your live location is being shared with passengers.');
    }

    final started = await trackingService.startDriverLocationSharing(
      ride.id,
      onPublished: (payload) async {
        final lat = (payload['latitude'] as num?)?.toDouble();
        final lng = (payload['longitude'] as num?)?.toDouble();
        if (!mounted || lat == null || lng == null) return;
        final next = gmap.LatLng(lat, lng);
        setState(() => _driverLivePoint = next);
        await _fitCamera();
      },
    );

    if (!mounted) return;
    if (!started) {
      setState(() => _trackingMessage =
          LocationPermissionHelper.liveTrackingRequiredMessage);
    }
  }

  Future<void> _startPassengerTracking(
      RideOffer ride, TrackingService trackingService) async {
    Future<void> fetchLatest() async {
      final data = await trackingService.latestLocation(ride.id);
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
    try {
      await trackingService.connect(
        ride.id,
        (payload) async {
          final lat = (payload['latitude'] as num?)?.toDouble();
          final lng = (payload['longitude'] as num?)?.toDouble();
          if (!mounted || lat == null || lng == null) return;
          setState(() {
            _driverLivePoint = gmap.LatLng(lat, lng);
            _trackingMessage = 'Driver is on the way';
          });
          await _fitCamera();
        },
        onTrackingStopped: () {
          if (!mounted) return;
          _passengerPollTimer?.cancel();
          setState(() => _trackingMessage = 'Tracking stopped');
        },
      );
    } catch (_) {}
  }

  Future<void> _fitCamera() async {
    if (_mapMovedByUser) return;
    if (!_mapController.isCompleted) return;
    final ride = _ride;
    if (ride == null) return;

    final pts = _sanitizeRoutePoints([
      if (_driverLivePoint != null) _driverLivePoint!,
      ..._fallbackRoutePoints(ride),
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
    await context.read<TrackingService>().stopAll();
    await _syncTracking(updated);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Ride completed')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ride = _ride;

    if (ride == null) {
      // Only reached when there genuinely is no ride data — never as a
      // loading flash, since _ride is now set synchronously in initState.
      return const Scaffold(
          body: Center(child: Text('Ride details unavailable')));
    }

    final isDesktop = MediaQuery.of(context).size.width >= 1100;

    if (_detailsLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF7F8FC),
        appBar: AppBar(
          leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).maybePop()),
          title: const Text('Ride Details'),
        ),
        body: SafeArea(
          child: _ShimmerRideDetails(isDesktop: isDesktop),
        ),
      );
    }

    final myUserId = context.watch<AuthProvider>().session?.userId;
    final isDriver = myUserId != null && ride.driverId == myUserId;
    final isStarted = ride.status == 3;
    final myBooking = _latestBooking(ride.id);
    final distanceKm = _driverDistanceKm(myBooking);
    final etaMin = _etaMinutes(myBooking);

    final markers = _buildMarkers(ride);

    final mapCard = _MapCard(
      ride: ride,
      isStarted: isStarted,
      trackingMessage: _trackingMessage,
      driverLivePoint: _driverLivePoint,
      distanceKm: distanceKm,
      etaMin: etaMin,
      markers: markers,
      mapController: _mapController,
      onUserMove: () => _mapMovedByUser = true,
      fallbackCenter: _fallbackMapCenter,
      onMyLocation: () async {
        if (!_mapController.isCompleted) return;
        final c = await _mapController.future;
        final fallback = _validRideOriginOrFallback(ride);
        await c.animateCamera(
            gmap.CameraUpdate.newLatLngZoom(_driverLivePoint ?? fallback, 14));
      },
    );

    final rightPanel = _RightPanel(
      ride: ride,
      myBooking: myBooking,
      isDriver: isDriver,
      trackingMessage: _trackingMessage,
      onChat: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => RideChatScreen(ride: ride))),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).maybePop()),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ride Details'),
            Text(
              'Ride ID: #${ride.id.substring(0, 8).toUpperCase()}',
              style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w500),
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
                  Text('CarPool',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1D4ED8))),
                ],
              ),
            ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => RideChatScreen(ride: ride))),
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
                                  onPressed: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              RideChatScreen(ride: ride))),
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
                                    final fallback =
                                        _validRideOriginOrFallback(ride);
                                    await c.animateCamera(
                                        gmap.CameraUpdate.newLatLngZoom(
                                            _driverLivePoint ?? fallback, 14));
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
                                    style: FilledButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF4F46E5)),
                                    icon:
                                        const Icon(Icons.check_circle_outline),
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
                    Expanded(
                        flex: 5,
                        child: SingleChildScrollView(child: rightPanel)),
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
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(24)),
                        boxShadow: [
                          BoxShadow(
                              color: Color(0x19000000),
                              blurRadius: 14,
                              offset: Offset(0, -4))
                        ],
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 120),
                        child: Column(
                          children: [
                            Container(
                              width: 42,
                              height: 5,
                              decoration: BoxDecoration(
                                  color: const Color(0xFFD1D5DB),
                                  borderRadius: BorderRadius.circular(99)),
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
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => RideChatScreen(ride: ride))),
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
                              final fallback = _validRideOriginOrFallback(ride);
                              await c.animateCamera(
                                  gmap.CameraUpdate.newLatLngZoom(
                                      _driverLivePoint ?? fallback, 14));
                            },
                      style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5)),
                      icon: Icon(isDriver && isStarted
                          ? Icons.check_circle_outline
                          : Icons.near_me_outlined),
                      label: Text(isDriver && isStarted
                          ? 'Complete Ride'
                          : 'View on Map'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Set<gmap.Marker> _buildMarkers(RideOffer ride) {
    return {
      if (_driverLivePoint != null)
        gmap.Marker(
          markerId: const gmap.MarkerId('driver-live'),
          position: _driverLivePoint!,
          icon: _driverMarkerIcon ??
              gmap.BitmapDescriptor.defaultMarkerWithHue(
                gmap.BitmapDescriptor.hueAzure,
              ),
          infoWindow: const gmap.InfoWindow(
            title: 'Driver',
            snippet: 'Live location',
          ),
        ),
      gmap.Marker(
        markerId: const gmap.MarkerId('origin'),
        position: gmap.LatLng(ride.origin.latitude, ride.origin.longitude),
        icon: _pickupMarkerIcon ??
            gmap.BitmapDescriptor.defaultMarkerWithHue(
              gmap.BitmapDescriptor.hueGreen,
            ),
        infoWindow: gmap.InfoWindow(
            title: 'Pickup',
            snippet: LocationDisplayFormatter.title(ride.origin)),
      ),
      gmap.Marker(
        markerId: const gmap.MarkerId('destination'),
        position:
            gmap.LatLng(ride.destination.latitude, ride.destination.longitude),
        icon: _destinationMarkerIcon ??
            gmap.BitmapDescriptor.defaultMarkerWithHue(
              gmap.BitmapDescriptor.hueRed,
            ),
        infoWindow: gmap.InfoWindow(
            title: 'Destination',
            snippet: LocationDisplayFormatter.title(ride.destination)),
      ),
      ...ride.intermediateStops.asMap().entries.map(
            (e) => gmap.Marker(
              markerId: gmap.MarkerId('stop-${e.key}'),
              position: gmap.LatLng(e.value.latitude, e.value.longitude),
              icon: _stopMarkerIcon ??
                  gmap.BitmapDescriptor.defaultMarkerWithHue(
                    gmap.BitmapDescriptor.hueBlue,
                  ),
              infoWindow: gmap.InfoWindow(
                  title: 'Stop ${e.key + 1}', snippet: e.value.name),
            ),
          ),
    };
  }

  gmap.LatLng _validRideOriginOrFallback(RideOffer ride) =>
      _isValidCoordinate(ride.origin.latitude, ride.origin.longitude)
          ? gmap.LatLng(ride.origin.latitude, ride.origin.longitude)
          : _fallbackMapCenter;

  double _driverDistanceKm(RideBooking? booking) {
    if (_driverLivePoint == null || booking?.passengerPickup == null) {
      return 2.4;
    }
    return _distance.as(
          LengthUnit.Kilometer,
          LatLng(_driverLivePoint!.latitude, _driverLivePoint!.longitude),
          LatLng(booking!.passengerPickup!.latitude,
              booking.passengerPickup!.longitude),
        ) +
        0.0001;
  }

  int _etaMinutes(RideBooking? booking) {
    if (_driverLivePoint == null || booking?.passengerPickup == null) return 8;
    final meters = _distance.as(
      LengthUnit.Meter,
      LatLng(_driverLivePoint!.latitude, _driverLivePoint!.longitude),
      LatLng(booking!.passengerPickup!.latitude,
          booking.passengerPickup!.longitude),
    );
    return (meters / 350).ceil().clamp(3, 50);
  }
}

// ============================================================
// Shimmer loading skeleton — shown only while marker icons,
// fallback location, booking history, and tracking sync resolve.
// ============================================================

class _ShimmerRideDetails extends StatelessWidget {
  const _ShimmerRideDetails({required this.isDesktop});

  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    if (isDesktop) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 8,
              child: Column(
                children: const [
                  Expanded(child: _Shimmer(child: _ShimmerBox(radius: 18))),
                  SizedBox(height: 10),
                  _Shimmer(child: _ShimmerBox(height: 80, radius: 16)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 5,
              child: ListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: const [
                  _ShimmerDetailsCard(),
                  _ShimmerDetailsCard(lines: 2),
                  _ShimmerDetailsCard(lines: 4),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        const SizedBox(
          height: 360,
          child: _Shimmer(child: _ShimmerBox(radius: 18)),
        ),
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
              children: const [
                _ShimmerDetailsCard(),
                _ShimmerDetailsCard(lines: 2),
                _ShimmerDetailsCard(lines: 4),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ShimmerDetailsCard extends StatelessWidget {
  const _ShimmerDetailsCard({this.lines = 3});

  final int lines;

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
      child: _Shimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _ShimmerBox(width: 140, height: 20, radius: 6),
            const SizedBox(height: 14),
            for (var i = 0; i < lines; i++) ...[
              _ShimmerBox(
                  width: i.isEven ? double.infinity : 200,
                  height: 14,
                  radius: 6),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  const _ShimmerBox({
    this.width,
    this.height = 14,
    this.radius = 8,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Lightweight shimmer sweep effect with no external dependency.
class _Shimmer extends StatefulWidget {
  const _Shimmer({required this.child});

  final Widget child;

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            final t = _controller.value;
            return LinearGradient(
              colors: const [
                Color(0xFFE2E8F0),
                Color(0xFFF8FAFC),
                Color(0xFFE2E8F0),
              ],
              stops: const [0.35, 0.5, 0.65],
              begin: Alignment(-1 - t * 2, 0),
              end: Alignment(1 - t * 2, 0),
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
      child: widget.child,
    );
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
    required this.mapController,
    required this.onUserMove,
    required this.fallbackCenter,
    required this.onMyLocation,
  });

  final RideOffer ride;
  final bool isStarted;
  final String? trackingMessage;
  final gmap.LatLng? driverLivePoint;
  final double distanceKm;
  final int etaMin;
  final Set<gmap.Marker> markers;
  final Completer<gmap.GoogleMapController> mapController;
  final VoidCallback onUserMove;
  final gmap.LatLng fallbackCenter;
  final VoidCallback onMyLocation;

  @override
  Widget build(BuildContext context) {
    final originIsValid = ride.origin.latitude.isFinite &&
        ride.origin.longitude.isFinite &&
        ride.origin.latitude >= -90 &&
        ride.origin.latitude <= 90 &&
        ride.origin.longitude >= -180 &&
        ride.origin.longitude <= 180;
    final center = driverLivePoint ??
        (originIsValid
            ? gmap.LatLng(ride.origin.latitude, ride.origin.longitude)
            : fallbackCenter);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth && constraints.maxWidth > 0
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        final height = constraints.hasBoundedHeight && constraints.maxHeight > 0
            ? constraints.maxHeight
            : 360.0;
        return SizedBox(
          width: width,
          height: height,
          child: Card(
            margin: EdgeInsets.zero,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                SizedBox.expand(
                  child: gmap.GoogleMap(
                    initialCameraPosition:
                        gmap.CameraPosition(target: center, zoom: 12),
                    onMapCreated: (c) {
                      if (!mapController.isCompleted) mapController.complete(c);
                    },
                    onCameraMoveStarted: onUserMove,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    markers: markers,
                    polylines: const {},
                  ),
                ),
                if (isStarted)
                  Positioned(
                    left: 14,
                    top: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xFF6D28D9), Color(0xFF2563EB)]),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'Ride Started\n${trackingMessage == null || trackingMessage!.isEmpty ? 'Driver is on the way' : trackingMessage!}',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700),
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
                      _MapControlButton(
                          icon: Icons.my_location, onTap: onMyLocation),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0x22000000),
                              blurRadius: 8,
                              offset: Offset(0, 3)),
                        ]),
                    child: Text('ETA $etaMin min'),
                  ),
                ),
                if (driverLivePoint != null)
                  Positioned(
                    left: 14,
                    bottom: 56,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      constraints: BoxConstraints(
                        maxWidth: (width - 28).clamp(160.0, 260.0),
                      ),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: const [
                            BoxShadow(
                                color: Color(0x22000000),
                                blurRadius: 8,
                                offset: Offset(0, 3)),
                          ]),
                      child: Text(
                          'Driver on the way\n${distanceKm.toStringAsFixed(1)} km'),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
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
    final timeline = <(String, String, Color)>[
      (
        'Pickup Point',
        LocationDisplayFormatter.title(ride.origin),
        const Color(0xFF16A34A)
      ),
      ...ride.intermediateStops.asMap().entries.map(
            (e) => ('Stop ${e.key + 1}', e.value.name, const Color(0xFF2563EB)),
          ),
      (
        'Destination Point',
        LocationDisplayFormatter.title(ride.destination),
        const Color(0xFFDC2626)
      ),
    ];
    return Column(
      children: [
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Trip Summary',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 26)),
              const SizedBox(height: 10),
              _KVRow(
                  'Date & Time',
                  DepartureTimeUtils.formatFriendly(ride.departureTimeUtc,
                      context: 'Ride Details Summary')),
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
                    trackingMessage ??
                        (isDriver
                            ? 'Your live location is being shared with passengers.'
                            : 'Live tracking has started. You can see driver’s real-time location.'),
                    style: const TextStyle(
                        color: Color(0xFF1D4ED8), fontWeight: FontWeight.w600),
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
                    Text(ride.driverName.isEmpty ? 'Driver' : ride.driverName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 24)),
                    const SizedBox(height: 4),
                    Text('★ 4.8  •  56 rides',
                        style: TextStyle(color: Colors.grey.shade600)),
                    const SizedBox(height: 4),
                    Text(
                        '${ride.vehicleName ?? 'Vehicle'} • ${ride.vehicleNumber ?? ''}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const Text('Black',
                        style: TextStyle(color: Color(0xFF6B7280))),
                  ],
                ),
              ),
              IconButton(
                  onPressed: onChat,
                  icon: const Icon(Icons.chat_bubble_outline)),
              IconButton(
                  onPressed: () {}, icon: const Icon(Icons.call_outlined)),
            ],
          ),
        ),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Trip Route',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 24)),
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
                const Text('Vehicle Details',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                Text(
                    '${ride.vehicleName ?? 'Vehicle'} • ${ride.vehicleNumber ?? ''}'),
                const Text('Black • Luxury',
                    style: TextStyle(color: Color(0xFF6B7280))),
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
          Expanded(
              child: Text(k, style: const TextStyle(color: Color(0xFF6B7280)))),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
