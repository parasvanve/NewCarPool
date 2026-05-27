import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_routes.dart';
import '../../core/utils/departure_time_utils.dart';
import '../../core/utils/location_display_formatter.dart';
import '../../core/widgets/app_design_system.dart';
import '../../core/widgets/ride_timeline_widgets.dart';
import '../../models/ride_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/ride_provider.dart';
import '../notifications/notification_screen.dart';
import '../profile/profile_screen.dart';
import '../rides/offer_ride_form_screen.dart';
import '../trips/trips_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RideProvider>().loadUpcomingActive();
      context.read<NotificationProvider>().loadUnreadCount();
    });
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
    final isWide = MediaQuery.of(context).size.width > 900;
    final auth = context.watch<AuthProvider>();
    final profile = context.watch<ProfileProvider>().profile;
    final rides = context.select<RideProvider, List<RideOffer>>(
      (provider) => provider.upcomingActiveRides,
    );
    final displayName =
        (profile?.fullName ?? auth.session?.fullName ?? '').trim();
    final firstName =
        displayName.isEmpty ? 'there' : displayName.split(' ').first;
    final myUserId = auth.session?.userId;
    final unreadCount = context.watch<NotificationProvider>().unreadCountValue;
    final upcomingRides = List<RideOffer>.from(rides)
      ..sort((a, b) => a.departureTimeUtc.compareTo(b.departureTimeUtc));
    final previewRides = upcomingRides.take(3).toList();

    final quickActions = Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        SizedBox(
          width: isWide ? 170 : (MediaQuery.of(context).size.width - 54) / 3,
          child: AppQuickActionTile(
            icon: Icons.garage_outlined,
            label: 'Vehicles',
            onTap: () => context.push(AppRoutes.vehicles),
          ),
        ),
        SizedBox(
          width: isWide ? 170 : (MediaQuery.of(context).size.width - 54) / 3,
          child: AppQuickActionTile(
            icon: Icons.payments_outlined,
            label: 'Payments',
            onTap: () => context.push(AppRoutes.payments),
          ),
        ),
        SizedBox(
          width: isWide ? 170 : (MediaQuery.of(context).size.width - 54) / 3,
          child: AppQuickActionTile(
            icon: Icons.location_searching_outlined,
            label: 'Tracking',
            onTap: () => context.push(AppRoutes.tracking),
          ),
        ),
        SizedBox(
          width: isWide ? 170 : (MediaQuery.of(context).size.width - 54) / 3,
          child: AppQuickActionTile(
            icon: Icons.fact_check_outlined,
            label: 'Requests',
            onTap: () => context.push(AppRoutes.driverRequests),
          ),
        ),
      ],
    );

    final searchCard = Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _RouteRow(
              icon: Icons.radio_button_checked,
              iconColor: Color(0xFF22C55E),
              text: 'Pickup location',
            ),
            const Padding(
              padding: EdgeInsets.only(left: 11),
              child: SizedBox(height: 18, child: VerticalDivider()),
            ),
            const _RouteRow(
              icon: Icons.location_on_rounded,
              iconColor: Color(0xFFEF4444),
              text: 'Destination',
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const OfferRideFormScreen(),
                ),
              ),
              icon: const Icon(Icons.local_taxi_outlined),
              label: const Text('Offer Ride'),
            ),
          ],
        ),
      ),
    );

    final rightColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppGradientHeroCard(
          title: 'Hi, $firstName',
          subtitle: 'Where are you going today?',
          icon: Icons.waving_hand_rounded,
        ),
        const SizedBox(height: 14),
        searchCard,
        const SizedBox(height: 16),
        quickActions,
      ],
    );

    final tripsColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: () => context.push(AppRoutes.searchRides),
          icon: const Icon(Icons.search),
          label: const Text('Search Ride'),
        ),
        const SizedBox(height: 14),
        AppSectionHeader(
          title: 'Upcoming Ride',
          actionText: 'View all',
          onAction: () => context.push(AppRoutes.trips),
        ),
        const SizedBox(height: 8),
        if (previewRides.isEmpty)
          const _TripPreviewCard()
        else
          ...previewRides.map(
            (ride) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _TripPreviewCard(
                ride: ride,
                canBook: myUserId == null
                    ? ride.availableSeats > 0
                    : (ride.driverId != myUserId && ride.availableSeats > 0),
              ),
            ),
          ),
        const SizedBox(height: 16),
        const AppSectionHeader(title: 'Recent Searches'),
        const SizedBox(height: 8),
        const _RecentTile('Use Search Ride', 'to find nearby trips',
            'Live results from backend'),
        const _RecentTile('Offer Ride', 'to publish your own route',
            'Driver or Passenger anytime'),
      ],
    );

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          title: const Text('Home'),
          actions: [
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
            ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 6, child: rightColumn),
                      const SizedBox(width: 16),
                      Expanded(flex: 5, child: tripsColumn),
                    ],
                  )
                : Column(
                    children: [
                      rightColumn,
                      const SizedBox(height: 16),
                      tripsColumn,
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _RouteRow extends StatelessWidget {
  const _RouteRow({
    required this.icon,
    required this.iconColor,
    required this.text,
  });

  final IconData icon;
  final Color iconColor;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 10),
        Text(text),
      ],
    );
  }
}

class _TripPreviewCard extends StatelessWidget {
  const _TripPreviewCard({this.ride, this.canBook = false});

  final RideOffer? ride;
  final bool canBook;

  @override
  Widget build(BuildContext context) {
    final nodes = ride == null
        ? const <RideTimelineNode>[]
        : buildRideTimeline(
            ride: ride!,
            departureUtc: ride!.departureTimeUtc,
          );
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ride == null
                  ? 'No upcoming rides yet'
                  : LocationDisplayFormatter.routeTitle(
                      ride!.origin,
                      ride!.destination,
                    ),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              ride == null
                  ? 'Search rides and book your next trip.'
                  : 'Departure: ${DepartureTimeUtils.formatFriendly(ride!.departureTimeUtc, context: 'Dashboard Upcoming Ride')}',
            ),
            if (ride != null) ...[
              const SizedBox(height: 10),
              Text(
                nodes.map((e) => e.locationTitle).join(' -> '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              RideMiniProgressTimeline(nodes: nodes),
            ],
            const SizedBox(height: 4),
            Text(ride == null
                ? 'Driver details appear after booking.'
                : 'Driver: ${ride!.driverName}'),
            if (ride != null) ...[
              const SizedBox(height: 4),
              Text('Seats: ${ride!.availableSeats} • ₹${ride!.pricePerSeat} / seat'),
              const SizedBox(height: 4),
              Text(
                'Vehicle: ${ride!.vehicleName ?? 'Vehicle'} ${ride!.vehicleNumber ?? ''}'
                    .trim(),
              ),
            ],
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: ride == null
                  ? const FilledButton.tonal(
                      onPressed: null,
                      child: Text('Empty'),
                    )
                  : canBook
                      ? FilledButton.tonal(
                          onPressed: () => context.push(
                            AppRoutes.rideDetails,
                            extra: ride,
                          ),
                          child: const Text('Book Ride'),
                        )
                      : const FilledButton.tonal(
                          onPressed: null,
                          child: Text('Upcoming'),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentTile extends StatelessWidget {
  const _RecentTile(this.origin, this.destination, this.time);
  final String origin;
  final String destination;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.history),
        title: Text('$origin  ->  $destination'),
        subtitle: Text(time),
      ),
    );
  }
}
