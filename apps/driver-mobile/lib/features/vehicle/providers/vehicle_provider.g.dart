// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vehicle_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(VehicleState)
final vehicleStateProvider = VehicleStateProvider._();

final class VehicleStateProvider
    extends $NotifierProvider<VehicleState, MockVehicle> {
  VehicleStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'vehicleStateProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$vehicleStateHash();

  @$internal
  @override
  VehicleState create() => VehicleState();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MockVehicle value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MockVehicle>(value),
    );
  }
}

String _$vehicleStateHash() => r'3a8bba1aa4a1603875a4d1b68796415b943ad4b8';

abstract class _$VehicleState extends $Notifier<MockVehicle> {
  MockVehicle build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<MockVehicle, MockVehicle>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<MockVehicle, MockVehicle>,
              MockVehicle,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
