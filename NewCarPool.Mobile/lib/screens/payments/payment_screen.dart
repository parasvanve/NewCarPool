import 'package:flutter/material.dart';

class PaymentScreen extends StatelessWidget {
  const PaymentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payments')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          ListTile(leading: Icon(Icons.account_balance_wallet), title: Text('UPI'), subtitle: Text('Fast mobile payment')),
          ListTile(leading: Icon(Icons.credit_card), title: Text('Card'), subtitle: Text('Debit or credit card')),
          ListTile(leading: Icon(Icons.currency_rupee), title: Text('Cash'), subtitle: Text('Pay driver directly')),
          SizedBox(height: 20),
          FilledButton(onPressed: null, child: Text('Continue')),
        ],
      ),
    );
  }
}
