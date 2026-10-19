// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ratings_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(RatingsState)
final ratingsStateProvider = RatingsStateProvider._();

final class RatingsStateProvider
    extends $NotifierProvider<RatingsState, List<MockRating>> {
  RatingsStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'ratingsStateProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$ratingsStateHash();

  @$internal
  @override
  RatingsState create() => RatingsState();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<MockRating> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<MockRating>>(value),
    );
  }
}

String _$ratingsStateHash() => r'4cd567c63674973e182de56e65817b63e84d9608';

abstract class _$RatingsState extends $Notifier<List<MockRating>> {
  List<MockRating> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<List<MockRating>, List<MockRating>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<MockRating>, List<MockRating>>,
              List<MockRating>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
