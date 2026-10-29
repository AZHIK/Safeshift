import 'package:flutter_test/flutter_test.dart';
import 'package:safeshift_customer/core/deep_links/deep_link_service.dart';

void main() {
  group('customer deepLinkLocation', () {
    test('custom-scheme tracking and job links open live tracking', () {
      expect(
        deepLinkLocation(Uri.parse('safeshift://tracking/job-1')),
        '/tracking?jobId=job-1',
      );
      expect(
        deepLinkLocation(Uri.parse('safeshift://jobs/job-2')),
        '/tracking?jobId=job-2',
      );
    });

    test('universal links use the first path segment as the section', () {
      expect(
        deepLinkLocation(Uri.parse('https://safeshift.app/tracking/job-3')),
        '/tracking?jobId=job-3',
      );
      expect(
        deepLinkLocation(Uri.parse('https://safeshift.app/jobs/job-4')),
        '/tracking?jobId=job-4',
      );
    });

    test('history links open the history detail route', () {
      expect(
        deepLinkLocation(Uri.parse('safeshift://history/job-5')),
        '/history/job-5',
      );
      expect(
        deepLinkLocation(Uri.parse('https://safeshift.app/history/job-6')),
        '/history/job-6',
      );
    });

    test('ids are URI-encoded and unknown links are ignored', () {
      expect(
        deepLinkLocation(Uri.parse('safeshift://jobs/job%207')),
        '/tracking?jobId=job%207',
      );
      expect(deepLinkLocation(Uri.parse('safeshift://tracking')), isNull);
      expect(deepLinkLocation(Uri.parse('safeshift://unknown/job-1')), isNull);
      expect(
        deepLinkLocation(Uri.parse('https://example.com/jobs/job-1')),
        isNull,
      );
    });
  });
}
