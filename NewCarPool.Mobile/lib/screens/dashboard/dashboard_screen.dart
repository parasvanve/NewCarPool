import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_routes.dart';
import '../../core/utils/departure_time_utils.dart';
import '../../core/utils/location_display_formatter.dart';
import '../../core/widgets/app_design_system.dart';
import '../../core/widgets/ride_timeline_widgets.dart';
import '../../models/booking_models.dart';
import '../../models/ride_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/ride_provider.dart';
import '../../services/notification_service.dart';
import '../notifications/notification_screen.dart';
import '../profile/profile_screen.dart';
import '../rides/offer_ride_form_screen.dart';
import '../rides/ride_chat_screen.dart';
import '../rides/ride_details_screen.dart';
import '../trips/trips_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _index = 0;
  bool _notificationRealtimeConnected = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      final userId = auth.session?.userId;
      final rideProvider = context.read<RideProvider>();
      rideProvider.loadUpcomingActive();
      if (userId != null && userId.isNotEmpty) {
        rideProvider.connectRealtime(userId: userId);
      }
      rideProvider.startUpcomingAutoRefresh();
      context.read<NotificationProvider>().loadUnreadCount();
      context.read<NotificationProvider>().startUnreadAutoRefresh();
      context.read<BookingProvider>().loadHistory();
      _connectNotificationRealtime();
    });
  }

  Future<void> _connectNotificationRealtime() async {
    if (_notificationRealtimeConnected) return;
    final profileProvider = context.read<ProfileProvider>();
    if (profileProvider.profile == null) {
      try {
        await profileProvider.loadProfile();
      } catch (_) {
        return;
      }
    }
    final userId = profileProvider.profile?.id;
    if (userId == null || userId.isEmpty || !mounted) return;
    final notificationService = context.read<NotificationService>();
    await notificationService.connect(userId, (notification) {
      if (!mounted) return;
      context.read<NotificationProvider>().prependRealtime(notification);
    });
    notificationService.onUnreadCountChanged((count) {
      if (!mounted) return;
      context.read<NotificationProvider>().setUnreadCountRealtime(count);
    });
    _notificationRealtimeConnected = true;
  }

  @override
  void dispose() {
    context.read<NotificationProvider>().stopUnreadAutoRefresh();
    context.read<RideProvider>().stopUpcomingAutoRefresh();
    context.read<RideProvider>().disconnectRealtime();
    context.read<NotificationService>().disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const _HomeTab(),
      const TripsScreen(showAppBar: false),
      const NotificationScreen(showAppBar: false),
      const ProfileScreen(showAppBar: false),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: SafeArea(child: pages[_index]),
      bottomNavigationBar: AppBottomNav(
        index: _index,
        onChanged: (value) => setState(() => _index = value),
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 980;
    final auth = context.watch<AuthProvider>();
    final profile = context.watch<ProfileProvider>().profile;
    final rideProvider = context.watch<RideProvider>();
    final nowUtc = DateTime.now().toUtc();
    final rides = List<RideOffer>.from(rideProvider.upcomingActiveRides)
      ..retainWhere((r) => r.departureTimeUtc.isAfter(nowUtc) && r.status == 1 && r.availableSeats > 0)
      ..sort((a, b) => a.departureTimeUtc.compareTo(b.departureTimeUtc));
    final bookings = context.watch<BookingProvider>().bookings;

    final displayName = (profile?.fullName ?? auth.session?.fullName ?? '').trim();
    final firstName = displayName.isEmpty ? 'there' : displayName.split(' ').first;
    final unreadCount = context.watch<NotificationProvider>().unreadCountValue;
    final myUserId = auth.session?.userId;

    final bookedByRide = {
      for (final booking in bookings.where(
        (b) =>
            b.bookingStatus == BookingStatus.accepted &&
            (myUserId == null || b.passengerId == myUserId),
      ))
        booking.rideOfferId: booking,
    };

    final firstRide = rides.isEmpty ? null : rides.first;
    final pickupText = firstRide == null
        ? 'Enter pickup location'
        : LocationDisplayFormatter.title(firstRide.origin);
    final destinationText = firstRide == null
        ? 'Enter destination'
        : LocationDisplayFormatter.title(firstRide.destination);

    final leftPanel = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GreetingCard(firstName: firstName),
        const SizedBox(height: 12),
        _PickupDestinationCard(
          pickupText: pickupText,
          destinationText: destinationText,
        ),
        const SizedBox(height: 12),
        _OfferRideButton(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OfferRideFormScreen()))),
        const SizedBox(height: 12),
        _QuickActions(isWide: isWide),
        const SizedBox(height: 12),
        const _WhyCarpoolCard(),
      ],
    );

    final rightPanel = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppDesignTokens.brandStart,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: () => context.push(AppRoutes.searchRides),
          icon: const Icon(Icons.search),
          label: const Text('Search Ride'),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            const Expanded(
              child: Text('Upcoming Rides', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700)),
            ),
            TextButton(
              onPressed: () => context.push(AppRoutes.trips),
              child: const Text('View all'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (isWide)
          Expanded(
            child: rideProvider.isLoading && rides.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : rides.isEmpty
                    ? const Card(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('No upcoming rides yet. Search rides and book your next trip.'),
                        ),
                      )
                    : ListView.builder(
                        itemCount: rides.length,
                        itemBuilder: (_, index) {
                          final ride = rides[index];
                          final booking = bookedByRide[ride.id];
                          final isDriver = myUserId != null && ride.driverId == myUserId;
                          final isBooked = booking != null;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _DashboardRideCard(
                              ride: ride,
                              booking: booking,
                              isDriver: isDriver,
                              isBooked: isBooked,
                            ),
                          );
                        },
                      ),
          )
        else ...[
          if (rideProvider.isLoading && rides.isEmpty)
            const Center(child: CircularProgressIndicator())
          else if (rides.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('No upcoming rides yet. Search rides and book your next trip.'),
              ),
            )
          else
            ...rides.map((ride) {
              final booking = bookedByRide[ride.id];
              final isDriver = myUserId != null && ride.driverId == myUserId;
              final isBooked = booking != null;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _DashboardRideCard(
                  ride: ride,
                  booking: booking,
                  isDriver: isDriver,
                  isBooked: isBooked,
                ),
              );
            }),
        ],
      ],
    );

    if (!isWide) {
      return CustomScrollView(
        slivers: [
          _HomeAppBar(unreadCount: unreadCount),
          SliverPadding(
            padding: const EdgeInsets.all(12),
            sliver: SliverToBoxAdapter(
              child: Column(
                children: [
                  leftPanel,
                  const SizedBox(height: 12),
                  rightPanel,
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        _HomeTopBar(unreadCount: unreadCount),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 5,
                  child: SingleChildScrollView(child: leftPanel),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 5,
                  child: rightPanel,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeAppBar extends StatelessWidget {
  const _HomeAppBar({required this.unreadCount});

  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: Colors.white,
      title: const Text('Home', style: TextStyle(fontWeight: FontWeight.w700)),
      actions: [_NotificationIcon(unreadCount: unreadCount), const SizedBox(width: 8)],
    );
  }
}

class _HomeTopBar extends StatelessWidget {
  const _HomeTopBar({required this.unreadCount});

  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      height: kToolbarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          const SizedBox(width: 8),
          const Text('Home', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
          const Spacer(),
          _NotificationIcon(unreadCount: unreadCount),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _NotificationIcon extends StatelessWidget {
  const _NotificationIcon({required this.unreadCount});

  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => context.push(AppRoutes.notifications),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_none_rounded),
          if (unreadCount > 0)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                constraints: const BoxConstraints(minWidth: 16),
                child: Text(
                  unreadCount > 99 ? '99+' : '$unreadCount',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GreetingCard extends StatelessWidget {
  const _GreetingCard({required this.firstName});

  final String firstName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF5B61FF), Color(0xFF2E39E6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x260F172A), blurRadius: 18, offset: Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hi, $firstName 👋',
                  style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Where are you going today?',
                  style: TextStyle(color: Colors.white70, fontSize: 22, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const Icon(Icons.directions_car_filled, color: Colors.white70, size: 48),
        ],
      ),
    );
  }
}

class _PickupDestinationCard extends StatelessWidget {
  const _PickupDestinationCard({
    required this.pickupText,
    required this.destinationText,
  });

  final String pickupText;
  final String destinationText;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            _LocationRow(
              icon: Icons.trip_origin,
              iconColor: const Color(0xFF16A34A),
              label: 'Pickup location',
              value: pickupText,
            ),
            const Divider(height: 18),
            _LocationRow(
              icon: Icons.location_on,
              iconColor: const Color(0xFFEF4444),
              label: 'Destination',
              value: destinationText,
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF475569))),
              const SizedBox(height: 2),
              Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        const Icon(Icons.gps_fixed, size: 16, color: AppDesignTokens.brandStart),
      ],
    );
  }
}

class _OfferRideButton extends StatelessWidget {
  const _OfferRideButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppDesignTokens.brandStart),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      icon: const Icon(Icons.local_taxi_outlined),
      label: const Text('Offer Ride'),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.isWide});

  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final actions = [
      (Icons.garage_outlined, 'Vehicles', 'Manage your vehicles', AppRoutes.vehicles),
      (Icons.payments_outlined, 'Payments', 'Transactions & history', AppRoutes.payments),
      (Icons.location_searching_outlined, 'Tracking', 'Live ride tracking', AppRoutes.tracking),
      (Icons.fact_check_outlined, 'Requests', 'Ride requests', AppRoutes.driverRequests),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: actions.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isWide ? 4 : 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: isWide ? 1.02 : 1.2,
      ),
      itemBuilder: (context, i) {
        final action = actions[i];
        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => context.push(action.$4),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFFEEF2FF),
                    child: Icon(action.$1, color: AppDesignTokens.brandStart, size: 18),
                  ),
                  const Spacer(),
                  Text(action.$2, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(action.$3, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WhyCarpoolCard extends StatelessWidget {
  const _WhyCarpoolCard();

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.account_balance_wallet_outlined, 'Save Money', 'Share rides and save on travel', Color(0xFF22C55E)),
      (Icons.verified_user_outlined, 'Verified Users', 'All users are verified for your safety', Color(0xFF4F46E5)),
      (Icons.location_searching_outlined, 'Live Tracking', 'Track rides in real-time', Color(0xFF06B6D4)),
      (Icons.touch_app_outlined, 'Easy Booking', 'Book rides in just a few taps', Color(0xFFF59E0B)),
    ];

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Why NewCarPool?', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: items
                  .map(
                    (e) => SizedBox(
                      width: 180,
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: e.$4.withValues(alpha: 0.15),
                            child: Icon(e.$1, color: e.$4),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(e.$2, style: const TextStyle(fontWeight: FontWeight.w700)),
                                Text(e.$3, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardRideCard extends StatelessWidget {
  const _DashboardRideCard({
    required this.ride,
    required this.booking,
    required this.isDriver,
    required this.isBooked,
  });

  final RideOffer ride;
  final RideBooking? booking;
  final bool isDriver;
  final bool isBooked;

  @override
  Widget build(BuildContext context) {
    final nodes = buildRideTimeline(
      ride: ride,
      yourPickupName: booking?.passengerPickup?.name == null
          ? null
          : LocationDisplayFormatter.title(booking!.passengerPickup!),
      yourDropName: booking?.passengerDrop?.name == null
          ? null
          : LocationDisplayFormatter.title(booking!.passengerDrop!),
      departureUtc: ride.departureTimeUtc,
    );

    final title = nodes.map((e) => e.locationTitle).join(' -> ');

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDFF7EA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    DepartureTimeUtils.formatFriendly(ride.departureTimeUtc, context: 'Dashboard Card'),
                    style: const TextStyle(color: Color(0xFF15803D), fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            RideMiniProgressTimeline(nodes: nodes),
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _MetaChip(icon: Icons.person_outline, label: 'Driver', value: ride.driverName),
                _MetaChip(icon: Icons.event_seat_outlined, label: 'Seats Left', value: '${ride.availableSeats} seats'),
                _MetaChip(icon: Icons.currency_rupee, label: 'Price / Seat', value: '₹${ride.pricePerSeat}'),
                _MetaChip(icon: Icons.directions_car_outlined, label: 'Vehicle', value: '${ride.vehicleName ?? 'Vehicle'} ${ride.vehicleNumber ?? ''}'.trim()),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: isBooked
                  ? FilledButton.icon(
                      onPressed: () => Navigator.of(context)
                          .push(MaterialPageRoute(builder: (_) => RideChatScreen(ride: ride))),
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('Chat with Driver'),
                    )
                  : isDriver
                      ? OutlinedButton.icon(
                          onPressed: () => Navigator.of(context)
                              .push(MaterialPageRoute(builder: (_) => RideDetailsScreen(extra: ride))),
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('View Details / Manage'),
                        )
                      : FilledButton(
                          onPressed: () => context.push(AppRoutes.booking, extra: ride),
                          child: const Text('Book Ride'),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppDesignTokens.brandStart),
        const SizedBox(width: 5),
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
        Text(value),
      ],
    );
  }
}
