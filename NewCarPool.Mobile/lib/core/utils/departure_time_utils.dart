import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class DepartureTimeUtils {
  static DateTime parseUtcFromBackend(dynamic value, {String? context}) {
    final raw = value?.toString() ?? '';
    final parsed = DateTime.parse(raw);
    final utc = parsed.isUtc ? parsed : parsed.toUtc();
    debugPrint(
      '[DepartureTime][RECEIVED_UTC]${context == null ? '' : '[$context]'} raw=$raw parsedUtc=${utc.toIso8601String()}',
    );
    return utc;
  }

  static DateTime toLocalForDisplay(DateTime utc, {String? context}) {
    final local = utc.toLocal();
    debugPrint(
      '[DepartureTime][DISPLAY_LOCAL]${context == null ? '' : '[$context]'} utc=${utc.toIso8601String()} local=${local.toIso8601String()}',
    );
    return local;
  }

  static String formatFriendly(DateTime utc, {DateTime? now, String? context}) {
    final local = toLocalForDisplay(utc, context: context);
    final localNow = (now ?? DateTime.now()).toLocal();
    final sameDay = local.year == localNow.year &&
        local.month == localNow.month &&
        local.day == localNow.day;
    if (sameDay) {
      return 'Today, ${DateFormat('hh:mm a').format(local)}';
    }
    return DateFormat('dd MMM, hh:mm a').format(local);
  }
}
