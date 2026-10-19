// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(DriverProfileState)
final driverProfileStateProvider = DriverProfileStateProvider._();

final class DriverProfileStateProvider
    extends $NotifierProvider<DriverProfileState, DriverProfile?> {
  DriverProfileStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'driverProfileStateProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$driverProfileStateHash();

  @$internal
  @override
  DriverProfileState create() => DriverProfileState();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DriverProfile? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DriverProfile?>(value),
    );
  }
}

String _$driverProfileStateHash() =>
    r'12ec00ae9b55153d9aaabe416a48f25339340cf9';

abstract class _$DriverProfileState extends $Notifier<DriverProfile?> {
  DriverProfile? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<DriverProfile?, DriverProfile?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<DriverProfile?, DriverProfile?>,
              DriverProfile?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
