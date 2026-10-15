// TODO: load the home summary from a repository in a later sprint. Returns a
// hardcoded mock for now.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/home_summary.dart';

final homeProvider = Provider<HomeSummary>((ref) {
  return const HomeSummary(
    greeting: 'Karibu back!',
    activeJobsCount: 1,
    completedJobsCount: 4,
  );
});
