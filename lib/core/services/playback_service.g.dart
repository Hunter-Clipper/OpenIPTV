// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playback_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(playbackService)
const playbackServiceProvider = PlaybackServiceProvider._();

final class PlaybackServiceProvider extends $FunctionalProvider<PlaybackService,
    PlaybackService, PlaybackService> with $Provider<PlaybackService> {
  const PlaybackServiceProvider._()
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

String _$playbackServiceHash() => r'2f5f30a382c7cfdf00ab99f06de49cc4874dde1d';
