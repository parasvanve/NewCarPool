import 'ride_models.dart';

enum BookingStatus {
  pending(1, 'Pending'),
  accepted(2, 'Booked'),
  rejected(4, 'Rejected'),
  cancelled(3, 'Cancelled'),
  completed(5, 'Completed');

  const BookingStatus(this.code, this.label);
  final int code;
  final String label;

  static BookingStatus fromCode(int code) {
    return switch (code) {
      2 => BookingStatus.accepted, // backend Confirmed
      3 => BookingStatus.cancelled,
      4 => BookingStatus.rejected,
      5 => BookingStatus.completed,
      1 || 0 => BookingStatus.pending, // include legacy 0 mapping
      _ => BookingStatus.pending,
    };
  }
}

class RideBooking {
  const RideBooking({
    required this.id,
    required this.rideOfferId,
    required this.passengerId,
    required this.passengerName,
    required this.seatsBooked,
    required this.status,
    required this.createdAtUtc,
    this.passengerPickup,
    this.passengerDrop,
  });

  final String id;
  final String rideOfferId;
  final String passengerId;
  final String passengerName;
  final int seatsBooked;
  final int status;
  final DateTime createdAtUtc;
  final GeoPoint? passengerPickup;
  final GeoPoint? passengerDrop;
  BookingStatus get bookingStatus => BookingStatus.fromCode(status);

  factory RideBooking.fromJson(Map<String, dynamic> json) => RideBooking(
        id: json['id']?.toString() ?? '',
        rideOfferId: json['rideOfferId']?.toString() ?? '',
        passengerId: json['passengerId']?.toString() ?? '',
        passengerName: json['passengerName']?.toString() ?? '',
        seatsBooked: (json['seatsBooked'] as num?)?.toInt() ?? 0,
        status: (json['status'] as num?)?.toInt() ?? 0,
        createdAtUtc: DateTime.tryParse(json['createdAtUtc']?.toString() ?? '') ?? DateTime.now().toUtc(),
        passengerPickup: _pointFromJson(
          raw: json['passengerPickup'] ?? json['pickup'],
          name: json['passengerPickupName'],
          address: json['passengerPickupAddress'],
          latitude: json['passengerPickupLatitude'],
          longitude: json['passengerPickupLongitude'],
        ),
        passengerDrop: _pointFromJson(
          raw: json['passengerDrop'] ?? json['drop'],
          name: json['passengerDropName'],
          address: json['passengerDropAddress'],
          latitude: json['passengerDropLatitude'],
          longitude: json['passengerDropLongitude'],
        ),
      );

  static GeoPoint? _pointFromJson({
    required dynamic raw,
    required dynamic name,
    required dynamic address,
    required dynamic latitude,
    required dynamic longitude,
  }) {
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      if (map['latitude'] != null && map['longitude'] != null) {
        return GeoPoint(
          name: map['name']?.toString() ?? 'Point',
          address: map['address']?.toString(),
          latitude: (map['latitude'] as num).toDouble(),
          longitude: (map['longitude'] as num).toDouble(),
        );
      }
    }

    if (latitude != null && longitude != null) {
      final latNum = latitude is num ? latitude : num.tryParse(latitude.toString());
      final lngNum = longitude is num ? longitude : num.tryParse(longitude.toString());
      if (latNum != null && lngNum != null) {
        return GeoPoint(
          name: name?.toString() ?? 'Point',
          address: address?.toString(),
          latitude: latNum.toDouble(),
          longitude: lngNum.toDouble(),
        );
      }
    }
    return null;
  }
}
