import 'package:flutter_test/flutter_test.dart';
import 'package:safeshift_shared/safeshift_shared.dart';

void main() {
  group('currency', () {
    test('formats TZS without decimals', () {
      expect(formatTzs(125000), 'TZS 125,000');
    });

    test('formats generic money with decimals', () {
      expect(formatMoney(12.5, 'USD'), 'USD 12.50');
    });
  });

  group('job status', () {
    test('maps snake_case wire values', () {
      expect(SafeShiftJobStatus.fromWire('heading_to_pickup'), SafeShiftJobStatus.headingToPickup);
      expect(SafeShiftJobStatus.inTransit.wireValue, 'in_transit');
    });

    test('marks terminal statuses', () {
      expect(SafeShiftJobStatus.completed.isTerminal, isTrue);
      expect(SafeShiftJobStatus.inTransit.isTerminal, isFalse);
    });
  });
}
