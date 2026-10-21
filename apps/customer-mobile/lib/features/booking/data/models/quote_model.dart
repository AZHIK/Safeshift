// Planned: convert to a @freezed class with json_serializable and run
// build_runner in a later sprint. Manual stubs below unblock the mock UI phase.
import '../../domain/entities/quote.dart';

/// Placeholder data model mirroring [Quote].
class QuoteModel {
  const QuoteModel({
    required this.baseFee,
    required this.distanceFee,
    required this.timeFee,
    required this.total,
  });

  final double baseFee;
  final double distanceFee;
  final double timeFee;
  final double total;

  factory QuoteModel.fromJson(Map<String, dynamic> json) {
    return QuoteModel(
      baseFee: (json['base_fee'] as num?)?.toDouble() ?? 0,
      distanceFee: (json['distance_fee'] as num?)?.toDouble() ?? 0,
      timeFee: (json['time_fee'] as num?)?.toDouble() ?? 0,
      total: (json['total'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'base_fee': baseFee,
      'distance_fee': distanceFee,
      'time_fee': timeFee,
      'total': total,
    };
  }

  Quote toEntity() {
    return Quote(
      baseFee: baseFee,
      distanceFee: distanceFee,
      timeFee: timeFee,
      total: total,
    );
  }
}
