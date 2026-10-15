// TODO: initialize local storage (Hive/SharedPreferences), Firebase, and dotenv
// before runApp in a later sprint. No real initialization logic yet.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/router/app_router.dart';
import 'shared/services/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
}
