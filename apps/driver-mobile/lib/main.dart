// Boots the driver app: Hive cache, Supabase, push, then the router.
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
  await CacheService.init();
  await SupabaseInit.ensureInitialized();
  await PushService.initialize();
  final onboardingCompleted =
      await StorageService().readValue('onboarding_completed') == 'true';
  runApp(
    ProviderScope(
      overrides: [
        routerInitialLocationProvider.overrideWithValue(
          onboardingCompleted ? '/login' : '/onboarding',
        ),
      ],
      child: const SafeShiftDriverApp(),
    ),
  );
}
