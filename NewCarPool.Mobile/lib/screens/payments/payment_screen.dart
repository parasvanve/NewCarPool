import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/booking_provider.dart';
import '../../providers/payment_provider.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _amountController = TextEditingController();
  final _transactionIdController = TextEditingController();
  String? _selectedBookingId;
  int _paymentMethod = 1;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrap();
    });
  }

  Future<void> _bootstrap() async {
    final bookingProvider = context.read<BookingProvider>();
    final paymentProvider = context.read<PaymentProvider>();

    await bookingProvider.loadHistory();
    if (!mounted) return;
    if (_selectedBookingId == null && bookingProvider.bookings.isNotEmpty) {
      setState(() => _selectedBookingId = bookingProvider.bookings.first.id);
    }

    await paymentProvider.loadHistory();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _transactionIdController.dispose();
    super.dispose();
  }

  Future<void> _createPayment() async {
    final bookingId = _selectedBookingId;
    final transactionId = _transactionIdController.text.trim();
    final amount = double.tryParse(_amountController.text.trim());

    if (bookingId == null || bookingId.isEmpty || transactionId.isEmpty || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select booking and enter valid amount/transaction ID.')),
      );
      return;
    }

    final paymentProvider = context.read<PaymentProvider>();

    setState(() => _submitting = true);
    try {
      await paymentProvider.create(
        bookingId: bookingId,
        amount: amount,
        transactionId: transactionId,
        paymentMethod: _paymentMethod,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment created successfully.')),
      );
      _amountController.clear();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final paymentProvider = context.watch<PaymentProvider>();
    final bookingProvider = context.watch<BookingProvider>();

    final bookings = bookingProvider.bookings;

    return Scaffold(
      appBar: AppBar(title: const Text('Payments')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Create Payment', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            key: ValueKey('booking-${_selectedBookingId ?? ''}-${bookings.length}'),
            initialValue: _selectedBookingId,
            decoration: const InputDecoration(labelText: 'Booking', border: OutlineInputBorder()),
            items: bookings
                .map((b) => DropdownMenuItem<String>(
                      value: b.id,
                      child: Text('Booking ${b.id.substring(0, 8)} | Seats ${b.seatsBooked}'),
                    ))
                .toList(),
            onChanged: (value) => setState(() => _selectedBookingId = value),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Amount', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _transactionIdController,
            decoration: const InputDecoration(labelText: 'Transaction ID', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            key: ValueKey('method-$_paymentMethod'),
            initialValue: _paymentMethod,
            decoration: const InputDecoration(labelText: 'Payment Method', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 1, child: Text('UPI')),
              DropdownMenuItem(value: 2, child: Text('Card')),
              DropdownMenuItem(value: 3, child: Text('Cash')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _paymentMethod = value);
            },
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _submitting ? null : _createPayment,
            child: Text(_submitting ? 'Processing...' : 'Create Payment'),
          ),
          const SizedBox(height: 20),
          Text('Payment History', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (paymentProvider.isLoading && paymentProvider.payments.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
          else if (paymentProvider.payments.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text('No payments yet.'),
            )
          else
            ...paymentProvider.payments.map(
              (payment) => Card(
                child: ListTile(
                  leading: const Icon(Icons.receipt_long),
                  title: Text('INR ${payment.amount.toStringAsFixed(2)}'),
                  subtitle: Text('Txn: ${payment.transactionId}\nBooking: ${payment.bookingId.substring(0, 8)}'),
                  isThreeLine: true,
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Chip(
                        label: Text(payment.isVerified ? 'Verified' : 'Pending'),
                        backgroundColor: payment.isVerified ? Colors.green.shade100 : Colors.orange.shade100,
                      ),
                      if (!payment.isVerified)
                        TextButton(
                          onPressed: () => context.read<PaymentProvider>().verify(payment.transactionId),
                          child: const Text('Verify'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
