import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_iptv/core/services/parental_service.dart';
import 'package:open_iptv/core/services/profile_service.dart';
import 'package:open_iptv/core/storage/preferences.dart';
import 'package:open_iptv/shared/utils/display_name.dart';
import 'package:open_iptv/shared/widgets/pin_field.dart';

/// Asks for a PIN with the system number keyboard. Returns the entered
/// PIN, or null if the user cancelled.
Future<String?> showParentalPinEntry(BuildContext context, String title) =>
    showPinEntryDialog(context, title: title);

/// Prompts for an admin PIN and verifies it. Shows an "Incorrect PIN"
/// snackbar on a wrong entry. Returns true only for a valid admin PIN.
Future<bool> promptAdminPin(
    BuildContext context, WidgetRef ref, String title) async {
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
