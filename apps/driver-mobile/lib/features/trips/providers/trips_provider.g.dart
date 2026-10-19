// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trips_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(TripsFilter)
final tripsFilterProvider = TripsFilterProvider._();

final class TripsFilterProvider extends $NotifierProvider<TripsFilter, String> {
  TripsFilterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tripsFilterProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tripsFilterHash();

  @$internal
  @override
  TripsFilter create() => TripsFilter();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$tripsFilterHash() => r'18e6d7376058a2e3919ef959cfc1cacba243be63';

abstract class _$TripsFilter extends $Notifier<String> {
  String build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String, String>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String, String>,
              String,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
