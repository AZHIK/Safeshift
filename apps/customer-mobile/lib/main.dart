// Boots the customer app: Hive cache, Supabase, then the router.
// Push notifications are initialized after first frame to reduce startup jank.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/cache/cache_service.dart';
import 'core/network/supabase_init.dart';
import 'core/notifications/push_service.dart';
import 'core/router/app_router.dart';
import 'shared/services/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait<void>([
    CacheService.init(),
    SupabaseInit.ensureInitialized(),
  ]);
  final onboardingCompleted =
      await StorageService().readValue('onboarding_completed') == 'true';
  runApp(
    ProviderScope(
      overrides: [
        routerInitialLocationProvider.overrideWithValue(
          onboardingCompleted ? '/login' : '/onboarding',
        ),
      ],
      child: const SafeShiftApp(),
    ),
  );
  // Defer non-critical push setup so the first frame renders sooner.
  unawaited(PushService.initialize());
}
