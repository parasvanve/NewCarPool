// import 'package:flutter/material.dart';
// import 'package:go_router/go_router.dart';
// import 'package:intl/intl.dart';
// import 'package:provider/provider.dart';

// import '../../core/constants/app_routes.dart';
// import '../../core/errors/app_exception.dart';
// import '../../core/network/token_store.dart';
// import '../../core/routing/pending_ride_redirect.dart';
// import '../../core/widgets/app_snack_bar.dart';
// import '../../models/ride_models.dart';
// import '../../services/auth_service.dart';
// import '../../services/ride_service.dart';

// class SharedRidePreviewScreen extends StatefulWidget {
//   const SharedRidePreviewScreen({super.key, required this.rideId});

//   final String rideId;

//   @override
//   State<SharedRidePreviewScreen> createState() =>
//       _SharedRidePreviewScreenState();
// }

// class _SharedRidePreviewScreenState extends State<SharedRidePreviewScreen> {
//   RidePublicSummary? _ride;
//   String? _loadError;
//   bool _bookingInProgress = false;

//   @override
//   void initState() {
//     super.initState();
//     _load();
//   }

//   Future<void> _load() async {
//     try {
//       final ride =
//           await context.read<RideService>().publicDetails(widget.rideId);
//       if (!mounted) return;
//       setState(() => _ride = ride);
//     } on Object catch (error) {
//       if (!mounted) return;
//       setState(() => _loadError = error is AppException
//           ? error.message
//           : 'This ride link is no longer valid.');
//     }
//   }

//   Future<void> _onBookRidePressed() async {
//     setState(() => _bookingInProgress = true);
//     try {
//       final tokenStore = context.read<TokenStore>();
//       final token = await tokenStore.accessToken;

//       if (token != null) {
//         final fullRide =
//             await context.read<RideService>().details(widget.rideId);
//         if (!mounted) return;
//         context.push(AppRoutes.booking, extra: fullRide);
//         return;
//       }

//       if (!mounted) return;
//       final email = await _promptForEmail();
//       if (email == null || email.trim().isEmpty) return;

//       final exists =
//           await context.read<AuthService>().emailExists(email.trim());
//       if (!mounted) return;

//       PendingRideRedirect.set(widget.rideId);
//       context.push(exists ? AppRoutes.login : AppRoutes.register);
//     } on Object catch (error) {
//       if (!mounted) return;
//       AppSnackBar.showError(
//           context,
//           error is AppException
//               ? error.message
//               : 'Something went wrong. Please try again.');
//     } finally {
//       if (mounted) setState(() => _bookingInProgress = false);
//     }
//   }

//   Future<String?> _promptForEmail() async {
//     final controller = TextEditingController();
//     return showDialog<String>(
//       context: context,
//       builder: (dialogContext) => AlertDialog(
//         title: const Text('Enter your email to continue'),
//         content: TextField(
//           controller: controller,
//           keyboardType: TextInputType.emailAddress,
//           autofocus: true,
//           decoration: const InputDecoration(hintText: 'you@example.com'),
//         ),
//         actions: [
//           TextButton(
//               onPressed: () => Navigator.pop(dialogContext),
//               child: const Text('Cancel')),
//           FilledButton(
//             onPressed: () => Navigator.pop(dialogContext, controller.text),
//             child: const Text('Continue'),
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Ride Details')),
//       body: _loadError != null
//           ? Center(
//               child: Padding(
//                   padding: const EdgeInsets.all(24), child: Text(_loadError!)))
//           : _ride == null
//               ? const Center(child: CircularProgressIndicator())
//               : _buildContent(_ride!),
//     );
//   }

//   Widget _buildContent(RidePublicSummary ride) {
//     return ListView(
//       padding: const EdgeInsets.all(16),
//       children: [
//         Card(
//           child: Padding(
//             padding: const EdgeInsets.all(16),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(ride.driverName,
//                     style: Theme.of(context).textTheme.titleLarge),
//                 const SizedBox(height: 12),
//                 _RouteRow(
//                     icon: Icons.trip_origin,
//                     label: 'From',
//                     value: ride.origin.name),
//                 const SizedBox(height: 6),
//                 _RouteRow(
//                     icon: Icons.place,
//                     label: 'To',
//                     value: ride.destination.name),
//                 const SizedBox(height: 12),
//                 Text(
//                     'Departs ${DateFormat('dd MMM yyyy, hh:mm a').format(ride.departureTimeUtc.toLocal())}'),
//                 const SizedBox(height: 4),
//                 Text(
//                     '${ride.availableSeats} seats available • ₹${ride.pricePerSeat} per seat'),
//                 if (ride.vehicleName != null) ...[
//                   const SizedBox(height: 4),
//                   Text('${ride.vehicleName} ${ride.vehicleNumber ?? ''}'),
//                 ],
//               ],
//             ),
//           ),
//         ),
//         const SizedBox(height: 24),
//         FilledButton(
//           onPressed: _bookingInProgress ? null : _onBookRidePressed,
//           child: _bookingInProgress
//               ? const SizedBox(
//                   height: 18,
//                   width: 18,
//                   child: CircularProgressIndicator(strokeWidth: 2))
//               : const Text('Book Ride'),
//         ),
//       ],
//     );
//   }
// }

// class _RouteRow extends StatelessWidget {
//   const _RouteRow(
//       {required this.icon, required this.label, required this.value});

//   final IconData icon;
//   final String label;
//   final String value;

//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       children: [
//         Icon(icon, size: 18),
//         const SizedBox(width: 8),
//         Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
//         Expanded(child: Text(value, overflow: TextOverflow.ellipsis)),
//       ],
//     );
//   }
// }

//new code i
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/errors/app_exception.dart';
import '../../models/ride_models.dart';
import '../../services/ride_service.dart';
import 'booking_flow_screen.dart';

class SharedRidePreviewScreen extends StatefulWidget {
  const SharedRidePreviewScreen({super.key, required this.rideId});

  final String rideId;

  @override
  State<SharedRidePreviewScreen> createState() =>
      _SharedRidePreviewScreenState();
}

class _SharedRidePreviewScreenState extends State<SharedRidePreviewScreen> {
  RideOffer? _rideShim;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final publicRide =
          await context.read<RideService>().publicDetails(widget.rideId);
      if (!mounted) return;
      setState(() => _rideShim = _toRideOfferShim(publicRide));
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _loadError = error is AppException
          ? error.message
          : 'This ride link is no longer valid.');
    }
  }

  RideOffer _toRideOfferShim(RidePublicSummary p) => RideOffer(
        id: p.id,
        driverId: '',
        driverName: p.driverName,
        origin: p.origin,
        destination: p.destination,
        intermediateStops: p.intermediateStops,
        departureTimeUtc: p.departureTimeUtc,
        availableSeats: p.availableSeats,
        participantCount: p.participantCount,
        pricePerSeat: p.pricePerSeat,
        vehicleName: p.vehicleName,
        vehicleNumber: p.vehicleNumber,
        status: p.status,
      );

  @override
  Widget build(BuildContext context) {
    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ride Details')),
        body: Center(
            child: Padding(
                padding: const EdgeInsets.all(24), child: Text(_loadError!))),
      );
    }
    if (_rideShim == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    // return BookingFlowScreen(extra: _rideShim);
    return BookingFlowScreen(extra: _rideShim, cameFromSharedLink: true);
  }
}
