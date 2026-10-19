// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'earnings_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(EarningsSegment)
final earningsSegmentProvider = EarningsSegmentProvider._();

final class EarningsSegmentProvider
    extends $NotifierProvider<EarningsSegment, String> {
  EarningsSegmentProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'earningsSegmentProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$earningsSegmentHash();

  @$internal
  @override
  EarningsSegment create() => EarningsSegment();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$earningsSegmentHash() => r'e9ab1cb20742aa33c81f39ae0b60987c6e1ffa5f';

abstract class _$EarningsSegment extends $Notifier<String> {
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
