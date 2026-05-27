import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/ride_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/ride_chat_provider.dart';

class RideChatScreen extends StatefulWidget {
  const RideChatScreen({super.key, required this.ride});

  final RideOffer ride;

  @override
  State<RideChatScreen> createState() => _RideChatScreenState();
}

class _RideChatScreenState extends State<RideChatScreen> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<RideChatProvider>();
      provider.load(widget.ride.id).then((_) => _scrollToEnd());
      provider.startPolling();
    });
  }

  @override
  void dispose() {
    context.read<RideChatProvider>().stopPolling();
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<RideChatProvider>();
    final me = context.watch<AuthProvider>().session?.userId;
    return Scaffold(
      appBar: AppBar(title: const Text('Ride Group Chat')),
      body: Column(
        children: [
          Expanded(
            child: chat.isLoading
                ? const Center(child: CircularProgressIndicator())
                : chat.messages.isEmpty
                    ? const Center(child: Text('No messages yet. Start the ride chat.'))
                    : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(12),
                    itemCount: chat.messages.length,
                    itemBuilder: (_, i) {
                      final m = chat.messages[i];
                      final mine = me != null && me == m.senderUserId;
                      return Align(
                        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          constraints: const BoxConstraints(maxWidth: 360),
                          decoration: BoxDecoration(
                            color: mine ? const Color(0xFFEDEBFF) : const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              Text(m.senderName, style: const TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text(m.message),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('hh:mm a').format(m.createdAtUtc.toLocal()),
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      decoration: const InputDecoration(
                        hintText: 'Type message...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: () async {
                      final text = _ctrl.text.trim();
                      if (text.isEmpty) return;
                      _ctrl.clear();
                      await context.read<RideChatProvider>().send(widget.ride.id, text);
                      await context.read<NotificationProvider>().loadUnreadCount();
                      _scrollToEnd();
                    },
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
