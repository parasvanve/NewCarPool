import 'package:flutter/material.dart';

class BookingFlowScreen extends StatefulWidget {
  const BookingFlowScreen({super.key});

  @override
  State<BookingFlowScreen> createState() => _BookingFlowScreenState();
}

class _BookingFlowScreenState extends State<BookingFlowScreen> {
  int seats = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm Booking')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Stepper(
            currentStep: 0,
            controlsBuilder: (_, __) => const SizedBox.shrink(),
            steps: [
              Step(title: const Text('Seat selection'), content: Row(children: [
                IconButton(onPressed: seats > 1 ? () => setState(() => seats--) : null, icon: const Icon(Icons.remove)),
                Text('$seats'),
                IconButton(onPressed: () => setState(() => seats++), icon: const Icon(Icons.add)),
              ])),
              const Step(title: Text('Payment'), content: Text('Choose payment method')),
              const Step(title: Text('Success'), content: Text('Booking confirmation appears here')),
            ],
          ),
          FilledButton(onPressed: () {}, child: const Text('Confirm Booking')),
        ],
      ),
    );
  }
}
