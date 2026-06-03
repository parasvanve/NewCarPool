import '../core/utils/app_date_formatter.dart';

enum RideChatMessageType {
  text,
  image,
  file;

  static RideChatMessageType fromJson(Object? value) {
    if (value is int) {
      return switch (value) {
        1 => RideChatMessageType.image,
        2 => RideChatMessageType.file,
        _ => RideChatMessageType.text,
      };
    }

    final text = value?.toString().toLowerCase() ?? '';
    return switch (text) {
      'image' => RideChatMessageType.image,
      'file' => RideChatMessageType.file,
      _ => RideChatMessageType.text,
    };
  }
}

class RideChatMessage {
  const RideChatMessage({
    required this.id,
    required this.rideChatGroupId,
    required this.senderUserId,
    required this.senderName,
    required this.message,
    required this.createdAtUtc,
    required this.messageType,
    this.attachmentUrl,
    this.attachmentFileName,
    this.attachmentContentType,
    this.attachmentSizeBytes,
  });

  final String id;
  final String rideChatGroupId;
  final String senderUserId;
  final String senderName;
  final String message;
  final DateTime createdAtUtc;
  final RideChatMessageType messageType;
  final String? attachmentUrl;
  final String? attachmentFileName;
  final String? attachmentContentType;
  final int? attachmentSizeBytes;

  factory RideChatMessage.fromJson(Map<String, dynamic> json) =>
      RideChatMessage(
        id: json['id']?.toString() ?? '',
        rideChatGroupId:
            (json['rideChatGroupId'] ?? json['rideOfferId'])?.toString() ?? '',
        senderUserId: json['senderUserId']?.toString() ?? '',
        senderName: json['senderName']?.toString() ?? 'User',
        message: json['message']?.toString() ?? '',
        createdAtUtc:
            parseUtcToLocal(json['createdAtUtc']?.toString() ?? '').toUtc(),
        messageType: RideChatMessageType.fromJson(json['messageType']),
        attachmentUrl: json['attachmentUrl']?.toString(),
        attachmentFileName: json['attachmentFileName']?.toString(),
        attachmentContentType: json['attachmentContentType']?.toString(),
        attachmentSizeBytes: _intOrNull(json['attachmentSizeBytes']),
      );
}

int? _intOrNull(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}
