// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'epg_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(epgService)
final epgServiceProvider = EpgServiceProvider._();

final class EpgServiceProvider
    extends $FunctionalProvider<EpgService, EpgService, EpgService>
    with $Provider<EpgService> {
  EpgServiceProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'epgServiceProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$epgServiceHash();

  @$internal
  @override
  $ProviderElement<EpgService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  EpgService create(Ref ref) {
    return epgService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EpgService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EpgService>(value),
    );
  }
}

String _$epgServiceHash() => r'5ea095a94a6ac1daece02697379793382e18f63c';
