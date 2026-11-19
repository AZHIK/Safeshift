import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safeshift_driver/features/home/domain/entities/driver_job.dart';
import 'package:safeshift_driver/features/home/domain/entities/home_state.dart';
import 'package:safeshift_driver/features/home/providers/home_provider.dart';
import 'package:safeshift_driver/features/home/presentation/widgets/sheets/cargo_review_sheet.dart';
import 'package:safeshift_driver/features/home/presentation/widgets/sheets/load_details.dart';
import 'package:safeshift_driver/features/home/providers/cargo_photos_provider.dart';

class _FakeHome extends HomeNotifier {
  @override
  HomeState build() => const HomeState();
}

DriverJob _job() => const DriverJob(
  id: 'job-1',
  pickup: 'Kariakoo',
  destination: 'Mlimani City',
  distanceKm: 7.2,
  estimatedFareTzs: 12000,
  cargoClass: 'Small van',
  customerName: 'Asha',
  pickupDistanceKm: 2.1,
  cargoDescription: 'Two crates of fresh vegetables',
  cargoWeightKg: 120,
  declaredValueTzs: 450000,
  cargoPhotoPaths: ['job-1/parcel_0_a.jpg', 'job-1/parcel_1_b.jpg'],
);

void main() {
  testWidgets('LoadDetails shows cargo info and opens the full review', (
    tester,
  ) async {
    final job = _job();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeProvider.overrideWith(_FakeHome.new),
          cargoPhotoUrlsProvider(cargoPhotoKey(job.cargoPhotoPaths))
              .overrideWith(
            (ref) async => [
              'https://example.test/1.jpg',
              'https://example.test/2.jpg',
            ],
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: LoadDetails(job: job)),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('Two crates'), findsOneWidget);
    expect(find.textContaining('120 kg'), findsOneWidget);
    expect(find.byType(CargoThumbnail), findsNWidgets(2));
    expect(find.text('Review cargo & photos'), findsOneWidget);

    await tester.tap(find.text('Review cargo & photos'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Cargo details'), findsOneWidget);
    expect(find.text('TZS 450,000'), findsOneWidget);
    expect(find.byType(CargoThumbnail), findsNWidgets(4));
  });
}
