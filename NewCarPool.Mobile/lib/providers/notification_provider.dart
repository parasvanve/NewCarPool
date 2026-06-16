import 'package:flutter/foundation.dart';
import 'dart:async';

import '../core/constants/app_constants.dart';
import '../models/notification_models.dart';
import '../services/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  NotificationProvider(this._notificationService);

  final NotificationService _notificationService;

  List<AppNotification> notifications = [];
  bool isLoading = false;
  String? errorMessage;
  int unreadCountValue = 0;
  NotificationKind activeFilter = NotificationKind.all;
  Timer? _unreadTimer;
  Timer? _listTimer;

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
    final existingIndex =
        notifications.indexWhere((x) => x.id == notification.id);
    if (existingIndex >= 0) {
      final copy = [...notifications];
      copy[existingIndex] = notification;
      notifications = copy;
    } else {
      notifications = [notification, ...notifications];
    }
    unreadCountValue = notifications.where((x) => !x.isRead).length;
    notifyListeners();
  }

  void setUnreadCountRealtime(int count) {
    unreadCountValue = count;
    notifyListeners();
  }

  Future<void> markRead(String notificationId) async {
    await _notificationService.markRead(notificationId);
    final index = notifications.indexWhere((x) => x.id == notificationId);
    if (index >= 0) {
      notifications[index] = notifications[index].copyWith(isRead: true);
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

  Future<void> markAllRead() async {
    await _notificationService.markAllRead();
    notifications = notifications.map((n) => n.copyWith(isRead: true)).toList();
    unreadCountValue = 0;
    notifyListeners();
  }

  void setFilter(NotificationKind filter) {
    activeFilter = filter;
    notifyListeners();
  }

  List<AppNotification> get filteredNotifications {
    if (activeFilter == NotificationKind.all) return notifications;
    return notifications.where((n) => n.kind == activeFilter).toList();
  }

  void startUnreadAutoRefresh(
      {Duration interval =
          const Duration(seconds: AppConstants.fallbackPollingSeconds)}) {
    _unreadTimer?.cancel();
  }

  void stopUnreadAutoRefresh() {
    _unreadTimer?.cancel();
    _unreadTimer = null;
  }

  void startListAutoRefresh(
      {Duration interval =
          const Duration(seconds: AppConstants.fallbackPollingSeconds)}) {
    _listTimer?.cancel();
  }

  void stopListAutoRefresh() {
    _listTimer?.cancel();
    _listTimer = null;
  }

  @override
  void dispose() {
    _unreadTimer?.cancel();
    _listTimer?.cancel();
    super.dispose();
  }
}
