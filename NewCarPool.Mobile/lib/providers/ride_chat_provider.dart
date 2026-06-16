import 'package:flutter/foundation.dart';
import 'dart:async';

import '../models/chat_models.dart';
import '../services/ride_chat_service.dart';

class RideChatProvider extends ChangeNotifier {
  RideChatProvider(this._service);

  final RideChatService _service;
  List<RideChatMessage> messages = [];
  bool isLoading = false;
  bool isUploading = false;
  Timer? _pollTimer;

  Future<void> load(String rideOfferId) async {
    isLoading = true;
    notifyListeners();
    try {
      messages = await _service.messages(rideOfferId);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void startPolling({Duration interval = const Duration(seconds: 120)}) {
    _pollTimer?.cancel();
  }

  Future<void> connectRealtime() async {
    await _service.connect(upsertRealtime);
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> send(String rideOfferId, String message) async {
    final sent =
        await _service.send(rideOfferId: rideOfferId, message: message);
    upsertRealtime(sent);
  }

  Future<void> uploadAttachment({
    required String rideOfferId,
    required ChatAttachmentFile file,
    String? caption,
  }) async {
    if (isUploading) return;
    isUploading = true;
    notifyListeners();
    try {
      final uploaded = await _service.uploadAttachment(
        rideOfferId: rideOfferId,
        file: file,
        caption: caption,
      );
      upsertRealtime(uploaded);
    } finally {
      isUploading = false;
      notifyListeners();
    }
  }

  void upsertRealtime(RideChatMessage message) {
    final index = messages.indexWhere((x) => x.id == message.id);
    if (index >= 0) {
      messages[index] = message;
    } else {
      messages = [...messages, message];
    }
    messages.sort((a, b) => a.createdAtUtc.compareTo(b.createdAtUtc));
    notifyListeners();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _service.disconnect();
    super.dispose();
  }
}
