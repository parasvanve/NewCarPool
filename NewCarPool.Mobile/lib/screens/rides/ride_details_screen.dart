import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import '../../models/ride_models.dart';

class RideDetailsScreen extends StatelessWidget {
  const RideDetailsScreen({super.key, this.extra});

  final Object? extra;

  @override
  Widget build(BuildContext context) {
    final ride = extra is RideOffer ? extra as RideOffer : null;
    return Scaffold(
      appBar: AppBar(title: const Text('Ride Details')),
      body: ride == null
          ? const Center(child: Text('Ride details unavailable'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SizedBox(
                  height: 240,
                  child: FlutterMap(
                    options: MapOptions(initialCenter: ride.origin.latLng, initialZoom: 9),
                    children: [
                      TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.newcarpool.mobile'),
                      MarkerLayer(markers: [
                        Marker(point: ride.origin.latLng, child: const Icon(Icons.trip_origin, color: Colors.green)),
                        Marker(point: ride.destination.latLng, child: const Icon(Icons.location_on, color: Colors.red)),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(title: Text('${ride.origin.name} to ${ride.destination.name}'), subtitle: Text('Driver: ${ride.driverName}')),
                ListTile(leading: const Icon(Icons.event_seat), title: Text('${ride.availableSeats} seats available')),
                ListTile(leading: const Icon(Icons.currency_rupee), title: Text('${ride.pricePerSeat} per seat')),
                FilledButton(onPressed: () => context.push('/booking'), child: const Text('Book seat')),
              ],
            ),
    );
  }
}
