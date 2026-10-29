import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:safeshift_customer/core/errors/failures.dart';
import 'package:safeshift_customer/features/auth/data/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  late AuthService service;

  setUp(() {
    service = AuthService(_MockSupabaseClient());
  });

  group('AuthService.normalizePhone', () {
    test('normalizes local, international, and plus-prefixed numbers', () {
      expect(AuthService.normalizePhone('0712345678'), '+255712345678');
      expect(AuthService.normalizePhone('712345678'), '+255712345678');
      expect(AuthService.normalizePhone('255712345678'), '+255712345678');
      expect(AuthService.normalizePhone('+255 712 345 678'), '+255712345678');
    });

    test('strips formatting characters', () {
      expect(AuthService.normalizePhone('0712-345-678'), '+255712345678');
    });
  });

  group('validation happens before network access', () {
    test('sendOtp rejects a short phone number', () async {
      await expectLater(
        service.sendOtp('123'),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('verifyOtp rejects a non-6-digit code', () async {
      await expectLater(
        service.verifyOtp('0712345678', '123'),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('verifyOtp rejects letters after stripping non-digits', () async {
      await expectLater(
        service.verifyOtp('0712345678', '12ab34'),
        throwsA(isA<ValidationFailure>()),
      );
    });
  });
}
