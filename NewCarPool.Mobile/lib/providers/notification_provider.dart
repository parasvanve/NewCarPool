import 'package:flutter/foundation.dart';

import '../models/notification_models.dart';
import '../services/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  NotificationProvider(this._notificationService);

  final NotificationService _notificationService;

  List<AppNotification> notifications = [];
  bool isLoading = false;
  String? errorMessage;

  Future<void> loadMine() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      notifications = await _notificationService.getMine();
    } catch (error) {
      errorMessage = error.toString();
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void prependRealtime(AppNotification notification) {
    notifications = [notification, ...notifications];
    notifyListeners();
  }

  Future<void> markRead(String notificationId) async {
    await _notificationService.markRead(notificationId);
    final index = notifications.indexWhere((x) => x.id == notificationId);
    if (index >= 0) {
      final current = notifications[index];
      notifications[index] = AppNotification(
        id: current.id,
        title: current.title,
        message: current.message,
        isRead: true,
        createdAtUtc: current.createdAtUtc,
      );
      notifyListeners();
    }
  }
}
