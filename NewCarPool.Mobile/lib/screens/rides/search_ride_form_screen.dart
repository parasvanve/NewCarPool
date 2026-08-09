import 'dart:async';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/errors/app_exception.dart';
import '../../core/utils/location_permission_helper.dart';
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
  final _pickupFocusNode = FocusNode();
  final _destinationFocusNode = FocusNode();
  final Completer<gmap.GoogleMapController> _mapController = Completer();

  DateTime _selectedDate = DateTime.now();
  int _seatsCount = 1;

  LatLng _centerLocation = const LatLng(
    LocationPermissionHelper.indoreLatitude,
    LocationPermissionHelper.indoreLongitude,
  );
  LatLng? _pickupLatLng;
  LatLng? _dropLatLng;

  bool _isLoadingLocation = false;
  bool _isSearching = false;
  bool _isSubmitting = false;
  bool _isLoadingRoute = false;
  bool _showSuggestions = false;
  bool _isMapReady = false;
  bool _canShowMyLocation = false;
  bool _suppressSearchOnChanged = false;

  List<Map<String, dynamic>> _searchSuggestions = const [];
  List<LatLng> _routePolylinePoints = const [];
  Map<String, dynamic>? _pickupSelection;
  Map<String, dynamic>? _destinationSelection;
  final List<String> _recentSearches = ['TCS Canteen', 'Footi Kothi Road'];
  final List<String> _savedLocations = const ['Home', 'Work', 'Airport'];
  double? _distanceKm;
  int? _etaMinutes;
  String? _routeWarning;
  _SearchMapPickField _activeField = _SearchMapPickField.pickup;

  Timer? _searchDebounce;
  int _searchRequestId = 0;

  LatLng? _pendingMapCenter;
  double _pendingMapZoom = 14;
  double _mapZoom = 13;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _pickupController.dispose();
    _destinationController.dispose();
    _pickupFocusNode.dispose();
    _destinationFocusNode.dispose();
    super.dispose();
  }

  Future<void> _determineCurrentLocation() async {
    if (!mounted) return;
    setState(() => _isLoadingLocation = true);
    try {
      final location = await LocationPermissionHelper.currentOrFallback(
        deniedMessage:
            'Location permission is required to use current location.',
      );

      if (!mounted) return;
      final point = LatLng(location.latitude, location.longitude);
      setState(() {
        _centerLocation = point;
        _canShowMyLocation = location.hasPermission;
      });
      _moveMapSafely(point, 14.5);

      if (!location.hasPermission) {
        _showError('Location permission is required to use current location.');
        return;
      }

      final reverse = await context.read<MapService>().reverseGeocode(
            latitude: location.latitude,
            longitude: location.longitude,
          );
      final pickupSuggestion = LocationDisplayFormatter.fromSearchSuggestion({
        'displayName': reverse,
        'formattedAddress': reverse,
        'latitude': location.latitude,
        'longitude': location.longitude,
      });
      setState(() {
        _pickupLatLng = point;
        _centerLocation = _pickupLatLng!;
        _pickupSelection = pickupSuggestion;
        _pickupController.text =
            pickupSuggestion['formattedAddress'].toString();
        _activeField = _SearchMapPickField.destination;
      });

      await _loadRoutePreview();
    } catch (_) {
      _showError('Unable to fetch GPS location. Please retry.');
    } finally {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  void _onSearchChanged(_SearchMapPickField field, String value) {
    if (_suppressSearchOnChanged) return;
    _activeField = field;

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

    setState(() {
      _showSuggestions = true;
      _searchSuggestions = const [];
    });

    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _fetchSearchSuggestions(query);
    });
  }

  Future<void> _fetchSearchSuggestions(String query) async {
    final requestId = ++_searchRequestId;
    setState(() => _isSearching = true);

    try {
      final results = await context.read<MapService>().geocode(
            query,
            latitude: _centerLocation.latitude,
            longitude: _centerLocation.longitude,
          );
      if (!mounted || requestId != _searchRequestId) return;

      final suggestions = results
          .take(5)
          .map((item) => LocationDisplayFormatter.fromSearchSuggestion(
              Map<String, dynamic>.from(item as Map)))
          .toList();

      setState(() {
        _searchSuggestions = suggestions;
        _showSuggestions = true;
      });
    } catch (_) {
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _searchSuggestions = const [];
        _showSuggestions = true;
      });
    } finally {
      if (mounted && requestId == _searchRequestId) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<void> _searchLocation(
    String query, {
    _SearchMapPickField? field,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    if (field != null) {
      setState(() => _activeField = field);
    }
    setState(() => _isSearching = true);
    try {
      final results = await context.read<MapService>().geocode(
            trimmed,
            latitude: _centerLocation.latitude,
            longitude: _centerLocation.longitude,
          );
      if (!mounted) return;
      if (results.isEmpty) {
        _showError('No locations found.');
        return;
      }

      final first = LocationDisplayFormatter.fromSearchSuggestion(
        Map<String, dynamic>.from(results.first as Map),
      );
      await _selectSuggestion(first, field: field);
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

  Future<void> _selectSuggestion(
    Map<String, dynamic> suggestion, {
    _SearchMapPickField? field,
  }) async {
    final point = LatLng(
      (suggestion['latitude'] as num).toDouble(),
      (suggestion['longitude'] as num).toDouble(),
    );

    _applySelectionToActiveField(point, suggestion, field: field);
    setState(() {
      _showSuggestions = false;
      _searchSuggestions = const [];
      _suppressSearchOnChanged = true;
      final searched = LocationDisplayFormatter.title(suggestion).trim();
      if (searched.isNotEmpty) {
        _recentSearches.remove(searched);
        _recentSearches.insert(0, searched);
        if (_recentSearches.length > 5) {
          _recentSearches.removeLast();
        }
      }
    });
    _suppressSearchOnChanged = false;
    _pickupFocusNode.unfocus();
    _destinationFocusNode.unfocus();

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

  void _applySelectionToActiveField(
    LatLng point,
    Map<String, dynamic> suggestion, {
    _SearchMapPickField? field,
  }) {
    final formattedAddress = suggestion['formattedAddress']?.toString() ??
        suggestion['displayName']?.toString() ??
        'Pinned location';
    final targetField = field ?? _activeField;
    setState(() {
      if (targetField == _SearchMapPickField.pickup) {
        _pickupLatLng = point;
        _pickupSelection = suggestion;
        _pickupController.text = formattedAddress;
        _activeField = _SearchMapPickField.destination;
      } else {
        _dropLatLng = point;
        _destinationSelection = suggestion;
        _destinationController.text = formattedAddress;
        _activeField = _SearchMapPickField.destination;
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
      _fitSelectedLocations(points);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _distanceKm = null;
        _etaMinutes = null;
        _routeWarning =
            'Route preview unavailable right now. Please try again.';
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
    await controller
        .animateCamera(gmap.CameraUpdate.newLatLngBounds(bounds, 52));
  }

  Future<void> _fitSelectedLocations(List<LatLng> routePoints) async {
    if (!_isMapReady || _pickupLatLng == null || _dropLatLng == null) return;
    final points = routePoints.length >= 2
        ? routePoints
        : <LatLng>[_pickupLatLng!, _dropLatLng!];
    await _fitRoute(points);
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

    if (_seatsCount < 1) {
      _showError('Select at least 1 seat.');
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  String _formattedDate(DateTime date) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final local = date.toLocal();
    return '${weekdays[local.weekday - 1]}, ${local.day.toString().padLeft(2, '0')} ${months[local.month - 1]} ${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    // const accent = AppDesignTokens.brandStart;
    // const pageBg = AppDesignTokens.pageBg;
    // return Scaffold(
    //   backgroundColor: pageBg,
    //   appBar: AppBar(
    //     title: const Text('Search Ride'),
    //     backgroundColor: Colors.white,
    //     surfaceTintColor: Colors.white,
    //     elevation: 0,
    //   ),

    //new code
    const accent = AppDesignTokens.brandStart;
    final pageBg = AppDesignTokens.pageBackground(context);
    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        title: const Text('Search Ride'),
        backgroundColor: AppDesignTokens.surface(context),
        surfaceTintColor: AppDesignTokens.surface(context),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 920;
            return Column(
              children: [
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1240),
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(
                          isWide ? 24 : 14,
                          16,
                          isWide ? 24 : 14,
                          isWide ? 24 : 104,
                        ),
                        children: [_buildSearchShell(context, isWide)],
                      ),
                    ),
                  ),
                ),
                if (!isWide)
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                      child: _buildFindButton(accent),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSearchShell(BuildContext context, bool isWide) {
    final formControls = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLocationSection(
          field: _SearchMapPickField.pickup,
          label: 'Pickup location',
          hint: 'Search pickup location',
          controller: _pickupController,
          focusNode: _pickupFocusNode,
          icon: Icons.trip_origin,
          iconColor: const Color(0xFF16A34A),
          selected: _pickupLatLng != null,
          onClear: _clearPickup,
          validatorText: 'Pickup required',
          showCurrentLocation: true,
        ),
        const SizedBox(height: 16),
        _buildLocationSection(
          field: _SearchMapPickField.destination,
          label: 'Destination',
          hint: 'Search destination',
          controller: _destinationController,
          focusNode: _destinationFocusNode,
          icon: Icons.location_on,
          iconColor: const Color(0xFFEF4444),
          selected: _dropLatLng != null,
          onClear: _clearDestination,
          validatorText: 'Destination required',
        ),
        const SizedBox(height: 14),
        _buildSelectedSummary(),
        const SizedBox(height: 16),
        _buildPlaceChips(
          title: 'Recent searches',
          icon: Icons.history,
          labels: _recentSearches,
        ),
        const SizedBox(height: 12),
        _buildPlaceChips(
          title: 'Saved places',
          icon: Icons.bookmark_border,
          labels: _savedLocations,
        ),
        const SizedBox(height: 18),
        _buildDateSeatsRow(isWide),
        if (isWide) ...[
          const SizedBox(height: 18),
          _buildFindButton(AppDesignTokens.brandStart),
        ],
      ],
    );

    final content = isWide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 46, child: formControls),
              const SizedBox(width: 20),
              Expanded(flex: 54, child: _buildMapCard(height: 470)),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              formControls,
              const SizedBox(height: 18),
              _buildMapCard(height: 230),
            ],
          );

    return Container(
      padding: EdgeInsets.all(isWide ? 22 : 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E7F3)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          const AppGradientHeroCard(
            title: 'Search Ride',
            subtitle: 'Find your next ride quickly and clearly',
            icon: Icons.travel_explore,
          ),
          SizedBox(height: isWide ? 22 : 18),
          content,
        ],
      ),
    );
  }

  Widget _buildLocationSection({
    required _SearchMapPickField field,
    required String label,
    required String hint,
    required TextEditingController controller,
    required FocusNode focusNode,
    required IconData icon,
    required Color iconColor,
    required bool selected,
    required VoidCallback onClear,
    required String validatorText,
    bool showCurrentLocation = false,
  }) {
    final isActive = _activeField == field;
    final showSuggestions = _showSuggestions && isActive;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF111827),
                    ),
              ),
            ),
            if (showCurrentLocation)
              OutlinedButton.icon(
                onPressed:
                    _isLoadingLocation ? null : _determineCurrentLocation,
                icon: _isLoadingLocation
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location, size: 18),
                label: const Text('Use Current Location'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppDesignTokens.brandStart,
                  side: const BorderSide(color: Color(0xFFD7DBFF)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          textInputAction: TextInputAction.search,
          onTap: () => setState(() => _activeField = field),
          onChanged: (value) => _onSearchChanged(field, value),
          onFieldSubmitted: (value) => _searchLocation(value, field: field),
          validator: (_) => selected ? null : validatorText,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isSearching && isActive)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                if (selected)
                  IconButton(
                    tooltip: field == _SearchMapPickField.pickup
                        ? 'Clear pickup'
                        : 'Clear destination',
                    icon: const Icon(Icons.cancel, color: Color(0xFF9CA3AF)),
                    onPressed: onClear,
                  ),
              ],
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFD6DAE8)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isActive
                    ? AppDesignTokens.brandStart
                    : const Color(0xFFD6DAE8),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppDesignTokens.brandStart,
                width: 1.5,
              ),
            ),
          ),
        ),
        if (showSuggestions) ...[
          const SizedBox(height: 6),
          _buildSuggestionsPanel(field),
        ],
      ],
    );
  }

  Widget _buildSuggestionsPanel(_SearchMapPickField field) {
    Widget child;
    if (_isSearching) {
      child = const Padding(
        padding: EdgeInsets.all(18),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Searching locations...'),
          ],
        ),
      );
    } else if (_searchSuggestions.isEmpty) {
      child = const Padding(
        padding: EdgeInsets.all(18),
        child: Text('No locations found'),
      );
    } else {
      child = ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _searchSuggestions.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final suggestion = _searchSuggestions[index];
          return ListTile(
            dense: true,
            leading: const Icon(
              Icons.place_outlined,
              color: Color(0xFF4F46E5),
            ),
            title: Text(
              LocationDisplayFormatter.title(suggestion),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              LocationDisplayFormatter.subtitleWithDistance(suggestion),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => _selectSuggestion(suggestion, field: field),
          );
        },
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 260),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE1E5F2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: child,
      ),
    );
  }

  Widget _buildSelectedSummary() {
    if (_pickupLatLng == null && _dropLatLng == null) {
      return const SizedBox.shrink();
    }
    return Row(
      children: [
        Expanded(
          child: _SelectedLocationCard(
            label: 'Pickup',
            title: _pickupLatLng == null
                ? 'Choose pickup'
                : LocationDisplayFormatter.title(_pickupSelection),
            color: const Color(0xFF16A34A),
            onClear: _pickupLatLng == null ? null : _clearPickup,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SelectedLocationCard(
            label: 'Destination',
            title: _dropLatLng == null
                ? 'Choose destination'
                : LocationDisplayFormatter.title(_destinationSelection),
            color: const Color(0xFFEF4444),
            onClear: _dropLatLng == null ? null : _clearDestination,
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceChips({
    required String title,
    required IconData icon,
    required List<String> labels,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF111827),
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: labels
              .map(
                (label) => ActionChip(
                  avatar:
                      Icon(icon, size: 16, color: AppDesignTokens.brandStart),
                  label: Text(label, overflow: TextOverflow.ellipsis),
                  backgroundColor: const Color(0xFFF8FAFF),
                  side: const BorderSide(color: Color(0xFFDDE2FF)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onPressed: () => _searchLocation(label, field: _activeField),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildDateSeatsRow(bool isWide) {
    return Row(
      children: [
        Expanded(
          child: _DateSeatCard(
            icon: Icons.calendar_today_outlined,
            label: 'Date',
            value: _formattedDate(_selectedDate),
            onTap: _pickDate,
            trailing: const Icon(Icons.keyboard_arrow_down),
          ),
        ),
        SizedBox(width: isWide ? 14 : 10),
        Expanded(
          child: _DateSeatCard(
            icon: Icons.groups_outlined,
            label: 'Seats',
            value: '$_seatsCount ${_seatsCount == 1 ? 'seat' : 'seats'}',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Decrease seats',
                  onPressed: _seatsCount > 1
                      ? () => setState(() => _seatsCount--)
                      : null,
                  icon: const Icon(Icons.remove),
                ),
                IconButton(
                  tooltip: 'Increase seats',
                  onPressed: _seatsCount < 6
                      ? () => setState(() => _seatsCount++)
                      : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMapCard({required double height}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.map_outlined, color: AppDesignTokens.brandStart),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Map preview',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            if (_distanceKm != null && _etaMinutes != null)
              Text(
                '${_distanceKm!.toStringAsFixed(1)} km - $_etaMinutes min',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF475569),
                      fontWeight: FontWeight.w700,
                    ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (_isLoadingRoute) const LinearProgressIndicator(minHeight: 2),
        if (_routeWarning != null) ...[
          const SizedBox(height: 8),
          Text(
            _routeWarning!,
            style: const TextStyle(
              color: Color(0xFFB45309),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 8),
        SizedBox(
          height: height,
          child: RepaintBoundary(
            child: Stack(
              children: [
                Material(
                  elevation: 0,
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
                            gmap.LatLng(pending.latitude, pending.longitude),
                            _pendingMapZoom,
                          ),
                        );
                        _pendingMapCenter = null;
                      }
                    },
                    myLocationEnabled: _canShowMyLocation,
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
                          markerId: const gmap.MarkerId('destination'),
                          position: gmap.LatLng(
                            _dropLatLng!.latitude,
                            _dropLatLng!.longitude,
                          ),
                          icon: gmap.BitmapDescriptor.defaultMarkerWithHue(
                            gmap.BitmapDescriptor.hueRed,
                          ),
                        ),
                    },
                    polylines: {
                      if (_routePolylinePoints.length >= 2)
                        gmap.Polyline(
                          polylineId: const gmap.PolylineId('search_route'),
                          points: _routePolylinePoints
                              .map((p) => gmap.LatLng(p.latitude, p.longitude))
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
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1A0F172A),
                          blurRadius: 16,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Text(
                      _activeField == _SearchMapPickField.pickup
                          ? 'Tap map to set pickup'
                          : 'Tap map to set destination',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
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
    );
  }

  Widget _buildFindButton(Color accent) {
    return SizedBox(
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
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _SelectedLocationCard extends StatelessWidget {
  const _SelectedLocationCard({
    required this.label,
    required this.title,
    required this.color,
    required this.onClear,
  });

  final String label;
  final String title;
  final Color color;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE1E5F2)),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          if (onClear != null)
            IconButton(
              tooltip: 'Clear $label',
              onPressed: onClear,
              icon: const Icon(Icons.close, size: 18),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}

class _DateSeatCard extends StatelessWidget {
  const _DateSeatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE1E5F2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF334155)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
