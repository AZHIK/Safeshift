import 'package:flutter_test/flutter_test.dart';
import 'package:safeshift_customer/core/utils/reference_number.dart';

void main() {
  group('generateReferenceNumber', () {
    test('formats the prefix and UTC date components', () {
      final value = generateReferenceNumber(' dsr ', DateTime(2026, 10, 29, 12));

      expect(value, startsWith('DSR-20261029-'));
      expect(value, isNot(contains(' ')));
    });

    test('falls back to REF when the prefix has no usable characters', () {
      final value = generateReferenceNumber('---', DateTime(2026, 1, 2));

      expect(value, startsWith('REF-20260102-'));
    });

    test('different timestamps produce different suffixes', () {
      final first = generateReferenceNumber('TKT', DateTime(2026, 10, 29, 12));
      final second = generateReferenceNumber(
        'TKT',
        DateTime(2026, 10, 29, 12, 0, 0, 1),
      );

      expect(first, isNot(second));
    });
  });
}
