// Driver ratings state (mock).
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/mock/mock_ratings.dart';

part 'ratings_provider.g.dart';

@riverpod
class RatingsState extends _$RatingsState {
  @override
  List<MockRating> build() {
    ref.keepAlive();
    return mockRatings;
  }

  double averageRating() {
    if (state.isEmpty) return 0;
    final sum = state.fold<int>(0, (acc, r) => acc + r.stars);
    return sum / state.length;
  }
}
