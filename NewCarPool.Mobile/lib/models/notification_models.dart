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
        createdAtUtc:
            DateTime.tryParse(json['createdAtUtc']?.toString() ?? '') ?? DateTime.now().toUtc(),
      );

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        title: title,
        message: message,
        typeCode: typeCode,
        rideId: rideId,
        bookingId: bookingId,
        isRead: isRead ?? this.isRead,
        createdAtUtc: createdAtUtc,
      );

  NotificationKind get kind {
    switch (typeCode) {
      case 1:
      case 6:
        return NotificationKind.booking;
      case 3:
        return NotificationKind.message;
      case 2:
      case 4:
      case 7:
      case 8:
        return NotificationKind.trip;
      case 9:
        return NotificationKind.system;
      default:
        final lower = title.toLowerCase();
        if (lower.contains('book')) return NotificationKind.booking;
        if (lower.contains('message') || lower.contains('chat')) return NotificationKind.message;
        if (lower.contains('ride') || lower.contains('trip')) return NotificationKind.trip;
        return NotificationKind.system;
    }
  }
}

enum NotificationKind { all, booking, trip, message, system }
