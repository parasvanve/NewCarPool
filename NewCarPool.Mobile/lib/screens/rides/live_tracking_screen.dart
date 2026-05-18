import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class LiveTrackingScreen extends StatefulWidget {
  const LiveTrackingScreen({super.key});

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  LatLng driverLocation = const LatLng(12.9716, 77.5946);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live Tracking')),
      body: FlutterMap(
        options: MapOptions(initialCenter: driverLocation, initialZoom: 13),
        children: [
          TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.newcarpool.mobile'),
          MarkerLayer(markers: [
            Marker(point: driverLocation, child: const Icon(Icons.local_taxi, color: Colors.blue, size: 36)),
          ]),
        ],
      ),
    );
  }
}
