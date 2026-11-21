import 'package:flutter_test/flutter_test.dart';
import 'package:safeshift_shared/safeshift_shared.dart';

void main() {
  group('Tanzanian numbers', () {
    test('local, national and international forms normalise to E.164', () {
      for (final input in [
        '0712 345 678',
        '712345678',
        '+255 712 345 678',
        '255712345678',
        '00255712345678',
        '(0712) 345-678',
      ]) {
        final check = checkPhone(input);
        expect(check.isValid, isTrue, reason: input);
        expect(check.e164, '+255712345678', reason: input);
        expect(check.isoCode, 'TZ', reason: input);
      }
    });

    test('Airtel, Halotel and Tigo prefixes are mobiles', () {
      expect(checkPhone('0766 123 456').e164, '+255766123456');
      expect(checkPhone('0621 234 567').e164, '+255621234567');
      expect(checkPhone('0655 123 456').e164, '+255655123456');
    });

    test('wrong lengths and unused prefixes are rejected', () {
      expect(checkPhone('0712 345 67').isValid, isFalse);
      expect(checkPhone('0712 345 6789').isValid, isFalse);
      expect(checkPhone('0812 345 678').isValid, isFalse);
      expect(checkPhone('0712 345 67').error, contains('Tanzanian'));
      expect(
        checkPhone('+255 712 345 6789').error,
        contains('wrong number of digits'),
      );
    });

    test('landlines pass only where any number is allowed', () {
      // Dar es Salaam fixed line.
      expect(checkPhone('022 211 1234', kind: PhoneKind.any).isValid, isTrue);
      final mobileOnly = checkPhone('022 211 1234');
      expect(mobileOnly.isValid, isFalse);
      expect(mobileOnly.error, contains('mobile'));
    });
  });

  group('other countries', () {
    test('are validated against their own plan', () {
      expect(checkPhone('+254 712 345 678').e164, '+254712345678');
      expect(checkPhone('+254 712 345 678').isoCode, 'KE');
      expect(checkPhone('+256 772 123 456').e164, '+256772123456');
      expect(checkPhone('+44 7911 123456').e164, '+447911123456');
      expect(checkPhone('+254 712 345').isValid, isFalse);
    });

    test('unknown country codes and letters are rejected', () {
      expect(checkPhone('+999 123 456 789').isValid, isFalse);
      expect(checkPhone('07l2 345 678').isValid, isFalse);
      expect(checkPhone('').error, 'Enter a phone number');
    });
  });

  test('flag and display helpers', () {
    expect(checkPhone('0712345678').flag, '🇹🇿');
    expect(formatPhoneInternational('+255712345678'), '+255 712 345 678');
  });
}
