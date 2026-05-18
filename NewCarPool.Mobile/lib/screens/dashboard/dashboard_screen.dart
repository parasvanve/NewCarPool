import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_routes.dart';
import '../notifications/notification_screen.dart';
import '../profile/profile_screen.dart';
import '../trips/trips_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _index = 0;

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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.route_outlined), selectedIcon: Icon(Icons.route), label: 'Trips'),
          NavigationDestination(icon: Icon(Icons.notifications_outlined), selectedIcon: Icon(Icons.notifications), label: 'Alerts'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          title: const Text('NewCarPool'),
          actions: [
            IconButton(
              onPressed: () => context.push(AppRoutes.notifications),
              icon: const Icon(Icons.notifications_outlined),
              tooltip: 'Notifications',
            ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList.list(
            children: [
              Text('Where are you going?', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              _SearchPanel(
                onSearch: () => context.push(AppRoutes.searchRides),
                onOffer: () => context.push(AppRoutes.offerRide),
              ),
              const SizedBox(height: 20),
              _QuickActions(),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Upcoming trips', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                  TextButton(onPressed: () => context.push(AppRoutes.trips), child: const Text('View all')),
                ],
              ),
              const _TripPreviewCard(
                title: 'No upcoming trips',
                subtitle: 'Search for a ride or offer seats to start your next trip.',
                icon: Icons.calendar_today_outlined,
              ),
              const SizedBox(height: 20),
              Text('Popular routes', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const _RouteTile(origin: 'Bengaluru', destination: 'Mysuru', price: 'Rs 350'),
              const _RouteTile(origin: 'Whitefield', destination: 'Electronic City', price: 'Rs 180'),
              const _RouteTile(origin: 'Indiranagar', destination: 'Airport', price: 'Rs 420'),
            ],
          ),
        ),
      ],
    );
  }
}

class _SearchPanel extends StatelessWidget {
  const _SearchPanel({required this.onSearch, required this.onOffer});

  final VoidCallback onSearch;
  final VoidCallback onOffer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _LocationRow(icon: Icons.trip_origin, label: 'Pickup location'),
          const Padding(
            padding: EdgeInsets.only(left: 11),
            child: SizedBox(height: 22, child: VerticalDivider(width: 1)),
          ),
          const _LocationRow(icon: Icons.location_on_outlined, label: 'Destination'),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: onSearch, icon: const Icon(Icons.search), label: const Text('Search ride')),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: onOffer, icon: const Icon(Icons.directions_car), label: const Text('Offer ride')),
        ],
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyLarge)),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _ActionTile(icon: Icons.garage_outlined, label: 'Vehicles', onTap: () => context.push(AppRoutes.vehicles))),
        const SizedBox(width: 10),
        Expanded(child: _ActionTile(icon: Icons.payments_outlined, label: 'Payments', onTap: () => context.push(AppRoutes.payments))),
        const SizedBox(width: 10),
        Expanded(child: _ActionTile(icon: Icons.map_outlined, label: 'Tracking', onTap: () => context.push(AppRoutes.tracking))),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon),
            const SizedBox(height: 8),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _TripPreviewCard extends StatelessWidget {
  const _TripPreviewCard({required this.title, required this.subtitle, required this.icon});

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
      ),
    );
  }
}

class _RouteTile extends StatelessWidget {
  const _RouteTile({required this.origin, required this.destination, required this.price});

  final String origin;
  final String destination;
  final String price;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.route),
        title: Text('$origin to $destination'),
        subtitle: const Text('Often available during commute hours'),
        trailing: Text(price, style: Theme.of(context).textTheme.labelLarge),
      ),
    );
  }
}
