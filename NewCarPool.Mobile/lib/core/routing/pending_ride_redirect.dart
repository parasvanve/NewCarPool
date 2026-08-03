class PendingRideRedirect {
  PendingRideRedirect._();

  static String? _rideId;

  static void set(String rideId) => _rideId = rideId;

  static String? consume() {
    final id = _rideId;
    _rideId = null;
    return id;
  }

  static bool get hasPending => _rideId != null;
}
