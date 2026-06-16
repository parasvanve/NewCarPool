import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import '../models/booking_models.dart';
import '../models/ride_models.dart';
import '../services/booking_service.dart';

class BookingProvider extends ChangeNotifier {
  BookingProvider(this._bookingService);

  final BookingService _bookingService;

  List<RideBooking> bookings = [];
  bool isLoading = false;
  String? errorMessage;
  final Set<String> _processingIds = <String>{};
  DateTime? _loadedAt;
  Set<String> get processingIds => _processingIds;

  bool _isCacheFresh(DateTime? loadedAt, int cacheSeconds) {
    if (loadedAt == null) return false;
    return DateTime.now().difference(loadedAt) <
        Duration(seconds: cacheSeconds);
  }

  Future<void> loadHistory({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        bookings.isNotEmpty &&
        _isCacheFresh(_loadedAt, AppConstants.tripsCacheSeconds)) {
      return;
    }
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      bookings = await _bookingService.history();
      _loadedAt = DateTime.now();
    } catch (error) {
      errorMessage = error.toString();
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> cancel(String bookingId, {String? reason}) async {
    await _updateBooking(
        bookingId, () => _bookingService.cancel(bookingId, reason: reason));
  }

  void markCacheStale() {
    _loadedAt = null;
  }

  void upsertRealtime(RideBooking booking) {
    final index = bookings.indexWhere((x) => x.id == booking.id);
    if (index >= 0) {
      bookings[index] = booking;
    } else {
      bookings = [booking, ...bookings];
    }
    notifyListeners();
  }

  Future<RideBooking> request({
    required String rideOfferId,
    required int seatsBooked,
    GeoPoint? pickup,
    GeoPoint? drop,
  }) async {
    final booking = await _bookingService.request(
      rideOfferId: rideOfferId,
      seatsBooked: seatsBooked,
      pickup: pickup,
      drop: drop,
    );
    bookings = [booking, ...bookings.where((x) => x.id != booking.id)];
    _loadedAt = DateTime.now();
    notifyListeners();
    return booking;
  }

  Future<void> accept(String bookingId) async {
    await _updateBooking(bookingId, () => _bookingService.accept(bookingId));
  }

  Future<void> reject(String bookingId) async {
    await _updateBooking(bookingId, () => _bookingService.reject(bookingId));
  }

  Future<void> _updateBooking(
    String bookingId,
    Future<RideBooking> Function() updater,
  ) async {
    _processingIds.add(bookingId);
    notifyListeners();
    try {
      final updated = await updater();
      final index = bookings.indexWhere((x) => x.id == bookingId);
      if (index >= 0) {
        bookings[index] = updated;
      } else {
        bookings = [updated, ...bookings];
      }
      _loadedAt = DateTime.now();
    } finally {
      _processingIds.remove(bookingId);
      notifyListeners();
    }
  }
}
