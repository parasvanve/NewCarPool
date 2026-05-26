import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/app_design_system.dart';
import '../../models/notification_models.dart';
import '../../providers/notification_provider.dart';
import '../../providers/profile_provider.dart';
import '../../services/notification_service.dart';
import '../../services/ride_service.dart';
import '../rides/ride_chat_screen.dart';
import '../rides/ride_details_screen.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key, required this.showAppBar});

  final bool showAppBar;

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  bool _connected = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    await context.read<NotificationProvider>().loadMine();
    await _connectRealtime();
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => context.read<NotificationProvider>().loadMine(),
    );
  }

  Future<void> _connectRealtime() async {
    if (_connected) return;
    final profileProvider = context.read<ProfileProvider>();
    if (profileProvider.profile == null) {
      try {
        await profileProvider.loadProfile();
      } catch (_) {
        return;
      }
    }
    final userId = profileProvider.profile?.id;
    if (userId == null || userId.isEmpty || !mounted) return;

    final notificationService = context.read<NotificationService>();
    await notificationService.connect(userId, (notification) {
      if (!mounted) return;
      context.read<NotificationProvider>().prependRealtime(notification);
    });
    _connected = true;
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    context.read<NotificationService>().disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();
    return Scaffold(
      backgroundColor: AppDesignTokens.pageBg,
      appBar:
          widget.showAppBar ? AppBar(title: const Text('Notifications')) : null,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: RefreshIndicator(
            onRefresh: () => context.read<NotificationProvider>().loadMine(),
            child: provider.errorMessage != null &&
                    provider.notifications.isEmpty
                ? AppRetryState(
                    title: 'Unable to load notifications',
                    subtitle: 'Check your internet connection and try again.',
                    onRetry: () =>
                        context.read<NotificationProvider>().loadMine(),
                  )
                : provider.isLoading && provider.notifications.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                        children: const [
                          AppSkeletonBox(height: 84, radius: 18),
                          SizedBox(height: 10),
                          AppSkeletonBox(height: 96, radius: 18),
                          SizedBox(height: 10),
                          AppSkeletonBox(height: 96, radius: 18),
                        ],
                      )
                    : provider.notifications.isEmpty
                        ? ListView(
                            children: [
                              const SizedBox(height: 130),
                              Icon(Icons.notifications_none,
                                  size: 56, color: Colors.grey.shade400),
                              const SizedBox(height: 10),
                              const Center(
                                  child: Text('No notifications yet.')),
                            ],
                          )
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                            children: [
                              const AppGradientHeroCard(
                                title: 'Notifications',
                                subtitle: 'Ride requests, bookings and updates',
                                icon: Icons.notifications_active_outlined,
                              ),
                              const SizedBox(height: 10),
                              ...provider.notifications.map(
                                (item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _NotificationCard(
                                    item: item,
                                    onMarkRead: item.isRead
                                        ? null
                                        : () => context.read<NotificationProvider>().markRead(item.id),
                                  ),
                                ),
                              ),
                            ],
                          ),
          ),
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.item,
    this.onMarkRead,
  });

  final AppNotification item;
  final VoidCallback? onMarkRead;

  @override
  Widget build(BuildContext context) {
    IconData icon = Icons.notifications_outlined;
    if (item.title.toLowerCase().contains('request')) {
      icon = Icons.group_add_outlined;
    }
    if (item.title.toLowerCase().contains('cancel')) {
      icon = Icons.cancel_outlined;
    }
    if (item.title.toLowerCase().contains('confirm')) {
      icon = Icons.check_circle_outline;
    }

    return Card(
      color: item.isRead ? Colors.white : const Color(0xFFEFF1FF),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppDesignTokens.brandStart.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppDesignTokens.brandStart),
              ),
              title: Text(item.title),
              subtitle: Text(item.message),
              trailing: onMarkRead == null
                  ? null
                  : TextButton(
                      onPressed: onMarkRead,
                      child: const Text('Mark read'),
                    ),
            ),
            if (item.rideId != null && item.rideId!.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final provider = context.read<NotificationProvider>();
                      if (!item.isRead) {
                        await provider.markRead(item.id);
                      }
                      final ride = await context.read<RideService>().details(item.rideId!);
                      if (!context.mounted) return;
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => RideDetailsScreen(extra: ride)),
                      );
                    },
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('View Booking'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final provider = context.read<NotificationProvider>();
                      if (!item.isRead) {
                        await provider.markRead(item.id);
                      }
                      final ride = await context.read<RideService>().details(item.rideId!);
                      if (!context.mounted) return;
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => RideChatScreen(ride: ride)),
                      );
                    },
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Open Chat'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
