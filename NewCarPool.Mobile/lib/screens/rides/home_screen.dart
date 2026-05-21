import 'package:flutter/material.dart';
import 'package:new_car_pool/screens/rides/offer_ride_form_screen.dart';
import 'package:new_car_pool/screens/rides/search_ride_form_screen.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NewCarPool'),
        actions: [
          IconButton(
            onPressed: () => context.read<AuthProvider>().logout(),
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const OfferRideFormScreen())),
            icon: const Icon(Icons.directions_car),
            label: const Text('Offer a ride'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const SearchRideFormScreen())),
            icon: const Icon(Icons.airline_seat_recline_normal),
            label: const Text('Find a ride'),
          ),
        ],
      ),
    );
  }
}
