import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

import 'app_router.dart';
import '../constants/app_routes.dart';

class DeepLinkService {
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;

  Future<void> init() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) _handleUri(initialUri);
    } catch (error) {
      debugPrint('[DeepLinkService] Failed to read initial link: $error');
    }

    _subscription = _appLinks.uriLinkStream.listen(
      _handleUri,
      onError: (error) =>
          debugPrint('[DeepLinkService] Link stream error: $error'),
    );
  }

  void _handleUri(Uri uri) {
    final segments = uri.pathSegments;
    final ridesIndex = segments.indexOf('rides');
    if (ridesIndex == -1 || ridesIndex + 1 >= segments.length) return;

    final rideId = segments[ridesIndex + 1];
    if (rideId.isEmpty) return;

    AppRouter.router.push(AppRoutes.sharedRidePath(rideId));
  }

  void dispose() => _subscription?.cancel();
}
