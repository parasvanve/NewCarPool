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

    return Scaffold(
      appBar: AppBar(title: const Text('Incoming Bookings')),
      body: provider.isLoading && provider.bookings.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : provider.bookings.isEmpty
              ? RefreshIndicator(
                  onRefresh: () => context.read<BookingProvider>().loadHistory(),
                  child: ListView(
                    children: const [
                      SizedBox(height: 140),
                      Center(child: Text('No booking requests found.')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => context.read<BookingProvider>().loadHistory(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: provider.bookings.length,
                    itemBuilder: (context, index) {
                      final booking = provider.bookings[index];
                      final processing = provider.processingIds.contains(booking.id);
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
                                          'Requested: ${booking.seatsBooked} seat(s) | Status: ${booking.bookingStatus.label}',
                                          style: const TextStyle(color: Colors.grey, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (booking.bookingStatus == BookingStatus.pending) ...[
                                    OutlinedButton(
                                      onPressed: processing
                                          ? null
                                          : () async {
                                              final bookingProvider = context.read<BookingProvider>();
                                              final messenger = ScaffoldMessenger.of(context);
                                              try {
                                                await bookingProvider.reject(booking.id);
                                                if (!mounted) return;
                                                messenger.showSnackBar(
                                                  const SnackBar(content: Text('Booking rejected.')),
                                                );
                                              } catch (error) {
                                                if (!mounted) return;
                                                messenger.showSnackBar(
                                                  SnackBar(content: Text(error.toString()), backgroundColor: Colors.red),
                                                );
                                              }
                                            },
                                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                                      child: const Text('Reject'),
                                    ),
                                    const SizedBox(width: 8),
                                    FilledButton(
                                      onPressed: processing
                                          ? null
                                          : () async {
                                              final bookingProvider = context.read<BookingProvider>();
                                              final messenger = ScaffoldMessenger.of(context);
                                              try {
                                                await bookingProvider.accept(booking.id);
                                                if (!mounted) return;
                                                messenger.showSnackBar(
                                                  const SnackBar(content: Text('Booking accepted.')),
                                                );
                                              } catch (error) {
                                                if (!mounted) return;
                                                messenger.showSnackBar(
                                                  SnackBar(content: Text(error.toString()), backgroundColor: Colors.red),
                                                );
                                              }
                                            },
                                      child: Text(processing ? 'Please wait...' : 'Accept'),
                                    ),
                                  ] else
                                    Chip(label: Text(booking.bookingStatus.label)),
                                ],
                              )
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
