import 'dart:async';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/errors/app_exception.dart';
import '../../core/utils/location_display_formatter.dart';
import '../../core/widgets/app_design_system.dart';
import '../../models/ride_models.dart';
import '../../providers/ride_provider.dart';
import '../../services/map_service.dart';
import 'ride_results_screen.dart';

class SearchRideFormScreen extends StatefulWidget {
  const SearchRideFormScreen({super.key});

  @override
  State<SearchRideFormScreen> createState() => _SearchRideFormScreenState();
}

enum _SearchMapPickField { pickup, destination }

class _SearchRideFormScreenState extends State<SearchRideFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pickupController = TextEditingController();
  final _destinationController = TextEditingController();
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final Completer<gmap.GoogleMapController> _mapController = Completer();

  DateTime _selectedDate = DateTime.now();
  int _seatsCount = 1;

  LatLng _centerLocation = const LatLng(12.9716, 77.5946);
  LatLng? _pickupLatLng;
  LatLng? _dropLatLng;

  bool _isLoadingLocation = false;
  bool _isSearching = false;
  bool _isSubmitting = false;
  bool _isLoadingRoute = false;
  bool _showSuggestions = false;
  bool _isMapReady = false;
  bool _suppressSearchOnChanged = false;

  List<Map<String, dynamic>> _searchSuggestions = const [];
  List<LatLng> _routePolylinePoints = const [];
  Map<String, dynamic>? _pickupSelection;
  Map<String, dynamic>? _destinationSelection;
  final List<String> _recentSearches = [];
  final List<String> _savedLocations = const ['Home', 'Work', 'Airport'];
  double? _distanceKm;
  int? _etaMinutes;
  String? _routeWarning;
  _SearchMapPickField _activeField = _SearchMapPickField.destination;

  Timer? _searchDebounce;
  int _searchRequestId = 0;

  LatLng? _pendingMapCenter;
  double _pendingMapZoom = 14;
  double _mapZoom = 13;

  @override
  void initState() {
    super.initState();
    _determineCurrentLocation();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _pickupController.dispose();
    _destinationController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _determineCurrentLocation() async {
    if (!mounted) return;
    setState(() => _isLoadingLocation = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        _showError('Location permission denied. Please enable GPS permission.');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );

      if (!mounted) return;
      final reverse = await context.read<MapService>().reverseGeocode(
            latitude: position.latitude,
            longitude: position.longitude,
          );
      final pickupSuggestion = LocationDisplayFormatter.fromSearchSuggestion({
        'displayName': reverse,
        'formattedAddress': reverse,
        'latitude': position.latitude,
        'longitude': position.longitude,
      });
      setState(() {
        _pickupLatLng = LatLng(position.latitude, position.longitude);
        _centerLocation = _pickupLatLng!;
        _pickupSelection = pickupSuggestion;
        _pickupController.text = pickupSuggestion['formattedAddress'].toString();
      });

      _moveMapSafely(_centerLocation, 14.5);
      await _loadRoutePreview();
    } catch (_) {
      _showError('Unable to fetch GPS location. Please retry.');
    } finally {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  void _onSearchChanged(String value) {
    if (_suppressSearchOnChanged) return;

    _searchDebounce?.cancel();
    final query = value.trim();

    if (query.length < 3) {
      if (_showSuggestions || _searchSuggestions.isNotEmpty) {
        setState(() {
          _showSuggestions = false;
          _searchSuggestions = const [];
        });
      }
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 600), () {
      _fetchSearchSuggestions(query);
    });
  }

  Future<void> _fetchSearchSuggestions(String query) async {
    final requestId = ++_searchRequestId;
    setState(() => _isSearching = true);

    try {
      final results = await context.read<MapService>().geocode(query);
      if (!mounted || requestId != _searchRequestId) return;

      final suggestions = results
          .take(5)
          .map((item) => LocationDisplayFormatter.fromSearchSuggestion(
              Map<String, dynamic>.from(item as Map)))
          .toList();

      setState(() {
        _searchSuggestions = suggestions;
        _showSuggestions = suggestions.isNotEmpty;
      });
    } catch (_) {
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _searchSuggestions = const [];
        _showSuggestions = false;
      });
    } finally {
      if (mounted && requestId == _searchRequestId) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<void> _searchLocation(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    setState(() => _isSearching = true);
    try {
      final results = await context.read<MapService>().geocode(trimmed);
      if (!mounted) return;
      if (results.isEmpty) {
        _showError('No destination found for "$trimmed".');
        return;
      }

      final first = Map<String, dynamic>.from(results.first as Map);
      await _selectSuggestion(first);
    } on DioException catch (exception) {
      _showError(_messageFromException(exception));
    } catch (_) {
      _showError('Search failed. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<void> _selectSuggestion(Map<String, dynamic> suggestion) async {
    final point = LatLng(
      (suggestion['latitude'] as num).toDouble(),
      (suggestion['longitude'] as num).toDouble(),
    );

    _applySelectionToActiveField(point, suggestion);
    setState(() {
      _showSuggestions = false;
      _searchSuggestions = const [];
      _suppressSearchOnChanged = true;
      _searchController.text = LocationDisplayFormatter.title(suggestion);
      final searched = _searchController.text.trim();
      if (searched.isNotEmpty) {
        _recentSearches.remove(searched);
        _recentSearches.insert(0, searched);
        if (_recentSearches.length > 5) {
          _recentSearches.removeLast();
        }
      }
    });
    _suppressSearchOnChanged = false;
    _searchFocusNode.unfocus();

    _moveMapSafely(point, 14.2);
    await _loadRoutePreview();
  }

  void _moveMapSafely(LatLng center, double zoom) {
    if (!_isMapReady) {
      _pendingMapCenter = center;
      _pendingMapZoom = zoom;
      return;
    }
    _mapController.future.then((controller) {
      controller.animateCamera(
        gmap.CameraUpdate.newLatLngZoom(
          gmap.LatLng(center.latitude, center.longitude),
          zoom,
        ),
      );
    });
  }

  Future<void> _setPointFromMap(LatLng point) async {
    final suggestion = await _reverseSuggestion(point);
    _applySelectionToActiveField(point, suggestion);
    if (!mounted) return;
    setState(() => _showSuggestions = false);
    await _loadRoutePreview();
  }

  void _applySelectionToActiveField(LatLng point, Map<String, dynamic> suggestion) {
    final formattedAddress =
        suggestion['formattedAddress']?.toString() ?? suggestion['displayName']?.toString() ?? 'Pinned location';
    setState(() {
      if (_activeField == _SearchMapPickField.pickup) {
        _pickupLatLng = point;
        _pickupSelection = suggestion;
        _pickupController.text = formattedAddress;
      } else {
        _dropLatLng = point;
        _destinationSelection = suggestion;
        _destinationController.text = formattedAddress;
      }
    });
  }

  Future<Map<String, dynamic>> _reverseSuggestion(LatLng point) async {
    String fullAddress = 'Pinned location';
    try {
      fullAddress = await context.read<MapService>().reverseGeocode(
            latitude: point.latitude,
            longitude: point.longitude,
          );
    } catch (_) {}
    return LocationDisplayFormatter.fromSearchSuggestion({
      'displayName': fullAddress,
      'formattedAddress': fullAddress,
      'latitude': point.latitude,
      'longitude': point.longitude,
    });
  }

  Future<void> _loadRoutePreview() async {
    if (_pickupLatLng == null || _dropLatLng == null) {
      if (!mounted) return;
      setState(() {
        _routePolylinePoints = const [];
        _distanceKm = null;
        _etaMinutes = null;
        _routeWarning = null;
      });
      return;
    }
    if (_isSamePoint(_pickupLatLng!, _dropLatLng!)) {
      setState(() {
        _routePolylinePoints = const [];
        _distanceKm = null;
        _etaMinutes = null;
        _routeWarning = 'Pickup and destination cannot be same.';
      });
      return;
    }

    setState(() {
      _isLoadingRoute = true;
      _routeWarning = null;
    });
    try {
      final route = await context.read<MapService>().route(
            fromLatitude: _pickupLatLng!.latitude,
            fromLongitude: _pickupLatLng!.longitude,
            toLatitude: _dropLatLng!.latitude,
            toLongitude: _dropLatLng!.longitude,
          );

      final distanceKm = (route['distanceKm'] as num?)?.toDouble();
      final etaMinutes = (route['etaMinutes'] as num?)?.toInt();
      final encodedPolyline = route['encodedPolyline']?.toString();
      final points = (encodedPolyline != null && encodedPolyline.isNotEmpty)
          ? _simplifyPolyline(_decodePolyline(encodedPolyline))
          : <LatLng>[];

      if (!mounted) return;
      setState(() {
        _distanceKm = distanceKm;
        _etaMinutes = etaMinutes;
        _routePolylinePoints = points;
      });
      _fitRoute(points);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _distanceKm = null;
        _etaMinutes = null;
        _routeWarning = 'Route preview unavailable right now. Please try again.';
        _routePolylinePoints = const [];
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingRoute = false);
      }
    }
  }

  Future<void> _fitRoute(List<LatLng> points) async {
    if (!_isMapReady || points.length < 2) return;
    final lats = points.map((p) => p.latitude);
    final lngs = points.map((p) => p.longitude);
    final bounds = gmap.LatLngBounds(
      southwest: gmap.LatLng(lats.reduce(math.min), lngs.reduce(math.min)),
      northeast: gmap.LatLng(lats.reduce(math.max), lngs.reduce(math.max)),
    );
    final controller = await _mapController.future;
    await controller.animateCamera(gmap.CameraUpdate.newLatLngBounds(bounds, 52));
  }

  List<LatLng> _decodePolyline(String encoded) {
    var index = 0;
    var lat = 0;
    var lng = 0;
    final coordinates = <LatLng>[];

    while (index < encoded.length) {
      var b = 0;
      var shift = 0;
      var result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20 && index < encoded.length);
      final dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20 && index < encoded.length);
      final dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      coordinates.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return coordinates;
  }

  List<LatLng> _simplifyPolyline(List<LatLng> points) {
    const maxPoints = 180;
    if (points.length <= maxPoints) return points;
    final step = (points.length / maxPoints).ceil();
    final simplified = <LatLng>[];
    for (var i = 0; i < points.length; i += step) {
      simplified.add(points[i]);
    }
    if (simplified.last != points.last) simplified.add(points.last);
    return simplified;
  }

  Future<void> _submitSearch() async {
    if (_isSubmitting) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_pickupLatLng == null || _dropLatLng == null) {
      _showError('Pickup and destination are required.');
      return;
    }

    if (_isSamePoint(_pickupLatLng!, _dropLatLng!)) {
      _showError('Pickup and destination cannot be same.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final originGeo = GeoPoint(
        name: LocationDisplayFormatter.title(_pickupSelection),
        address: _pickupController.text.trim(),
        latitude: _pickupLatLng!.latitude,
        longitude: _pickupLatLng!.longitude,
      );
      final destGeo = GeoPoint(
        name: LocationDisplayFormatter.title(_destinationSelection),
        address: _destinationController.text.trim(),
        latitude: _dropLatLng!.latitude,
        longitude: _dropLatLng!.longitude,
      );

      await context.read<RideProvider>().search(
            originGeo,
            destGeo,
            _seatsCount,
            departureDateUtc: _selectedDate.toUtc(),
          );

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RideResultsScreen(
            pickup: LocationDisplayFormatter.title(_pickupSelection),
            destination: LocationDisplayFormatter.title(_destinationSelection),
          ),
        ),
      );
    } on DioException catch (exception) {
      _showError(_messageFromException(exception));
    } catch (error) {
      _showError(error.toString());
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  bool _isSamePoint(LatLng a, LatLng b) {
    return (a.latitude - b.latitude).abs() < 0.0001 &&
        (a.longitude - b.longitude).abs() < 0.0001;
  }

  String _messageFromException(DioException exception) {
    final err = exception.error;
    if (err is AppException) {
      return err.message;
    }
    return AppException.fromDio(exception).message;
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _clearPickup() async {
    setState(() {
      _pickupLatLng = null;
      _pickupSelection = null;
      _pickupController.clear();
      _activeField = _SearchMapPickField.pickup;
      _routeWarning = null;
    });
    await _loadRoutePreview();
  }

  Future<void> _clearDestination() async {
    setState(() {
      _dropLatLng = null;
      _destinationSelection = null;
      _destinationController.clear();
      _activeField = _SearchMapPickField.destination;
      _routeWarning = null;
    });
    await _loadRoutePreview();
  }

  @override
  Widget build(BuildContext context) {
    const accent = AppDesignTokens.brandStart;
    const pageBg = AppDesignTokens.pageBg;
    final nearbyRides = context.select<RideProvider, List<RideOffer>>(
      (p) => p.rides.take(12).toList(growable: false),
    );
    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        title: const Text('Search Ride'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                  const AppGradientHeroCard(
                    title: 'Search Ride',
                    subtitle: 'Find your next ride with live route preview',
                    icon: Icons.travel_explore,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _pickupController,
                    readOnly: true,
                    onTap: () => setState(() => _activeField = _SearchMapPickField.pickup),
                    decoration: InputDecoration(
                      labelText: 'Pickup Location',
                      prefixIcon:
                          const Icon(Icons.my_location, color: Colors.green),
                      suffixIcon: _isLoadingLocation
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: Padding(
                                padding: EdgeInsets.all(12),
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_pickupLatLng != null)
                                  IconButton(
                                    tooltip: 'Clear pickup',
                                    icon: const Icon(Icons.close),
                                    onPressed: _clearPickup,
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.refresh),
                                  onPressed: _determineCurrentLocation,
                                ),
                              ],
                            ),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (_) => _pickupLatLng == null
                        ? 'Pickup location required'
                        : null,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            labelText: _activeField == _SearchMapPickField.pickup ? 'Search Pickup' : 'Search Destination',
                            hintText: 'Type area/city',
                            prefixIcon:
                                const Icon(Icons.search, color: Colors.orange),
                            suffixIcon: _isSearching
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: Padding(
                                      padding: EdgeInsets.all(12),
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    ),
                                  )
                                : null,
                            border: const OutlineInputBorder(),
                          ),
                          onChanged: _onSearchChanged,
                          onFieldSubmitted: _searchLocation,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _isSearching
                            ? null
                            : () => _searchLocation(_searchController.text),
                        icon: const Icon(Icons.search),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_showSuggestions)
                    Container(
                      constraints: const BoxConstraints(maxHeight: 220),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _searchSuggestions.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final suggestion = _searchSuggestions[index];
                          return ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            leading: const Icon(Icons.place_outlined),
                            title: Text(
                              LocationDisplayFormatter.title(suggestion),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              LocationDisplayFormatter.subtitle(suggestion),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => _selectSuggestion(suggestion),
                          );
                        },
                      ),
                    ),
                  if (_showSuggestions) const SizedBox(height: 8),
                  if (_recentSearches.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Recent searches',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _recentSearches
                          .map(
                            (s) => ActionChip(
                              avatar: const Icon(Icons.history, size: 16),
                              label: Text(s, overflow: TextOverflow.ellipsis),
                              onPressed: () => _searchLocation(s),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Saved places',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _savedLocations
                        .map(
                          (label) => ActionChip(
                            avatar: const Icon(Icons.bookmark_border, size: 16),
                            label: Text(label),
                            onPressed: () {
                              if (label == 'Airport') {
                                _searchLocation('Airport');
                              } else if (label == 'Home') {
                                _searchLocation('Home');
                              } else {
                                _searchLocation('Work');
                              }
                            },
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _destinationController,
                    readOnly: true,
                    onTap: () => setState(() => _activeField = _SearchMapPickField.destination),
                    decoration: InputDecoration(
                      labelText: 'Destination',
                      hintText: 'Tap map or use search',
                      prefixIcon: const Icon(Icons.location_on, color: Colors.red),
                      suffixIcon: _dropLatLng == null
                          ? null
                          : IconButton(
                              tooltip: 'Clear destination',
                              icon: const Icon(Icons.close),
                              onPressed: _clearDestination,
                            ),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (_) =>
                        _dropLatLng == null ? 'Destination required' : null,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Pickup'),
                        selected: _activeField == _SearchMapPickField.pickup,
                        onSelected: (_) => setState(() => _activeField = _SearchMapPickField.pickup),
                      ),
                      ChoiceChip(
                        label: const Text('Destination'),
                        selected: _activeField == _SearchMapPickField.destination,
                        onSelected: (_) => setState(() => _activeField = _SearchMapPickField.destination),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 8),
                          title: Text(
                            'Date: ${_selectedDate.toLocal().toString().split(' ').first}',
                            style: const TextStyle(fontSize: 14),
                          ),
                          trailing: const Icon(Icons.calendar_today, size: 20),
                          shape: RoundedRectangleBorder(
                            side: BorderSide(
                                color: Theme.of(context).colorScheme.outline),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate,
                              firstDate: DateTime.now(),
                              lastDate:
                                  DateTime.now().add(const Duration(days: 30)),
                            );
                            if (picked != null) {
                              setState(() => _selectedDate = picked);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: Theme.of(context).colorScheme.outline),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: _seatsCount > 1
                                  ? () => setState(() => _seatsCount--)
                                  : null,
                              icon: const Icon(Icons.remove_circle_outline,
                                  size: 20),
                            ),
                            Text(
                              '$_seatsCount',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            IconButton(
                              onPressed: _seatsCount < 6
                                  ? () => setState(() => _seatsCount++)
                                  : null,
                              icon: const Icon(Icons.add_circle_outline,
                                  size: 20),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_isLoadingRoute) const LinearProgressIndicator(),
                  if (_distanceKm != null && _etaMinutes != null)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.route),
                        title: Text(
                            'Distance: ${_distanceKm!.toStringAsFixed(1)} km'),
                        subtitle: Text('ETA: $_etaMinutes min'),
                      ),
                    ),
                  if (_routeWarning != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _routeWarning!,
                        style: const TextStyle(color: Colors.orange),
                      ),
                    ),
                  SizedBox(
                    height: 280,
                    child: RepaintBoundary(
                      child: Stack(
                        children: [
                          Material(
                            elevation: 4,
                            borderRadius: BorderRadius.circular(18),
                            clipBehavior: Clip.antiAlias,
                            child: gmap.GoogleMap(
                              initialCameraPosition: gmap.CameraPosition(
                                target: gmap.LatLng(
                                  _centerLocation.latitude,
                                  _centerLocation.longitude,
                                ),
                                zoom: 13,
                              ),
                              onMapCreated: (controller) {
                                if (!_mapController.isCompleted) {
                                  _mapController.complete(controller);
                                }
                                _isMapReady = true;
                                final pending = _pendingMapCenter;
                                if (pending != null) {
                                  controller.animateCamera(
                                    gmap.CameraUpdate.newLatLngZoom(
                                      gmap.LatLng(
                                        pending.latitude,
                                        pending.longitude,
                                      ),
                                      _pendingMapZoom,
                                    ),
                                  );
                                  _pendingMapCenter = null;
                                }
                              },
                              myLocationEnabled: true,
                              myLocationButtonEnabled: false,
                              zoomControlsEnabled: false,
                              compassEnabled: true,
                              mapToolbarEnabled: false,
                              onCameraMove: (position) => _mapZoom = position.zoom,
                              minMaxZoomPreference:
                                  const gmap.MinMaxZoomPreference(4, 18),
                              onTap: (point) => _setPointFromMap(
                                LatLng(point.latitude, point.longitude),
                              ),
                              markers: {
                                if (_pickupLatLng != null)
                                  gmap.Marker(
                                    markerId: const gmap.MarkerId('pickup'),
                                    position: gmap.LatLng(
                                      _pickupLatLng!.latitude,
                                      _pickupLatLng!.longitude,
                                    ),
                                    icon: gmap.BitmapDescriptor.defaultMarkerWithHue(
                                      gmap.BitmapDescriptor.hueGreen,
                                    ),
                                  ),
                                if (_dropLatLng != null)
                                  gmap.Marker(
                                    markerId: const gmap.MarkerId('drop'),
                                    position: gmap.LatLng(
                                      _dropLatLng!.latitude,
                                      _dropLatLng!.longitude,
                                    ),
                                    icon: gmap.BitmapDescriptor.defaultMarkerWithHue(
                                      gmap.BitmapDescriptor.hueRed,
                                    ),
                                  ),
                                ...nearbyRides.map(
                                      (ride) => gmap.Marker(
                                        markerId:
                                            gmap.MarkerId('ride-${ride.id}'),
                                        position: gmap.LatLng(
                                          ride.origin.latitude,
                                          ride.origin.longitude,
                                        ),
                                        icon: gmap.BitmapDescriptor
                                            .defaultMarkerWithHue(
                                          gmap.BitmapDescriptor.hueAzure,
                                        ),
                                        infoWindow: gmap.InfoWindow(
                                          title: ride.driverName.isEmpty
                                              ? 'Ride'
                                              : ride.driverName,
                                          snippet: '\u20B9${ride.pricePerSeat} • ${ride.availableSeats} seats',
                                        ),
                                      ),
                                    ),
                              },
                              polylines: {
                                if (_routePolylinePoints.length >= 2)
                                  gmap.Polyline(
                                    polylineId:
                                        const gmap.PolylineId('search_route'),
                                    points: _routePolylinePoints
                                        .map((p) => gmap.LatLng(
                                            p.latitude, p.longitude))
                                        .toList(),
                                    width: 5,
                                    color: AppDesignTokens.brandStart,
                                    geodesic: true,
                                    startCap: gmap.Cap.roundCap,
                                    endCap: gmap.Cap.roundCap,
                                  ),
                              },
                            ),
                          ),
                          Positioned(
                            bottom: 12,
                            right: 12,
                            child: AppMapControls(
                              onZoomIn: () => _moveMapSafely(
                                _dropLatLng ?? _pickupLatLng ?? _centerLocation,
                                (_mapZoom + 1).clamp(4, 18).toDouble(),
                              ),
                              onZoomOut: () => _moveMapSafely(
                                _dropLatLng ?? _pickupLatLng ?? _centerLocation,
                                (_mapZoom - 1).clamp(4, 18).toDouble(),
                              ),
                              onRecenter: () => _moveMapSafely(
                                _pickupLatLng ?? _centerLocation,
                                15,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSubmitting ? null : _submitSearch,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                  label: Text(_isSubmitting ? 'Searching...' : 'Find Rides'),
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}




