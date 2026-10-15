import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/services/storage_service.dart';

part 'onboarding_provider.g.dart';

@riverpod
StorageService onboardingStorage(Ref ref) => StorageService();

@riverpod
class Onboarding extends _$Onboarding {
  static const String _storageKey = 'onboarding_completed';

  @override
  bool build() => false;

  bool get isCompleted => state;

  Future<void> completeOnboarding() async {
    await ref.read(onboardingStorageProvider).writeValue(_storageKey, 'true');
    // The screen can be the only caller, so this auto-disposed provider may
    // have gone away while secure storage was being written.
    if (ref.mounted) state = true;
  }

  Future<bool> checkOnboardingStatus() async {
    final value = await ref
        .read(onboardingStorageProvider)
        .readValue(_storageKey);
    final completed = value == 'true';
    if (ref.mounted) state = completed;
    return completed;
  }
}
