import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../models/ride_models.dart';

class RideMapScreen extends StatelessWidget {
  const RideMapScreen({super.key, required this.ride});

  final RideOffer ride;

  @override
  Widget build(BuildContext context) {
    final points = [ride.origin.latLng, ride.destination.latLng];
    return Scaffold(
      appBar: AppBar(title: Text(ride.destination.name)),
      body: FlutterMap(
        options: MapOptions(initialCenter: ride.origin.latLng, initialZoom: 9),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.newcarpool.mobile',
          ),
          PolylineLayer(
            polylines: [
              Polyline(points: points, strokeWidth: 4, color: Theme.of(context).colorScheme.primary),
            ],
          ),
          MarkerLayer(
            markers: [
              Marker(point: ride.origin.latLng, child: const Icon(Icons.trip_origin, color: Colors.green)),
              Marker(point: ride.destination.latLng, child: const Icon(Icons.location_on, color: Colors.red)),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.check),
        label: const Text('Book'),
      ),
    );
  }
}
