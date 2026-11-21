import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safeshift_driver/core/theme/app_theme.dart';
import 'package:safeshift_driver/features/home/domain/entities/driver_job.dart';
import 'package:safeshift_driver/features/home/domain/entities/driver_status.dart';
import 'package:safeshift_driver/features/home/domain/entities/home_state.dart';
import 'package:safeshift_driver/features/home/providers/home_provider.dart';
import 'package:safeshift_driver/features/home/presentation/widgets/sheets/cargo_review_sheet.dart';
import 'package:safeshift_driver/features/home/presentation/widgets/sheets/incoming_job_sheet.dart';
import 'package:safeshift_driver/features/home/providers/cargo_photos_provider.dart';

class _FakeHome extends HomeNotifier {
  @override
  HomeState build() =>
      HomeState(driverStatus: DriverStatus.incomingJob, incomingJob: _job());
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
  testWidgets(
    'Drivers can inspect large cargo photos before accepting an offer',
    (tester) async {
      const screenSize = Size(390, 700);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = screenSize;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final dispatcher = tester.platformDispatcher;
      dispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(dispatcher.clearPlatformBrightnessTestValue);
      final job = _job();
      const urls = ['https://example.test/1.jpg', 'https://example.test/2.jpg'];
      for (final url in urls) {
        final image = await tester.runAsync(
          () => createTestImage(width: 640, height: 480),
        );
        final key = CachedNetworkImageProvider(url);
        PaintingBinding.instance.imageCache.putIfAbsent(
          key,
          () => OneFrameImageStreamCompleter(
            Future.value(ImageInfo(image: image!)),
          ),
        );
      }
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            homeProvider.overrideWith(_FakeHome.new),
            cargoPhotoUrlsProvider(cargoPhotoKey(job.cargoPhotoPaths))
                .overrideWith((ref) async => urls),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            home: const Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: FractionallySizedBox(
                  heightFactor: 0.9,
                  child: IncomingJobSheet(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final firstPhoto = find.byType(CargoThumbnail).first;
      expect(tester.getSize(firstPhoto).width, greaterThan(260));
      expect(tester.getSize(firstPhoto).height, greaterThan(190));
      expect(find.text('Accept').hitTestable(), findsOneWidget);
      expect(find.text('Decline').hitTestable(), findsOneWidget);
      await tester.drag(firstPhoto, const Offset(-270, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CargoThumbnail).last);
      await tester.pumpAndSettle();
      expect(find.text('2 / 2'), findsOneWidget);
      final preview = find.descendant(
        of: find.byType(InteractiveViewer),
        matching: find.byType(RawImage),
      );
      expect(tester.widget<RawImage>(preview).image, isNotNull);
      expect(tester.widget<RawImage>(preview).fit, BoxFit.cover);
      expect(tester.getSize(preview), const Size(374, 350));
      expect(tester.getCenter(preview), screenSize.center(Offset.zero));

      tester.view.physicalSize = const Size(700, 390);
      await tester.pumpAndSettle();
      expect(tester.getSize(preview), const Size(684, 195));
      tester.view.physicalSize = screenSize;
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close photo'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Review cargo & photos'));
      await tester.pumpAndSettle();
      expect(find.text('Accept').hitTestable(), findsOneWidget);

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

      final panel = find
          .descendant(
            of: find.byType(CargoReviewSheet),
            matching: find.byType(Container),
          )
          .first;
      for (final brightness in [
        Brightness.light,
        Brightness.dark,
        Brightness.light,
      ]) {
        dispatcher.platformBrightnessTestValue = brightness;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        final theme = brightness == Brightness.dark
            ? AppTheme.darkTheme
            : AppTheme.lightTheme;
        final decoration =
            tester.widget<Container>(panel).decoration! as BoxDecoration;
        expect(decoration.color, theme.colorScheme.surface);
        expect(find.text('Cargo details'), findsOneWidget);
      }

      final thumbnails = find.descendant(
        of: find.byType(CargoReviewSheet),
        matching: find.byType(CargoThumbnail),
      );
      expect(tester.getSize(thumbnails.first).width, greaterThan(300));
      await tester.ensureVisible(thumbnails.last);
      await tester.pumpAndSettle();
      await tester.tap(thumbnails.last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        tester.getSize(find.byType(InteractiveViewer)),
        const Size(374, 350),
      );
      expect(find.text('2 / 2'), findsOneWidget);
      await tester.tap(find.byTooltip('Previous photo'));
      await tester.pump();
      expect(find.text('1 / 2'), findsOneWidget);
      await tester.tap(find.byTooltip('Close photo'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(InteractiveViewer), findsNothing);
      expect(find.text('Cargo details'), findsOneWidget);
    },
  );
}
