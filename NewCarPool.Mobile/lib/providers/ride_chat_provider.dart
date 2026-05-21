import 'package:flutter/foundation.dart';
import 'dart:async';

import '../models/chat_models.dart';
import '../services/ride_chat_service.dart';

class RideChatProvider extends ChangeNotifier {
  RideChatProvider(this._service);

  final RideChatService _service;
  List<RideChatMessage> messages = [];
  bool isLoading = false;
  Timer? _pollTimer;
  String? _rideId;

  Future<void> load(String rideOfferId) async {
    _rideId = rideOfferId;
    isLoading = true;
    notifyListeners();
    try {
      messages = await _service.messages(rideOfferId);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void startPolling({Duration interval = const Duration(seconds: 3)}) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(interval, (_) async {
      final rideId = _rideId;
      if (rideId == null) return;
      try {
        final latest = await _service.messages(rideId);
        if (!_sameMessages(latest, messages)) {
          messages = latest;
          notifyListeners();
        }
      } catch (_) {}
    });
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> send(String rideOfferId, String message) async {
    final sent = await _service.send(rideOfferId: rideOfferId, message: message);
    messages = [...messages, sent];
    notifyListeners();
  }

  bool _sameMessages(List<RideChatMessage> a, List<RideChatMessage> b) {
    if (a.length != b.length) return false;
    if (a.isEmpty) return true;
    return a.last.id == b.last.id;
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
