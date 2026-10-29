import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Compile-time escape hatch for UI-only demos and widget tests.
///
/// Production/staging builds leave this false and always use Supabase.
/// Mock providers/screens remain in the repository for design work.
final mockEnabledProvider = Provider<bool>((ref) {
  return const bool.fromEnvironment('MOCK_MODE', defaultValue: false);
});
