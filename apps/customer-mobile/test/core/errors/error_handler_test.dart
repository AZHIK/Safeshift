import 'package:flutter_test/flutter_test.dart';
import 'package:safeshift_customer/core/errors/error_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('ErrorHandler.map domain errors', () {
    test(
      'explains an out-of-area pickup instead of returning generic copy',
      () {
        final failure = ErrorHandler.map(
          const PostgrestException(
            message: 'pickup point is outside every active service city',
            code: '22023',
          ),
        );

        expect(failure.message, contains('outside our service area'));
        expect(
          failure.message,
          isNot('The server could not complete that request.'),
        );
      },
    );

    test('keeps unknown PostgREST failures generic', () {
      final failure = ErrorHandler.map(
        const PostgrestException(
          message: 'unexpected database detail',
          code: 'XX000',
        ),
      );

      expect(failure.message, 'The server could not complete that request.');
    });
  });
}
