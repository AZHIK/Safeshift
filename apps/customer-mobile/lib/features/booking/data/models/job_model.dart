// Planned: convert to a @freezed class with json_serializable and run
// build_runner in a later sprint. Manual stubs below unblock the mock UI phase.
import '../../domain/entities/job.dart';

/// Placeholder data model mirroring [Job].
class JobModel {
  const JobModel({
    required this.id,
    required this.status,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.quoteAmount,
  });

  final String id;
  final String status;
  final String pickupAddress;
  final String destinationAddress;
  final double quoteAmount;

  factory JobModel.fromJson(Map<String, dynamic> json) {
    return JobModel(
      id: json['id'] as String? ?? '',
      status: json['status'] as String? ?? '',
      pickupAddress: json['pickup_address'] as String? ?? '',
      destinationAddress: json['destination_address'] as String? ?? '',
      quoteAmount: (json['quote_amount'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'status': status,
      'pickup_address': pickupAddress,
      'destination_address': destinationAddress,
      'quote_amount': quoteAmount,
    };
  }

  Job toEntity() {
    return Job(
      id: id,
      status: status,
      pickupAddress: pickupAddress,
      destinationAddress: destinationAddress,
      quoteAmount: quoteAmount,
    );
  }
}
