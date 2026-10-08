import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_iptv/core/storage/preferences.dart';

/// How a fingerprint / face check for an admin prompt ended.
enum BiometricOutcome {
  success,

  /// Cancelled, "Use PIN", or too many tries: ask for the PIN instead.
  fallback,

  /// A fingerprint or face was added since the admin turned this on.
  invalidated,

  /// The device has no key for it (e.g. app data restored elsewhere).
  notEnabled,

  /// No strong biometrics on this device, or a TV.
  unavailable,
  error,
}

/// Fingerprint / face unlock in place of the admin PIN (#47), through the
/// native `openiptv/biometric` channel (AdminBiometric.kt). Only ever used
/// where the admin PIN is asked for; profile PINs stay typed.
class AdminBiometric {
  const AdminBiometric();

  static const _channel = MethodChannel('openiptv/biometric');

  Future<bool> isAvailable() async {
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Creates the device key and confirms it with a scan.
  Future<BiometricOutcome> enable() => _run('enable', {
        'title': 'Turn on fingerprint and face unlock',
        'subtitle': 'Scan to confirm',
        'negative': 'Cancel',
      });

  Future<BiometricOutcome> authenticate(String action) =>
      _run('authenticate', {
        'title': "Confirm it's the admin",
        'subtitle': action,
        'negative': 'Use PIN',
      });

  Future<void> disable() async {
    try {
      await _channel.invokeMethod<void>('disable');
    } on MissingPluginException {
      // Nothing to remove on this platform.
    }
  }

  Future<BiometricOutcome> _run(String method, Map<String, String> args) async {
    try {
      return parseOutcome(await _channel.invokeMethod<String>(method, args));
    } on MissingPluginException {
      return BiometricOutcome.unavailable;
    } on PlatformException {
      return BiometricOutcome.error;
    }
  }

  static BiometricOutcome parseOutcome(String? value) => switch (value) {
        'success' => BiometricOutcome.success,
        'fallback' => BiometricOutcome.fallback,
        'invalidated' => BiometricOutcome.invalidated,
        'not_enabled' => BiometricOutcome.notEnabled,
        'unavailable' => BiometricOutcome.unavailable,
        _ => BiometricOutcome.error,
      };
}

final adminBiometricProvider = Provider<AdminBiometric>(
  (ref) => const AdminBiometric(),
);

/// Whether this device can offer fingerprint / face unlock at all.
final adminBiometricAvailableProvider = FutureProvider<bool>(
  (ref) => ref.watch(adminBiometricProvider).isAvailable(),
);

const kBiometricResetNotice = 'A new fingerprint or face was added to this '
    'device, so fingerprint and face unlock was turned off. Use the admin '
    'PIN, then turn it back on in Parental Controls.';

/// Tries a fingerprint / face scan for an admin prompt about [action].
/// True only on a real match; false means "ask for the admin PIN". When
/// the device's key is gone (a new fingerprint or face was enrolled, or the
/// key is missing) the setting is switched off and [onNotice] explains why.
Future<bool> unlockAdminWithBiometric(
  AppPreferences prefs,
  AdminBiometric biometric,
  String action, {
  void Function(String message)? onNotice,
}) async {
  if (!prefs.adminBiometricUnlock) return false;
  final outcome = await biometric.authenticate(action);
  switch (outcome) {
    case BiometricOutcome.success:
      return true;
    case BiometricOutcome.invalidated:
      await prefs.setAdminBiometricUnlock(false);
      onNotice?.call(kBiometricResetNotice);
      return false;
    case BiometricOutcome.notEnabled:
      await prefs.setAdminBiometricUnlock(false);
      return false;
    case BiometricOutcome.fallback:
    case BiometricOutcome.unavailable:
    case BiometricOutcome.error:
      return false;
  }
}
