import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/deep_links/deep_link_service.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

/// Root widget for the SafeShift Driver app.
class SafeShiftDriverApp extends ConsumerStatefulWidget {
  const SafeShiftDriverApp({super.key});

  @override
  ConsumerState<SafeShiftDriverApp> createState() => _SafeShiftDriverAppState();
}

class _SafeShiftDriverAppState extends ConsumerState<SafeShiftDriverApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(deepLinkServiceProvider).start(ref.read(routerProvider));
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    ref.listen(routerProvider, (_, next) {
      ref.read(deepLinkServiceProvider).start(next);
    });
    return MaterialApp.router(
      title: 'SafeShift Driver',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
