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
import 'notification_details_screen.dart';

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
    final provider = context.read<NotificationProvider>();
    if (provider.notifications.isEmpty) {
      await provider.loadMine();
    }
    await _connectRealtime();
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) async {
        await context.read<NotificationProvider>().loadUnreadCount();
        await context.read<NotificationProvider>().loadMine();
      },
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
    final items = provider.filteredNotifications;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: const Color(0xFFF8F9FD),
              elevation: 0,
              leading: BackButton(
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              centerTitle: true,
              title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.w700)),
              actions: const [
                Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Icons.tune),
                ),
              ],
            )
          : null,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: RefreshIndicator(
            onRefresh: () => context.read<NotificationProvider>().loadMine(),
            child: provider.errorMessage != null && provider.notifications.isEmpty
                ? AppRetryState(
                    title: 'Unable to load notifications',
                    subtitle: 'Check your internet connection and try again.',
                    onRetry: () => context.read<NotificationProvider>().loadMine(),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                    children: [
                      if (!widget.showAppBar)
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back),
                              onPressed: () => Navigator.of(context).maybePop(),
                            ),
                            const Expanded(
                              child: Text(
                                'Notifications',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
                              ),
                            ),
                            IconButton(
                              onPressed: () {},
                              icon: const Icon(Icons.tune),
                            ),
                          ],
                        ),
                      const SizedBox(height: 4),
                      _NotificationFilterTabs(
                        active: provider.activeFilter,
                        onSelect: provider.setFilter,
                      ),
                      const SizedBox(height: 10),
                      if (provider.isLoading && provider.notifications.isEmpty)
                        ...List.generate(
                          4,
                          (_) => const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: AppSkeletonBox(height: 142, radius: 20),
                          ),
                        )
                      else if (items.isEmpty)
                        Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          child: const Padding(
                            padding: EdgeInsets.all(24),
                            child: Column(
                              children: [
                                Icon(Icons.notifications_none, size: 52, color: Colors.grey),
                                SizedBox(height: 8),
                                Text('No notifications yet', style: TextStyle(fontWeight: FontWeight.w700)),
                                SizedBox(height: 6),
                                Text('Ride updates and messages will appear here.'),
                              ],
                            ),
                          ),
                        )
                      else
                        ...items.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _NotificationCard(item: item),
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

class _NotificationFilterTabs extends StatelessWidget {
  const _NotificationFilterTabs({required this.active, required this.onSelect});

  final NotificationKind active;
  final ValueChanged<NotificationKind> onSelect;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      (NotificationKind.all, 'All'),
      (NotificationKind.booking, 'Bookings'),
      (NotificationKind.trip, 'Trips'),
      (NotificationKind.message, 'Messages'),
      (NotificationKind.system, 'System'),
    ];
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: tabs
            .map(
              (tab) => Expanded(
                child: InkWell(
                  onTap: () => onSelect(tab.$1),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8, top: 4),
                    child: Column(
                      children: [
                        Text(
                          tab.$2,
                          style: TextStyle(
                            color: active == tab.$1 ? const Color(0xFF3450F7) : const Color(0xFF667085),
                            fontWeight: active == tab.$1 ? FontWeight.w700 : FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 2,
                          color: active == tab.$1 ? const Color(0xFF3450F7) : Colors.transparent,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item});

  final AppNotification item;

  @override
  Widget build(BuildContext context) {
    final style = _style(item.kind, item.typeCode);
    final elapsed = DateTime.now().toUtc().difference(item.createdAtUtc);
    final timeAgo = elapsed.inMinutes < 1
        ? 'just now'
        : elapsed.inMinutes < 60
            ? '${elapsed.inMinutes} min ago'
            : elapsed.inHours < 24
                ? '${elapsed.inHours} hr ago'
                : '${elapsed.inDays} day ago';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () async {
          if (!item.isRead) {
            await context.read<NotificationProvider>().markRead(item.id);
          }
          if (!context.mounted) return;
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => NotificationDetailsScreen(notification: item)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: style.$2,
                    child: Icon(style.$1, color: style.$3, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                        const SizedBox(height: 4),
                        Text(item.message, style: const TextStyle(color: Color(0xFF667085), height: 1.35)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(timeAgo, style: const TextStyle(color: Color(0xFF667085))),
                      const SizedBox(height: 4),
                      if (!item.isRead)
                        const CircleAvatar(radius: 4, backgroundColor: Color(0xFF3450F7)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _ActionButtons(item: item),
            ],
          ),
        ),
      ),
    );
  }

  (IconData, Color, Color) _style(NotificationKind kind, int typeCode) {
    if (typeCode == 2) {
      return (Icons.cancel_outlined, const Color(0xFFFFEBEB), const Color(0xFFFF3B30));
    }
    switch (kind) {
      case NotificationKind.booking:
        if (typeCode == 6) {
          return (Icons.check_circle_outline, const Color(0xFFDDF7E8), const Color(0xFF10B981));
        }
        return (Icons.event_note_outlined, const Color(0xFFE7EEFF), const Color(0xFF3450F7));
      case NotificationKind.trip:
        if (typeCode == 4) {
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

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({required this.item});

  final AppNotification item;

  @override
  Widget build(BuildContext context) {
    final hasRide = item.rideId != null && item.rideId!.isNotEmpty;
    if (!hasRide) {
      if (item.kind == NotificationKind.message) {
        return _OutlineBtn(
          label: 'Open Chat',
          onTap: () async {
            if (!item.isRead) {
              await context.read<NotificationProvider>().markRead(item.id);
            }
            if (!context.mounted) return;
            if (item.rideId != null && item.rideId!.isNotEmpty) {
              final ride = await context.read<RideService>().details(item.rideId!);
              if (!context.mounted) return;
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => RideChatScreen(ride: ride)));
            }
          },
        );
      }
      return const SizedBox.shrink();
    }

    final isBooking = item.kind == NotificationKind.booking;
    final isMessage = item.kind == NotificationKind.message;
    final isCancelled = item.typeCode == 2;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _OutlineBtn(
          label: isCancelled
              ? 'View Details'
              : (isBooking ? (item.typeCode == 6 ? 'View Trip' : 'View Booking') : 'View Trip'),
          onTap: () async {
            if (!item.isRead) {
              await context.read<NotificationProvider>().markRead(item.id);
            }
            if (!context.mounted) return;
            final ride = await context.read<RideService>().details(item.rideId!);
            if (!context.mounted) return;
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => RideDetailsScreen(extra: ride)));
          },
        ),
        if (!isCancelled)
          _FilledBtn(
            label: isMessage ? 'Open Chat' : 'Open Chat',
            onTap: () async {
              if (!item.isRead) {
                await context.read<NotificationProvider>().markRead(item.id);
              }
              if (!context.mounted) return;
              final ride = await context.read<RideService>().details(item.rideId!);
              if (!context.mounted) return;
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => RideChatScreen(ride: ride)));
            },
          ),
      ],
    );
  }
}

class _OutlineBtn extends StatelessWidget {
  const _OutlineBtn({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0xFF9CB1FF)),
        foregroundColor: const Color(0xFF3450F7),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}

class _FilledBtn extends StatelessWidget {
  const _FilledBtn({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF3450F7),
        foregroundColor: Colors.white,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}
