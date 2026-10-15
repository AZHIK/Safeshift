// TODO: add copyWith and value equality (or convert to Freezed) in a later
// sprint. Placeholder entity only.
class HomeSummary {
  const HomeSummary({
    required this.greeting,
    required this.activeJobsCount,
    required this.completedJobsCount,
  });

  final String greeting;
  final int activeJobsCount;
  final int completedJobsCount;
}
