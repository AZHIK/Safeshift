import 'package:flutter_test/flutter_test.dart';
import 'package:safeshift_customer/shared/utils/geo.dart';

void main() {
  group('distanceMetersBetween', () {
    test('returns zero for identical points', () {
      const point = GeoPoint(-6.7924, 39.2083);
      expect(distanceMetersBetween(point, point), 0);
    });

    test('is roughly correct between Dar es Salaam and Dodoma', () {
      const dar = GeoPoint(-6.7924, 39.2083);
      const dodoma = GeoPoint(-6.163, 35.7516);
      expect(distanceMetersBetween(dar, dodoma), closeTo(380000, 30000));
    });
  });

  group('formatDistanceMeters', () {
    test('uses metres below one kilometre', () {
      expect(formatDistanceMeters(850), '850 m');
    });

    test('uses one decimal for single-digit kilometres', () {
      expect(formatDistanceMeters(4200), '4.2 km');
    });

    test('rounds larger distances', () {
      expect(formatDistanceMeters(24000), '24 km');
    });

    test('returns empty for missing values', () {
      expect(formatDistanceMeters(null), '');
      expect(formatDistanceMeters(double.nan), '');
    });
  });

  group('formatAccuracyMeters', () {
    test('formats a valid accuracy', () {
      expect(formatAccuracyMeters(35), '±35 m');
    });

    test('handles unknown accuracy', () {
      expect(formatAccuracyMeters(0), 'Accuracy unavailable');
      expect(formatAccuracyMeters(null), 'Accuracy unavailable');
    });
  });

  group('GeoPoint.isValid', () {
    test('rejects out-of-range coordinates', () {
      expect(const GeoPoint(91, 0).isValid, isFalse);
      expect(const GeoPoint(0, 181).isValid, isFalse);
      expect(const GeoPoint(double.nan, 0).isValid, isFalse);
    });
  });
}
