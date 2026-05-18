import 'package:flutter/material.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key, this.showAppBar = true});

  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: showAppBar ? AppBar(title: const Text('Notifications')) : null,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Card(
            child: ListTile(
              leading: Icon(Icons.notifications),
              title: Text('Realtime alerts'),
              subtitle: Text('SignalR notifications will appear here.'),
            ),
          ),
        ],
      ),
    );
  }
}
