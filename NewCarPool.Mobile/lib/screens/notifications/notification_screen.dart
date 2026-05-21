import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/app_design_system.dart';
import '../../providers/notification_provider.dart';
import '../../providers/profile_provider.dart';
import '../../services/notification_service.dart';

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
      appBar: widget.showAppBar ? AppBar(title: const Text('Notifications')) : null,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: RefreshIndicator(
            onRefresh: () => context.read<NotificationProvider>().loadMine(),
            child: provider.errorMessage != null && provider.notifications.isEmpty
                ? AppRetryState(
                    title: 'Unable to load notifications',
                    subtitle: 'Check your internet connection and try again.',
                    onRetry: () => context.read<NotificationProvider>().loadMine(),
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
                          Icon(Icons.notifications_none, size: 56, color: Colors.grey.shade400),
                          const SizedBox(height: 10),
                          const Center(child: Text('No notifications yet.')),
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
                                title: item.title,
                                message: item.message,
                                isRead: item.isRead,
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
    required this.title,
    required this.message,
    required this.isRead,
    this.onMarkRead,
  });

  final String title;
  final String message;
  final bool isRead;
  final VoidCallback? onMarkRead;

  @override
  Widget build(BuildContext context) {
    IconData icon = Icons.notifications_outlined;
    if (title.toLowerCase().contains('request')) icon = Icons.group_add_outlined;
    if (title.toLowerCase().contains('cancel')) icon = Icons.cancel_outlined;
    if (title.toLowerCase().contains('confirm')) icon = Icons.check_circle_outline;

    return Card(
      color: isRead ? Colors.white : const Color(0xFFEFF1FF),
      child: ListTile(
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppDesignTokens.brandStart.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppDesignTokens.brandStart),
        ),
        title: Text(title),
        subtitle: Text(message),
        trailing: onMarkRead == null
            ? null
            : TextButton(
                onPressed: onMarkRead,
                child: const Text('Mark read'),
              ),
      ),
    );
  }
}
