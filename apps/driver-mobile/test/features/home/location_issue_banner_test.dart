import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safeshift_driver/core/config/mock_mode.dart';
import 'package:safeshift_driver/features/home/domain/entities/home_state.dart';
import 'package:safeshift_driver/features/home/presentation/widgets/location_issue_banner.dart';
import 'package:safeshift_driver/features/home/providers/home_provider.dart';

class _RecordingHome extends HomeNotifier {
  int fixes = 0;
  int dismissals = 0;

  @override
  HomeState build() => const HomeState(isMockMode: true);

  @override
  Future<void> fixLocation() async => fixes++;

  @override
  void dismissLocationIssue() => dismissals++;
}

Future<_RecordingHome> _pump(
  WidgetTester tester,
  LocationIssue issue, {
  required bool offline,
}) async {
  final notifier = _RecordingHome();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mockEnabledProvider.overrideWith((ref) => true),
        homeProvider.overrideWith(() => notifier),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: LocationIssueBanner(issue: issue, offline: offline),
        ),
      ),
    ),
  );
  return notifier;
}

void main() {
  testWidgets('location off while offline explains and can be dismissed', (
    tester,
  ) async {
    final home = await _pump(tester, LocationIssue.serviceOff, offline: true);
    expect(find.text('Location is off'), findsOneWidget);
    expect(find.textContaining('to go online'), findsOneWidget);

    await tester.tap(find.text('Turn on'));
    expect(home.fixes, 1);
    await tester.tap(find.byTooltip('Dismiss'));
    expect(home.dismissals, 1);
  });

  testWidgets('location off while online is urgent and not dismissible', (
    tester,
  ) async {
    await _pump(tester, LocationIssue.serviceOff, offline: false);
    expect(find.textContaining('can’t see where you are'), findsOneWidget);
    expect(find.byTooltip('Dismiss'), findsNothing);
  });

  testWidgets('blocked permission points to Settings', (tester) async {
    await _pump(tester, LocationIssue.permissionBlocked, offline: true);
    expect(find.text('Location access is blocked'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  test('copyWith keeps, replaces, and clears the location issue', () {
    const base = HomeState(locationIssue: LocationIssue.serviceOff);
    expect(base.copyWith().locationIssue, LocationIssue.serviceOff);
    expect(
      base
          .copyWith(locationIssue: LocationIssue.permissionDenied)
          .locationIssue,
      LocationIssue.permissionDenied,
    );
    expect(base.copyWith(clearLocationIssue: true).locationIssue, isNull);
  });
}
