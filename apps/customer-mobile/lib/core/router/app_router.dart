import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/otp_screen.dart';
import '../../features/booking/presentation/screens/booking_screen.dart';
import '../../features/booking/presentation/screens/matching_screen.dart';
import '../../features/booking/presentation/screens/quote_screen.dart';
import '../../features/delivery/presentation/screens/delivery_confirmation_screen.dart';
import '../../features/history/presentation/screens/history_screen.dart';
import '../../features/history/presentation/screens/history_detail_screen.dart';
import '../../features/ride/presentation/screens/ride_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/tracking/presentation/screens/tracking_screen.dart';

/// Provides the app router. Authenticated route redirects are intentionally
/// deferred; screens navigate directly through GoRouter.
final routerInitialLocationProvider = Provider<String>((ref) => '/login');

final routerProvider = Provider<GoRouter>((ref) {
  final initialLocation = ref.watch(routerInitialLocationProvider);
  return GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/otp', builder: (context, state) => const OtpScreen()),
      ShellRoute(
        builder: (context, state, child) => MainScaffold(child: child),
        routes: <RouteBase>[
          GoRoute(
            path: '/home',
            builder: (context, state) => const RideScreen(),
          ),
          GoRoute(
            path: '/ride',
            builder: (context, state) => const RideScreen(),
          ),
          GoRoute(
            path: '/history',
            builder: (context, state) => const HistoryScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/booking',
        builder: (context, state) => const BookingScreen(),
      ),
      GoRoute(path: '/quote', builder: (context, state) => const QuoteScreen()),
      GoRoute(
        path: '/matching',
        builder: (context, state) => const MatchingScreen(),
      ),
      GoRoute(
        path: '/tracking',
        builder: (context, state) => const TrackingScreen(),
      ),
      GoRoute(
        path: '/delivery',
        builder: (context, state) => const DeliveryConfirmationScreen(),
      ),
      GoRoute(
        path: '/history/:id',
        builder: (context, state) =>
            HistoryDetailScreen(jobId: state.pathParameters['id']!),
      ),
    ],
  );
});

/// Bottom-navigation shell for the main tabs.
class MainScaffold extends StatelessWidget {
  const MainScaffold({super.key, required this.child});

  final Widget child;

  static const List<String> _tabs = <String>['/home', '/history', '/profile'];

  int _indexFor(String location) {
    if (location.startsWith('/ride')) return 0;
    for (var i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i])) {
        return i;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final currentIndex = _indexFor(location);
    return Scaffold(
      body: child,
      // extendBody:true keeps the map + glass nav effect. The sheet
      // compensates with extra bottom padding (see RideSheetBody)
      // so the confirm CTA scrolls above the nav instead of under it.
      extendBody: true,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          border: Border(
            top: BorderSide(
              color: const Color(0xFFE1EBF2),
              width: 0.8,
            ),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A4E5E73),
              blurRadius: 24,
              offset: Offset(0, -8),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: NavigationBar(
            selectedIndex: currentIndex,
            onDestinationSelected: (index) => context.go(_tabs[index]),
            backgroundColor: Colors.transparent,
            elevation: 0,
            destinations: const <NavigationDestination>[
              NavigationDestination(
                icon: Icon(Icons.bolt_outlined),
                selectedIcon: Icon(Icons.bolt_rounded),
                label: 'Ride',
              ),
              NavigationDestination(
                icon: Icon(Icons.history_rounded),
                label: 'History',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
