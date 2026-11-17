// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'preferences.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(appPreferences)
final appPreferencesProvider = AppPreferencesProvider._();

final class AppPreferencesProvider extends $FunctionalProvider<
        AsyncValue<AppPreferences>, AppPreferences, FutureOr<AppPreferences>>
    with $FutureModifier<AppPreferences>, $FutureProvider<AppPreferences> {
  AppPreferencesProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'appPreferencesProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$appPreferencesHash();

  @$internal
  @override
  $FutureProviderElement<AppPreferences> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<AppPreferences> create(Ref ref) {
    return appPreferences(ref);
  }
}

String _$appPreferencesHash() => r'd88a2ceb7fbfe247c1e2de274b02215c72d4fd91';
