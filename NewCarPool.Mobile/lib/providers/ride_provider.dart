import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:signalr_netcore/signalr_client.dart';

import '../core/config/app_config.dart';
import '../core/constants/app_constants.dart';
import '../core/network/token_store.dart';
import '../models/ride_models.dart';
import '../models/booking_models.dart';
import '../services/ride_service.dart';

class RideProvider extends ChangeNotifier {
  RideProvider(this._rideService, this._tokenStore);

  final RideService _rideService;
  final TokenStore _tokenStore;
  List<RideOffer> rides = [];
  List<RideOffer> myRides = [];
  List<RideOffer> get upcomingActiveRides => rides;
  bool isLoading = false;
  String? errorMessage;
  Timer? _refreshTimer;
  HubConnection? _realtimeConnection;
  bool _upcomingRequestInFlight = false;
  bool _myRidesRequestInFlight = false;
  GeoPoint? _lastOrigin;
  GeoPoint? _lastDestination;
  int _lastSeats = 1;
  DateTime? _lastDepartureDateUtc;
  DateTime? _upcomingLoadedAt;
  DateTime? _myRidesLoadedAt;
  bool _ridesContainUpcomingActive = false;
  final Set<String> _processedRealtimeEvents = <String>{};
  final Set<String> _locallyCreatedRideIds = <String>{};
  final List<void Function(RideBooking)> _bookingHandlers = [];
  final List<void Function(RideOffer)> _rideHandlers = [];

  Future<void> search(GeoPoint origin, GeoPoint destination, int seats,
      {DateTime? departureDateUtc}) async {
    if (isLoading) return;
    isLoading = true;
    errorMessage = null;
    _lastOrigin = origin;
    _lastDestination = destination;
    _lastSeats = seats;
    _lastDepartureDateUtc = departureDateUtc;
    notifyListeners();
    try {
      rides = await _rideService.search(
        origin: origin,
        destination: destination,
        seats: seats,
        departureDateUtc: departureDateUtc,
      );
      _ridesContainUpcomingActive = false;
    } catch (error) {
      errorMessage = error.toString();
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  bool _isCacheFresh(DateTime? loadedAt, int cacheSeconds) {
    if (loadedAt == null) return false;
    return DateTime.now().difference(loadedAt) <
        Duration(seconds: cacheSeconds);
  }

  Future<void> loadUpcomingActive({bool forceRefresh = false}) async {
    if (_upcomingRequestInFlight) return;
    if (!forceRefresh &&
        _ridesContainUpcomingActive &&
        rides.isNotEmpty &&
        _isCacheFresh(_upcomingLoadedAt, AppConstants.dashboardCacheSeconds)) {
      return;
    }
    _upcomingRequestInFlight = true;
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final fetchedRides = await _rideService.upcomingActiveRides();
      rides = _mergeWithValidLocalCreatedRides(fetchedRides);
      _upcomingLoadedAt = DateTime.now();
      _ridesContainUpcomingActive = true;
    } catch (error) {
      errorMessage = error.toString();
      rethrow;
    } finally {
      _upcomingRequestInFlight = false;
      isLoading = false;
      notifyListeners();
    }
  }

  void markRideCachesStale() {
    _upcomingLoadedAt = null;
    _myRidesLoadedAt = null;
  }

  Future<void> loadMyRides({bool forceRefresh = false}) async {
    if (_myRidesRequestInFlight) return;
    if (!forceRefresh &&
        myRides.isNotEmpty &&
        _isCacheFresh(_myRidesLoadedAt, AppConstants.tripsCacheSeconds)) {
      return;
    }
    _myRidesRequestInFlight = true;
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      myRides = await _rideService.myRides();
      _myRidesLoadedAt = DateTime.now();
    } catch (error) {
      errorMessage = error.toString();
      rethrow;
    } finally {
      _myRidesRequestInFlight = false;
      isLoading = false;
      notifyListeners();
    }
  }

  Future<RideOffer> offerRide({
    required String vehicleId,
    required GeoPoint origin,
    required GeoPoint destination,
    required DateTime departureTimeUtc,
    required int seats,
    required num pricePerSeat,
    List<RideStop> intermediateStops = const [],
    String? notes,
    String? vehicleName,
    String? vehicleNumber,
  }) async {
    final ride = await _rideService.offerRide(
      origin: origin,
      vehicleId: vehicleId,
      destination: destination,
      departureTimeUtc: departureTimeUtc,
      seats: seats,
      pricePerSeat: pricePerSeat,
      intermediateStops: intermediateStops,
      notes: notes,
      vehicleName: vehicleName,
      vehicleNumber: vehicleNumber,
    );
    rides = [ride, ...rides.where((x) => x.id != ride.id)];
    myRides = [ride, ...myRides.where((x) => x.id != ride.id)];
    _locallyCreatedRideIds.add(ride.id);
    _ridesContainUpcomingActive = true;
    notifyListeners();
    return ride;
  }

  Future<void> bookRide(String rideOfferId, int seats) async {
    await _rideService.bookRide(rideOfferId, seats);
  }

  Future<List<RideBooking>> participants(String rideOfferId) {
    return _rideService.participants(rideOfferId);
  }

  Future<RideOffer> startRide(String rideOfferId) async {
    final updated = await _rideService.startRide(rideOfferId);
    _upsertRide(updated);
    return updated;
  }

  Future<void> completeRide(String rideOfferId) async {
    final updated = await _rideService.completeRide(rideOfferId);
    _upsertRide(updated);
  }

  Future<void> cancelRide(String rideOfferId, {String? reason}) async {
    final updated = await _rideService.cancelRide(rideOfferId, reason: reason);
    _upsertRide(updated);
  }

  Future<void> refreshNearby() async {
    if (_lastOrigin == null || _lastDestination == null || isLoading) return;
    try {
      final items = await _rideService.search(
        origin: _lastOrigin!,
        destination: _lastDestination!,
        seats: _lastSeats,
        departureDateUtc: _lastDepartureDateUtc,
      );
      rides = items;
      _ridesContainUpcomingActive = false;
      errorMessage = null;
      notifyListeners();
    } catch (_) {
      // Keep previous list for better UX on flaky connections.
    }
  }

  void startAutoRefresh({Duration interval = const Duration(seconds: 20)}) {
    if (!AppConstants.searchAutoRefreshEnabled) return;
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(interval, (_) => refreshNearby());
  }

  void stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  void _upsertRide(RideOffer ride) {
    final index = rides.indexWhere((x) => x.id == ride.id);
    if (index >= 0) {
      rides[index] = ride;
    } else {
      rides = [ride, ...rides];
    }
    final myIndex = myRides.indexWhere((x) => x.id == ride.id);
    if (myIndex >= 0) {
      myRides[myIndex] = ride;
    }
    markRideCachesStale();
    notifyListeners();
  }

  List<RideOffer> _mergeWithValidLocalCreatedRides(
      List<RideOffer> fetchedRides) {
    final nowUtc = DateTime.now().toUtc();
    final merged = <String, RideOffer>{
      for (final ride in fetchedRides) ride.id: ride,
    };

    _locallyCreatedRideIds.removeWhere((rideId) {
      final localRide = rides.where((ride) => ride.id == rideId).firstOrNull ??
          myRides.where((ride) => ride.id == rideId).firstOrNull;
      if (localRide == null) return true;
      final isActiveStatus = localRide.status == 1 ||
          localRide.status == 2 ||
          localRide.status == 3;
      final isUpcomingOrStarted =
          localRide.status == 3 || localRide.departureTimeUtc.isAfter(nowUtc);
      final shouldKeep = isActiveStatus && isUpcomingOrStarted;
      if (shouldKeep) {
        merged.putIfAbsent(localRide.id, () => localRide);
      }
      return !shouldKeep || fetchedRides.any((ride) => ride.id == rideId);
    });

    return merged.values.toList()
      ..sort((a, b) => a.departureTimeUtc.compareTo(b.departureTimeUtc));
  }

  Future<void> connectRealtime({
    String? userId,
    void Function(RideBooking booking)? onBookingChanged,
    void Function(RideOffer ride)? onRideChanged,
  }) async {
    if (onBookingChanged != null &&
        !_bookingHandlers.contains(onBookingChanged)) {
      _bookingHandlers.add(onBookingChanged);
    }
    if (onRideChanged != null && !_rideHandlers.contains(onRideChanged)) {
      _rideHandlers.add(onRideChanged);
    }
    if (_realtimeConnection?.state == HubConnectionState.Connected) return;
    final token = await _tokenStore.accessToken;
    if (token == null) return;
    _realtimeConnection = HubConnectionBuilder()
        .withUrl(
          '${AppConfig.apiBaseUrl}/hubs/notifications',
          options: HttpConnectionOptions(accessTokenFactory: () async => token),
        )
        .withAutomaticReconnect()
        .build();

    _realtimeConnection!.on('RideCreated', _handleRideRealtime);
    _realtimeConnection!.on('UpcomingRidesChanged', _handleRideRealtime);
    _realtimeConnection!.on('BookingCreated', _handleBookingRealtime);
    _realtimeConnection!.on('BookingCancelled', _handleBookingRealtime);
    _realtimeConnection!.on('RideStarted', _handleRideRealtime);
    _realtimeConnection!.on('RideCompleted', _handleRideRealtime);
    _realtimeConnection!.on('RideCancelled', _handleRideRealtime);
    await _realtimeConnection!.start();
    if (userId != null && userId.isNotEmpty) {
      await _realtimeConnection!.invoke('JoinUserGroup', args: [userId]);
    }
  }

  Future<void> disconnectRealtime() async {
    await _realtimeConnection?.stop();
    _realtimeConnection = null;
  }

  void startUpcomingAutoRefresh(
      {Duration interval =
          const Duration(seconds: AppConstants.fallbackPollingSeconds)}) {
    if (AppConstants.realtimePrimary &&
        _realtimeConnection?.state == HubConnectionState.Connected) {
      return;
    }
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(interval, (_) async {
      if (AppConstants.realtimePrimary &&
          _realtimeConnection?.state == HubConnectionState.Connected) {
        return;
      }
      if (_upcomingRequestInFlight) return;
      await loadUpcomingActive();
    });
  }

  void _handleBookingRealtime(List<Object?>? args) {
    final payload = _payload(args);
    if (payload == null) return;
    final bookingPayload = payload['booking'] ?? payload;
    if (bookingPayload is! Map) return;
    final booking =
        RideBooking.fromJson(Map<String, dynamic>.from(bookingPayload));
    if (!_markRealtimeEventProcessed(
        'booking:${booking.id}:${booking.status}')) {
      return;
    }
    final ridePayload = payload['ride'];
    if (ridePayload is Map) {
      _upsertRide(RideOffer.fromJson(Map<String, dynamic>.from(ridePayload)));
    } else {
      markRideCachesStale();
      notifyListeners();
    }
    for (final handler in List.of(_bookingHandlers)) {
      handler(booking);
    }
  }

  void _handleRideRealtime(List<Object?>? args) {
    final payload = _payload(args);
    if (payload == null) return;
    final ridePayload = payload['ride'] ?? payload;
    if (ridePayload is! Map) {
      markRideCachesStale();
      notifyListeners();
      return;
    }
    final ride = RideOffer.fromJson(Map<String, dynamic>.from(ridePayload));
    if (!_markRealtimeEventProcessed(
        'ride:${ride.id}:${ride.status}:${ride.departureTimeUtc.toIso8601String()}')) {
      return;
    }
    _upsertRide(ride);
    for (final handler in List.of(_rideHandlers)) {
      handler(ride);
    }
  }

  Map<String, dynamic>? _payload(List<Object?>? args) {
    if (args == null || args.isEmpty || args.first is! Map) return null;
    return Map<String, dynamic>.from(args.first as Map);
  }

  bool _markRealtimeEventProcessed(String key) {
    if (_processedRealtimeEvents.contains(key)) return false;
    _processedRealtimeEvents.add(key);
    if (_processedRealtimeEvents.length > 200) {
      _processedRealtimeEvents.remove(_processedRealtimeEvents.first);
    }
    return true;
  }

  void stopUpcomingAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _realtimeConnection?.stop();
    super.dispose();
  }
}
