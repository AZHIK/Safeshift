import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/otp_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/documents/presentation/screens/documents_screen.dart';
import '../../features/earnings/presentation/screens/earnings_screen.dart';
import '../../features/home/domain/entities/driver_status.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/home/providers/home_provider.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/phase9/presentation/phase9_screens.dart';
import '../../features/profile/presentation/screens/complete_profile_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/ratings/presentation/screens/ratings_screen.dart';
import '../../features/trips/presentation/screens/trip_detail_screen.dart';
import '../../features/trips/presentation/screens/trips_screen.dart';
import '../../features/vehicle/presentation/screens/vehicle_screen.dart';
import 'route_guards.dart';

/// Provides the app router. There is NO /job-request, NO /active-trip and
/// NO /trip-summary route — every job-flow state lives inside /home.
final routerInitialLocationProvider = Provider<String>((ref) => '/login');

final routerProvider = Provider<GoRouter>((ref) {
  final initialLocation = ref.watch(routerInitialLocationProvider);
  // Rebuild the router when auth or profile-completion state changes so the
  // redirect below always sees the latest gate values.
  final auth = ref.watch(authProvider);
  return GoRouter(
    initialLocation: initialLocation,
    redirect: (context, state) => authRedirect(
      isAuthenticated: auth.isAuthenticated,
      isInitialized: auth.isInitialized,
      isDriverRegistered: auth.driverRegistered == true,
      location: state.uri.path,
    ),
    routes: <RouteBase>[
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/otp', builder: (context, state) => const OtpScreen()),
      GoRoute(
        path: '/driver-onboarding',
        builder: (context, state) => const DriverOnboardingScreen(),
      ),
      GoRoute(
        path: '/complete-profile',
        builder: (context, state) => const CompleteProfileScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => MainScaffold(child: child),
        routes: <RouteBase>[
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/trips',
            builder: (context, state) => const TripsScreen(),
          ),
          GoRoute(
            path: '/earnings',
            builder: (context, state) => const EarningsScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/trips/:id',
        builder: (context, state) =>
            TripDetailScreen(tripId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/vehicle',
        builder: (context, state) => const VehicleScreen(),
      ),
      GoRoute(
        path: '/documents',
        builder: (context, state) => const DocumentsScreen(),
      ),
      GoRoute(
        path: '/ratings',
        builder: (context, state) => const RatingsScreen(),
      ),
      GoRoute(
        path: '/verification',
        builder: (context, state) => const DriverVerificationStatusScreen(),
      ),
      GoRoute(
        path: '/settings/notifications',
        builder: (context, state) => const NotificationPreferencesScreen(),
      ),
      GoRoute(
        path: '/settings/account',
        builder: (context, state) => const AccountSettingsScreen(),
      ),
      GoRoute(
        path: '/settings/privacy',
        builder: (context, state) => const PrivacyDataScreen(),
      ),
      GoRoute(
        path: '/disputes',
        builder: (context, state) => const DisputesListScreen(),
      ),
      GoRoute(
        path: '/disputes/new',
        builder: (context, state) => const DisputeCreateScreen(),
      ),
      GoRoute(
        path: '/disputes/:id',
        builder: (context, state) =>
            DisputeDetailScreen(disputeId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/support',
        builder: (context, state) => const SupportHomeScreen(),
      ),
      GoRoute(
        path: '/support/new',
        builder: (context, state) => const SupportCreateScreen(),
      ),
      GoRoute(
        path: '/support/:id',
        builder: (context, state) =>
            SupportDetailScreen(ticketId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/safety/contacts',
        builder: (context, state) => const EmergencyContactsScreen(),
      ),
    ],
  );
});

/// Bottom-navigation shell with FOUR tabs. The bar is hidden while the
/// driver has an active job so the whole screen becomes the job experience.
class MainScaffold extends ConsumerWidget {
  const MainScaffold({super.key, required this.child});

  final Widget child;

  static const List<String> _tabs = <String>[
    '/home',
    '/trips',
    '/earnings',
    '/profile',
  ];

  int _indexFor(String location) {
    for (var i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i])) {
        return i;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeProvider);
    final showNav = home.driverStatus.showBottomNav;
    final location = GoRouterState.of(context).uri.toString();
    final currentIndex = _indexFor(location);
    return Scaffold(
      body: child,
      extendBody: true,
      bottomNavigationBar: showNav
          ? Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                border: const Border(
                  top: BorderSide(
                    color: Color(0xFFE1EBF2),
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
                  height: 58,
                  labelBehavior:
                      NavigationDestinationLabelBehavior.alwaysShow,
                  destinations: const <NavigationDestination>[
                    NavigationDestination(
                      icon: Icon(Icons.home_outlined, size: 20),
                      selectedIcon: Icon(Icons.home_rounded, size: 20),
                      label: 'Home',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.history_rounded, size: 20),
                      label: 'Trips',
                    ),
                    NavigationDestination(
                      icon: Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 20,
                      ),
                      selectedIcon: Icon(
                        Icons.account_balance_wallet_rounded,
                        size: 20,
                      ),
                      label: 'Earnings',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.person_outline_rounded, size: 20),
                      selectedIcon: Icon(Icons.person_rounded, size: 20),
                      label: 'Profile',
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}
