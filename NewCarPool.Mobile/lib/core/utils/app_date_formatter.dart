import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

DateTime parseUtcToLocal(String value) {
  final raw = value.trim();
  if (raw.isEmpty) {
    final fallbackUtc = DateTime.now().toUtc();
    final fallbackLocal = fallbackUtc.toLocal();
    debugPrint(
      '[AppDateFormatter] raw createdAtUtc="<empty>", parsedUtc=$fallbackUtc, local=$fallbackLocal, displayed=${DateFormat('dd MMM, hh:mm a').format(fallbackLocal)}',
    );
    return fallbackLocal;
  }

  final hasTimezone =
      RegExp(r'(z|[+-]\d{2}:?\d{2})$', caseSensitive: false).hasMatch(raw);
  final normalizedRaw = hasTimezone ? raw : '${raw}Z';
  final parsed = DateTime.tryParse(normalizedRaw);
  if (parsed == null) {
    final fallbackUtc = DateTime.now().toUtc();
    final fallbackLocal = fallbackUtc.toLocal();
    debugPrint(
      '[AppDateFormatter] raw createdAtUtc="$raw" (invalid), parsedUtc=$fallbackUtc, local=$fallbackLocal, displayed=${DateFormat('dd MMM, hh:mm a').format(fallbackLocal)}',
    );
    return fallbackLocal;
  }

  final utc = parsed.toUtc();
  final local = utc.toLocal();
  debugPrint(
    '[AppDateFormatter] raw createdAtUtc="$raw", normalized="$normalizedRaw", parsedUtc=$utc, local=$local, displayed=${DateFormat('dd MMM, hh:mm a').format(local)}',
  );
  return local;
}

String timeAgo(DateTime utc) {
  final local = utc.toLocal();
  final now = DateTime.now();
  final elapsed = now.difference(local);

  if (elapsed.inSeconds < 60) {
    debugPrint('[AppDateFormatter] utc=$utc, local=$local, displayed=Just now');
    return 'Just now';
  }
  if (elapsed.inMinutes == 1) {
    debugPrint(
        '[AppDateFormatter] utc=$utc, local=$local, displayed=1 min ago');
    return '1 min ago';
  }
  if (elapsed.inMinutes < 60) {
    final displayed = '${elapsed.inMinutes} min ago';
    debugPrint(
        '[AppDateFormatter] utc=$utc, local=$local, displayed=$displayed');
    return displayed;
  }

  final isToday = local.year == now.year &&
      local.month == now.month &&
      local.day == now.day;
  if (isToday) {
    final displayed = 'Today, ${DateFormat('hh:mm a').format(local)}';
    debugPrint(
        '[AppDateFormatter] utc=$utc, local=$local, displayed=$displayed');
    return displayed;
  }

  final displayed = DateFormat('dd MMM, hh:mm a').format(local);
  debugPrint('[AppDateFormatter] utc=$utc, local=$local, displayed=$displayed');
  return displayed;
}

String chatTime(DateTime utc) {
  final local = utc.toLocal();
  final displayed = DateFormat('hh:mm a').format(local);
  debugPrint('[AppDateFormatter] utc=$utc, local=$local, displayed=$displayed');
  return displayed;
}

String notificationDetailsTime(DateTime utc) {
  final local = utc.toLocal();
  final now = DateTime.now();
  final isToday = local.year == now.year &&
      local.month == now.month &&
      local.day == now.day;

  if (isToday) {
    final displayed = 'Today, ${DateFormat('hh:mm a').format(local)}';
    debugPrint(
        '[AppDateFormatter] utc=$utc, local=$local, displayed=$displayed');
    return displayed;
  }
  final displayed = DateFormat('dd MMM, hh:mm a').format(local);
  debugPrint('[AppDateFormatter] utc=$utc, local=$local, displayed=$displayed');
  return displayed;
}
