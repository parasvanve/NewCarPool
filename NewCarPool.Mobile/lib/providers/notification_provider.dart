import 'package:flutter/foundation.dart';

import '../models/notification_models.dart';
import '../services/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  NotificationProvider(this._notificationService);

  final NotificationService _notificationService;

  List<AppNotification> notifications = [];
  bool isLoading = false;
  String? errorMessage;
  int unreadCountValue = 0;

  Future<void> loadMine() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      notifications = await _notificationService.getMine();
      unreadCountValue = notifications.where((x) => !x.isRead).length;
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
    unreadCountValue += notification.isRead ? 0 : 1;
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
        typeCode: current.typeCode,
        rideId: current.rideId,
        bookingId: current.bookingId,
        isRead: true,
        createdAtUtc: current.createdAtUtc,
      );
      unreadCountValue = notifications.where((x) => !x.isRead).length;
      notifyListeners();
    }
  }

  Future<void> loadUnreadCount() async {
    try {
      unreadCountValue = await _notificationService.unreadCount();
      notifyListeners();
    } catch (_) {}
  }
}
