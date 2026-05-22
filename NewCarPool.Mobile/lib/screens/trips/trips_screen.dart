import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/errors/app_exception.dart';
import '../../core/widgets/app_design_system.dart';
import '../../models/booking_models.dart';
import '../../models/ride_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../providers/ride_provider.dart';
import '../rides/ride_chat_screen.dart';
import '../rides/ride_details_screen.dart';

class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key, this.showAppBar = true});

  final bool showAppBar;

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  int _tab = 0; // 0 upcoming, 1 booked, 2 cancelled
  String? _bookingRideId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshAll());
  }

  Future<void> _refreshAll() async {
    await context.read<RideProvider>().loadUpcomingActive();
    await context.read<BookingProvider>().loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    final rideProvider = context.watch<RideProvider>();
    final bookingProvider = context.watch<BookingProvider>();
    final myUserId = context.watch<AuthProvider>().session?.userId;

    final allRides = rideProvider.rides;
    final allBookings = bookingProvider.bookings;
    final bookedByMe = allBookings
        .where((b) =>
            b.bookingStatus == BookingStatus.accepted &&
            (myUserId == null || b.passengerId == myUserId))
        .toList();
    final bookedRideIds = bookedByMe.map((b) => b.rideOfferId).toSet();

    final offeredRides = allRides
        .where((r) => myUserId != null && r.driverId == myUserId)
        .toList();
    final availableRides = allRides
        .where((r) => myUserId == null || r.driverId != myUserId)
        .toList();

    final cancelledBookings = allBookings
        .where((b) =>
            b.bookingStatus == BookingStatus.cancelled ||
            b.bookingStatus == BookingStatus.rejected)
        .toList();

    return Scaffold(
      backgroundColor: AppDesignTokens.pageBg,
      appBar: widget.showAppBar ? AppBar(title: const Text('My Trips')) : null,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
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
                        onTap: () => setState(() => _tab = 0)),
                    const SizedBox(width: 8),
                    _TripFilterChip(
                        label: 'Booked',
                        selected: _tab == 1,
                        onTap: () => setState(() => _tab = 1)),
                    const SizedBox(width: 8),
                    _TripFilterChip(
                        label: 'Cancelled',
                        selected: _tab == 2,
                        onTap: () => setState(() => _tab = 2)),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refreshAll,
                  child: rideProvider.isLoading && rideProvider.rides.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : _tab == 0
                          ? _UpcomingTab(
                              offeredRides: offeredRides,
                              availableRides: availableRides,
                              bookedRideIds: bookedRideIds,
                              bookingRideId: _bookingRideId,
                              currentUserId: myUserId,
                              onRideAction: (ride, action) async {
                                final provider = context.read<RideProvider>();
                                if (action == 'start')
                                  await provider.startRide(ride.id);
                                if (action == 'complete')
                                  await provider.completeRide(ride.id);
                                if (action == 'cancel')
                                  await provider.cancelRide(ride.id);
                                await _refreshAll();
                              },
                              onBookRide: (ride) async {
                                setState(() => _bookingRideId = ride.id);
                                try {
                                  await context.read<BookingProvider>().request(
                                      rideOfferId: ride.id, seatsBooked: 1);
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content:
                                            Text('Ride booked successfully')),
                                  );
                                  await _refreshAll();
                                } on DioException catch (error) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          AppException.fromDio(error).message),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                } finally {
                                  if (mounted)
                                    setState(() => _bookingRideId = null);
                                }
                              },
                            )
                          : _tab == 1
                              ? _BookedTab(
                                  bookings: bookedByMe, rides: allRides)
                              : _CancelledTab(bookings: cancelledBookings),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpcomingTab extends StatelessWidget {
  const _UpcomingTab({
    required this.offeredRides,
    required this.availableRides,
    required this.bookedRideIds,
    required this.bookingRideId,
    required this.currentUserId,
    required this.onRideAction,
    required this.onBookRide,
  });

  final List<RideOffer> offeredRides;
  final List<RideOffer> availableRides;
  final Set<String> bookedRideIds;
  final String? bookingRideId;
  final String? currentUserId;
  final Future<void> Function(RideOffer ride, String action) onRideAction;
  final Future<void> Function(RideOffer ride) onBookRide;

  @override
  Widget build(BuildContext context) {
    if (offeredRides.isEmpty && availableRides.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 140),
          Icon(Icons.calendar_month_outlined,
              size: 54, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          const Center(child: Text('No upcoming rides available')),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      children: [
        if (offeredRides.isNotEmpty) ...[
          const _SectionHeader('My Offered Rides'),
          ...offeredRides.map(
            (ride) => _RideCard(
              ride: ride,
              statusBadge: 'Scheduled',
              primaryLabel: 'Chat',
              secondaryLabel: 'View Details',
              tertiaryLabel: 'Edit Ride',
              dangerLabel: 'Cancel Ride',
              onPrimary: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => RideChatScreen(ride: ride))),
              onSecondary: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => RideDetailsScreen(extra: ride))),
              onTertiary: null,
              onDanger: () => onRideAction(ride, 'cancel'),
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (availableRides.isNotEmpty) ...[
          const _SectionHeader('Available Rides'),
          ...availableRides.map((ride) {
            final alreadyBooked = bookedRideIds.contains(ride.id);
            final bookingInProgress = bookingRideId == ride.id;
            return _RideCard(
              ride: ride,
              statusBadge: alreadyBooked ? 'Booked' : 'Available',
              primaryLabel: alreadyBooked
                  ? 'Chat with Driver'
                  : (ride.availableSeats <= 0 ? 'Ride Full' : 'Book Ride'),
              secondaryLabel: 'View Details',
              onPrimary: alreadyBooked
                  ? () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => RideChatScreen(ride: ride)))
                  : (ride.availableSeats > 0 && !bookingInProgress
                      ? () => onBookRide(ride)
                      : null),
              onSecondary: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => RideDetailsScreen(extra: ride))),
              primaryBusy: bookingInProgress,
            );
          }),
        ],
      ],
    );
  }
}

class _BookedTab extends StatelessWidget {
  const _BookedTab({required this.bookings, required this.rides});

  final List<RideBooking> bookings;
  final List<RideOffer> rides;

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 140),
          Icon(Icons.event_available_outlined,
              size: 54, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          const Center(child: Text('No booked rides yet')),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      children: [
        const _SectionHeader('My Booked Rides'),
        ...bookings.map((booking) {
          RideOffer? ride;
          for (final r in rides) {
            if (r.id == booking.rideOfferId) {
              ride = r;
              break;
            }
          }
          if (ride == null) {
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(
                    'Booking ${booking.id.substring(0, booking.id.length > 8 ? 8 : booking.id.length)}'),
                subtitle: Text(
                    'Seats: ${booking.seatsBooked} • Status: ${booking.bookingStatus.label}'),
              ),
            );
          }

          return _RideCard(
            ride: ride,
            statusBadge: 'Booked',
            bookingMeta:
                'Booking ID: ${booking.id.substring(0, booking.id.length > 8 ? 8 : booking.id.length)}  •  ${booking.seatsBooked} seat(s)',
            primaryLabel: 'View Details',
            secondaryLabel: 'Chat with Driver',
            onPrimary: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => RideDetailsScreen(extra: ride!))),
            onSecondary: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => RideChatScreen(ride: ride!))),
          );
        }),
      ],
    );
  }
}

class _CancelledTab extends StatelessWidget {
  const _CancelledTab({required this.bookings});

  final List<RideBooking> bookings;

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 140),
          Icon(Icons.cancel_outlined, size: 54, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          const Center(child: Text('No cancelled rides')),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      children: [
        const _SectionHeader('Cancelled / Rejected'),
        ...bookings.map(
          (booking) => Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading:
                  const Icon(Icons.cancel_outlined, color: Colors.redAccent),
              title: Text(
                  'Booking ${booking.id.substring(0, booking.id.length > 8 ? 8 : booking.id.length)}'),
              subtitle: Text(
                  '${booking.seatsBooked} seat(s) • ${booking.bookingStatus.label}'),
            ),
          ),
        ),
      ],
    );
  }
}

class _RideCard extends StatelessWidget {
  const _RideCard({
    required this.ride,
    required this.statusBadge,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.tertiaryLabel,
    this.onTertiary,
    this.dangerLabel,
    this.onDanger,
    this.primaryBusy = false,
    this.bookingMeta,
  });

  final RideOffer ride;
  final String statusBadge;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final String? tertiaryLabel;
  final VoidCallback? onTertiary;
  final String? dangerLabel;
  final VoidCallback? onDanger;
  final bool primaryBusy;
  final String? bookingMeta;

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
                Expanded(
                  child: Text(
                    '${ride.origin.name} → ${ride.destination.name}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 18),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBadge == 'Booked'
                        ? const Color(0xFFDFF7EA)
                        : const Color(0xFFE7EAFE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusBadge,
                    style: TextStyle(
                      color: statusBadge == 'Booked'
                          ? const Color(0xFF15803D)
                          : AppDesignTokens.brandStart,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(DateFormat('dd MMM yyyy, hh:mm a')
                .format(ride.departureTimeUtc.toLocal())),
            const SizedBox(height: 4),
            Text(
                'Driver: ${ride.driverName.isEmpty ? 'Driver' : ride.driverName}'),
            const SizedBox(height: 4),
            Text(
                '₹${ride.pricePerSeat} / seat • ${ride.availableSeats} seats left'),
            const SizedBox(height: 4),
            Text('${ride.vehicleName ?? 'Vehicle'} ${ride.vehicleNumber ?? ''}'
                .trim()),
            if ((bookingMeta ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(bookingMeta!,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: primaryBusy ? null : onPrimary,
                  icon: primaryBusy
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.check_circle_outline),
                  label: Text(primaryLabel),
                ),
                if (secondaryLabel != null)
                  OutlinedButton.icon(
                    onPressed: onSecondary,
                    icon: const Icon(Icons.open_in_new),
                    label: Text(secondaryLabel!),
                  ),
                if (tertiaryLabel != null)
                  OutlinedButton.icon(
                    onPressed: onTertiary,
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(tertiaryLabel!),
                  ),
                if (dangerLabel != null)
                  OutlinedButton.icon(
                    onPressed: onDanger,
                    style:
                        OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    icon: const Icon(Icons.cancel_outlined),
                    label: Text(dangerLabel!),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 6, 2, 10),
      child: Text(
        title,
        style: const TextStyle(
            fontWeight: FontWeight.w700, color: AppDesignTokens.brandStart),
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
        label: Text(label), selected: selected, onSelected: (_) => onTap());
  }
}
