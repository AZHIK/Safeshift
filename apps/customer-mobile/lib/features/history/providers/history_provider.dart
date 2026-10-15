import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/mock/mock_jobs.dart';
import '../../booking/domain/entities/job.dart';

class HistoryFilterNotifier extends Notifier<String> {
  @override
  String build() => 'All';

  void select(String filter) => state = filter;
}

final historyFilterProvider = NotifierProvider<HistoryFilterNotifier, String>(
  HistoryFilterNotifier.new,
);

final historyProvider = Provider<List<Job>>((ref) {
  final filter = ref.watch(historyFilterProvider);
  if (filter == 'All') return mockJobs;
  final status = switch (filter) {
    'Completed' => 'completed',
    'Cancelled' => 'cancelled',
    'In Progress' => 'in_progress',
    _ => '',
  };
  return mockJobs.where((job) => job.status == status).toList();
});
