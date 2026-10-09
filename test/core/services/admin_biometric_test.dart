import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_iptv/core/services/admin_biometric.dart';
import 'package:open_iptv/core/services/profile_service.dart';
import 'package:open_iptv/core/storage/database.dart';
import 'package:open_iptv/core/storage/preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/open.dart';

/// Answers every scan with [outcome] and records the prompts shown.
class _FakeBiometric extends AdminBiometric {
  _FakeBiometric(this.outcome);

  final BiometricOutcome outcome;
  final asked = <String>[];

  @override
  Future<BiometricOutcome> authenticate(String action) async {
    asked.add(action);
    return outcome;
  }
}

/// A scan prompt that stays up until [answer] completes.
class _SlowBiometric extends AdminBiometric {
  final answer = Completer<BiometricOutcome>();

  @override
  Future<BiometricOutcome> authenticate(String action) => answer.future;
}

void main() {
  if (Platform.isLinux &&
      File('/lib/x86_64-linux-gnu/libsqlite3.so.0').existsSync()) {
    open.overrideFor(
        OperatingSystem.linux, () => DynamicLibrary.open('libsqlite3.so.0'));
  }

  Future<AppPreferences> prefsWith({required bool biometricOn}) async {
    SharedPreferences.setMockInitialValues(
        {'admin_biometric_unlock': biometricOn});
    return AppPreferences(await SharedPreferences.getInstance());
  }

  test('native results map to outcomes; anything unknown is an error', () {
    expect(AdminBiometric.parseOutcome('success'), BiometricOutcome.success);
    expect(AdminBiometric.parseOutcome('fallback'), BiometricOutcome.fallback);
    expect(AdminBiometric.parseOutcome('invalidated'),
        BiometricOutcome.invalidated);
    expect(AdminBiometric.parseOutcome('not_enabled'),
        BiometricOutcome.notEnabled);
    expect(AdminBiometric.parseOutcome('unavailable'),
        BiometricOutcome.unavailable);
    expect(AdminBiometric.parseOutcome('???'), BiometricOutcome.error);
    expect(AdminBiometric.parseOutcome(null), BiometricOutcome.error);
  });

  test('off by default: no scan, the PIN is asked for', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = AppPreferences(await SharedPreferences.getInstance());
    final bio = _FakeBiometric(BiometricOutcome.success);
    expect(await unlockAdminWithBiometric(prefs, bio, 'Unlock "Adult"'),
        AdminScanResult.usePin);
    expect(bio.asked, isEmpty);
  });

  test('a matching scan unlocks', () async {
    final prefs = await prefsWith(biometricOn: true);
    final bio = _FakeBiometric(BiometricOutcome.success);
    expect(await unlockAdminWithBiometric(prefs, bio, 'Unlock "Adult"'),
        AdminScanResult.unlocked);
    expect(bio.asked, ['Unlock "Adult"']);
  });

  test('"Use PIN", cancel or an error fall back to the PIN', () async {
    for (final o in [
      BiometricOutcome.fallback,
      BiometricOutcome.unavailable,
      BiometricOutcome.error,
    ]) {
      final prefs = await prefsWith(biometricOn: true);
      expect(await unlockAdminWithBiometric(prefs, _FakeBiometric(o), 'x'),
          AdminScanResult.usePin,
          reason: '$o');
      expect(prefs.adminBiometricUnlock, isTrue, reason: '$o');
    }
  });

  test('a newly enrolled fingerprint turns the feature off and says why',
      () async {
    final prefs = await prefsWith(biometricOn: true);
    final notices = <String>[];
    final ok = await unlockAdminWithBiometric(
        prefs, _FakeBiometric(BiometricOutcome.invalidated), 'x',
        onNotice: notices.add);
    expect(ok, AdminScanResult.usePin);
    expect(prefs.adminBiometricUnlock, isFalse);
    expect(notices.single, kBiometricResetNotice);
  });

  test('a missing device key quietly turns the feature off', () async {
    final prefs = await prefsWith(biometricOn: true);
    final notices = <String>[];
    expect(
        await unlockAdminWithBiometric(
            prefs, _FakeBiometric(BiometricOutcome.notEnabled), 'x',
            onNotice: notices.add),
        AdminScanResult.usePin);
    expect(prefs.adminBiometricUnlock, isFalse);
    expect(notices, isEmpty);
  });

  test('a double tap shows one scan prompt, not two', () async {
    final prefs = await prefsWith(biometricOn: true);
    final bio = _SlowBiometric();
    final first = unlockAdminWithBiometric(prefs, bio, 'x');
    expect(await unlockAdminWithBiometric(prefs, bio, 'x'),
        AdminScanResult.alreadyShowing);
    bio.answer.complete(BiometricOutcome.success);
    expect(await first, AdminScanResult.unlocked);
    // Once it closes, the next prompt works again.
    expect(
        await unlockAdminWithBiometric(
            prefs, _FakeBiometric(BiometricOutcome.success), 'x'),
        AdminScanResult.unlocked);
  });

  test('a prompt whose answer never comes blocks nobody after 60 s',
      () async {
    final prefs = await prefsWith(biometricOn: true);
    final lost = _SlowBiometric(); // never answers
    final t0 = DateTime(2026, 1, 1, 12);
    unawaited(unlockAdminWithBiometric(prefs, lost, 'x', now: () => t0));
    expect(
        await unlockAdminWithBiometric(
            prefs, _FakeBiometric(BiometricOutcome.success), 'x',
            now: () => t0.add(const Duration(seconds: 59))),
        AdminScanResult.alreadyShowing);
    expect(
        await unlockAdminWithBiometric(
            prefs, _FakeBiometric(BiometricOutcome.success), 'x',
            now: () => t0.add(const Duration(seconds: 61))),
        AdminScanResult.unlocked);
  });

  group('switching profiles after a scan', () {
    late AppDatabase db;
    late ProfileService service;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      service = ProfileService(
          db: db, prefs: await prefsWith(biometricOn: true));
    });
    tearDown(() => db.close());

    test('a verified scan opens the admin profile without its PIN', () async {
      final admin =
          await service.createProfile(name: 'Admin', pin: '0001', isAdmin: true);
      expect(await service.switchToProfile(admin.id), isFalse);
      expect(await service.switchToProfile(admin.id, pinVerified: true),
          isTrue);
    });

    test('removing the admin PIN turns fingerprint / face unlock off',
        () async {
      final admin = await service.createProfile(
          name: 'Admin', pin: '0001', isAdmin: true);
      expect(service.prefs!.adminBiometricUnlock, isTrue);
      await service.clearPin(admin.id, currentPin: '0001');
      expect(service.prefs!.adminBiometricUnlock, isFalse);
    });

    test("a scan never stands in for another profile's PIN", () async {
      await service.createProfile(name: 'Admin', pin: '0001', isAdmin: true);
      final kid = await service.createProfile(name: 'Kid', pin: '1234');
      expect(await service.switchToProfile(kid.id, pinVerified: true),
          isFalse);
      expect(await service.switchToProfile(kid.id, pin: '1234'), isTrue);
    });
  });
}
