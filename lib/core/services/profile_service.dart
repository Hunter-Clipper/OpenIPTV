import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:open_iptv/core/models/profile.dart';
import 'package:open_iptv/core/storage/database.dart';
import 'package:open_iptv/core/storage/preferences.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'profile_service.g.dart';

const _uuid = Uuid();
const _maxProfiles = 10;

@Riverpod(keepAlive: true)
ProfileService profileService(ProfileServiceRef ref) {
  final db = ref.watch(appDatabaseProvider);
  final prefs = ref.watch(appPreferencesProvider).valueOrNull;
  return ProfileService(db: db, prefs: prefs);
}

@Riverpod(keepAlive: true)
Stream<List<Profile>> allProfiles(AllProfilesRef ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchAllProfiles();
}

@Riverpod(keepAlive: true)
Future<Profile?> activeProfile(ActiveProfileRef ref) async {
  final prefs = await ref.watch(appPreferencesProvider.future);
  final id = prefs.activeProfileId;
  if (id == null) return null;
  final db = ref.watch(appDatabaseProvider);
  return db.getProfileById(id);
}

class ProfileService {
  const ProfileService({required this.db, required this.prefs});

  final AppDatabase db;
  final AppPreferences? prefs;

  Future<Profile> createProfile({
    required String name,
    String avatarEmoji = '🧑',
    String? pin,
    bool isAdmin = false,
  }) async {
    final existing = await db.getAllProfiles();
    if (existing.length >= _maxProfiles) {
      throw StateError('Maximum of $_maxProfiles profiles reached.');
    }
    if (!isAdmin &&
        existing.any((p) => p.isAdmin) &&
        !existing.any((p) => p.isAdmin && p.hasPin)) {
      throw StateError(
          'Set a PIN on your admin profile before adding a restricted profile.');
    }

    final now = DateTime.now();
    final profile = Profile(
      id: _uuid.v4(),
      name: name,
      avatarEmoji: avatarEmoji,
      pinHash: pin != null ? _hashPin(pin) : null,
      isAdmin: isAdmin,
      createdAt: now,
      updatedAt: now,
    );

    await db.upsertProfile(profile);

    // First profile created → make it active automatically.
    if (existing.isEmpty) {
      await prefs?.setActiveProfileId(profile.id);
    }

    return profile;
  }

  Future<void> updateProfile(Profile profile) async {
    await db.upsertProfile(profile.copyWith(updatedAt: DateTime.now()));
  }

  Future<void> deleteProfile(String id) async {
    final all = await db.getAllProfiles();
    final target = all.firstWhere((p) => p.id == id);
    final others = all.where((p) => p.id != id);
    if (target.isAdmin &&
        others.isNotEmpty &&
        !others.any((p) => p.isAdmin)) {
      throw StateError('Cannot delete the last admin account.');
    }
    await db.deleteProfile(id);
    if (prefs?.activeProfileId == id) {
      final remaining = await db.getAllProfiles();
      await prefs?.setActiveProfileId(remaining.isNotEmpty ? remaining.first.id : '');
    }
  }

  Future<bool> switchToProfile(String id, {String? pin}) async {
    final profile = await db.getProfileById(id);
    if (profile == null) return false;

    if (profile.hasPin) {
      if (pin == null || _hashPin(pin) != profile.pinHash) return false;
    }

    await prefs?.setActiveProfileId(id);
    return true;
  }

  Future<void> setPin(String profileId, String pin) async {
    final profile = await db.getProfileById(profileId);
    if (profile == null) return;
    await db.upsertProfile(
      profile.copyWith(pinHash: _hashPin(pin), updatedAt: DateTime.now()),
    );
  }

  Future<void> clearPin(String profileId, {required String currentPin}) async {
    final profile = await db.getProfileById(profileId);
    if (profile == null) return;
    if (_hashPin(currentPin) != profile.pinHash) {
      throw ArgumentError('Incorrect PIN.');
    }
    if (profile.isAdmin) {
      final others = (await db.getAllProfiles()).where((p) => p.id != profileId);
      if (others.isNotEmpty) {
        throw StateError(
            'Cannot remove the admin PIN while other profiles exist.');
      }
    }
    await db.upsertProfile(
      profile.copyWith(clearPin: true, updatedAt: DateTime.now()),
    );
  }

  bool verifyPin(Profile profile, String pin) =>
      profile.pinHash != null && _hashPin(pin) == profile.pinHash;

  Future<bool> verifyAnyAdminPin(String pin) async {
    final all = await db.getAllProfiles();
    final hash = _hashPin(pin);
    return all.any((p) => p.isAdmin && p.pinHash == hash);
  }

  Future<void> toggleFavoriteChannel(String profileId, String channelId) async {
    final profile = await db.getProfileById(profileId);
    if (profile == null) return;
    final favs = List<String>.from(profile.favoriteChannelIds);
    if (favs.contains(channelId)) {
      favs.remove(channelId);
    } else {
      favs.add(channelId);
    }
    await db.upsertProfile(
      profile.copyWith(favoriteChannelIds: favs, updatedAt: DateTime.now()),
    );
  }

  Future<void> toggleFavoriteMovie(String profileId, String movieId) async {
    final profile = await db.getProfileById(profileId);
    if (profile == null) return;
    final favs = List<String>.from(profile.favoriteMovieIds);
    if (favs.contains(movieId)) {
      favs.remove(movieId);
    } else {
      favs.add(movieId);
    }
    await db.upsertProfile(
      profile.copyWith(favoriteMovieIds: favs, updatedAt: DateTime.now()),
    );
  }

  Future<void> toggleFavoriteSeries(String profileId, String seriesId) async {
    final profile = await db.getProfileById(profileId);
    if (profile == null) return;
    final favs = List<String>.from(profile.favoriteSeriesIds);
    if (favs.contains(seriesId)) {
      favs.remove(seriesId);
    } else {
      favs.add(seriesId);
    }
    await db.upsertProfile(
      profile.copyWith(favoriteSeriesIds: favs, updatedAt: DateTime.now()),
    );
  }

  Future<void> hideCategory(String profileId, String category) async {
    final profile = await db.getProfileById(profileId);
    if (profile == null) return;
    final hidden = List<String>.from(profile.hiddenCategories);
    if (!hidden.contains(category)) {
      hidden.add(category);
      await db.upsertProfile(
        profile.copyWith(hiddenCategories: hidden, updatedAt: DateTime.now()),
      );
    }
  }

  Future<void> unhideCategory(String profileId, String category) async {
    final profile = await db.getProfileById(profileId);
    if (profile == null) return;
    final hidden = List<String>.from(profile.hiddenCategories)
      ..remove(category);
    await db.upsertProfile(
      profile.copyWith(hiddenCategories: hidden, updatedAt: DateTime.now()),
    );
  }

  static String _hashPin(String pin) {
    return sha256.convert(utf8.encode(pin)).toString();
  }
}

// Provider for the AppDatabase — kept here to avoid circular imports.
@Riverpod(keepAlive: true)
AppDatabase appDatabase(AppDatabaseRef ref) => AppDatabase();
