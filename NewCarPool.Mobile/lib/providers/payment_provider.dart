import 'package:flutter/foundation.dart';

import '../models/payment_models.dart';
import '../services/payment_service.dart';

class PaymentProvider extends ChangeNotifier {
  PaymentProvider(this._paymentService);

  final PaymentService _paymentService;

  List<PaymentRecord> payments = [];
  bool isLoading = false;
  String? errorMessage;

  Future<void> loadHistory() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      payments = await _paymentService.history();
    } catch (error) {
      errorMessage = error.toString();
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<PaymentRecord> create({
    required String bookingId,
    required double amount,
    required String transactionId,
    required int paymentMethod,
  }) async {
    final payment = await _paymentService.create(
      bookingId: bookingId,
      amount: amount,
      transactionId: transactionId,
      paymentMethod: paymentMethod,
    );
    payments = [payment, ...payments];
    notifyListeners();
    return payment;
  }

  Future<PaymentRecord> verify(String transactionId) async {
    final verified = await _paymentService.verify(transactionId);
    final index = payments.indexWhere((x) => x.id == verified.id);
    if (index >= 0) {
      payments[index] = verified;
    } else {
      payments = [verified, ...payments];
    }
    notifyListeners();
    return verified;
  }
}
