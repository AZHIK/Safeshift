import 'package:flutter_test/flutter_test.dart';
import 'package:safeshift_customer/features/ride/data/route_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('mapRouteFunctionException', () {
    test('treats a missing function as a deployment problem', () {
      final error = RouteService.mapRouteFunctionException(
        const FunctionException(status: 404),
      );

      expect(error.type, RouteErrorType.notConfigured);
      expect(error.isConfigurationError, isTrue);
      expect(error.message, isNot(contains('404')));
    });

    test('maps a provider failure to a retryable server error', () {
      final error = RouteService.mapRouteFunctionException(
        const FunctionException(status: 502),
      );

      expect(error.type, RouteErrorType.server);
      expect(error.message, contains('unavailable'));
    });

    test('maps auth failures to a configuration problem', () {
      for (final status in [401, 403]) {
        final error = RouteService.mapRouteFunctionException(
          FunctionException(status: status),
        );
        expect(error.type, RouteErrorType.invalidRequest);
      }
    });

    test('maps rate limiting to a retryable error', () {
      final error = RouteService.mapRouteFunctionException(
        const FunctionException(status: 429),
      );

      expect(error.type, RouteErrorType.rateLimited);
      expect(error.isRateLimited, isTrue);
      expect(error.statusCode, 429);
    });

    test('never leaks the raw provider message to riders', () {
      final error = RouteService.mapRouteFunctionException(
        const FunctionException(
          status: 500,
          details: 'google_maps rejected the request',
        ),
      );

      expect(error.message, isNot(contains('google_maps')));
    });
  });
}
