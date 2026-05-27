import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;
import 'package:provider/provider.dart';

import '../../core/constants/app_routes.dart';
import '../../core/utils/departure_time_utils.dart';
import '../../core/utils/location_display_formatter.dart';
import '../../core/widgets/app_design_system.dart';
import '../../core/widgets/ride_timeline_widgets.dart';
import '../../models/booking_models.dart';
import '../../models/ride_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../providers/ride_provider.dart';
import '../../services/map_service.dart';
import 'ride_chat_screen.dart';

class RideDetailsScreen extends StatefulWidget {
  const RideDetailsScreen({super.key, this.extra});

  final Object? extra;

  @override
  State<RideDetailsScreen> createState() => _RideDetailsScreenState();
}

class _RideDetailsScreenState extends State<RideDetailsScreen> {
  final Completer<gmap.GoogleMapController> _mapController = Completer();
  static const double _defaultZoom = 12;
  List<gmap.LatLng> _routePoints = const [];
  bool _isRouteLoading = false;
  List<RideBooking> _participants = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bookingProvider = context.read<BookingProvider>();
      if (bookingProvider.bookings.isEmpty && !bookingProvider.isLoading) {
        bookingProvider.loadHistory();
      }
      final ride = widget.extra is RideOffer ? widget.extra as RideOffer : null;
      if (ride != null) {
        _loadRoadRoute(ride);
        _loadParticipants(ride.id);
      }
    });
  }

  Future<void> _loadParticipants(String rideId) async {
    try {
      final list = await context.read<RideProvider>().participants(rideId);
      if (!mounted) return;
      setState(() => _participants = list);
    } catch (_) {}
  }

  List<gmap.LatLng> _decodePolyline(String encoded) {
    var index = 0;
    var lat = 0;
    var lng = 0;
    final points = <gmap.LatLng>[];
    while (index < encoded.length) {
      var b = 0;
      var shift = 0;
      var result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20 && index < encoded.length);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20 && index < encoded.length);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      points.add(gmap.LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }

  Future<void> _loadRoadRoute(RideOffer ride) async {
    setState(() => _isRouteLoading = true);
    try {
      final chain = <GeoPoint>[
        ride.origin,
        ...ride.intermediateStops.map((s) => GeoPoint(
            name: s.name, latitude: s.latitude, longitude: s.longitude)),
        ride.destination,
      ];
      final route = <gmap.LatLng>[];
      for (var i = 0; i < chain.length - 1; i++) {
        final a = chain[i];
        final b = chain[i + 1];
        final seg = await context.read<MapService>().route(
              fromLatitude: a.latitude,
              fromLongitude: a.longitude,
              toLatitude: b.latitude,
              toLongitude: b.longitude,
            );
        final encoded = seg['encodedPolyline']?.toString() ?? '';
        final points = _decodePolyline(encoded);
        if (route.isNotEmpty && points.isNotEmpty) {
          route.addAll(points.skip(1));
        } else {
          route.addAll(points);
        }
      }
      if (!mounted) return;
      setState(() => _routePoints = route);
    } catch (_) {
      if (!mounted) return;
      setState(() => _routePoints = const []);
    } finally {
      if (mounted) setState(() => _isRouteLoading = false);
    }
  }

  Future<void> _moveTo(gmap.LatLng target, double zoom) async {
    final c = await _mapController.future;
    await c.animateCamera(gmap.CameraUpdate.newLatLngZoom(target, zoom));
  }

  @override
  Widget build(BuildContext context) {
    final ride = widget.extra is RideOffer ? widget.extra as RideOffer : null;
    final myUserId = context.watch<AuthProvider>().session?.userId;
    final bookings = context.watch<BookingProvider>().bookings;
    final isMyRide =
        ride != null && myUserId != null && myUserId == ride.driverId;

    if (ride == null) {
      return const Scaffold(
          body: Center(child: Text('Ride details unavailable')));
    }

    final fallbackPoints = <gmap.LatLng>[
      gmap.LatLng(ride.origin.latitude, ride.origin.longitude),
      ...ride.intermediateStops
          .map((s) => gmap.LatLng(s.latitude, s.longitude)),
      gmap.LatLng(ride.destination.latitude, ride.destination.longitude),
    ];

    final center = fallbackPoints[fallbackPoints.length ~/ 2];
    final markers = <gmap.Marker>{
      gmap.Marker(
        markerId: const gmap.MarkerId('origin'),
        position: gmap.LatLng(ride.origin.latitude, ride.origin.longitude),
        infoWindow: gmap.InfoWindow(title: ride.origin.name),
      ),
      gmap.Marker(
        markerId: const gmap.MarkerId('destination'),
        position:
            gmap.LatLng(ride.destination.latitude, ride.destination.longitude),
        infoWindow: gmap.InfoWindow(title: ride.destination.name),
      ),
      ...ride.intermediateStops.asMap().entries.map(
            (e) => gmap.Marker(
              markerId: gmap.MarkerId('stop-${e.key}'),
              position: gmap.LatLng(e.value.latitude, e.value.longitude),
              icon: gmap.BitmapDescriptor.defaultMarkerWithHue(
                  gmap.BitmapDescriptor.hueAzure),
              infoWindow: gmap.InfoWindow(
                  title: 'Drop ${e.key + 1}', snippet: e.value.name),
            ),
          ),
    };

    final mapWidget = SizedBox(
      height: 280,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: gmap.GoogleMap(
              initialCameraPosition:
                  gmap.CameraPosition(target: center, zoom: _defaultZoom),
              onMapCreated: (c) {
                if (!_mapController.isCompleted) _mapController.complete(c);
              },
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              myLocationButtonEnabled: false,
              markers: markers,
              polylines: {
                if (_routePoints.length > 1)
                  gmap.Polyline(
                    polylineId: const gmap.PolylineId('ride_line'),
                    width: 5,
                    color: AppDesignTokens.brandStart,
                    points: _routePoints,
                    geodesic: true,
                    startCap: gmap.Cap.roundCap,
                    endCap: gmap.Cap.roundCap,
                  ),
              },
            ),
          ),
          if (_isRouteLoading)
            const Positioned(
              left: 12,
              right: 12,
              top: 12,
              child: LinearProgressIndicator(),
            ),
          Positioned(
            right: 12,
            bottom: 12,
            child: AppMapControls(
              onZoomIn: () => _moveTo(center, 15.5),
              onZoomOut: () => _moveTo(center, 10.8),
              onRecenter: () => _moveTo(center, _defaultZoom),
            ),
          ),
        ],
      ),
    );

    final detailsWidget = Column(
      children: [
        Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFFEEF0FF),
              child: Text(
                (ride.driverName.isEmpty ? 'D' : ride.driverName[0])
                    .toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppDesignTokens.brandStart,
                ),
              ),
            ),
            title: Text(ride.driverName.isEmpty ? 'Driver' : ride.driverName),
            subtitle: const Text('Verified profile'),
            trailing: Text(
              '₹${ride.pricePerSeat}',
              style: const TextStyle(
                color: AppDesignTokens.brandStart,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.route_outlined),
            title: Text(LocationDisplayFormatter.routeTitle(ride.origin, ride.destination)),
            subtitle: Text('${LocationDisplayFormatter.compactAddress(ride.origin)} · ${ride.availableSeats} seats available'),
          ),
        ),
        Builder(
          builder: (_) {
            final myBooking = bookings
                .where((b) => b.rideOfferId == ride.id)
                .toList()
              ..sort((a, b) => b.createdAtUtc.compareTo(a.createdAtUtc));
            final latest = myBooking.isEmpty ? null : myBooking.first;
            final nodes = buildRideTimeline(
              ride: ride,
              yourPickupName: latest?.passengerPickup == null
                  ? null
                  : LocationDisplayFormatter.title(latest!.passengerPickup!),
              yourDropName: latest?.passengerDrop == null
                  ? null
                  : LocationDisplayFormatter.title(latest!.passengerDrop!),
              departureUtc: ride.departureTimeUtc,
            );
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Full Route Timeline', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    RideVerticalTimeline(nodes: nodes),
                  ],
                ),
              ),
            );
          },
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.schedule_outlined),
            title: const Text('Departure'),
            subtitle: Text(
              DepartureTimeUtils.formatFriendly(
                ride.departureTimeUtc,
                context: 'Ride Details',
              ),
            ),
          ),
        ),
        if (ride.intermediateStops.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Drop Points',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ride.intermediateStops
                        .map((s) => Chip(label: Text(s.name)))
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
        if (_participants.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Participants',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  ..._participants.map(
                    (p) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.person_outline),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    p.passengerName,
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('${p.seatsBooked} seat'),
                                    const SizedBox(height: 2),
                                    const Text('Booked', style: TextStyle(fontSize: 12, color: Colors.green)),
                                  ],
                                ),
                              ],
                            ),
                            if (p.passengerPickup != null) ...[
                              const SizedBox(height: 6),
                              Text('Your Pickup: ${LocationDisplayFormatter.title(p.passengerPickup)}'),
                            ],
                            if (p.passengerDrop != null) ...[
                              const SizedBox(height: 2),
                              Text('Your Drop: ${LocationDisplayFormatter.title(p.passengerDrop)}'),
                            ],
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: OutlinedButton.icon(
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => RideChatScreen(ride: ride)),
                                ),
                                icon: const Icon(Icons.chat_bubble_outline),
                                label: const Text('Chat'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Builder(
          builder: (context) {
            final myBooking = bookings
                .where((b) => b.rideOfferId == ride.id)
                .toList()
              ..sort((a, b) => b.createdAtUtc.compareTo(a.createdAtUtc));
            if (myBooking.isEmpty) return const SizedBox.shrink();
            final latest = myBooking.first;
            final color = switch (latest.bookingStatus) {
              BookingStatus.accepted => Colors.green,
              BookingStatus.rejected || BookingStatus.cancelled => Colors.red,
              BookingStatus.completed => Colors.teal,
              _ => Colors.orange,
            };
            final bookingLabel = latest.bookingStatus == BookingStatus.accepted
                ? 'Booked'
                : latest.bookingStatus.label;
            return Card(
              child: ListTile(
                leading: Icon(Icons.verified, color: color),
                title: Text('Your booking: $bookingLabel'),
                subtitle: Text('${latest.seatsBooked} seat(s) requested'),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: isMyRide
                    ? null
                    : () => context.push(AppRoutes.booking, extra: ride),
                child: Text(isMyRide ? 'Your own ride' : 'Book Seat'),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => RideChatScreen(ride: ride)),
              ),
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Ride Chat'),
            ),
          ],
        ),
        if (isMyRide)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'You cannot book your own ride.',
              style: TextStyle(color: Colors.red),
            ),
          ),
      ],
    );

    return Scaffold(
      backgroundColor: AppDesignTokens.pageBg,
      appBar: AppBar(title: const Text('Ride Details')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 920;
          final scrollBody = isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 6, child: mapWidget),
                    const SizedBox(width: 12),
                    Expanded(flex: 5, child: detailsWidget),
                  ],
                )
              : Column(
                  children: [
                    mapWidget,
                    const SizedBox(height: 12),
                    detailsWidget,
                  ],
                );
          return SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: scrollBody,
          );
        },
      ),
    );
  }
}
