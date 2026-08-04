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
      final bookingProvider = context.read<BookingProvider>();
      rideProvider.loadUpcomingActive();
      if (userId != null && userId.isNotEmpty) {
        rideProvider.connectRealtime(
          userId: userId,
          onBookingChanged: bookingProvider.upsertRealtime,
        );
      }
      context.read<NotificationProvider>().loadUnreadCount();
      context.read<NotificationProvider>().startUnreadAutoRefresh();
      bookingProvider.loadHistory();
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
    context.read<RideProvider>().disconnectRealtime();
    context.read<NotificationService>().disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1100;
    final pages = [
      _HomePage(onProfileTap: () => setState(() => _index = 3)),
      const TripsScreen(showAppBar: false),
      const NotificationScreen(showAppBar: false),
      const ProfileScreen(showAppBar: false),
    ];

    if (!isDesktop) {
      return Scaffold(
        backgroundColor: const Color(0xFFF7F8FC),
        body: SafeArea(child: pages[_index]),
        bottomNavigationBar: AppBottomNav(
          index: _index,
          onChanged: (value) => setState(() => _index = value),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: SafeArea(
        child: Row(
          children: [
            _DesktopSidebar(
              index: _index,
              onChanged: (value) => setState(() => _index = value),
            ),
            Expanded(child: pages[_index]),
          ],
        ),
      ),
    );
  }
}

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.home_outlined, 'Home'),
      (Icons.route_outlined, 'Trips'),
      (Icons.notifications_none_outlined, 'Alerts'),
      (Icons.person_outline, 'Profile'),
    ];
    return Container(
      width: 240,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
              color: Color(0x140F172A), blurRadius: 16, offset: Offset(0, 6))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Color(0xFFE7EAFE),
                child: Icon(Icons.directions_car_filled,
                    color: AppDesignTokens.brandStart),
              ),
              SizedBox(width: 10),
              Text('CarPool',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 18),
          ...items.asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () => onChanged(entry.key),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: index == entry.key
                            ? const Color(0xFFE7EAFE)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(entry.value.$1,
                              color: index == entry.key
                                  ? AppDesignTokens.brandStart
                                  : const Color(0xFF64748B)),
                          const SizedBox(width: 10),
                          Text(
                            entry.value.$2,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: index == entry.key
                                  ? AppDesignTokens.brandStart
                                  : const Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Need Help?',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                SizedBox(height: 4),
                Text('Contact support 24/7 for booking and trip help.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomePage extends StatelessWidget {
  const _HomePage({required this.onProfileTap});
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1100;
    final auth = context.watch<AuthProvider>();
    final profile = context.watch<ProfileProvider>().profile;
    final rideProvider = context.watch<RideProvider>();
    final bookings = context.watch<BookingProvider>().bookings;
    final nowUtc = DateTime.now().toUtc();
    final activeRides = List<RideOffer>.from(rideProvider.upcomingActiveRides)
      ..retainWhere((ride) => ride.status == 3)
      ..sort((a, b) => b.departureTimeUtc.compareTo(a.departureTimeUtc));
    final upcomingRides = List<RideOffer>.from(rideProvider.upcomingActiveRides)
      ..retainWhere((ride) =>
          (ride.status == 1 || ride.status == 2) &&
          ride.departureTimeUtc.isAfter(nowUtc))
      ..sort((a, b) => a.departureTimeUtc.compareTo(b.departureTimeUtc));
    final rides = [...activeRides, ...upcomingRides];
    final myUserId = auth.session?.userId;
    final firstName = ((profile?.fullName ?? auth.session?.fullName ?? '')
        .trim()
        .split(' ')
        .firstWhere((e) => e.trim().isNotEmpty, orElse: () => 'there'));
    final unreadCount = context.watch<NotificationProvider>().unreadCountValue;

    final bookedByRide = {
      for (final booking in bookings.where((b) =>
          b.bookingStatus == BookingStatus.accepted &&
          (myUserId == null || b.passengerId == myUserId)))
        booking.rideOfferId: booking,
    };

    final firstRide = rides.isEmpty ? null : rides.first;
    final pickupText = firstRide == null
        ? 'Pickup Location'
        : LocationDisplayFormatter.title(firstRide.origin);

    final destinationText = firstRide == null
        ? 'Destination'
        : LocationDisplayFormatter.title(firstRide.destination);

    final leftContent = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TopHomeBar(unreadCount: unreadCount, onProfileTap: onProfileTap),
        const SizedBox(height: 12),
        _GreetingCard(firstName: firstName),
        const SizedBox(height: 12),
        _PickupDestinationCard(
            pickupText: pickupText, destinationText: destinationText),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => context.push(AppRoutes.searchRides),
                style: FilledButton.styleFrom(
                  backgroundColor: AppDesignTokens.brandStart,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.search),
                label: const Text('Search Ride'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.push(AppRoutes.offerRide),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppDesignTokens.brandStart),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.local_taxi_outlined),
                label: const Text('Offer Ride'),
              ),
            ),
          ],
        ),
        if (!isDesktop) ...[
          const SizedBox(height: 14),
          _UpcomingSection(
            activeRides: activeRides,
            upcomingRides: upcomingRides,
            bookedByRide: bookedByRide,
            isLoading: rideProvider.isLoading,
            myUserId: myUserId,
            desktopScrollable: false,
          ),
        ],
        const SizedBox(height: 12),
        _QuickActions(isWide: isDesktop),
        const SizedBox(height: 12),
        const _WhyNewCarpoolCard(),
        const SizedBox(height: 14),
      ],
    );

    if (!isDesktop) {
      return CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(12),
            sliver: SliverToBoxAdapter(child: leftContent),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 12, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 6,
            child: SingleChildScrollView(
              child: leftContent,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 5,
            child: Column(
              children: [
                const SizedBox(height: 8),
                Expanded(
                  child: _UpcomingSection(
                    activeRides: activeRides,
                    upcomingRides: upcomingRides,
                    bookedByRide: bookedByRide,
                    isLoading: rideProvider.isLoading,
                    myUserId: myUserId,
                    desktopScrollable: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopHomeBar extends StatelessWidget {
  const _TopHomeBar({required this.unreadCount, required this.onProfileTap});

  final int unreadCount;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('Home',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
        const Spacer(),
        IconButton(
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
            ],
          ),
        ),
        InkWell(
          onTap: onProfileTap,
          customBorder: const CircleBorder(),
          child: const CircleAvatar(
              radius: 16, child: Icon(Icons.person, size: 18)),
        ),
      ],
    );
  }
}

class _GreetingCard extends StatelessWidget {
  const _GreetingCard({required this.firstName});

  final String firstName;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 720;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
            colors: [Color(0xFF5B61FF), Color(0xFF2E39E6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        boxShadow: const [
          BoxShadow(
              color: Color(0x260F172A), blurRadius: 18, offset: Offset(0, 8))
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hi, $firstName 👋',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: isMobile ? 28 : 36,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('Where are you going today?',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: isMobile ? 18 : 22,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const Icon(Icons.directions_car_filled,
              color: Colors.white70, size: 50),
        ],
      ),
    );
  }
}

class _PickupDestinationCard extends StatelessWidget {
  const _PickupDestinationCard(
      {required this.pickupText, required this.destinationText});

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
                value: pickupText),
            const Divider(height: 18),
            _LocationRow(
                icon: Icons.location_on,
                iconColor: const Color(0xFFEF4444),
                label: 'Destination',
                value: destinationText),
          ],
        ),
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow(
      {required this.icon,
      required this.iconColor,
      required this.label,
      required this.value});

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
              Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, color: Color(0xFF475569))),
              const SizedBox(height: 2),
              Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.isWide});

  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final actions = [
      (
        Icons.garage_outlined,
        'Vehicles',
        'Manage your vehicles',
        AppRoutes.vehicles
      ),
      (
        Icons.payments_outlined,
        'Payments',
        'Transactions & history',
        AppRoutes.payments
      ),
      (
        Icons.location_searching_outlined,
        'Tracking',
        'Live ride tracking',
        AppRoutes.tracking
      ),
      (
        Icons.fact_check_outlined,
        'Requests',
        'Ride requests',
        AppRoutes.driverRequests
      ),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: actions.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isWide ? 4 : 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: isWide ? 1.05 : 1.35,
      ),
      itemBuilder: (context, i) {
        final action = actions[i];
        return Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
                    child: Icon(action.$1,
                        color: AppDesignTokens.brandStart, size: 18),
                  ),
                  const Spacer(),
                  Text(action.$2,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(action.$3,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF64748B))),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WhyNewCarpoolCard extends StatelessWidget {
  const _WhyNewCarpoolCard();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 700;
    final available = width > 1100 ? width - 340 : width - 48;
    final itemWidth = width >= 1200
        ? (available - 36) / 4
        : width >= 700
            ? (available - 12) / 2
            : (available - 12) / 2;
    final items = [
      (
        Icons.verified_user_outlined,
        'Verified Drivers',
        'Safe & secure users',
        const Color(0xFF4F46E5)
      ),
      (
        Icons.savings_outlined,
        'Affordable Rides',
        'Save on every ride',
        const Color(0xFF22C55E)
      ),
      (
        Icons.schedule_outlined,
        'On-time Travel',
        'Reliable schedules',
        const Color(0xFFF59E0B)
      ),
      (
        Icons.support_agent_outlined,
        '24/7 Support',
        'Help when needed',
        const Color(0xFF06B6D4)
      ),
    ];
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Why CarPool?',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            if (isMobile)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  mainAxisExtent: 104,
                ),
                itemBuilder: (_, i) => _WhyBenefitTile(item: items[i]),
              )
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: items.map((e) {
                  return SizedBox(
                    width: itemWidth,
                    child: _WhyBenefitTile(item: e),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _WhyBenefitTile extends StatelessWidget {
  const _WhyBenefitTile({required this.item});

  final (IconData, String, String, Color) item;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 105),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: item.$4.withValues(alpha: 0.15),
            child: Icon(item.$1, color: item.$4, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.$2,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  item.$3,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UpcomingSection extends StatelessWidget {
  const _UpcomingSection({
    required this.activeRides,
    required this.upcomingRides,
    required this.bookedByRide,
    required this.isLoading,
    required this.myUserId,
    required this.desktopScrollable,
  });

  final List<RideOffer> activeRides;
  final List<RideOffer> upcomingRides;
  final Map<String, RideBooking> bookedByRide;
  final bool isLoading;
  final String? myUserId;
  final bool desktopScrollable;

  @override
  Widget build(BuildContext context) {
    final rides = [...activeRides, ...upcomingRides];
    final showUpcomingHeader =
        activeRides.isNotEmpty && upcomingRides.isNotEmpty;
    final list = isLoading && rides.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : rides.isEmpty
            ? const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                      'No upcoming rides yet. Search rides and book your next trip.'),
                ),
              )
            : ListView.builder(
                shrinkWrap: !desktopScrollable,
                physics: desktopScrollable
                    ? const AlwaysScrollableScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                itemCount: rides.length + (showUpcomingHeader ? 1 : 0),
                itemBuilder: (_, index) {
                  if (showUpcomingHeader && index == activeRides.length) {
                    return const Padding(
                      padding: EdgeInsets.fromLTRB(0, 4, 0, 12),
                      child: Text(
                        'Upcoming Rides',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    );
                  }
                  final rideIndex =
                      activeRides.isNotEmpty && index > activeRides.length
                          ? index - 1
                          : index;
                  if (rideIndex >= rides.length) {
                    return const SizedBox.shrink();
                  }
                  final ride = rides[rideIndex];
                  final booking = bookedByRide[ride.id];
                  final isDriver =
                      myUserId != null && ride.driverId == myUserId;
                  final isBooked = booking != null;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _DashboardRideCard(
                        ride: ride,
                        booking: booking,
                        isDriver: isDriver,
                        isBooked: isBooked),
                  );
                },
              );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                  activeRides.isNotEmpty ? 'Active Ride' : 'Upcoming Rides',
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.w800)),
            ),
            TextButton(
                onPressed: () => context.push(AppRoutes.trips),
                child: const Text('View all')),
          ],
        ),
        const SizedBox(height: 8),
        if (desktopScrollable) Expanded(child: list) else list,
      ],
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
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 17),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: const Color(0xFFDFF7EA),
                      borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    DepartureTimeUtils.formatFriendly(ride.departureTimeUtc,
                        context: 'Dashboard Card'),
                    style: const TextStyle(
                        color: Color(0xFF15803D),
                        fontWeight: FontWeight.w700,
                        fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            RideMiniProgressTimeline(nodes: nodes),
            const SizedBox(height: 10),
            Wrap(
              spacing: 14,
              runSpacing: 8,
              children: [
                _MetaChip(
                    icon: Icons.person_outline,
                    label: 'Driver',
                    value: ride.driverName),
                _MetaChip(
                    icon: Icons.event_seat_outlined,
                    label: 'Seats Left',
                    value: '${ride.availableSeats} seats'),
                _MetaChip(
                    icon: Icons.currency_rupee,
                    label: 'Price / Seat',
                    value: '₹${ride.pricePerSeat}'),
                _MetaChip(
                    icon: Icons.directions_car_outlined,
                    label: 'Vehicle',
                    value:
                        '${ride.vehicleName ?? 'Vehicle'} ${ride.vehicleNumber ?? ''}'
                            .trim()),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: isBooked
                  ? FilledButton.icon(
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => RideChatScreen(ride: ride))),
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('Chat with Driver'),
                    )
                  : isDriver
                      ? OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) =>
                                      RideDetailsScreen(extra: ride))),
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('View Details / Manage'),
                        )
                      : FilledButton(
                          onPressed: () =>
                              context.push(AppRoutes.booking, extra: ride),
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
  const _MetaChip(
      {required this.icon, required this.label, required this.value});

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
