import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/app_design_system.dart';
import '../../models/ride_models.dart';
import '../../providers/ride_provider.dart';
import 'ride_details_screen.dart';

enum RideSort { nearby, cheapest, soonest }

class RideResultsScreen extends StatefulWidget {
  const RideResultsScreen({super.key, required this.pickup, required this.destination});

  final String pickup;
  final String destination;

  @override
  State<RideResultsScreen> createState() => _RideResultsScreenState();
}

class _RideResultsScreenState extends State<RideResultsScreen> {
  RideSort _sort = RideSort.nearby;
  int _maxPrice = 2000;
  int _minSeats = 1;

  @override
  void initState() {
    super.initState();
    context.read<RideProvider>().startAutoRefresh(interval: const Duration(seconds: 8));
  }

  @override
  void dispose() {
    context.read<RideProvider>().stopAutoRefresh();
    super.dispose();
  }

  List<RideOffer> _visibleRides(List<RideOffer> rides) {
    final filtered = rides.where((r) => r.availableSeats >= _minSeats && r.pricePerSeat <= _maxPrice).toList();
    switch (_sort) {
      case RideSort.cheapest:
        filtered.sort((a, b) => a.pricePerSeat.compareTo(b.pricePerSeat));
        break;
      case RideSort.soonest:
        filtered.sort((a, b) => a.departureTimeUtc.compareTo(b.departureTimeUtc));
        break;
      case RideSort.nearby:
        filtered.sort((a, b) => b.availableSeats.compareTo(a.availableSeats));
        break;
    }
    return filtered;
  }

  String _sortLabel(RideSort sort) {
    switch (sort) {
      case RideSort.nearby:
        return 'Nearby';
      case RideSort.cheapest:
        return 'Cheapest';
      case RideSort.soonest:
        return 'Soonest';
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RideProvider>();
    final rides = _visibleRides(provider.rides);
    return Scaffold(
      backgroundColor: AppDesignTokens.pageBg,
      appBar: AppBar(title: const Text('Ride Results')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: AppGradientHeroCard(
              title: '${provider.rides.length} Rides Found',
              subtitle: '${widget.pickup} -> ${widget.destination}',
              icon: Icons.route,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: RideSort.values
                          .map(
                            (sort) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(_sortLabel(sort)),
                                selected: _sort == sort,
                                onSelected: (_) => setState(() => _sort = sort),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
                IconButton.filledTonal(onPressed: _openFilters, icon: const Icon(Icons.tune)),
              ],
            ),
          ),
          Expanded(
            child: provider.isLoading
                ? const _LoadingList()
                : rides.isEmpty
                    ? _EmptyState(onRetry: () => Navigator.of(context).pop())
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                        itemCount: rides.length,
                        itemBuilder: (context, index) {
                          final ride = rides[index];
                          return _RideCard(
                            ride: ride,
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RideDetailsScreen(extra: ride))),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<(int, int)>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        var tempMaxPrice = _maxPrice.toDouble();
        var tempMinSeats = _minSeats.toDouble();
        return StatefulBuilder(
          builder: (context, setSheetState) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Filters', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Text('Max price per seat: INR ${tempMaxPrice.toInt()}'),
                Slider(min: 100, max: 3000, divisions: 29, value: tempMaxPrice, onChanged: (v) => setSheetState(() => tempMaxPrice = v)),
                Text('Minimum seats: ${tempMinSeats.toInt()}'),
                Slider(min: 1, max: 6, divisions: 5, value: tempMinSeats, onChanged: (v) => setSheetState(() => tempMinSeats = v)),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, (tempMaxPrice.toInt(), tempMinSeats.toInt())),
                    child: const Text('Apply Filters'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result != null) {
      setState(() {
        _maxPrice = result.$1;
        _minSeats = result.$2;
      });
    }
  }
}

class _RideCard extends StatelessWidget {
  const _RideCard({required this.ride, required this.onTap});

  final RideOffer ride;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: const Color(0xFFDCFCE7),
                    child: Text((ride.driverName.isEmpty ? 'D' : ride.driverName[0]).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF166534))),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ride.driverName.isEmpty ? 'Driver' : ride.driverName, style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(DateFormat('dd MMM, hh:mm a').format(ride.departureTimeUtc.toLocal()), style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  Text('INR ${ride.pricePerSeat}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppDesignTokens.brandStart)),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12)),
                child: Text('${ride.origin.name} -> ${ride.destination.name}', maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
              if (ride.intermediateStops.isNotEmpty) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(spacing: 6, runSpacing: 6, children: ride.intermediateStops.take(3).map((s) => Chip(label: Text(s.name))).toList()),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Chip(label: Text('${ride.availableSeats} seats'), avatar: const Icon(Icons.event_seat, size: 16)),
                  const SizedBox(width: 8),
                  Chip(label: Text('${ride.participantCount} joined'), avatar: const Icon(Icons.group_outlined, size: 16)),
                  const Spacer(),
                  Text(
                    ride.availableSeats <= 0 ? 'Ride Full' : 'Open',
                    style: TextStyle(color: ride.availableSeats <= 0 ? Colors.red : Colors.green, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      itemCount: 5,
      itemBuilder: (_, __) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: const Padding(
          padding: EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSkeletonBox(height: 18, width: 160),
              SizedBox(height: 10),
              AppSkeletonBox(height: 14, width: 220),
              SizedBox(height: 12),
              AppSkeletonBox(height: 46),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.route_outlined, size: 56, color: Colors.grey),
            const SizedBox(height: 10),
            const Text('No rides found for this route.', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const Text('Try changing seats, date, or destination.', textAlign: TextAlign.center),
            const SizedBox(height: 14),
            OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.arrow_back), label: const Text('Back to Search')),
          ],
        ),
      ),
    );
  }
}
