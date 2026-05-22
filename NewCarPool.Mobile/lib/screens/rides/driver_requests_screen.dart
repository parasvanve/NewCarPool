import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/booking_models.dart';
import '../../providers/booking_provider.dart';

class DriverRequestsScreen extends StatefulWidget {
  const DriverRequestsScreen({super.key});

  @override
  State<DriverRequestsScreen> createState() => _DriverRequestsScreenState();
}

class _DriverRequestsScreenState extends State<DriverRequestsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BookingProvider>().loadHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BookingProvider>();
    final booked = provider.bookings
        .where((b) => b.bookingStatus == BookingStatus.accepted)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Booked Passengers')),
      body: provider.isLoading && booked.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : booked.isEmpty
              ? RefreshIndicator(
                  onRefresh: () => context.read<BookingProvider>().loadHistory(),
                  child: ListView(
                    children: const [
                      SizedBox(height: 140),
                      Center(child: Text('No booked passengers found.')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => context.read<BookingProvider>().loadHistory(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: booked.length,
                    itemBuilder: (context, index) {
                      final booking = booked[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 14),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  const CircleAvatar(
                                    backgroundColor: Colors.amber,
                                    child: Icon(Icons.person, color: Colors.white),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          booking.passengerName.isEmpty ? 'Passenger' : booking.passengerName,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                        Text(
                                          'Booked: ${booking.seatsBooked} seat(s) | Status: ${booking.bookingStatus.label}',
                                          style: const TextStyle(color: Colors.grey, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Chip(label: Text(booking.bookingStatus.label)),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
