// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'source_manager.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(sourceManager)
final sourceManagerProvider = SourceManagerProvider._();

final class SourceManagerProvider
    extends $FunctionalProvider<SourceManager, SourceManager, SourceManager>
    with $Provider<SourceManager> {
  SourceManagerProvider._()
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

String _$sourceManagerHash() => r'd5e7ab21e35e32de13686f6a1030478e96c7458c';

@ProviderFor(allSources)
final allSourcesProvider = AllSourcesProvider._();

final class AllSourcesProvider extends $FunctionalProvider<
        AsyncValue<List<Source>>, List<Source>, FutureOr<List<Source>>>
    with $FutureModifier<List<Source>>, $FutureProvider<List<Source>> {
  AllSourcesProvider._()
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

String _$allSourcesHash() => r'a7c38ba9d69c49ceb695431906990820b1d6a1f9';
