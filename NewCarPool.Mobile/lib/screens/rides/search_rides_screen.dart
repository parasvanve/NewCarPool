import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/ride_models.dart';
import '../../providers/ride_provider.dart';
import 'package:go_router/go_router.dart';

class SearchRidesScreen extends StatelessWidget {
  const SearchRidesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RideProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Find rides')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: () => provider.search(
                const GeoPoint(name: 'Bengaluru', latitude: 12.9716, longitude: 77.5946),
                const GeoPoint(name: 'Mysuru', latitude: 12.2958, longitude: 76.6394),
                1,
              ),
              icon: const Icon(Icons.search),
              label: const Text('Search demo route'),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: provider.rides.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, index) {
                final ride = provider.rides[index];
                return ListTile(
                  title: Text('${ride.origin.name} to ${ride.destination.name}'),
                  subtitle: Text('${ride.driverName} | ${ride.availableSeats} seats | Rs ${ride.pricePerSeat}'),
                  trailing: const Icon(Icons.map),
                  onTap: () => context.push('/ride-details', extra: ride),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
