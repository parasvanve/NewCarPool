import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/app_date_formatter.dart';
import '../../models/notification_models.dart';
import '../../providers/notification_provider.dart';
import '../../services/ride_service.dart';
import '../rides/ride_chat_screen.dart';
import '../rides/ride_details_screen.dart';

class NotificationDetailsScreen extends StatelessWidget {
  const NotificationDetailsScreen({
    super.key,
    required this.notification,
  });

  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    final dateText = notificationDetailsTime(notification.createdAtUtc);
    final style = _style(notification);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FD),
        elevation: 0,
        leading: const BackButton(),
        centerTitle: true,
        title: const Text('Notification Details', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: ListView(
            padding: const EdgeInsets.all(14),
            children: [
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: style.$2,
                            child: Icon(style.$1, color: style.$3, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  notification.title,
                                  style: TextStyle(
                                    fontSize: 29,
                                    fontWeight: FontWeight.w700,
                                    color: notification.kind == NotificationKind.message
                                        ? const Color(0xFF3450F7)
                                        : const Color(0xFF1F2937),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(dateText, style: const TextStyle(color: Color(0xFF667085))),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(notification.message, style: const TextStyle(fontSize: 24, height: 1.35, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 16),
                      _DetailActionButtons(notification: notification),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  (IconData, Color, Color) _style(AppNotification n) {
    if (n.typeCode == 2) {
      return (Icons.cancel_outlined, const Color(0xFFFFEBEB), const Color(0xFFFF3B30));
    }
    switch (n.kind) {
      case NotificationKind.booking:
        if (n.typeCode == 6) {
          return (Icons.check_circle_outline, const Color(0xFFDDF7E8), const Color(0xFF10B981));
        }
        return (Icons.event_note_outlined, const Color(0xFFE7EEFF), const Color(0xFF3450F7));
      case NotificationKind.trip:
        if (n.typeCode == 4) {
          return (Icons.notifications_none, const Color(0xFFFFF1D8), const Color(0xFFF59E0B));
        }
        return (Icons.directions_car_outlined, const Color(0xFFDDF7E8), const Color(0xFF10B981));
      case NotificationKind.message:
        return (Icons.chat_bubble_outline, const Color(0xFFF1E7FF), const Color(0xFF8B5CF6));
      case NotificationKind.system:
        return (Icons.settings_outlined, const Color(0xFFEFF2F8), const Color(0xFF64748B));
      case NotificationKind.all:
        return (Icons.notifications_outlined, const Color(0xFFE7EEFF), const Color(0xFF3450F7));
    }
  }
}

class _DetailActionButtons extends StatelessWidget {
  const _DetailActionButtons({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    final hasRide = notification.rideId != null && notification.rideId!.isNotEmpty;
    if (!hasRide) return const SizedBox.shrink();

    final isCancelled = notification.typeCode == 2;
    final isBooking = notification.kind == NotificationKind.booking;
    final primaryLabel = isCancelled
        ? 'View Details'
        : (isBooking ? (notification.typeCode == 6 ? 'View Trip' : 'View Booking') : 'View Trip');

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () async {
              if (!notification.isRead) {
                await context.read<NotificationProvider>().markRead(notification.id);
              }
              if (!context.mounted) return;
              final ride = await context.read<RideService>().details(notification.rideId!);
              if (!context.mounted) return;
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => RideDetailsScreen(extra: ride)));
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF3450F7)),
              foregroundColor: const Color(0xFF3450F7),
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            child: Text(primaryLabel),
          ),
        ),
        if (!isCancelled) ...[
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              onPressed: () async {
                if (!notification.isRead) {
                  await context.read<NotificationProvider>().markRead(notification.id);
                }
                if (!context.mounted) return;
                final ride = await context.read<RideService>().details(notification.rideId!);
                if (!context.mounted) return;
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => RideChatScreen(ride: ride)));
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF3450F7),
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: const Text('Open Chat'),
            ),
          ),
        ],
      ],
    );
  }
}
