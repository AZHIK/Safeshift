import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Handles `safeshift://` and universal links.
///
/// Supported shapes:
///   `safeshift://tracking/<jobId>`
///   `safeshift://jobs/<jobId>`
///   `https://safeshift.app/tracking/<jobId>`
///   `https://safeshift.app/jobs/<jobId>`
///   `safeshift://history/<jobId>`
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

/// Resolves a supported customer link to a GoRouter location.
///
/// Custom scheme: `safeshift://tracking/<id>` -> host is the section.
/// Universal link: `https://safeshift.app/tracking/<id>` -> first path segment.
String? deepLinkLocation(Uri uri) {
  final segments = uri.pathSegments.where((part) => part.isNotEmpty).toList();
  final host = uri.host;
  final isUniversal = host == 'safeshift.app' || host.isEmpty;
  final section = isUniversal ? (segments.isEmpty ? '' : segments.first) : host;
  final id = isUniversal
      ? (segments.length > 1 ? segments[1] : null)
      : (segments.isEmpty ? null : segments.first);

  if (id == null || id.isEmpty) return null;
  switch (section) {
    case 'tracking':
    case 'jobs':
      return '/tracking?jobId=${Uri.encodeComponent(id)}';
    case 'history':
      return '/history/${Uri.encodeComponent(id)}';
    default:
      return null;
  }
}

final deepLinkServiceProvider = Provider<DeepLinkService>((ref) {
  final service = DeepLinkService(AppLinks());
  ref.onDispose(service.stop);
  return service;
});
