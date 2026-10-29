import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Handles `safeshift://` and universal links for the driver app.
///
/// A job link opens the active-job home flow. History links open /trips.
class DeepLinkService {
  DeepLinkService(this._appLinks);

  final AppLinks _appLinks;
  StreamSubscription<Uri>? _subscription;
  GoRouter? _router;

  Future<void> start(GoRouter router) async {
    _router = router;
    if (_subscription != null) return;
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) _handle(initial);
    } catch (error) {
      debugPrint('Initial deep link unavailable: $error');
    }
    _subscription ??= _appLinks.uriLinkStream.listen(
      _handle,
      onError: (Object error) => debugPrint('Deep link error: $error'),
    );
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
    _router = null;
  }

  void _handle(Uri uri) {
    final router = _router;
    if (router == null) return;
    final location = deepLinkLocation(uri);
    if (location == null) {
      debugPrint('Unhandled deep link: $uri');
      return;
    }
    router.go(location);
  }
}

/// Resolves a supported driver link to a GoRouter location.
///
/// Job links always open the active-job home flow; history links open trips.
String? deepLinkLocation(Uri uri) {
  final segments = uri.pathSegments.where((part) => part.isNotEmpty).toList();
  final host = uri.host;
  final isUniversal = host == 'safeshift.app' || host.isEmpty;
  final section = isUniversal ? (segments.isEmpty ? '' : segments.first) : host;

  switch (section) {
    case 'tracking':
    case 'jobs':
    case 'home':
      return '/home';
    case 'trips':
    case 'history':
      return '/trips';
    default:
      return null;
  }
}

final deepLinkServiceProvider = Provider<DeepLinkService>((ref) {
  final service = DeepLinkService(AppLinks());
  ref.onDispose(service.stop);
  return service;
});
