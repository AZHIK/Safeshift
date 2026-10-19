// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'documents_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(DocumentsState)
final documentsStateProvider = DocumentsStateProvider._();

final class DocumentsStateProvider
    extends $NotifierProvider<DocumentsState, List<MockDocument>> {
  DocumentsStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'documentsStateProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$documentsStateHash();

  @$internal
  @override
  DocumentsState create() => DocumentsState();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<MockDocument> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<MockDocument>>(value),
    );
  }
}

String _$documentsStateHash() => r'da54d15dd922d68eb6110578ce0a468192e05182';

abstract class _$DocumentsState extends $Notifier<List<MockDocument>> {
  List<MockDocument> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<List<MockDocument>, List<MockDocument>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<MockDocument>, List<MockDocument>>,
              List<MockDocument>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
