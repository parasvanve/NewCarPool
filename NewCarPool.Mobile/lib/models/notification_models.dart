class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.typeCode,
    required this.rideId,
    required this.bookingId,
    required this.isRead,
    required this.createdAtUtc,
  });

  final String id;
  final String title;
  final String message;
  final int typeCode;
  final String? rideId;
  final String? bookingId;
  final bool isRead;
  final DateTime createdAtUtc;

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        message: json['message']?.toString() ?? '',
        typeCode: (json['type'] as num?)?.toInt() ?? 5,
        rideId: json['rideId']?.toString(),
        bookingId: json['bookingId']?.toString(),
        isRead: json['isRead'] == true,
        createdAtUtc: DateTime.tryParse(json['createdAtUtc']?.toString() ?? '') ?? DateTime.now().toUtc(),
      );
}
