// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$profileServiceHash() => r'eec86fe863a15057ceb658b5c24083a9a671ee90';

/// See also [profileService].
@ProviderFor(profileService)
final profileServiceProvider = Provider<ProfileService>.internal(
  profileService,
  name: r'profileServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$profileServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef ProfileServiceRef = ProviderRef<ProfileService>;
String _$allProfilesHash() => r'6459a01309ddbc9c12c12471255782738a9240d4';

/// See also [allProfiles].
@ProviderFor(allProfiles)
final allProfilesProvider = StreamProvider<List<Profile>>.internal(
  allProfiles,
  name: r'allProfilesProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$allProfilesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef AllProfilesRef = StreamProviderRef<List<Profile>>;
String _$activeProfileHash() => r'eb22759cf2e92fdfc696da94e9a2e25d930fd364';

/// See also [activeProfile].
@ProviderFor(activeProfile)
final activeProfileProvider = FutureProvider<Profile?>.internal(
  activeProfile,
  name: r'activeProfileProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$activeProfileHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef ActiveProfileRef = FutureProviderRef<Profile?>;
String _$appDatabaseHash() => r'92a246abcb363d93aa5a028712241f464abc4efe';

/// See also [appDatabase].
@ProviderFor(appDatabase)
final appDatabaseProvider = Provider<AppDatabase>.internal(
  appDatabase,
  name: r'appDatabaseProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$appDatabaseHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef AppDatabaseRef = ProviderRef<AppDatabase>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
