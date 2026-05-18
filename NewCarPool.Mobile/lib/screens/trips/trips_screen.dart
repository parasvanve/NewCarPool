import 'package:flutter/material.dart';

class TripsScreen extends StatelessWidget {
  const TripsScreen({super.key, this.showAppBar = true});

  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: showAppBar
            ? AppBar(title: const Text('My Trips'), bottom: const TabBar(tabs: [Tab(text: 'As Driver'), Tab(text: 'As Passenger')]))
            : const TabBar(tabs: [Tab(text: 'As Driver'), Tab(text: 'As Passenger')]),
        body: const TabBarView(
          children: [
            Center(child: Text('Driver trips will appear here')),
            Center(child: Text('Passenger trips will appear here')),
          ],
        ),
      ),
    );
  }
}
