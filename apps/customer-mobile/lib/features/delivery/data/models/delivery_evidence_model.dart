// TODO: convert to a @freezed class with json_serializable and run
// build_runner in a later sprint. Manual stubs below unblock the mock UI phase.
import '../../domain/entities/delivery_evidence.dart';

/// Placeholder data model mirroring [DeliveryEvidence].
class DeliveryEvidenceModel {
  const DeliveryEvidenceModel({
    required this.id,
    required this.jobId,
    required this.photoUrls,
    required this.otpVerified,
  });

  final String id;
  final String jobId;
  final List<String> photoUrls;
  final bool otpVerified;

  factory DeliveryEvidenceModel.fromJson(Map<String, dynamic> json) {
    return DeliveryEvidenceModel(
      id: json['id'] as String? ?? '',
      jobId: json['job_id'] as String? ?? '',
      photoUrls:
          (json['photo_urls'] as List<dynamic>? ?? []).map((e) => '$e').toList(),
      otpVerified: json['otp_verified'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'job_id': jobId,
      'photo_urls': photoUrls,
      'otp_verified': otpVerified,
    };
  }

  DeliveryEvidence toEntity() {
    return DeliveryEvidence(
      id: id,
      jobId: jobId,
      photoUrls: photoUrls,
      otpVerified: otpVerified,
    );
  }
}
