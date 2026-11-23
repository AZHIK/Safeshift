import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:safeshift_shared/safeshift_shared.dart' show InboxListener;

import 'core/network/supabase_client.dart';
import 'features/auth/providers/auth_provider.dart';
import 'core/deep_links/deep_link_service.dart';
import 'core/notifications/push_service.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

/// Root widget for the SafeShift Driver app.
class SafeShiftDriverApp extends ConsumerStatefulWidget {
  const SafeShiftDriverApp({super.key});

  @override
  ConsumerState<SafeShiftDriverApp> createState() => _SafeShiftDriverAppState();
}

class _SafeShiftDriverAppState extends ConsumerState<SafeShiftDriverApp> {
  StreamSubscription<String>? _pushLinks;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(deepLinkServiceProvider).start(ref.read(routerProvider));

      // An offer notification opens the home screen, where the offer inbox
      // already lives.
      _pushLinks = PushService.deepLinks.listen(_openPushLink);
      final pending = PushService.takePendingDeepLink();
      if (pending != null) _openPushLink(pending);
    });
  }

  void _openPushLink(String link) {
    final uri = Uri.tryParse(link);
    if (uri == null) return;
    final location = deepLinkLocation(uri);
    if (location == null) return;
    ref.read(routerProvider).go(location);
  }

  @override
  void dispose() {
    _pushLinks?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final profileId = ref.watch(
      authProvider.select(
        (state) => state.isAuthenticated ? state.currentUser?.id : null,
      ),
    );
    final inboxClient = profileId == null ? null : ref.watch(supabaseProvider);
    ref.listen(routerProvider, (_, next) {
      ref.read(deepLinkServiceProvider).start(next);
    });
    return MaterialApp.router(
      title: 'SafeShift Driver',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: Theme.of(context).appBarTheme.systemOverlayStyle!,
        child: inboxClient == null || profileId == null
            ? child!
            : InboxListener(
                key: ValueKey(profileId),
                client: inboxClient,
                profileId: profileId,
                onOpen: () => router.push('/settings/notifications'),
                child: child!,
              ),
      ),
      routerConfig: router,
    );
  }
}
