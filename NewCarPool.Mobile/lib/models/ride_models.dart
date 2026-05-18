import 'package:latlong2/latlong.dart';

class GeoPoint {
  const GeoPoint({required this.name, required this.latitude, required this.longitude});

  final String name;
  final double latitude;
  final double longitude;

  LatLng get latLng => LatLng(latitude, longitude);

  Map<String, dynamic> toJson() => {
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
      };

  factory GeoPoint.fromJson(Map<String, dynamic> json) => GeoPoint(
        name: json['name'],
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
      );
}

class RideOffer {
  RideOffer({
    required this.id,
    required this.driverName,
    required this.origin,
    required this.destination,
    required this.departureTimeUtc,
    required this.availableSeats,
    required this.pricePerSeat,
    required this.status,
  });

  final String id;
  final String driverName;
  final GeoPoint origin;
  final GeoPoint destination;
  final DateTime departureTimeUtc;
  final int availableSeats;
  final num pricePerSeat;
  final int status;

  factory RideOffer.fromJson(Map<String, dynamic> json) => RideOffer(
        id: json['id'],
        driverName: json['driverName'] ?? '',
        origin: GeoPoint.fromJson(json['origin']),
        destination: GeoPoint.fromJson(json['destination']),
        departureTimeUtc: DateTime.parse(json['departureTimeUtc']),
        availableSeats: json['availableSeats'],
        pricePerSeat: json['pricePerSeat'],
        status: json['status'],
      );
}
