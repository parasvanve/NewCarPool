class RideChatMessage {
  const RideChatMessage({
    required this.id,
    required this.rideOfferId,
    required this.senderUserId,
    required this.senderName,
    required this.message,
    required this.createdAtUtc,
  });

  final String id;
  final String rideOfferId;
  final String senderUserId;
  final String senderName;
  final String message;
  final DateTime createdAtUtc;

  factory RideChatMessage.fromJson(Map<String, dynamic> json) => RideChatMessage(
        id: json['id']?.toString() ?? '',
        rideOfferId: json['rideOfferId']?.toString() ?? '',
        senderUserId: json['senderUserId']?.toString() ?? '',
        senderName: json['senderName']?.toString() ?? 'User',
        message: json['message']?.toString() ?? '',
        createdAtUtc: DateTime.tryParse(json['createdAtUtc']?.toString() ?? '') ?? DateTime.now().toUtc(),
      );
}
