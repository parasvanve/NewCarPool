enum BookingStatus {
  pending(0, 'Pending'),
  accepted(1, 'Accepted'),
  rejected(2, 'Rejected'),
  cancelled(3, 'Cancelled'),
  completed(4, 'Completed');

  const BookingStatus(this.code, this.label);
  final int code;
  final String label;

  static BookingStatus fromCode(int code) {
    return BookingStatus.values.firstWhere(
      (status) => status.code == code,
      orElse: () => BookingStatus.pending,
    );
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
  });

  final String id;
  final String rideOfferId;
  final String passengerId;
  final String passengerName;
  final int seatsBooked;
  final int status;
  final DateTime createdAtUtc;
  BookingStatus get bookingStatus => BookingStatus.fromCode(status);

  factory RideBooking.fromJson(Map<String, dynamic> json) => RideBooking(
        id: json['id']?.toString() ?? '',
        rideOfferId: json['rideOfferId']?.toString() ?? '',
        passengerId: json['passengerId']?.toString() ?? '',
        passengerName: json['passengerName']?.toString() ?? '',
        seatsBooked: (json['seatsBooked'] as num?)?.toInt() ?? 0,
        status: (json['status'] as num?)?.toInt() ?? 0,
        createdAtUtc: DateTime.tryParse(json['createdAtUtc']?.toString() ?? '') ?? DateTime.now().toUtc(),
      );
}
