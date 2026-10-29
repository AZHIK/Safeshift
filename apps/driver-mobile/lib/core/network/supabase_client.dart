import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_init.dart';

/// The one Supabase client for the customer app.
///
/// Features must read this provider; no feature owns a global singleton.
/// `SupabaseInit.ensureInitialized()` must have completed in `main()`.
final supabaseProvider = Provider<SupabaseClient>((ref) {
  return SupabaseInit.client;
});
