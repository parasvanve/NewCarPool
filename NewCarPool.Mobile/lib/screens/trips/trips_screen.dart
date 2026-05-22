import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';

import '../../core/errors/app_exception.dart';
import '../../core/widgets/app_design_system.dart';
import '../../models/booking_models.dart';
import '../../models/ride_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../providers/ride_provider.dart';

class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key, this.showAppBar = true});

  final bool showAppBar;

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  int _tab = 0; // 0 upcoming, 1 completed, 2 cancelled
  String? _bookingRideId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BookingProvider>().loadHistory();
      context.read<RideProvider>().loadUpcomingActive();
    });
  }

  @override
  Widget build(BuildContext context) {
    final rideProvider = context.watch<RideProvider>();
    final bookingProvider = context.watch<BookingProvider>();
    final myUserId = context.watch<AuthProvider>().session?.userId;

    return Scaffold(
      backgroundColor: AppDesignTokens.pageBg,
      appBar: widget.showAppBar ? AppBar(title: const Text('My Trips')) : null,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: AppGradientHeroCard(
                  title: 'My Trips',
                  subtitle: 'Track your upcoming and past rides',
                  icon: Icons.route,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: Row(
                  children: [
                    _TripFilterChip(
                      label: 'Upcoming',
                      selected: _tab == 0,
                      onTap: () => setState(() => _tab = 0),
                    ),
                    const SizedBox(width: 8),
                    _TripFilterChip(
                      label: 'Completed',
                      selected: _tab == 1,
                      onTap: () => setState(() => _tab = 1),
                    ),
                    const SizedBox(width: 8),
                    _TripFilterChip(
                      label: 'Cancelled',
                      selected: _tab == 2,
                      onTap: () => setState(() => _tab = 2),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _TripsContent(
                    key: ValueKey(
                        'trip-tab-$_tab-${rideProvider.rides.length}-${bookingProvider.bookings.length}'),
                    tab: _tab,
                    currentUserId: myUserId,
                    rides: rideProvider.rides,
                    bookings: bookingProvider.bookings,
                    rideError: rideProvider.errorMessage,
                    rideLoading: rideProvider.isLoading,
                    loadingBookings: bookingProvider.isLoading,
                    bookingRideId: _bookingRideId,
                    onRefresh: () async {
                      await context.read<RideProvider>().loadUpcomingActive();
                      await context.read<BookingProvider>().loadHistory();
                    },
                    onBookRide: (ride) async {
                      setState(() => _bookingRideId = ride.id);
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        await context.read<BookingProvider>().request(
                              rideOfferId: ride.id,
                              seatsBooked: 1,
                            );
                        if (!mounted) return;
                        messenger.showSnackBar(
                          const SnackBar(
                              content: Text('Ride booked successfully')),
                        );
                        await context.read<RideProvider>().loadUpcomingActive();
                      } on DioException catch (error) {
                        if (!mounted) return;
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(AppException.fromDio(error).message),
                            backgroundColor: Colors.red,
                          ),
                        );
                      } catch (error) {
                        if (!mounted) return;
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(error.toString()),
                            backgroundColor: Colors.red,
                          ),
                        );
                      } finally {
                        if (mounted) {
                          setState(() => _bookingRideId = null);
                        }
                      }
                    },
                    onRideAction: (ride, action) async {
                      final provider = context.read<RideProvider>();
                      if (action == 'start') await provider.startRide(ride.id);
                      if (action == 'complete')
                        await provider.completeRide(ride.id);
                      if (action == 'cancel')
                        await provider.cancelRide(ride.id);
                      await provider.loadUpcomingActive();
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TripsContent extends StatelessWidget {
  const _TripsContent({
    super.key,
    required this.tab,
    required this.currentUserId,
    required this.rides,
    required this.bookings,
    required this.rideError,
    required this.rideLoading,
    required this.loadingBookings,
    required this.bookingRideId,
    required this.onRefresh,
    required this.onBookRide,
    required this.onRideAction,
  });

  final int tab;
  final String? currentUserId;
  final List<RideOffer> rides;
  final List<RideBooking> bookings;
  final String? rideError;
  final bool rideLoading;
  final bool loadingBookings;
  final String? bookingRideId;
  final Future<void> Function() onRefresh;
  final Future<void> Function(RideOffer ride) onBookRide;
  final Future<void> Function(RideOffer ride, String action) onRideAction;

  @override
  Widget build(BuildContext context) {
    final upcomingRides = rides;
    final completedRides = const <RideOffer>[];
    final cancelledRides = const <RideOffer>[];

    final list = switch (tab) {
      0 => upcomingRides,
      1 => completedRides,
      _ => cancelledRides,
    };

    final bookingList = bookings.where((booking) {
      final status = booking.bookingStatus;
      if (tab == 0)
        return status == BookingStatus.pending ||
            status == BookingStatus.accepted;
      if (tab == 1) return status == BookingStatus.completed;
      return status == BookingStatus.rejected ||
          status == BookingStatus.cancelled;
    }).toList();

    if (rideLoading && rides.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (tab == 0 &&
        rideError != null &&
        rideError!.trim().isNotEmpty &&
        rides.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 54, color: Colors.redAccent),
              const SizedBox(height: 10),
              Text(rideError!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: list.isEmpty && bookingList.isEmpty
          ? ListView(
              children: [
                const SizedBox(height: 140),
                Icon(Icons.calendar_month_outlined,
                    size: 54, color: Colors.grey.shade400),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    tab == 0
                        ? 'No upcoming rides available'
                        : tab == 1
                            ? 'No completed trips'
                            : 'No cancelled trips',
                  ),
                ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              children: [
                ...list.map(
                  (ride) => _TripRideCard(
                    ride: ride,
                    statusLabel: tab == 0
                        ? 'Upcoming'
                        : tab == 1
                            ? 'Completed'
                            : 'Cancelled',
                    currentUserId: currentUserId,
                    isBooking: bookingRideId == ride.id,
                    onBook: tab == 0 ? () => onBookRide(ride) : null,
                    onAction: (action) => onRideAction(ride, action),
                  ),
                ),
                if (loadingBookings && bookings.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ...bookingList.map(
                  (booking) => Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: const Icon(Icons.confirmation_number_outlined),
                      title: Text(
                          'Booking ${booking.id.substring(0, booking.id.length > 8 ? 8 : booking.id.length)}'),
                      subtitle: Text(
                          '${booking.seatsBooked} seat(s) • ${booking.bookingStatus.label}'),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _TripRideCard extends StatelessWidget {
  const _TripRideCard({
    required this.ride,
    required this.statusLabel,
    required this.currentUserId,
    required this.isBooking,
    required this.onBook,
    required this.onAction,
  });

  final RideOffer ride;
  final String statusLabel;
  final String? currentUserId;
  final bool isBooking;
  final VoidCallback? onBook;
  final Future<void> Function(String action) onAction;

  @override
  Widget build(BuildContext context) {
    final isOwner = currentUserId != null && currentUserId == ride.driverId;
    final canBook =
        !isOwner && ride.availableSeats > 0 && statusLabel == 'Upcoming';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.route),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${ride.origin.name} → ${ride.destination.name}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                _StatusBadge(label: statusLabel),
              ],
            ),
            const SizedBox(height: 6),
            Text(
                'Driver: ${ride.driverName.isEmpty ? 'Driver' : ride.driverName}'),
            const SizedBox(height: 2),
            Text(DateFormat('dd MMM, hh:mm a')
                .format(ride.departureTimeUtc.toLocal())),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text('₹${ride.pricePerSeat} / seat')),
                Chip(label: Text('${ride.availableSeats} seats')),
                if ((ride.vehicleName ?? '').trim().isNotEmpty ||
                    (ride.vehicleNumber ?? '').trim().isNotEmpty)
                  Chip(
                      label: Text(
                          '${ride.vehicleName ?? ''} ${ride.vehicleNumber ?? ''}'
                              .trim())),
              ],
            ),
            if (statusLabel == 'Upcoming') ...[
              const SizedBox(height: 8),
              if (isOwner)
                Row(
                  children: [
                    TextButton(
                        onPressed: () => onAction('start'),
                        child: const Text('Start')),
                    TextButton(
                        onPressed: () => onAction('complete'),
                        child: const Text('Complete')),
                    TextButton(
                        onPressed: () => onAction('cancel'),
                        child: const Text('Cancel')),
                  ],
                )
              else
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: canBook && !isBooking ? onBook : null,
                    icon: isBooking
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.event_seat_outlined),
                    label: Text(
                        ride.availableSeats <= 0 ? 'Ride Full' : 'Book Ride'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TripFilterChip extends StatelessWidget {
  const _TripFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = switch (label) {
      'Completed' => Colors.green,
      'Cancelled' => Colors.red,
      _ => AppDesignTokens.brandStart,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

