class PaymentRecord {
  const PaymentRecord({
    required this.id,
    required this.bookingId,
    required this.amount,
    required this.transactionId,
    required this.paymentStatus,
    required this.paymentMethod,
    required this.createdAtUtc,
  });

  final String id;
  final String bookingId;
  final double amount;
  final String transactionId;
  final int paymentStatus;
  final int paymentMethod;
  final DateTime createdAtUtc;

  bool get isVerified => paymentStatus == 2;

  factory PaymentRecord.fromJson(Map<String, dynamic> json) => PaymentRecord(
        id: json['id']?.toString() ?? '',
        bookingId: json['bookingId']?.toString() ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        transactionId: json['transactionId']?.toString() ?? '',
        paymentStatus: (json['paymentStatus'] as num?)?.toInt() ?? 0,
        paymentMethod: (json['paymentMethod'] as num?)?.toInt() ?? 0,
        createdAtUtc: DateTime.tryParse(json['createdAtUtc']?.toString() ?? '') ?? DateTime.now().toUtc(),
      );
}
