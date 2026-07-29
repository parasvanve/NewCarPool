import 'dart:async';

import 'package:app_links/app_links.dart';

class DeepLinkService {
  DeepLinkService._();

  static final DeepLinkService instance = DeepLinkService._();

  final AppLinks _appLinks = AppLinks();

  StreamSubscription? _subscription;

  void initialize(
    void Function(Uri uri) onLinkReceived,
  ) {
    _subscription?.cancel();

    _subscription = _appLinks.uriLinkStream.listen(
      (Uri uri) {
        onLinkReceived(uri);
      },
      onError: (error) {
        print(error);
      },
    );
  }

  Future<Uri?> getInitialLink() async {
    return await _appLinks.getInitialLink();
  }

  void dispose() {
    _subscription?.cancel();
  }
}
