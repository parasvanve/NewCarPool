import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../core/errors/app_exception.dart';
import '../../core/utils/location_display_formatter.dart';
import '../../models/ride_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../providers/ride_provider.dart';
import '../../services/map_service.dart';

class BookingFlowScreen extends StatefulWidget {
  const BookingFlowScreen({super.key, this.extra});

  final Object? extra;

  @override
  State<BookingFlowScreen> createState() => _BookingFlowScreenState();
}

class _BookingFlowScreenState extends State<BookingFlowScreen> {
  int _seats = 1;
  bool _submitting = false;
  GeoPoint? _pickupPoint;
  GeoPoint? _dropPoint;

  Future<void> _pickPickupFromSearch() async {
    final selected = await _openSearchSheet(title: 'Select Boarding Point');
    if (selected == null || !mounted) return;
    setState(() => _pickupPoint = selected);
  }

  Future<GeoPoint?> _openSearchSheet({required String title}) {
    final searchCtrl = TextEditingController();
    final suggestions = <Map<String, dynamic>>[];
    bool loading = false;
    String? error;

    return showModalBottomSheet<GeoPoint>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setInnerState) {
            Future<void> search(String value) async {
              final q = value.trim();
              if (q.length < 3) {
                setInnerState(() {
                  suggestions.clear();
                  error = null;
                });
                return;
              }
              setInnerState(() {
                loading = true;
                error = null;
              });
              try {
                final results = await context.read<MapService>().geocode(q);
                final mapped = results
                    .take(10)
                    .map((e) => LocationDisplayFormatter.fromSearchSuggestion(
                        Map<String, dynamic>.from(e as Map)))
                    .toList(growable: false);
                setInnerState(() {
                  suggestions
                    ..clear()
                    ..addAll(mapped);
                });
              } catch (_) {
                setInnerState(() => error = 'Failed to load suggestions.');
              } finally {
                setInnerState(() => loading = false);
              }
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                14,
                16,
                MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  TextField(
                    controller: searchCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Search location',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: search,
                  ),
                  const SizedBox(height: 8),
                  if (loading) const LinearProgressIndicator(),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(error!, style: const TextStyle(color: Colors.red)),
                    ),
                  if (suggestions.isNotEmpty)
                    SizedBox(
                      height: 280,
                      child: ListView.builder(
                        itemCount: suggestions.length,
                        itemBuilder: (_, i) {
                          final item = suggestions[i];
                          return ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            leading: const Icon(Icons.place_outlined),
                            title: Text(
                              LocationDisplayFormatter.title(item),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              LocationDisplayFormatter.subtitle(item),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () {
                              Navigator.pop(
                                context,
                                GeoPoint(
                                  name: LocationDisplayFormatter.title(item),
                                  address: item['formattedAddress']?.toString() ??
                                      item['displayName']?.toString(),
                                  latitude: (item['latitude'] as num).toDouble(),
                                  longitude: (item['longitude'] as num).toDouble(),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _useCurrentLocation() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        _showError('Location services are disabled.');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        _showError('Location permission denied.');
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _pickupPoint = GeoPoint(
          name: 'Current location',
          address: 'Current location',
          latitude: position.latitude,
          longitude: position.longitude,
        );
      });
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ride = widget.extra is RideOffer ? widget.extra as RideOffer : null;
    final myUserId = context.watch<AuthProvider>().session?.userId;
    final isMyRide = ride != null && myUserId != null && myUserId == ride.driverId;

    if (ride == null) {
      return const Scaffold(
        body: Center(child: Text('Ride details unavailable for booking.')),
      );
    }

    if (isMyRide) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'You are the driver of this ride. Booking is disabled.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final routePoints = <GeoPoint>[
      ride.origin,
      ...ride.intermediateStops.map(
        (s) => GeoPoint(
          name: s.name,
          address: s.address,
          latitude: s.latitude,
          longitude: s.longitude,
        ),
      ),
      ride.destination,
    ];

    final dropOptions = <GeoPoint>[
      ...ride.intermediateStops.map(
        (s) => GeoPoint(
          name: s.name,
          address: s.address,
          latitude: s.latitude,
          longitude: s.longitude,
        ),
      ),
      ride.destination,
    ];

    final total = (ride.pricePerSeat * _seats).toStringAsFixed(2);

    return Scaffold(
      appBar: AppBar(title: const Text('Confirm Booking')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    LocationDisplayFormatter.routeTitle(
                      ride.origin,
                      ride.destination,
                    ),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text('Driver: ${ride.driverName.isEmpty ? 'Driver' : ride.driverName}'),
                  const SizedBox(height: 2),
                  Text('Available seats: ${ride.availableSeats}'),
                  const SizedBox(height: 2),
                  Text('Price per seat: INR ${ride.pricePerSeat}'),
                  const SizedBox(height: 2),
                  Text(
                    'Vehicle: ${ride.vehicleName ?? 'Vehicle'} ${ride.vehicleNumber ?? ''}'.trim(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Boarding / Pickup Point', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  if (_pickupPoint != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_pickupPoint!.name),
                          Text(
                            LocationDisplayFormatter.compactAddress(_pickupPoint),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _useCurrentLocation,
                        icon: const Icon(Icons.my_location),
                        label: const Text('Use Current Location'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _pickPickupFromSearch,
                        icon: const Icon(Icons.search),
                        label: const Text('Search Location'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('Or select from route stops'),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: routePoints
                        .map(
                          (p) => ChoiceChip(
                            label: Text(p.name),
                            selected: _pickupPoint?.name == p.name && _pickupPoint?.latitude == p.latitude,
                            onSelected: (_) => setState(() => _pickupPoint = p),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Drop Point', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _dropPoint == null ? null : '${_dropPoint!.name}|${_dropPoint!.latitude}|${_dropPoint!.longitude}',
                    hint: const Text('Select drop point'),
                    items: dropOptions
                        .map(
                          (p) => DropdownMenuItem<String>(
                            value: '${p.name}|${p.latitude}|${p.longitude}',
                            child: Text(p.name, overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      final point = dropOptions.firstWhere(
                        (p) => '${p.name}|${p.latitude}|${p.longitude}' == value,
                      );
                      setState(() => _dropPoint = point);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Seats', style: TextStyle(fontWeight: FontWeight.w700)),
                  Row(
                    children: [
                      IconButton(
                        onPressed: _seats > 1 ? () => setState(() => _seats--) : null,
                        icon: const Icon(Icons.remove),
                      ),
                      Text('$_seats', style: const TextStyle(fontWeight: FontWeight.w700)),
                      IconButton(
                        onPressed: _seats < ride.availableSeats ? () => setState(() => _seats++) : null,
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text('Total: INR $total', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _submitting
                ? null
                : () async {
                    if (_pickupPoint == null) {
                      _showError('Pickup point is required');
                      return;
                    }
                    if (_dropPoint == null) {
                      _showError('Drop point is required');
                      return;
                    }
                    if (_seats < 1) {
                      _showError('Select at least 1 seat');
                      return;
                    }
                    if (_seats > ride.availableSeats) {
                      _showError('Selected seats exceed available seats');
                      return;
                    }

                    final bookingProvider = context.read<BookingProvider>();
                    final messenger = ScaffoldMessenger.of(context);
                    final navigator = Navigator.of(context);
                    setState(() => _submitting = true);
                    try {
                      await bookingProvider.request(
                        rideOfferId: ride.id,
                        seatsBooked: _seats,
                        pickup: _pickupPoint,
                        drop: _dropPoint,
                      );
                      if (!mounted) return;
                      await context.read<RideProvider>().loadUpcomingActive();
                      await context.read<BookingProvider>().loadHistory();
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Ride booked successfully')),
                      );
                      navigator.pop(true);
                    } on DioException catch (error) {
                      if (!mounted) return;
                      final message = AppException.fromDio(error).message;
                      messenger.showSnackBar(
                        SnackBar(content: Text(message), backgroundColor: Colors.red),
                      );
                    } catch (error) {
                      if (!mounted) return;
                      messenger.showSnackBar(
                        SnackBar(content: Text(error.toString()), backgroundColor: Colors.red),
                      );
                    } finally {
                      if (mounted) setState(() => _submitting = false);
                    }
                  },
            child: Text(_submitting ? 'Booking...' : 'Confirm Booking'),
          ),
        ],
      ),
    );
  }
}
