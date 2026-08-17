import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_routes.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/departure_time_utils.dart';
import '../../core/utils/location_display_formatter.dart';
import '../../core/widgets/app_design_system.dart';
import '../../core/widgets/ride_timeline_widgets.dart';
import '../../models/booking_models.dart';
import '../../models/ride_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../providers/ride_provider.dart';
import '../../services/ride_service.dart';
import '../rides/ride_chat_screen.dart';
import '../rides/ride_details_screen.dart';

class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key, this.showAppBar = true});

  final bool showAppBar;

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  int _tab = 0;
  String? _bookingRideId;
  final Map<String, RideOffer> _bookingRideDetails = {};

  // New: tracks the very first data load so we can show a shimmer skeleton
  // instead of briefly flashing "No rides available" before data arrives.
  bool _initialLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final userId = context.read<AuthProvider>().session?.userId;
      final rideProvider = context.read<RideProvider>();
      if (userId != null && userId.isNotEmpty) {
        await rideProvider.connectRealtime(userId: userId);
      }
      await _refreshAll();
      if (mounted) setState(() => _initialLoading = false);
    });
  }

  @override
  void dispose() => super.dispose();

  Future<String?> _showCancelDialog({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<bool> _showConfirmationDialog({
    required String title,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _refreshAll() async {
    final rideProvider = context.read<RideProvider>();
    final bookingProvider = context.read<BookingProvider>();
    final rideService = context.read<RideService>();
    await rideProvider.loadUpcomingActive(forceRefresh: true);
    await rideProvider.loadMyRides(forceRefresh: true);
    await bookingProvider.loadHistory(forceRefresh: true);

    final allBookingRideIds =
        bookingProvider.bookings.map((x) => x.rideOfferId).toSet();
    final knownIds = {
      ...rideProvider.upcomingActiveRides.map((x) => x.id),
      ...rideProvider.myRides.map((x) => x.id),
      ..._bookingRideDetails.keys,
    };
    final missingIds =
        allBookingRideIds.where((id) => !knownIds.contains(id)).toList();
    if (missingIds.isEmpty) return;

    final fetched = await Future.wait(
      missingIds.map((id) async {
        try {
          return await rideService.details(id);
        } catch (_) {
          return null;
        }
      }),
    );
    if (!mounted) return;
    for (final ride in fetched) {
      if (ride != null) _bookingRideDetails[ride.id] = ride;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final rideProvider = context.watch<RideProvider>();
    final bookingProvider = context.watch<BookingProvider>();
    final myUserId = context.watch<AuthProvider>().session?.userId;
    final nowUtc = DateTime.now().toUtc();

    final allBookings = bookingProvider.bookings;
    final myUserIdKey = myUserId?.toLowerCase();
    final bookedByMe = allBookings.where((b) {
      if (myUserIdKey == null || myUserIdKey.isEmpty) return true;
      return b.passengerId.toLowerCase() == myUserIdKey;
    }).toList();

    final ridesById = <String, RideOffer>{
      for (final ride in rideProvider.upcomingActiveRides) ride.id: ride,
      for (final ride in rideProvider.myRides) ride.id: ride,
      ..._bookingRideDetails,
    };

    final myOfferedUpcoming = rideProvider.myRides.where((r) {
      final isNotFinished = r.status != 4 && r.status != 5;
      return isNotFinished &&
          (r.departureTimeUtc.isAfter(nowUtc) || r.status == 3);
    }).toList()
      ..sort((a, b) => a.departureTimeUtc.compareTo(b.departureTimeUtc));

    final myBookedActive = bookedByMe.where((b) {
      final ride = ridesById[b.rideOfferId];
      if (ride == null) return false;
      if (b.bookingStatus != BookingStatus.accepted) return false;
      final activeRide =
          ride.status == 1 || ride.status == 2 || ride.status == 3;
      return activeRide &&
          (ride.departureTimeUtc.isAfter(nowUtc) || ride.status == 3);
    }).toList()
      ..sort((a, b) {
        final aRide = ridesById[a.rideOfferId];
        final bRide = ridesById[b.rideOfferId];
        if (aRide == null || bRide == null) return 0;
        return aRide.departureTimeUtc.compareTo(bRide.departureTimeUtc);
      });

    final myBookedRideIds = bookedByMe.map((x) => x.rideOfferId).toSet();
    final availableRides = rideProvider.upcomingActiveRides.where((r) {
      final isOpen = r.status == 1;
      final future = r.departureTimeUtc.isAfter(nowUtc);
      final hasSeats = r.availableSeats > 0;
      final otherDriver = myUserId == null || r.driverId != myUserId;
      final notBooked = !myBookedRideIds.contains(r.id);
      return isOpen && future && hasSeats && otherDriver && notBooked;
    }).toList()
      ..sort((a, b) => a.departureTimeUtc.compareTo(b.departureTimeUtc));

    final myOfferedCompleted = rideProvider.myRides.where((r) {
      final completed = r.status == 4;
      final past = r.departureTimeUtc.isBefore(nowUtc);
      return completed || past;
    }).toList()
      ..sort((a, b) => b.departureTimeUtc.compareTo(a.departureTimeUtc));

    final myBookedCompleted = bookedByMe.where((b) {
      final ride = ridesById[b.rideOfferId];
      if (ride == null) return false;
      return ride.status == 4 || ride.departureTimeUtc.isBefore(nowUtc);
    }).toList();

    final cancelledBookings = allBookings
        .where((b) =>
            b.bookingStatus == BookingStatus.cancelled ||
            b.bookingStatus == BookingStatus.rejected)
        .toList();
    final cancelledOfferedRides =
        rideProvider.myRides.where((r) => r.status == 5).toList();

    Future<void> cancelBooking(RideBooking booking) async {
      final messenger = ScaffoldMessenger.of(context);
      final reason = await _showCancelDialog(
        title: 'Are you sure you want to cancel this booking?',
        message: 'Your booking will be cancelled and moved to history.',
        confirmLabel: 'Yes, Cancel Booking',
      );
      if (reason == null) return;
      await bookingProvider.cancel(booking.id, reason: reason);
      await _refreshAll();
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Booking cancelled successfully')),
        );
      }
    }

    return Scaffold(
      // backgroundColor: const Color(0xFFF6F7FC),
      backgroundColor: AppDesignTokens.pageBackground(context),
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
                  subtitle: 'Track upcoming rides and travel history',
                  icon: Icons.route,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
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
                          label: 'Completed',
                          selected: _tab == 2,
                          onTap: () => setState(() => _tab = 2)),
                      const SizedBox(width: 8),
                      _TripFilterChip(
                          label: 'Cancelled',
                          selected: _tab == 3,
                          onTap: () => setState(() => _tab = 3)),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refreshAll,
                  child: _initialLoading
                      ? const _ShimmerTripList()
                      : _tab == 0
                          ? _UpcomingTab(
                              myOfferedUpcoming: myOfferedUpcoming,
                              myBookedUpcoming: myBookedActive,
                              availableRides: availableRides,
                              ridesById: ridesById,
                              bookingRideId: _bookingRideId,
                              onCancelBooking: cancelBooking,
                              onRideAction: (ride, action) async {
                                final provider = context.read<RideProvider>();
                                final messenger = ScaffoldMessenger.of(context);
                                final navigator = Navigator.of(context);
                                if (action == 'start') {
                                  final ok = await _showConfirmationDialog(
                                    title: 'Start this ride?',
                                    confirmLabel: 'Yes, Start Ride',
                                  );
                                  if (!ok) return;
                                  final startedRide =
                                      await provider.startRide(ride.id);
                                  if (mounted) {
                                    messenger.showSnackBar(
                                      const SnackBar(
                                          content: Text('Ride started')),
                                    );
                                    await navigator.push(
                                      MaterialPageRoute(
                                        builder: (_) => RideDetailsScreen(
                                            extra: startedRide),
                                      ),
                                    );
                                  }
                                }
                                if (action == 'complete') {
                                  final ok = await _showConfirmationDialog(
                                    title: 'Complete this ride?',
                                    confirmLabel: 'Yes, Complete Ride',
                                  );
                                  if (!ok) return;
                                  await provider.completeRide(ride.id);
                                  if (mounted) {
                                    messenger.showSnackBar(
                                      const SnackBar(
                                          content: Text('Ride completed')),
                                    );
                                  }
                                }
                                if (action == 'cancel') {
                                  final reason = await _showCancelDialog(
                                    title:
                                        'Are you sure you want to cancel this ride?',
                                    message:
                                        'This ride will be moved to cancelled history.',
                                    confirmLabel: 'Yes, Cancel Ride',
                                  );
                                  if (reason == null) return;
                                  await provider.cancelRide(ride.id,
                                      reason: reason);
                                  if (mounted) {
                                    messenger.showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Ride cancelled successfully')),
                                    );
                                  }
                                }
                                await _refreshAll();
                              },
                              onBookRide: (ride) async {
                                final messenger = ScaffoldMessenger.of(context);
                                setState(() => _bookingRideId = ride.id);
                                try {
                                  await context.push(AppRoutes.booking,
                                      extra: ride);
                                  if (!mounted) return;
                                  await _refreshAll();
                                } on DioException catch (error) {
                                  if (!mounted) return;
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          AppException.fromDio(error).message),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                } finally {
                                  if (mounted) {
                                    setState(() => _bookingRideId = null);
                                  }
                                }
                              },
                            )
                          : _tab == 1
                              ? _BookedTab(
                                  booked: myBookedActive,
                                  ridesById: ridesById,
                                  onCancelBooking: cancelBooking,
                                )
                              : _tab == 2
                                  ? _CompletedTab(
                                      offeredCompleted: myOfferedCompleted,
                                      bookedCompleted: myBookedCompleted,
                                      ridesById: ridesById,
                                    )
                                  : _CancelledTab(
                                      bookings: cancelledBookings,
                                      offeredCancelled: cancelledOfferedRides,
                                      ridesById: ridesById,
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

// ============================================================
// Shimmer loading skeleton — shown only during the initial load
// ============================================================

class _ShimmerTripList extends StatelessWidget {
  const _ShimmerTripList();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      children: const [
        _ShimmerSectionHeader(),
        _ShimmerRideCard(),
        _ShimmerRideCard(),
        SizedBox(height: 8),
        _ShimmerSectionHeader(),
        _ShimmerRideCard(),
      ],
    );
  }
}

class _ShimmerSectionHeader extends StatelessWidget {
  const _ShimmerSectionHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(2, 6, 2, 10),
      child: _Shimmer(
        child: _ShimmerBox(width: 160, height: 16, radius: 6),
      ),
    );
  }
}

class _ShimmerRideCard extends StatelessWidget {
  const _ShimmerRideCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: _Shimmer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _ShimmerBox(height: 22, radius: 6),
                  ),
                  SizedBox(width: 10),
                  _ShimmerBox(width: 70, height: 24, radius: 14),
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  _ShimmerBox(width: 100, height: 14, radius: 6),
                  SizedBox(width: 12),
                  Expanded(child: _ShimmerBox(height: 14, radius: 6)),
                ],
              ),
              SizedBox(height: 12),
              _ShimmerBox(height: 90, radius: 16),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _ShimmerBox(height: 14, radius: 6)),
                  SizedBox(width: 10),
                  Expanded(child: _ShimmerBox(height: 14, radius: 6)),
                  SizedBox(width: 10),
                  Expanded(child: _ShimmerBox(height: 14, radius: 6)),
                ],
              ),
              SizedBox(height: 14),
              Row(
                children: [
                  _ShimmerBox(width: 120, height: 36, radius: 10),
                  SizedBox(width: 8),
                  _ShimmerBox(width: 100, height: 36, radius: 10),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  const _ShimmerBox({
    this.width,
    required this.height,
    this.radius = 8,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Lightweight shimmer sweep effect with no external dependency.
class _Shimmer extends StatefulWidget {
  const _Shimmer({required this.child});

  final Widget child;

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            final t = _controller.value;
            return LinearGradient(
              colors: const [
                Color(0xFFE2E8F0),
                Color(0xFFF8FAFC),
                Color(0xFFE2E8F0),
              ],
              stops: const [0.35, 0.5, 0.65],
              begin: Alignment(-1 - t * 2, 0),
              end: Alignment(1 - t * 2, 0),
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _UpcomingTab extends StatelessWidget {
  const _UpcomingTab({
    required this.myOfferedUpcoming,
    required this.myBookedUpcoming,
    required this.availableRides,
    required this.ridesById,
    required this.bookingRideId,
    required this.onCancelBooking,
    required this.onRideAction,
    required this.onBookRide,
  });

  final List<RideOffer> myOfferedUpcoming;
  final List<RideBooking> myBookedUpcoming;
  final List<RideOffer> availableRides;
  final Map<String, RideOffer> ridesById;
  final String? bookingRideId;
  final Future<void> Function(RideBooking booking) onCancelBooking;
  final Future<void> Function(RideOffer ride, String action) onRideAction;
  final Future<void> Function(RideOffer ride) onBookRide;

  @override
  Widget build(BuildContext context) {
    if (myOfferedUpcoming.isEmpty &&
        myBookedUpcoming.isEmpty &&
        availableRides.isEmpty) {
      return ListView(children: const [
        SizedBox(height: 140),
        Center(child: Text('No upcoming rides available'))
      ]);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      children: [
        if (myOfferedUpcoming.isNotEmpty) ...[
          const _SectionHeader('My Offered Rides'),
          ...myOfferedUpcoming.map((ride) {
            final isOpenOrFull = ride.status == 1 || ride.status == 2;
            final isStarted = ride.status == 3;
            final statusBadge = switch (ride.status) {
              1 => 'Open',
              2 => 'Full',
              3 => 'Started',
              4 => 'Completed',
              5 => 'Cancelled',
              _ => 'Offered',
            };
            return _RideCard(
              ride: ride,
              statusBadge: statusBadge,
              primaryLabel: 'View Details',
              secondaryLabel: 'Chat',
              tertiaryLabel: isOpenOrFull
                  ? 'Cancel Ride'
                  : (isStarted ? 'Complete Ride' : null),
              showPassengerCount: true,
              onPrimary: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => RideDetailsScreen(extra: ride))),
              onSecondary: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => RideChatScreen(ride: ride))),
              onTertiary: isOpenOrFull
                  ? () => onRideAction(ride, 'cancel')
                  : (isStarted ? () => onRideAction(ride, 'complete') : null),
              quaternaryLabel: isOpenOrFull ? 'Start Ride' : null,
              onQuaternary:
                  isOpenOrFull ? () => onRideAction(ride, 'start') : null,
            );
          }),
        ],
        if (myBookedUpcoming.isNotEmpty) ...[
          const _SectionHeader('My Booked Rides'),
          ...myBookedUpcoming.map((booking) {
            final ride = ridesById[booking.rideOfferId];
            if (ride == null) return const SizedBox.shrink();
            return _RideCard(
              ride: ride,
              statusBadge: ride.status == 3 ? 'Ride Started' : 'Booked',
              primaryLabel: 'View Details',
              secondaryLabel: 'Chat with Rider',
              tertiaryLabel: 'Cancel Booking',
              bookedSeats: booking.seatsBooked,
              yourPickupName: booking.passengerPickup?.name,
              yourDropName: booking.passengerDrop?.name,
              onPrimary: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => RideDetailsScreen(extra: ride))),
              onSecondary: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => RideChatScreen(ride: ride))),
              onTertiary: () => onCancelBooking(booking),
            );
          }),
        ],
        if (availableRides.isNotEmpty) ...[
          const _SectionHeader('Available Rides'),
          ...availableRides.map((ride) => _RideCard(
                ride: ride,
                statusBadge: 'Available',
                primaryLabel:
                    bookingRideId == ride.id ? 'Booking...' : 'Book Ride',
                secondaryLabel: 'View Details',
                onPrimary:
                    bookingRideId == ride.id ? null : () => onBookRide(ride),
                onSecondary: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => RideDetailsScreen(extra: ride))),
              )),
        ],
      ],
    );
  }
}

class _BookedTab extends StatelessWidget {
  const _BookedTab({
    required this.booked,
    required this.ridesById,
    required this.onCancelBooking,
  });

  final List<RideBooking> booked;
  final Map<String, RideOffer> ridesById;
  final Future<void> Function(RideBooking booking) onCancelBooking;

  @override
  Widget build(BuildContext context) {
    if (booked.isEmpty) {
      return ListView(children: const [
        SizedBox(height: 140),
        Center(child: Text('No booked rides'))
      ]);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      children: [
        const _SectionHeader('My Booked Rides'),
        ...booked.map((booking) {
          final ride = ridesById[booking.rideOfferId];
          if (ride == null) return const SizedBox.shrink();
          return _RideCard(
            ride: ride,
            statusBadge: ride.status == 3 ? 'Ride Started' : 'Booked',
            primaryLabel: 'View Details',
            secondaryLabel: 'Chat with Driver',
            tertiaryLabel: 'Cancel Booking',
            bookedSeats: booking.seatsBooked,
            yourPickupName: booking.passengerPickup?.name,
            yourDropName: booking.passengerDrop?.name,
            onPrimary: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => RideDetailsScreen(extra: ride))),
            onSecondary: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => RideChatScreen(ride: ride))),
            onTertiary: () => onCancelBooking(booking),
          );
        }),
      ],
    );
  }
}

class _CompletedTab extends StatelessWidget {
  const _CompletedTab({
    required this.offeredCompleted,
    required this.bookedCompleted,
    required this.ridesById,
  });

  final List<RideOffer> offeredCompleted;
  final List<RideBooking> bookedCompleted;
  final Map<String, RideOffer> ridesById;

  @override
  Widget build(BuildContext context) {
    if (offeredCompleted.isEmpty && bookedCompleted.isEmpty) {
      return ListView(children: const [
        SizedBox(height: 140),
        Center(child: Text('No completed trip history yet'))
      ]);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      children: [
        if (offeredCompleted.isNotEmpty) ...[
          const _SectionHeader('Completed Rides I Offered'),
          ...offeredCompleted
              .map((ride) => _CompletedOfferedRideCard(ride: ride)),
        ],
        if (bookedCompleted.isNotEmpty) ...[
          const _SectionHeader('Completed Rides I Booked'),
          ...bookedCompleted.map((booking) {
            final ride = ridesById[booking.rideOfferId];
            if (ride == null) return const SizedBox.shrink();
            return _RideCard(
              ride: ride,
              statusBadge: 'Completed',
              primaryLabel: 'View Details',
              secondaryLabel: 'Chat',
              bookedSeats: booking.seatsBooked,
              yourPickupName: booking.passengerPickup?.name,
              yourDropName: booking.passengerDrop?.name,
              onPrimary: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => RideDetailsScreen(extra: ride))),
              onSecondary: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => RideChatScreen(ride: ride))),
            );
          }),
        ],
      ],
    );
  }
}

class _CompletedOfferedRideCard extends StatelessWidget {
  const _CompletedOfferedRideCard({required this.ride});

  final RideOffer ride;

  @override
  Widget build(BuildContext context) {
    final nodes = buildRideTimeline(
      ride: ride,
      departureUtc: ride.departureTimeUtc,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    LocationDisplayFormatter.routeTitle(
                        ride.origin, ride.destination),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 24),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDFF7EA),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Completed',
                    style: TextStyle(
                        color: Color(0xFF15803D), fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    DepartureTimeUtils.formatFriendly(ride.departureTimeUtc,
                        context: 'Trips Completed'),
                  ),
                ),
                const Icon(Icons.person_outline, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    ride.driverName.isEmpty ? 'Rider' : ride.driverName,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.directions_car_outlined, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${ride.vehicleName ?? 'Vehicle'} ${ride.vehicleNumber ?? ''}'
                        .trim(),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: RideVerticalTimeline(nodes: nodes),
            ),
            const SizedBox(height: 10),
            FutureBuilder<List<RideBooking>>(
              future: context.read<RideProvider>().participants(ride.id),
              builder: (context, snapshot) {
                final passengers = (snapshot.data ?? const <RideBooking>[])
                    .where((b) =>
                        b.bookingStatus == BookingStatus.accepted ||
                        b.bookingStatus == BookingStatus.completed)
                    .toList();
                final totalEarning = passengers.fold<num>(
                    0, (sum, b) => sum + (ride.pricePerSeat * b.seatsBooked));
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _SummaryChip(
                            label: 'Total Seats Booked',
                            value:
                                '${passengers.fold<int>(0, (sum, b) => sum + b.seatsBooked)}'),
                        _SummaryChip(
                            label: 'Total Earning', value: 'â‚¹$totalEarning'),
                        _SummaryChip(
                            label: 'Vehicle',
                            value:
                                '${ride.vehicleName ?? 'Vehicle'} ${ride.vehicleNumber ?? ''}'
                                    .trim()),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('Passengers',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    if (snapshot.connectionState == ConnectionState.waiting)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    else if (passengers.isEmpty)
                      const Text('No passengers'),
                    ...passengers.map((p) => _PassengerCard(booking: p)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => RideDetailsScreen(extra: ride)),
                          ),
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('View Details'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => RideChatScreen(ride: ride)),
                          ),
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: const Text('Chat'),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _PassengerCard extends StatelessWidget {
  const _PassengerCard({required this.booking});

  final RideBooking booking;

  @override
  Widget build(BuildContext context) {
    final isCompleted = booking.bookingStatus == BookingStatus.completed;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  booking.passengerName.isEmpty
                      ? 'Passenger'
                      : booking.passengerName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isCompleted
                      ? const Color(0xFFDFF7EA)
                      : const Color(0xFFE7EAFE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isCompleted ? 'Completed' : 'Booked',
                  style: TextStyle(
                    color: isCompleted
                        ? const Color(0xFF15803D)
                        : AppDesignTokens.brandStart,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
              'Pickup: ${LocationDisplayFormatter.title(booking.passengerPickup)}'),
          Text(
              'Drop: ${LocationDisplayFormatter.title(booking.passengerDrop)}'),
          Text('Seats: ${booking.seatsBooked}'),
        ],
      ),
    );
  }
}

class _CancelledTab extends StatelessWidget {
  const _CancelledTab({
    required this.bookings,
    required this.offeredCancelled,
    required this.ridesById,
  });

  final List<RideBooking> bookings;
  final List<RideOffer> offeredCancelled;
  final Map<String, RideOffer> ridesById;

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty && offeredCancelled.isEmpty) {
      return ListView(children: const [
        SizedBox(height: 140),
        Center(child: Text('No cancelled rides'))
      ]);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      children: [
        if (offeredCancelled.isNotEmpty) ...[
          const _SectionHeader('Cancelled Rides I Offered'),
          ...offeredCancelled
              .map((ride) => _CancelledOfferedRideCard(ride: ride)),
        ],
        if (bookings.isNotEmpty) ...[
          const _SectionHeader('Cancelled / Rejected Bookings'),
          ...bookings.map((booking) => _CancelledBookingCard(
                booking: booking,
                ride: ridesById[booking.rideOfferId],
              )),
        ],
      ],
    );
  }
}

class _CancelledBookingCard extends StatelessWidget {
  const _CancelledBookingCard({
    required this.booking,
    required this.ride,
  });

  final RideBooking booking;
  final RideOffer? ride;

  @override
  Widget build(BuildContext context) {
    final routeTitle = ride == null
        ? 'Cancelled Booking'
        : LocationDisplayFormatter.routeTitle(ride!.origin, ride!.destination);
    final cancelledBy = ride?.status == 5 ? 'Driver' : 'You';
    final cancelledAt = booking.cancelledAtUtc;
    final reason = booking.cancellationReason?.trim();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    routeTitle,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 22),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(14)),
                  child: const Text('Cancelled',
                      style: TextStyle(
                          color: Color(0xFFB91C1C),
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            if (ride != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                      child: Text(DepartureTimeUtils.formatFriendly(
                          ride!.departureTimeUtc,
                          context: 'Trips Cancelled Booking'))),
                  const Icon(Icons.person_outline, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                      child: Text(
                          ride!.driverName.isEmpty
                              ? 'Driver'
                              : ride!.driverName,
                          overflow: TextOverflow.ellipsis)),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      'Pickup: ${LocationDisplayFormatter.title(booking.passengerPickup)}'),
                  const SizedBox(height: 4),
                  Text(
                      'Drop: ${LocationDisplayFormatter.title(booking.passengerDrop)}'),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: Text('Seats: ${booking.seatsBooked}')),
                Expanded(
                  child: Text(
                    '${ride?.vehicleName ?? 'Vehicle'} ${ride?.vehicleNumber ?? ''}'
                        .trim(),
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text('Cancelled by: $cancelledBy'),
            if (reason != null && reason.isNotEmpty) Text('Reason: $reason'),
            if (cancelledAt != null)
              Text(
                  'Cancelled at: ${DepartureTimeUtils.formatFriendly(cancelledAt, context: 'Trips Cancelled At')}'),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: ride == null
                  ? null
                  : () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => RideDetailsScreen(extra: ride!))),
              icon: const Icon(Icons.open_in_new),
              label: const Text('View Details'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CancelledOfferedRideCard extends StatelessWidget {
  const _CancelledOfferedRideCard({required this.ride});

  final RideOffer ride;

  @override
  Widget build(BuildContext context) {
    final reason = ride.cancellationReason?.trim();
    final cancelledAt = ride.cancelledAtUtc;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    LocationDisplayFormatter.routeTitle(
                        ride.origin, ride.destination),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 22),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(14)),
                  child: const Text('Cancelled',
                      style: TextStyle(
                          color: Color(0xFFB91C1C),
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 16),
                const SizedBox(width: 6),
                Expanded(
                    child: Text(DepartureTimeUtils.formatFriendly(
                        ride.departureTimeUtc,
                        context: 'Trips Cancelled Offered'))),
                const Icon(Icons.group_outlined, size: 16),
                const SizedBox(width: 6),
                Text('${ride.participantCount} booked'),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      'Pickup: ${LocationDisplayFormatter.title(ride.origin)}'),
                  const SizedBox(height: 4),
                  Text(
                      'Drop: ${LocationDisplayFormatter.title(ride.destination)}'),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: Text('Seats left: ${ride.availableSeats}')),
                Expanded(
                  child: Text(
                    '${ride.vehicleName ?? 'Vehicle'} ${ride.vehicleNumber ?? ''}'
                        .trim(),
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text('Cancelled by: You'),
            if (reason != null && reason.isNotEmpty) Text('Reason: $reason'),
            if (cancelledAt != null)
              Text(
                  'Cancelled at: ${DepartureTimeUtils.formatFriendly(cancelledAt, context: 'Trips Cancelled Ride At')}'),
            Text(
                'Passenger summary: ${ride.participantCount} booked passenger(s)'),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => RideDetailsScreen(extra: ride))),
              icon: const Icon(Icons.open_in_new),
              label: const Text('View Details'),
            ),
          ],
        ),
      ),
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
    this.quaternaryLabel,
    this.onQuaternary,
    this.bookedSeats,
    this.yourPickupName,
    this.yourDropName,
    this.showPassengerCount = false,
  });

  final RideOffer ride;
  final String statusBadge;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final String? tertiaryLabel;
  final VoidCallback? onTertiary;
  final String? quaternaryLabel;
  final VoidCallback? onQuaternary;
  final int? bookedSeats;
  final String? yourPickupName;
  final String? yourDropName;
  final bool showPassengerCount;

  @override
  Widget build(BuildContext context) {
    final nodes = buildRideTimeline(
      ride: ride,
      yourPickupName: (yourPickupName == null || yourPickupName!.trim().isEmpty)
          ? null
          : LocationDisplayFormatter.title({'name': yourPickupName}),
      yourDropName: (yourDropName == null || yourDropName!.trim().isEmpty)
          ? null
          : LocationDisplayFormatter.title({'name': yourDropName}),
      departureUtc: ride.departureTimeUtc,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    LocationDisplayFormatter.routeTitle(
                        ride.origin, ride.destination),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 24),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: const Color(0xFFE7EAFE),
                      borderRadius: BorderRadius.circular(14)),
                  child: Text(statusBadge,
                      style: const TextStyle(
                          color: AppDesignTokens.brandStart,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 16),
                const SizedBox(width: 6),
                Text(DepartureTimeUtils.formatFriendly(ride.departureTimeUtc,
                    context: 'Trips Card')),
                const SizedBox(width: 12),
                const Icon(Icons.person_outline, size: 16),
                const SizedBox(width: 6),
                Expanded(
                    child: Text(
                        ride.driverName.isEmpty ? 'Rider' : ride.driverName)),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(16)),
              child: RideVerticalTimeline(nodes: nodes),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: Text('${ride.pricePerSeat} / seat')),
                Expanded(
                  child: Text(
                    bookedSeats == null
                        ? '${ride.availableSeats} seats left'
                        : '$bookedSeats seat booked',
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: Text(
                    showPassengerCount
                        ? '${ride.participantCount} passengers'
                        : '${ride.vehicleName ?? 'Vehicle'} ${ride.vehicleNumber ?? ''}'
                            .trim(),
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                    onPressed: onPrimary,
                    icon: const Icon(Icons.open_in_new),
                    label: Text(primaryLabel)),
                if (secondaryLabel != null)
                  FilledButton.tonalIcon(
                    onPressed: onSecondary,
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: Text(secondaryLabel!),
                  ),
                if (tertiaryLabel != null)
                  OutlinedButton.icon(
                    onPressed: onTertiary,
                    icon: const Icon(Icons.cancel_outlined),
                    label: Text(tertiaryLabel!),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent),
                  ),
                if (quaternaryLabel != null)
                  FilledButton.icon(
                    onPressed: onQuaternary,
                    icon: const Icon(Icons.play_arrow),
                    label: Text(quaternaryLabel!),
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
      child: Text(title,
          style: const TextStyle(
              fontWeight: FontWeight.w700, color: AppDesignTokens.brandStart)),
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

//â‚¹
