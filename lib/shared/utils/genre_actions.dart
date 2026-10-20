import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:open_iptv/core/providers/theme_providers.dart';
import 'package:open_iptv/core/services/parental_service.dart';
import 'package:open_iptv/core/services/profile_service.dart';
import 'package:open_iptv/shared/utils/display_name.dart';
import 'package:open_iptv/shared/widgets/parental_pin_dialog.dart';

/// Navigates to a genre screen after ensuring the category is unlocked.
Future<void> tapGenre(
  BuildContext context,
  WidgetRef ref,
  String routePrefix,
  String genre,
) async {
  if (await ensureCategoryUnlocked(context, ref, genre) && context.mounted) {
    unawaited(context.push('$routePrefix/genre/${Uri.encodeComponent(genre)}'));
  }
}

/// Shows a bottom sheet to hide a genre for a profile.
Future<void> hideGenre(
  BuildContext context,
  WidgetRef ref,
  String profileId,
  String genre,
) async {
  unawaited(HapticFeedback.mediumImpact());
  final hide = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            autofocus: true,
            leading: const Icon(Icons.visibility_off_outlined),
            title: const Text('Hide Genre'),
            subtitle: Text(context.displayName(genre),
                style: Theme.of(sheetContext).textTheme.bodySmall),
            onTap: () => Navigator.of(sheetContext).pop(true),
          ),
        ],
      ),
    ),
  );
  if (hide == true) {
    await ref.read(profileServiceProvider).hideCategory(profileId, genre);
    ref.invalidate(activeProfileProvider);
  }
}
