// Planned: add signature/photo receipt fields and value equality in a later
// sprint. Placeholder entity only.
class DeliveryEvidence {
  const DeliveryEvidence({
    required this.id,
    required this.jobId,
    required this.photoUrls,
    required this.otpVerified,
  });

  final String id;
  final String jobId;
  final List<String> photoUrls;
  final bool otpVerified;
}
