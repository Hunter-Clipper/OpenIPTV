import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_iptv/core/models/profile.dart';
import 'package:open_iptv/core/services/profile_service.dart';
import 'package:open_iptv/shared/utils/display_name.dart';
import 'package:open_iptv/shared/widgets/tv_focusable.dart';
import 'package:open_iptv/l10n/gen/app_localizations.dart';

/// What a Live TV category is called for [profile]: the profile's own name
/// if it gave one, otherwise the (optionally cleaned-up) provider name.
/// Display-only — search, locks and icons keep using the original name.
String categoryLabel(BuildContext context, Profile? profile, String category) {
  final l10n = AppLocalizations.of(context);
  return profile?.categoryNames[category] ??
      switch (category) {
        'All' => l10n.liveTvAllChannels,
        'Favorites' => l10n.liveTvFavorites,
        'Recently Watched' => l10n.liveTvRecentlyWatched,
        _ => context.displayName(category),
      };
}

enum _CategoryAction { hide, rename, moveUp, moveDown, resetName }

/// Hold OK / long-press on a category: rename it, move it up or down, reset
/// its name, or hide it. [visible] is the categories as the screen shows
/// them (used for Move up / Move down); [label] overrides the title for
/// built-in rows such as "All Channels", which can only be hidden.
Future<void> showCategoryOptions(
  BuildContext context,
  WidgetRef ref,
  String profileId,
  String category, {
  String? label,
  List<String> visible = const [],
}) async {
  unawaited(HapticFeedback.mediumImpact());
  final profile = ref.read(activeProfileProvider).valueOrNull;
  final real = category != 'All';
  final index = visible.indexOf(category);
  final action = await showModalBottomSheet<_CategoryAction>(
    context: context,
    useRootNavigator: true,
    builder: (sheetContext) => _CategoryOptionsSheet(
      label: label ?? categoryLabel(context, profile, category),
      canRename: real,
      canMoveUp: real && index > 0,
      canMoveDown: real && index >= 0 && index < visible.length - 1,
      canResetName: real && (profile?.categoryNames.containsKey(category) ?? false),
    ),
  );
  if (action == null || !context.mounted) return;
  final service = ref.read(profileServiceProvider);
  switch (action) {
    case _CategoryAction.hide:
      await service.hideCategory(profileId, category);
    case _CategoryAction.rename:
      final name = await showDialog<String>(
        context: context,
        useRootNavigator: true,
        builder: (_) => _RenameCategoryDialog(
          original: category,
          current: categoryLabel(context, profile, category),
        ),
      );
      if (name == null) return;
      await service.renameCategory(profileId, category, name);
    case _CategoryAction.moveUp:
      await service.moveCategory(profileId, visible, category, -1);
    case _CategoryAction.moveDown:
      await service.moveCategory(profileId, visible, category, 1);
    case _CategoryAction.resetName:
      await service.renameCategory(profileId, category, null);
  }
  ref.invalidate(activeProfileProvider);
}

class _CategoryOptionsSheet extends StatelessWidget {
  const _CategoryOptionsSheet({
    required this.label,
    required this.canRename,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.canResetName,
  });

  final String label;
  final bool canRename;
  final bool canMoveUp;
  final bool canMoveDown;
  final bool canResetName;

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall;
    final l10n = AppLocalizations.of(context);
    final entries = <(IconData, String, _CategoryAction)>[
      if (canRename)
        (Icons.edit_outlined, l10n.categoryToolsRename, _CategoryAction.rename),
      if (canMoveUp)
        (Icons.arrow_upward_rounded, l10n.categoryToolsMoveUp,
            _CategoryAction.moveUp),
      if (canMoveDown)
        (Icons.arrow_downward_rounded, l10n.categoryToolsMoveDown,
            _CategoryAction.moveDown),
      if (canResetName)
        (Icons.restart_alt_rounded, l10n.categoryToolsResetName,
            _CategoryAction.resetName),
      (Icons.visibility_off_outlined, l10n.categoryToolsHide,
          _CategoryAction.hide),
    ];
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(label,
                  style: small, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            for (var i = 0; i < entries.length; i++)
              ListTile(
                autofocus: i == 0,
                leading: Icon(entries[i].$1),
                title: Text(entries[i].$2),
                onTap: () => Navigator.of(context).pop(entries[i].$3),
              ),
          ],
        ),
      ),
    );
  }
}

/// Asks for a new display name (blank = go back to the original). Returns
/// null when cancelled.
Future<String?> showRenameDialog(
  BuildContext context, {
  required String title,
  required String hint,
  required String current,
}) =>
    showDialog<String>(
      context: context,
      useRootNavigator: true,
      builder: (_) => _RenameCategoryDialog(
          original: current, current: current, title: title, hint: hint),
    );

class _RenameCategoryDialog extends StatefulWidget {
  const _RenameCategoryDialog({
    required this.original,
    required this.current,
    this.title,
    this.hint,
  });

  final String original;
  final String current;
  final String? title;
  final String? hint;

  @override
  State<_RenameCategoryDialog> createState() => _RenameCategoryDialogState();
}

class _RenameCategoryDialogState extends State<_RenameCategoryDialog> {
  late final _name = TextEditingController(text: widget.current);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() => Navigator.of(context).pop(_name.text.trim());

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title ?? l10n.categoryToolsRename),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TvTextFieldGate(
              autofocus: true,
              builder: (context, fieldNode) => TextField(
                focusNode: fieldNode,
                controller: _name,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                    hintText: widget.hint ?? l10n.categoryToolsNameHint),
                onSubmitted: (_) => _save(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.categoryToolsRenameNote,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TvActivatable(
          onTap: () => Navigator.of(context).pop(),
          builder: (onTap) =>
              TextButton(onPressed: onTap, child: Text(l10n.commonCancel)),
        ),
        TvActivatable(
          // Same as the other typing dialogs: the field must not hold the
          // default focus on TV (it would trap the D-pad).
          autofocus: true,
          onTap: _save,
          builder: (onTap) =>
              FilledButton(onPressed: onTap, child: Text(l10n.categoryToolsSave)),
        ),
      ],
    );
  }
}
