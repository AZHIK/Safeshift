// Driver profile state (mock).
//
// Assumes the driver has NO profile until they complete it. The real
// backend lookup will replace the null initial state later.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/mock/mock_driver.dart';

part 'profile_provider.g.dart';

@riverpod
class DriverProfileState extends _$DriverProfileState {
  @override
  DriverProfile? build() {
    ref.keepAlive();
    // TODO: replace with real profile fetch (Supabase) after OTP verify.
    // Null = no profile, so OTP success must route to /complete-profile.
    return null;
  }

  /// True when a profile exists and meets the minimum completeness rules.
  bool get hasCompletedProfile => state?.isComplete ?? false;

  /// Saves the completed profile (called from CompleteProfileScreen).
  void setProfile(DriverProfile profile) {
    state = profile;
  }

  /// Clears the profile (e.g. on sign out).
  void clearProfile() {
    state = null;
  }
}
