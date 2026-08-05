import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:signalr_netcore/signalr_client.dart';
import '../core/constants/app_constants.dart';
import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../core/network/token_store.dart';
import '../core/utils/location_permission_helper.dart';

class TrackingService {
  TrackingService(this._apiClient, this._tokenStore);

  final ApiClient _apiClient;
  final TokenStore _tokenStore;
  HubConnection? _connection;
  StreamSubscription<Position>? _driverLocationSubscription;
  DateTime? _lastPublishedAtUtc;
  Position? _lastPublishedPosition;
  String? _connectedRideOfferId;

  Future<void> connect(
    String rideOfferId,
    void Function(Map<String, dynamic>) onLocation, {
    VoidCallback? onTrackingStarted,
    VoidCallback? onTrackingStopped,
  }) async {
    if (_connection?.state == HubConnectionState.Connected &&
        _connectedRideOfferId == rideOfferId) {
      return;
    }

    await disconnect();
    final token = await _tokenStore.accessToken;
    // _connection = HubConnectionBuilder()
    //     .withUrl(
    //       '${AppConfig.apiBaseUrl}/hubs/tracking',
    //       options: HttpConnectionOptions(
    //           accessTokenFactory: () async => token ?? ''),
    //     )
    //     .withAutomaticReconnect()
    //     .build();

    //new code
    _connection = HubConnectionBuilder()
        .withUrl(
          '${AppConfig.apiBaseUrl}/hubs/notifications',
          options: HttpConnectionOptions(
            accessTokenFactory: () async => await _tokenStore.accessToken ?? '',
          ),
        )
        .withAutomaticReconnect()
        .build();
    _connectedRideOfferId = rideOfferId;

    void handleLocationPayload(List<Object?>? args) {
      if (args != null && args.isNotEmpty) {
        onLocation(Map<String, dynamic>.from(args.first as Map));
      }
    }

    _connection!.on('locationUpdated', handleLocationPayload);
    _connection!.on('DriverLocationUpdated', handleLocationPayload);
    _connection!.on('TrackingStarted', (_) => onTrackingStarted?.call());
    _connection!.on('TrackingStopped', (_) => onTrackingStopped?.call());

    await _connection!.start();
    await _connection!.invoke('JoinRide', args: [rideOfferId]);
  }

  Future<void> publishLocation({
    required String rideOfferId,
    required double latitude,
    required double longitude,
    double? heading,
    double? speedKph,
  }) async {
    await _apiClient.dio.post('/rides/$rideOfferId/location', data: {
      'rideOfferId': rideOfferId,
      'latitude': latitude,
      'longitude': longitude,
      'heading': heading,
      'speedKph': speedKph,
    });
  }

  Future<bool> startDriverLocationSharing(
    String rideOfferId, {
    void Function(Map<String, dynamic>)? onPublished,
  }) async {
    final permission = await LocationPermissionHelper.request();
    if (!permission.isGranted) {
      return false;
    }

    await stopDriverLocationSharing();
    _lastPublishedAtUtc = null;
    _lastPublishedPosition = null;

    Future<void> publish(Position position, {bool force = false}) async {
      if (!force && !_shouldPublish(position)) return;
      await publishLocation(
        rideOfferId: rideOfferId,
        latitude: position.latitude,
        longitude: position.longitude,
        heading: position.heading.isFinite ? position.heading : null,
        speedKph: position.speed.isFinite ? position.speed * 3.6 : null,
      );
      _lastPublishedAtUtc = DateTime.now().toUtc();
      _lastPublishedPosition = position;
      onPublished?.call({
        'rideOfferId': rideOfferId,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'heading': position.heading.isFinite ? position.heading : null,
        'speedKph': position.speed.isFinite ? position.speed * 3.6 : null,
        'createdAtUtc': _lastPublishedAtUtc!.toIso8601String(),
      });
    }

    final current = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
      ),
    );
    await publish(current, force: true);

    _driverLocationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 8,
      ),
    ).listen((position) async {
      try {
        await publish(position);
      } catch (_) {}
    });

    return true;
  }

  bool _shouldPublish(Position position) {
    final lastAt = _lastPublishedAtUtc;
    final lastPosition = _lastPublishedPosition;
    if (lastAt == null || lastPosition == null) return true;

    final seconds = DateTime.now().toUtc().difference(lastAt).inSeconds;
    final meters = Geolocator.distanceBetween(
      lastPosition.latitude,
      lastPosition.longitude,
      position.latitude,
      position.longitude,
    );
    return seconds >= AppConstants.locationDbSaveIntervalSeconds ||
        meters >= AppConstants.locationMinDistanceMeters;
  }

  Future<void> stopDriverLocationSharing() async {
    await _driverLocationSubscription?.cancel();
    _driverLocationSubscription = null;
    _lastPublishedAtUtc = null;
    _lastPublishedPosition = null;
  }

  Future<Map<String, dynamic>?> latestLocation(String rideOfferId) async {
    try {
      final response =
          await _apiClient.dio.get('/rides/$rideOfferId/location/latest');
      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> disconnect() async {
    final connection = _connection;
    final rideOfferId = _connectedRideOfferId;
    if (connection?.state == HubConnectionState.Connected &&
        rideOfferId != null) {
      try {
        await connection!.invoke('LeaveRide', args: [rideOfferId]);
      } catch (_) {}
    }
    await connection?.stop();
    _connection = null;
    _connectedRideOfferId = null;
  }

  Future<void> stopAll() async {
    await stopDriverLocationSharing();
    await disconnect();
  }
}

typedef VoidCallback = void Function();
