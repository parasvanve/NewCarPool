import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/ride_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';

class BookingFlowScreen extends StatefulWidget {
  const BookingFlowScreen({super.key, this.extra});

  final Object? extra;

  @override
  State<BookingFlowScreen> createState() => _BookingFlowScreenState();
}

class _BookingFlowScreenState extends State<BookingFlowScreen> {
  int seats = 1;
  bool submitting = false;

  @override
  Widget build(BuildContext context) {
    final ride = widget.extra is RideOffer ? widget.extra as RideOffer : null;
    final myUserId = context.watch<AuthProvider>().session?.userId;
    final isMyRide = ride != null && myUserId != null && myUserId == ride.driverId;

    return Scaffold(
      appBar: AppBar(title: const Text('Confirm Booking')),
      body: ride == null
          ? const Center(child: Text('Ride details unavailable for booking.'))
          : isMyRide
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'You are the driver of this ride. Booking is disabled.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('${ride.origin.name} -> ${ride.destination.name}', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text('Price per seat: INR ${ride.pricePerSeat}'),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Seats'),
                        Row(
                          children: [
                            IconButton(
                              onPressed: seats > 1 ? () => setState(() => seats--) : null,
                              icon: const Icon(Icons.remove),
                            ),
                            Text('$seats', style: const TextStyle(fontWeight: FontWeight.w700)),
                            IconButton(
                              onPressed: seats < ride.availableSeats ? () => setState(() => seats++) : null,
                              icon: const Icon(Icons.add),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text('Total: INR ${(ride.pricePerSeat * seats).toStringAsFixed(2)}', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          final bookingProvider = context.read<BookingProvider>();
                          final messenger = ScaffoldMessenger.of(context);
                          final navigator = Navigator.of(context);
                          setState(() => submitting = true);
                          try {
                            final booking = await bookingProvider.request(
                              rideOfferId: ride.id,
                              seatsBooked: seats,
                            );
                            if (!mounted) return;
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Seat booked successfully. You have joined this ride.'),
                              ),
                            );
                            navigator.pop();
                          } catch (error) {
                            if (!mounted) return;
                            final message = error.toString();
                            if (message.contains('Driver cannot book their own ride')) {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('You cannot book your own ride.'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }
                            messenger.showSnackBar(
                              SnackBar(content: Text(message), backgroundColor: Colors.red),
                            );
                          } finally {
                            if (mounted) setState(() => submitting = false);
                          }
                        },
                  child: Text(submitting ? 'Booking...' : 'Confirm Booking'),
                ),
              ],
            ),
    );
  }
}

