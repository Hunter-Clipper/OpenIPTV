import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_iptv/core/models/channel.dart';
import 'package:open_iptv/core/services/profile_service.dart';
import 'package:open_iptv/core/storage/preferences.dart';
import 'package:open_iptv/shared/utils/display_name.dart';

/// One profile's own channel tweaks: channels it has hidden and the names it
/// has given channels. Both are display-only: search, sorting and the
/// provider's data keep using the real names.
class ChannelCustom {
  const ChannelCustom({this.hidden = const {}, this.names = const {}});

  final Set<String> hidden;
  final Map<String, String> names;

  static const empty = ChannelCustom();

  bool get isEmpty => hidden.isEmpty && names.isEmpty;

  Map<String, Object?> toJson() => {
        'hidden': hidden.toList()..sort(),
        'names': names,
      };

  static ChannelCustom fromJson(Object? json) {
    if (json is! Map) return empty;
    final hidden = json['hidden'];
    final names = json['names'];
    return ChannelCustom(
      hidden: {
        if (hidden is List)
          for (final h in hidden)
            if (h is String) h,
      },
      names: {
        if (names is Map)
          for (final e in names.entries)
            if (e.key is String && e.value is String && (e.value as String).trim().isNotEmpty)
              e.key as String: (e.value as String).trim(),
      },
    );
  }
}

/// Everything in the saved JSON, keyed by profile id. Bad data reads as empty.
Map<String, ChannelCustom> parseChannelCustom(String? json) {
  if (json == null || json.isEmpty) return {};
  try {
    final decoded = jsonDecode(json);
    if (decoded is! Map) return {};
    return {
      for (final e in decoded.entries)
        if (e.key is String) e.key as String: ChannelCustom.fromJson(e.value),
    };
  } catch (_) {
    return {};
  }
}

String encodeChannelCustom(Map<String, ChannelCustom> all) => jsonEncode({
      for (final e in all.entries)
        if (!e.value.isEmpty) e.key: e.value.toJson(),
    });

/// The active profile's channel tweaks.
final channelCustomProvider =
    NotifierProvider<ChannelCustomNotifier, ChannelCustom>(
        ChannelCustomNotifier.new);

class ChannelCustomNotifier extends Notifier<ChannelCustom> {
  @override
  ChannelCustom build() {
    final profileId = ref.watch(activeProfileIdProvider);
    final prefs = ref.watch(appPreferencesProvider).valueOrNull;
    if (profileId == null || prefs == null) return ChannelCustom.empty;
    return parseChannelCustom(prefs.channelCustomJson)[profileId] ??
        ChannelCustom.empty;
  }

  Future<void> _save(ChannelCustom next) async {
    final profileId = ref.read(activeProfileIdProvider);
    if (profileId == null) return;
    final prefs = await ref.read(appPreferencesProvider.future);
    final all = parseChannelCustom(prefs.channelCustomJson);
    all[profileId] = next;
    await prefs.setChannelCustomJson(encodeChannelCustom(all));
    state = next;
  }

  Future<void> hide(String channelId) =>
      _save(ChannelCustom(hidden: {...state.hidden, channelId}, names: state.names));

  Future<void> unhide(String channelId) => _save(ChannelCustom(
      hidden: {...state.hidden}..remove(channelId), names: state.names));

  Future<void> unhideAll() => _save(ChannelCustom(names: state.names));

  /// Gives a channel a display name; a blank name goes back to the original.
  Future<void> rename(String channelId, String? name) {
    final names = {...state.names};
    final clean = name?.trim() ?? '';
    if (clean.isEmpty) {
      names.remove(channelId);
    } else {
      names[channelId] = clean;
    }
    return _save(ChannelCustom(hidden: state.hidden, names: names));
  }
}

/// The names the user gave channels, near the root so any widget can show
/// them with `context.channelName(channel)`.
class ChannelNames extends InheritedWidget {
  const ChannelNames({super.key, required this.names, required super.child});

  final Map<String, String> names;

  static Map<String, String> of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ChannelNames>()?.names ??
      const {};

  @override
  bool updateShouldNotify(ChannelNames oldWidget) =>
      !identical(names, oldWidget.names) && names != oldWidget.names;
}

extension ChannelNameContext on BuildContext {
  /// What to show for [channel]: the name the user gave it, else its
  /// (optionally tidied) own name.
  String channelName(Channel channel) =>
      ChannelNames.of(this)[channel.id] ?? displayName(channel.name);
}
