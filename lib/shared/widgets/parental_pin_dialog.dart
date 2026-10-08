import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_iptv/core/services/admin_biometric.dart';
import 'package:open_iptv/core/services/parental_service.dart';
import 'package:open_iptv/core/services/profile_service.dart';
import 'package:open_iptv/core/storage/preferences.dart';
import 'package:open_iptv/shared/utils/display_name.dart';
import 'package:open_iptv/shared/widgets/pin_field.dart';

/// Asks for a PIN with the system number keyboard. Returns the entered
/// PIN, or null if the user cancelled.
Future<String?> showParentalPinEntry(BuildContext context, String title) =>
    showPinEntryDialog(context, title: title);

/// Fingerprint / face in place of the admin PIN, when the admin turned it
/// on for this device (profile → Security). True only on a real match;
/// false means "ask for the PIN". [action] is shown under the prompt.
Future<bool> tryAdminBiometric(
    BuildContext context, WidgetRef ref, String action) async {
  final prefs = ref.read(appPreferencesProvider).valueOrNull;
  if (prefs == null) return false;
  return unlockAdminWithBiometric(
    prefs,
    ref.read(adminBiometricProvider),
    action,
    onNotice: (message) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    },
  );
}

/// "Enter admin PIN to unlock X" → "Unlock X", for the biometric prompt.
String _actionFrom(String title) {
  const lead = 'Enter admin PIN to ';
  if (!title.startsWith(lead)) return title;
  final rest = title.substring(lead.length);
  return rest.isEmpty ? title : rest[0].toUpperCase() + rest.substring(1);
}

/// Asks for the admin — by fingerprint / face when turned on, else (or on
/// "Use PIN") the admin PIN. Shows an "Incorrect PIN" snackbar on a wrong
/// entry. Returns true only for the admin.
Future<bool> promptAdminPin(
    BuildContext context, WidgetRef ref, String title) async {
  if (await tryAdminBiometric(context, ref, _actionFrom(title))) return true;
  if (!context.mounted) return false;
  final pin = await showParentalPinEntry(context, title);
  if (pin == null || !context.mounted) return false;
  if (await ref.read(profileServiceProvider).verifyAnyAdminPin(pin)) {
    return true;
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Incorrect PIN')));
  }
  return false;
}

/// Returns true if [category] may be opened: it is not locked, or the user
/// entered a valid admin PIN (which unlocks it for the rest of the session).
Future<bool> ensureCategoryUnlocked(
    BuildContext context, WidgetRef ref, String category) async {
  final prefs = ref.read(appPreferencesProvider).valueOrNull;
  final sessionUnlocked = ref.read(parentalSessionUnlockedProvider);
  if (prefs == null || !isCategoryLocked(category, prefs, sessionUnlocked)) {
    return true;
  }
  if (!await promptAdminPin(
      context, ref, 'Enter admin PIN to unlock "${context.displayName(category)}"')) {
    return false;
  }
  ref.read(parentalSessionUnlockedProvider.notifier).state = {
    ...ref.read(parentalSessionUnlockedProvider),
    category,
  };
  return context.mounted;
}
