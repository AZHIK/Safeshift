import 'package:supabase/supabase.dart';

/// Quick-tag codes the server accepts, with the wording shown to people.
const Map<String, String> ratingTagLabels = {
  // Customer rating the driver.
  'on_time': 'On time',
  'careful_handling': 'Careful with items',
  'friendly': 'Friendly',
  'clean_vehicle': 'Clean vehicle',
  'good_route': 'Good route',
  'late': 'Late',
  'rough_handling': 'Rough handling',
  'vehicle_condition': 'Vehicle condition',
  'poor_route': 'Poor route',
  'damaged_items': 'Items damaged',
  // Driver rating the customer.
  'ready_on_time': 'Ready on time',
  'clear_directions': 'Clear directions',
  'helped_loading': 'Helped loading',
  'polite': 'Polite',
  'accurate_cargo': 'Cargo as described',
  'kept_waiting': 'Kept me waiting',
  'cargo_not_as_described': 'Cargo not as described',
  'hard_to_reach': 'Hard to reach',
  'unsafe_loading': 'Unsafe loading',
  // Both.
  'rude': 'Rude',
};

String ratingTagLabel(String code) =>
    ratingTagLabels[code] ??
    code
        .replaceAll('_', ' ')
        .replaceFirstMapped(RegExp('^.'), (m) => m[0]!.toUpperCase());

/// Short word for a star count, shown under the stars.
String ratingScoreWord(int score) => switch (score) {
  1 => 'Terrible',
  2 => 'Bad',
  3 => 'Okay',
  4 => 'Good',
  5 => 'Excellent',
  _ => '',
};

/// The caller's rating state for one job, from `job_rating_status`.
class JobRatingStatus {
  const JobRatingStatus({
    required this.canRate,
    required this.rated,
    this.score,
    this.tags = const [],
    this.comment,
    this.positiveTags = const [],
    this.negativeTags = const [],
  });

  factory JobRatingStatus.fromJson(Map<String, dynamic> json) {
    List<String> list(Object? value) =>
        (value as List?)?.map((e) => '$e').toList(growable: false) ??
        const <String>[];
    return JobRatingStatus(
      canRate: json['can_rate'] == true,
      rated: json['rated'] == true,
      score: (json['score'] as num?)?.toInt(),
      tags: list(json['tags']),
      comment: json['comment'] as String?,
      positiveTags: list(json['positive_tags']),
      negativeTags: list(json['negative_tags']),
    );
  }

  /// Whether a rating can be given now (or the given one still changed).
  final bool canRate;

  /// Whether the caller already rated this job.
  final bool rated;
  final int? score;
  final List<String> tags;
  final String? comment;

  /// Tags offered for 4-5 stars and for 1-3 stars.
  final List<String> positiveTags;
  final List<String> negativeTags;

  List<String> tagsFor(int score) => score >= 4 ? positiveTags : negativeTags;
}

/// Ratings through the server RPCs (the table itself is read-only to apps).
class RatingRepository {
  const RatingRepository(this._client);

  final SupabaseClient _client;

  Future<JobRatingStatus> status(String jobId) async {
    final row = await _client.rpc<Map<String, dynamic>>(
      'job_rating_status',
      params: <String, dynamic>{'p_job_id': jobId},
    );
    return JobRatingStatus.fromJson(row);
  }

  Future<JobRatingStatus> submit({
    required String jobId,
    required int score,
    List<String> tags = const [],
    String? comment,
  }) async {
    final row = await _client.rpc<Map<String, dynamic>>(
      'job_submit_rating',
      params: <String, dynamic>{
        'p_job_id': jobId,
        'p_score': score,
        'p_tags': tags,
        'p_comment': (comment?.trim().isEmpty ?? true) ? null : comment!.trim(),
      },
    );
    return JobRatingStatus.fromJson(row);
  }
}
