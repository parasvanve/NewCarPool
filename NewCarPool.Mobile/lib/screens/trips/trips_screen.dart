import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/app_design_system.dart';
import '../../models/booking_models.dart';
import '../../models/ride_models.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BookingProvider>().loadHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final rideProvider = context.watch<RideProvider>();
    final bookingProvider = context.watch<BookingProvider>();

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
                    key: ValueKey('trip-tab-$_tab-${rideProvider.rides.length}-${bookingProvider.bookings.length}'),
                    tab: _tab,
                    rides: rideProvider.rides,
                    bookings: bookingProvider.bookings,
                    loadingBookings: bookingProvider.isLoading,
                    onRefresh: () => context.read<BookingProvider>().loadHistory(),
                    onRideAction: (ride, action) async {
                      final provider = context.read<RideProvider>();
                      if (action == 'start') await provider.startRide(ride.id);
                      if (action == 'complete') await provider.completeRide(ride.id);
                      if (action == 'cancel') await provider.cancelRide(ride.id);
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
    required this.rides,
    required this.bookings,
    required this.loadingBookings,
    required this.onRefresh,
    required this.onRideAction,
  });

  final int tab;
  final List<RideOffer> rides;
  final List<RideBooking> bookings;
  final bool loadingBookings;
  final Future<void> Function() onRefresh;
  final Future<void> Function(RideOffer ride, String action) onRideAction;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().toUtc();
    final upcomingRides = rides.where((r) => r.departureTimeUtc.isAfter(now)).toList();
    final completedRides = rides.where((r) => r.status == 2).toList();
    final cancelledRides = rides.where((r) => r.status == 3).toList();

    final list = switch (tab) {
      0 => upcomingRides,
      1 => completedRides,
      _ => cancelledRides,
    };
    final bookingList = bookings.where((booking) {
      final status = booking.bookingStatus;
      if (tab == 0) return status == BookingStatus.pending || status == BookingStatus.accepted;
      if (tab == 1) return status == BookingStatus.completed;
      return status == BookingStatus.rejected || status == BookingStatus.cancelled;
    }).toList();

    if (loadingBookings && rides.isEmpty && bookings.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: list.isEmpty && bookingList.isEmpty
          ? ListView(
              children: [
                const SizedBox(height: 140),
                Icon(Icons.calendar_month_outlined, size: 54, color: Colors.grey.shade400),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    tab == 0 ? 'No upcoming trips' : tab == 1 ? 'No completed trips' : 'No cancelled trips',
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
                    statusLabel: tab == 0 ? 'Upcoming' : tab == 1 ? 'Completed' : 'Cancelled',
                    onAction: (action) => onRideAction(ride, action),
                  ),
                ),
                ...bookingList.map(
                  (booking) => Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: const Icon(Icons.confirmation_number_outlined),
                      title: Text('Booking ${booking.id.substring(0, booking.id.length > 8 ? 8 : booking.id.length)}'),
                      subtitle: Text('${booking.seatsBooked} seat(s) • ${booking.bookingStatus.label}'),
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
    required this.onAction,
  });

  final RideOffer ride;
  final String statusLabel;
  final Future<void> Function(String action) onAction;

  @override
  Widget build(BuildContext context) {
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
            Text(DateFormat('dd MMM, hh:mm a').format(ride.departureTimeUtc.toLocal())),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text('₹${ride.pricePerSeat} / seat')),
                Chip(label: Text('${ride.availableSeats} seats')),
              ],
            ),
            if (statusLabel == 'Upcoming') ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton(onPressed: () => onAction('start'), child: const Text('Start')),
                  TextButton(onPressed: () => onAction('complete'), child: const Text('Complete')),
                  TextButton(onPressed: () => onAction('cancel'), child: const Text('Cancel')),
                ],
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
