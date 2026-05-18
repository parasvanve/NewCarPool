import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/ride_models.dart';
import '../../providers/ride_provider.dart';

class OfferRideScreen extends StatelessWidget {
  const OfferRideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Offer ride')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: FilledButton(
          onPressed: () async {
            await context.read<RideProvider>().offerRide(
                  vehicleId: '00000000-0000-0000-0000-000000000000',
                  origin: const GeoPoint(name: 'Bengaluru', latitude: 12.9716, longitude: 77.5946),
                  destination: const GeoPoint(name: 'Mysuru', latitude: 12.2958, longitude: 76.6394),
                  departureTimeUtc: DateTime.now().toUtc().add(const Duration(hours: 2)),
                  seats: 3,
                  pricePerSeat: 350,
                  vehicleName: 'Sedan',
                  vehicleNumber: 'KA 01 AB 1234',
                );
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Create Bengaluru to Mysuru demo ride'),
        ),
      ),
    );
  }
}
