// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playback_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(playbackService)
final playbackServiceProvider = PlaybackServiceProvider._();

final class PlaybackServiceProvider extends $FunctionalProvider<PlaybackService,
    PlaybackService, PlaybackService> with $Provider<PlaybackService> {
  PlaybackServiceProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'playbackServiceProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$playbackServiceHash();

  @$internal
  @override
  $ProviderElement<PlaybackService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PlaybackService create(Ref ref) {
    return playbackService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PlaybackService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PlaybackService>(value),
    );
  }
}

String _$playbackServiceHash() => r'1a5df24d9153680ce85c567e131beaab3ce85afa';
