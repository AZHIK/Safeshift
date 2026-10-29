import 'package:flutter_test/flutter_test.dart';
import 'package:safeshift_driver/core/deep_links/deep_link_service.dart';

void main() {
  group('driver deepLinkLocation', () {
    test('job links open the active-job home flow', () {
      expect(
        deepLinkLocation(Uri.parse('safeshift://tracking/job-1')),
        '/home',
      );
      expect(deepLinkLocation(Uri.parse('safeshift://jobs/job-2')), '/home');
      expect(deepLinkLocation(Uri.parse('safeshift://home')), '/home');
      expect(
        deepLinkLocation(Uri.parse('https://safeshift.app/tracking/job-3')),
        '/home',
      );
    });

    test('history links open trips', () {
      expect(
        deepLinkLocation(Uri.parse('safeshift://history/job-4')),
        '/trips',
      );
      expect(deepLinkLocation(Uri.parse('safeshift://trips/job-5')), '/trips');
      expect(
        deepLinkLocation(Uri.parse('https://safeshift.app/history/job-6')),
        '/trips',
      );
    });

    test('unknown links are ignored', () {
      expect(deepLinkLocation(Uri.parse('safeshift://unknown/job-1')), isNull);
      expect(
        deepLinkLocation(Uri.parse('https://example.com/jobs/job-1')),
        isNull,
      );
    });
  });
}
