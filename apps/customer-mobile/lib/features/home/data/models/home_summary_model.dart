// TODO: convert to a @freezed class with json_serializable and run
// build_runner in a later sprint. Manual stubs below unblock the mock UI phase.
import '../../domain/entities/home_summary.dart';

/// Placeholder data model mirroring [HomeSummary].
class HomeSummaryModel {
  const HomeSummaryModel({
    required this.greeting,
    required this.activeJobsCount,
    required this.completedJobsCount,
  });

  final String greeting;
  final int activeJobsCount;
  final int completedJobsCount;

  factory HomeSummaryModel.fromJson(Map<String, dynamic> json) {
    return HomeSummaryModel(
      greeting: json['greeting'] as String? ?? '',
      activeJobsCount: json['active_jobs_count'] as int? ?? 0,
      completedJobsCount: json['completed_jobs_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'greeting': greeting,
      'active_jobs_count': activeJobsCount,
      'completed_jobs_count': completedJobsCount,
    };
  }

  HomeSummary toEntity() {
    return HomeSummary(
      greeting: greeting,
      activeJobsCount: activeJobsCount,
      completedJobsCount: completedJobsCount,
    );
  }
}
