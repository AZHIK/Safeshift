import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/supabase_client.dart';

/// Private bucket that holds the customer's parcel photos.
const cargoPhotoBucket = 'job-evidence';

/// Signed URLs for the customer's parcel photos.
///
/// `job-evidence` is private, so the paths returned by `driver_pending_offers`
/// and `driver_active_job` cannot be used directly as image URLs. Storage RLS
/// lets the assigned driver read objects under the job's folder, which is all
/// `createSignedUrl` needs.
///
/// The family key is the paths joined by newlines. A `FutureProvider.family`
/// caches per key, so reopening the cargo sheet does not re-sign the URLs.
final cargoPhotoUrlsProvider = FutureProvider.autoDispose
    .family<List<String>, String>((ref, key) async {
      if (key.isEmpty) return const <String>[];
      final client = ref.read(supabaseProvider);
      final urls = <String>[];
      for (final path in key.split('\n')) {
        if (path.isEmpty) continue;
        try {
          urls.add(
            await client.storage
                .from(cargoPhotoBucket)
                .createSignedUrl(path, 3600),
          );
        } catch (_) {
          // One unreadable photo must not hide the rest of the cargo details.
        }
      }
      return List<String>.unmodifiable(urls);
    });

/// Stable provider key for a job's cargo photo paths.
String cargoPhotoKey(List<String> paths) => paths.join('\n');
