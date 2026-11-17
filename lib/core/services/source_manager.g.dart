// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'source_manager.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(sourceManager)
const sourceManagerProvider = SourceManagerProvider._();

final class SourceManagerProvider
    extends $FunctionalProvider<SourceManager, SourceManager, SourceManager>
    with $Provider<SourceManager> {
  const SourceManagerProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'sourceManagerProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$sourceManagerHash();

  @$internal
  @override
  $ProviderElement<SourceManager> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SourceManager create(Ref ref) {
    return sourceManager(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SourceManager value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SourceManager>(value),
    );
  }
}

String _$sourceManagerHash() => r'65d25c3c4f37602210c7776da818e57f7889685b';

@ProviderFor(allSources)
const allSourcesProvider = AllSourcesProvider._();

final class AllSourcesProvider extends $FunctionalProvider<
        AsyncValue<List<Source>>, List<Source>, FutureOr<List<Source>>>
    with $FutureModifier<List<Source>>, $FutureProvider<List<Source>> {
  const AllSourcesProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'allSourcesProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$allSourcesHash();

  @$internal
  @override
  $FutureProviderElement<List<Source>> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<List<Source>> create(Ref ref) {
    return allSources(ref);
  }
}

String _$allSourcesHash() => r'3fbaa59be00843e726473ffccaa8ae1ae31ed92b';
