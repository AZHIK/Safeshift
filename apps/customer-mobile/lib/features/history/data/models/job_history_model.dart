// TODO: convert to a @freezed class with json_serializable and run
// build_runner in a later sprint. Manual stubs below unblock the mock UI phase.
import '../../domain/entities/job_history.dart';

/// Placeholder data model mirroring [JobHistory].
class JobHistoryModel {
  const JobHistoryModel({
    required this.id,
    required this.status,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.completedAt,
    required this.amount,
  });

  final String id;
  final String status;
  final String pickupAddress;
  final String destinationAddress;
  final DateTime completedAt;
  final double amount;

  factory JobHistoryModel.fromJson(Map<String, dynamic> json) {
    return JobHistoryModel(
      id: json['id'] as String? ?? '',
      status: json['status'] as String? ?? '',
      pickupAddress: json['pickup_address'] as String? ?? '',
      destinationAddress: json['destination_address'] as String? ?? '',
      completedAt: DateTime.tryParse(json['completed_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'status': status,
      'pickup_address': pickupAddress,
      'destination_address': destinationAddress,
      'completed_at': completedAt.toIso8601String(),
      'amount': amount,
    };
  }

  JobHistory toEntity() {
    return JobHistory(
      id: id,
      status: status,
      pickupAddress: pickupAddress,
      destinationAddress: destinationAddress,
      completedAt: completedAt,
      amount: amount,
    );
  }
}
