import 'package:latlong2/latlong.dart';
import '../core/utils/departure_time_utils.dart';

class GeoPoint {
  const GeoPoint({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.address,
  });

  final String name;
  final double latitude;
  final double longitude;
  final String? address;

  LatLng get latLng => LatLng(latitude, longitude);

  Map<String, dynamic> toJson() => {
        'name': name,
        if (address != null && address!.trim().isNotEmpty) 'address': address,
        'latitude': latitude,
        'longitude': longitude,
      };

  factory GeoPoint.fromJson(Map<String, dynamic> json) => GeoPoint(
        name: json['name'],
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        address: json['address']?.toString(),
      );
}

class RideOffer {
  RideOffer({
    required this.id,
    required this.driverId,
    required this.driverName,
    required this.origin,
    required this.destination,
    this.intermediateStops = const [],
    required this.departureTimeUtc,
    required this.availableSeats,
    this.participantCount = 0,
    required this.pricePerSeat,
    this.notes,
    this.vehicleName,
    this.vehicleNumber,
    this.cancelledAtUtc,
    this.cancellationReason,
    required this.status,
  });

  final String id;
  final String driverId;
  final String driverName;
  final GeoPoint origin;
  final GeoPoint destination;
  final List<RideStop> intermediateStops;
  final DateTime departureTimeUtc;
  final int availableSeats;
  final int participantCount;
  final num pricePerSeat;
  final String? notes;
  final String? vehicleName;
  final String? vehicleNumber;
  final DateTime? cancelledAtUtc;
  final String? cancellationReason;
  final int status;

  factory RideOffer.fromJson(Map<String, dynamic> json) => RideOffer(
        id: json['id'],
        driverId: json['driverId']?.toString() ?? '',
        driverName: json['driverName'] ?? '',
        origin: GeoPoint.fromJson(json['origin']),
        destination: GeoPoint.fromJson(json['destination']),
        intermediateStops: ((json['intermediateStops'] ?? json['dropPoints']) as List<dynamic>? ?? const [])
            .map((x) => RideStop.fromJson(Map<String, dynamic>.from(x as Map)))
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order)),
        departureTimeUtc: DepartureTimeUtils.parseUtcFromBackend(
          json['departureTimeUtc'],
          context: 'RideOffer.fromJson',
        ),
        availableSeats: json['availableSeats'],
        participantCount: (json['participantCount'] as num?)?.toInt() ?? 0,
        pricePerSeat: json['pricePerSeat'],
        notes: json['notes']?.toString(),
        vehicleName: json['vehicleName']?.toString(),
        vehicleNumber: json['vehicleNumber']?.toString(),
        cancelledAtUtc: DateTime.tryParse(json['cancelledAtUtc']?.toString() ?? ''),
        cancellationReason: json['cancellationReason']?.toString(),
        status: json['status'],
      );
}

class RideStop {
  const RideStop({
    required this.name,
    this.address,
    required this.latitude,
    required this.longitude,
    required this.order,
  });

  final String name;
  final String? address;
  final double latitude;
  final double longitude;
  final int order;

  LatLng get latLng => LatLng(latitude, longitude);

  Map<String, dynamic> toJson() => {
        'name': name,
        if (address != null && address!.trim().isNotEmpty) 'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'order': order,
      };

  factory RideStop.fromJson(Map<String, dynamic> json) => RideStop(
        name: json['name']?.toString() ?? 'Stop',
        address: json['address']?.toString(),
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        order: (json['order'] as num? ?? json['stopOrder'] as num?)?.toInt() ?? 0,
      );
}
