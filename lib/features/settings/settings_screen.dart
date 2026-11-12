import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_iptv/telemetry/consent.dart';
import 'package:open_iptv/core/models/channel.dart';
import 'package:open_iptv/core/models/profile.dart';
import 'package:open_iptv/core/models/source.dart';
import 'package:open_iptv/core/parsers/xtream_client.dart';
import 'package:open_iptv/core/providers/theme_providers.dart';
import 'package:open_iptv/core/services/channel_customisation.dart';
import 'package:open_iptv/core/services/device_info_channel.dart';
import 'package:open_iptv/core/services/auto_refresh_service.dart';
import 'package:open_iptv/core/services/profile_service.dart';
import 'package:open_iptv/core/services/source_manager.dart';
import 'package:open_iptv/core/storage/local_playlists.dart';
import 'package:open_iptv/core/storage/preferences.dart';
import 'package:open_iptv/features/live_tv/category_tools.dart';
import 'package:open_iptv/features/settings/car_video_addon.dart';
import 'package:open_iptv/features/settings/edit_playlist_screen.dart';
import 'package:open_iptv/features/settings/profile_picker_screen.dart';
import 'package:open_iptv/features/settings/refresh_all.dart';
import 'package:open_iptv/features/updates/update_dialog.dart';
import 'package:open_iptv/shared/theme/app_theme.dart';
import 'package:open_iptv/shared/utils/format.dart';
import 'package:open_iptv/shared/utils/friendly_error.dart';
// friendlyEpgErrorMessage is used by _refreshEpg below.
import 'package:open_iptv/shared/utils/redact.dart';
import 'package:open_iptv/shared/widgets/info_tooltip.dart';
import 'package:open_iptv/shared/widgets/loading_view.dart';
import 'package:open_iptv/shared/widgets/profile_avatar.dart';
import 'package:open_iptv/shared/widgets/settings_group.dart';
import 'package:open_iptv/l10n/gen/app_localizations.dart';
import 'package:open_iptv/shared/widgets/language_picker.dart';
import 'package:open_iptv/shared/widgets/tv_focusable.dart';
import 'package:open_iptv/ui/platform_helper.dart';
import 'package:package_info_plus/package_info_plus.dart';

extension _SettingsL10n on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// The accent swatch names live in [AppTheme.accentSwatches] as English
/// labels; they are translated here.
String _accentName(BuildContext context, String label) => switch (label) {
      'Blue' => context.l10n.settingsAccentBlue,
      'Purple' => context.l10n.settingsAccentPurple,
      'Pink' => context.l10n.settingsAccentPink,
      'Orange' => context.l10n.settingsAccentOrange,
      'Green' => context.l10n.settingsAccentGreen,
      'Teal' => context.l10n.settingsAccentTeal,
      'Custom' => context.l10n.settingsAccentCustom,
      _ => label,
    };

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tooltipController = InfoTooltipController();
    final theme = Theme.of(context);

    // Derive active profile for the subtitle.
    final profile = ref.watch(activeProfileProvider).valueOrNull;
    final isAdmin = profile?.isAdmin ?? false;
    final tv = PlatformHelper.isTVDevice;

    return InfoTooltipScope(
      controller: tooltipController,
      child: Scaffold(
        appBar: AppBar(title: Text(context.l10n.settingsTitle)),
        body: TvFollowFocus(child: ListView(
          children: [
            SettingsGroup(title: context.l10n.settingsGroupAccount, children: [
              ..._accountTiles(context, theme, profile),
              if (isAdmin) ..._parentalTiles(context, theme, isAdmin),
            ]),
            if (isAdmin)
              SettingsGroup(title: context.l10n.settingsGroupPlaylistsGuides, children: [
                ..._playlistTiles(context, theme, isAdmin),
                ..._autoRefreshTiles(context, theme, isAdmin),
                ..._extraGuideTiles(context, theme, isAdmin),
                ..._guideDataTiles(context, theme, isAdmin),
                ..._backupTiles(context, theme, isAdmin),
              ]),
            SettingsGroup(title: context.l10n.settingsGroupWatching, children: [
              _pageTile(
                context,
                icon: Icons.play_circle_outline_rounded,
                title: context.l10n.settingsPlaybackTitle,
                subtitle: context.l10n.settingsPlaybackSubtitle,
                groups: [
                  (
                    null,
                    [
                      ..._askStartOverTiles(context, theme, isAdmin),
                      if (!tv) ..._startupTiles(context, theme, isAdmin),
                    ]
                  ),
                  (context.l10n.settingsGroupPlayerControls, _playerTiles(context, theme, isAdmin)),
                ],
              ),
              if (tv)
                _pageTile(
                  context,
                  icon: Icons.power_settings_new_rounded,
                  title: context.l10n.settingsStartupTitle,
                  subtitle: context.l10n.settingsStartupSubtitle,
                  groups: [(null, _startupTiles(context, theme, isAdmin))],
                ),
              _pageTile(
                context,
                icon: Icons.live_tv_outlined,
                title: context.l10n.settingsChannelListsTitle,
                subtitle: context.l10n.settingsChannelListsSubtitle,
                groups: [(null, _channelListTiles(context, theme, isAdmin))],
              ),
              if (tv)
                _pageTile(
                  context,
                  icon: Icons.grid_view_rounded,
                  title: context.l10n.settingsGuideLayoutTitle,
                  subtitle: context.l10n.settingsGuideLayoutSubtitle,
                  groups: [(null, _guideLayoutTiles(context, theme, isAdmin))],
                ),
            ]),
            SettingsGroup(
                title: context.l10n.settingsGroupAppearance,
                children: _appearanceTiles(context, theme, isAdmin)),
            SettingsGroup(title: context.l10n.settingsGroupAboutAdvanced, children: [
              ..._aboutTiles(context, theme, isAdmin),
              _updatesTile(context),
              if (isAdmin) ..._advancedTiles(context, theme, isAdmin),
            ]),
            const SizedBox(height: 32),
          ],
        )),
      ),
    );
  }

  /// A row that opens a page of related settings (keeps the main list short).
  Widget _pageTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required List<(String?, List<Widget>)> groups,
  }) {
    return _NavTile(
      leading: Icon(icon),
      title: title,
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => _SubPage(title: title, groups: groups))),
    );
  }

  /// Updates: check now, and whether the app checks by itself.
  Widget _updatesTile(BuildContext context) {
    return StatefulBuilder(builder: (context, setLocal) {
      return Consumer(builder: (context, ref, _) {
        final prefs = ref.watch(appPreferencesProvider).valueOrNull;
        final auto = prefs?.autoUpdateCheck ?? true;
        return InfoTooltip(
          id: 'settings_check_updates',
          title: context.l10n.settingsUpdatesTitle,
          body: context.l10n.settingsUpdatesBody,
          child: _NavTile(
            leading: const Icon(Icons.system_update_outlined),
            title: context.l10n.settingsUpdatesTitle,
            subtitle: Text(auto ? context.l10n.settingsUpdatesAutoOn : context.l10n.settingsUpdatesManual,
                style: Theme.of(context).textTheme.bodySmall),
            onTap: () async {
              final check = await showDialog<bool>(
                context: context,
                builder: (ctx) => StatefulBuilder(
                  builder: (ctx, setDialog) => AlertDialog(
                    title: Text(context.l10n.settingsUpdatesTitle),
                    content: _ToggleTile(
                      icon: Icons.update,
                      title: context.l10n.settingsUpdatesCheckAuto,
                      value: prefs?.autoUpdateCheck ?? true,
                      onChanged: (v) async {
                        await prefs?.setAutoUpdateCheck(v);
                        setDialog(() {});
                      },
                    ),
                    actions: [
                      TvActivatable(
                        onTap: () => Navigator.of(ctx).pop(false),
                        builder: (onTap) => TextButton(
                            onPressed: onTap, child: Text(context.l10n.settingsUpdatesClose)),
                      ),
                      TvActivatable(
                        autofocus: true,
                        onTap: () => Navigator.of(ctx).pop(true),
                        builder: (onTap) => FilledButton(
                            onPressed: onTap, child: Text(context.l10n.settingsUpdatesCheckNow)),
                      ),
                    ],
                  ),
                ),
              );
              setLocal(() {});
              if (check == true && context.mounted) {
                await checkForUpdateManually(context);
              }
            },
          ),
        );
      });
    });
  }

  List<Widget> _accountTiles(BuildContext context, ThemeData theme, Profile? profile) => [
    InfoTooltip(
      id: 'settings_profile',
      title: context.l10n.settingsProfileTitle,
      body: context.l10n.settingsProfileBody,
      child: _NavTile(
        autofocus: true,
        leading: profile != null
            ? ProfileAvatar(
                emoji: profile.avatarEmoji, name: profile.name)
            : const Icon(Icons.person_outline),
        title: profile?.name ?? context.l10n.settingsProfileTitle,
        subtitle: Text(
          profile == null
              ? context.l10n.settingsProfileNone
              : context.l10n.settingsProfileSubtitle(profile.isAdmin
                  ? 'admin'
                  : profile.isKidsProfile
                      ? 'kids'
                      : 'standard'),
          style: theme.textTheme.bodySmall,
        ),
        onTap: () => context.push('/settings/profiles'),
      ),
    ),
    Consumer(builder: (context, ref, _) {
      final all = ref.watch(allProfilesProvider);
      final count = all.valueOrNull?.length ?? 0;
      if (count <= 1) return const SizedBox.shrink();
      return InfoTooltip(
        id: 'settings_switch_profile',
        title: context.l10n.settingsSwitchProfileTitle,
        body: context.l10n.settingsSwitchProfileBody,
        child: _NavTile(
          leading: const Icon(Icons.switch_account_outlined),
          title: context.l10n.settingsSwitchProfileTitle,
          subtitle: Text(context.l10n.settingsProfilesAvailable(count),
              style: theme.textTheme.bodySmall),
          onTap: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (_) => ProfilePickerScreen(
              onPicked: () => Navigator.of(context).pop(),
            ),
          ),
        ),
      );
    }),
      ];

  List<Widget> _parentalTiles(BuildContext context, ThemeData theme, bool isAdmin) => [
    InfoTooltip(
      id: 'settings_parental',
      title: context.l10n.settingsParentalTitle,
      body: context.l10n.settingsParentalBody,
      child: _NavTile(
        leading: const Icon(Icons.family_restroom_outlined),
        title: context.l10n.settingsParentalTitle,
        subtitle: Text(
          context.l10n.settingsParentalSubtitle,
          style: theme.textTheme.bodySmall,
        ),
        onTap: () => context.push('/settings/parental'),
      ),
    ),
      ];

  List<Widget> _playlistTiles(BuildContext context, ThemeData theme, bool isAdmin) => [
    Consumer(builder: (context, ref, _) {
      final sources = ref.watch(allSourcesProvider);
      return InfoTooltip(
        id: 'settings_sources',
        title: context.l10n.settingsPlaylistsTitle,
        body: context.l10n.settingsPlaylistsBody,
        child: _NavTile(
          leading: const Icon(Icons.playlist_play_outlined),
          title: context.l10n.settingsPlaylistsTitle,
          subtitle: sources.when(
            loading: () => null,
            error: (_, __) => null,
            data: (list) => Text(
              list.isEmpty
                  ? context.l10n.settingsPlaylistsNone
                  : context.l10n.settingsPlaylistsCount(list.length),
              style: theme.textTheme.bodySmall,
            ),
          ),
          onTap: () => _openSourcesPage(context),
        ),
      );
    }),
    const RefreshNowTile(),
      ];

  List<Widget> _backupTiles(BuildContext context, ThemeData theme, bool isAdmin) => [
    InfoTooltip(
      id: 'settings_backup',
      title: context.l10n.settingsBackupTitle,
      body: context.l10n.settingsBackupBody,
      child: _NavTile(
        leading: const Icon(Icons.backup_outlined),
        title: context.l10n.settingsBackupTitle,
        subtitle: Text(
          context.l10n.settingsBackupSubtitle,
          style: theme.textTheme.bodySmall,
        ),
        onTap: () => context.push('/settings/backup'),
      ),
    ),
      ];

  List<Widget> _autoRefreshTiles(BuildContext context, ThemeData theme, bool isAdmin) => [
    Consumer(builder: (context, ref, _) {
      final hours = ref.watch(refreshIntervalHoursProvider);
      return InfoTooltip(
        id: 'settings_auto_refresh',
        title: context.l10n.settingsAutoRefreshTitle,
        body: context.l10n.settingsAutoRefreshBody,
        child: _NavTile(
          leading: const Icon(Icons.autorenew),
          title: context.l10n.settingsAutoRefreshTitle,
          subtitle: Text(
            hours > 0 && ref.watch(refreshNotificationsEnabledProvider)
              ? context.l10n.settingsAutoRefreshNotifies(
                  _refreshIntervalLabel(context, hours))
              : _refreshIntervalLabel(context, hours),
            style: theme.textTheme.bodySmall,
          ),
          onTap: () => _showAutoRefreshDialog(context, ref, hours),
        ),
      );
    }),
      ];

  List<Widget> _guideDataTiles(BuildContext context, ThemeData theme, bool isAdmin) => [
    InfoTooltip(
      id: 'settings_guide_data',
      title: context.l10n.settingsGuideDataTitle,
      body: context.l10n.settingsGuideDataBody,
      child: _NavTile(
        leading: const Icon(Icons.event_note_outlined),
        title: context.l10n.settingsGuideDataTitle,
        subtitle: Text(context.l10n.settingsGuideDataSubtitle,
            style: theme.textTheme.bodySmall),
        onTap: () => context.push('/settings/guide-data'),
      ),
    ),
      ];

  List<Widget> _extraGuideTiles(BuildContext context, ThemeData theme, bool isAdmin) => [
    InfoTooltip(
      id: 'settings_extra_guides',
      title: context.l10n.settingsExtraGuidesTitle,
      body: context.l10n.settingsExtraGuidesBody,
      child: _NavTile(
        leading: const Icon(Icons.event_note_outlined),
        title: context.l10n.settingsExtraGuidesTitle,
        subtitle: Text(
          context.l10n.settingsExtraGuidesSubtitle,
          style: theme.textTheme.bodySmall,
        ),
        onTap: () => context.push('/settings/extra-guides'),
      ),
    ),
      ];

  List<Widget> _askStartOverTiles(BuildContext context, ThemeData theme, bool isAdmin) => [
    Consumer(builder: (context, ref, _) {
      final ask = ref.watch(askStartOverProvider);
      return InfoTooltip(
        id: 'settings_ask_start_over',
        title: context.l10n.settingsAskStartOverTitle,
        body: context.l10n.settingsAskStartOverBody,
        child: _ToggleTile(
          icon: Icons.history_rounded,
          title: context.l10n.settingsAskStartOverTitle,
          value: ask,
          onChanged: (v) async {
            final prefs =
                await ref.read(appPreferencesProvider.future);
            await setAskStartOver(ref, v, prefs);
          },
        ),
      );
    }),
    Consumer(builder: (context, ref, _) {
      final pipEnabled = ref.watch(pipEnabledProvider);
      return InfoTooltip(
        id: 'settings_pip',
        title: context.l10n.settingsPipTitle,
        body: context.l10n.settingsPipBody,
        child: _ToggleTile(
          icon: Icons.picture_in_picture_alt_outlined,
          title: context.l10n.settingsPipTitle,
          value: pipEnabled,
          onChanged: (v) async {
            final prefs =
                await ref.read(appPreferencesProvider.future);
            await setPipEnabled(ref, v, prefs);
          },
        ),
      );
    }),
    Consumer(builder: (context, ref, _) {
      final notifyEnabled =
          ref.watch(mediaNotificationEnabledProvider);
      return InfoTooltip(
        id: 'settings_media_notification',
        title: context.l10n.settingsMediaNotificationTitle,
        body: context.l10n.settingsMediaNotificationBody,
        child: _ToggleTile(
          icon: Icons.notifications_active_outlined,
          title: context.l10n.settingsMediaNotificationTitle,
          value: notifyEnabled,
          onChanged: (v) async {
            final prefs =
                await ref.read(appPreferencesProvider.future);
            await setMediaNotificationEnabled(ref, v, prefs);
          },
        ),
      );
    }),
    // Android Auto video add-on (phones; installing apps is
    // an admin job).
    if (isAdmin && Platform.isAndroid && !PlatformHelper.isTVDevice)
      const CarVideoAddonTile(),
      ];

  List<Widget> _playerTiles(BuildContext context, ThemeData theme, bool isAdmin) => [
    Consumer(builder: (context, ref, _) {
      final seconds = ref.watch(skipSecondsProvider);
      return _ChoiceTile(
        icon: Icons.forward_10_rounded,
        title: context.l10n.settingsSkipButtonsTitle,
        options: const [5, 10, 30],
        current: seconds,
        label: (v) => context.l10n.settingsSecondsChoice(v),
        onPicked: (v) async {
          final prefs = await ref.read(appPreferencesProvider.future);
          await setSkipSeconds(ref, v, prefs);
        },
      );
    }),
    Consumer(builder: (context, ref, _) {
      final seconds = ref.watch(panelTimeoutProvider);
      return _ChoiceTile(
        icon: Icons.timer_outlined,
        title: context.l10n.settingsHideControlsTitle,
        options: const [3, 4, 6, 8, 12],
        current: seconds,
        label: (v) => context.l10n.settingsSecondsChoice(v),
        onPicked: (v) async {
          final prefs = await ref.read(appPreferencesProvider.future);
          await setPanelTimeout(ref, v, prefs);
        },
      );
    }),
    Consumer(builder: (context, ref, _) {
      final keys = ref.watch(seekKeysProvider);
      return _ChoiceTile(
        icon: Icons.keyboard_double_arrow_right_rounded,
        title: context.l10n.settingsSeekKeysTitle,
        options: const ['media', 'leftRight', 'upDown'],
        current: keys,
        label: (v) => switch (v) {
          'leftRight' => context.l10n.settingsSeekKeysLeftRight,
          'upDown' => context.l10n.settingsSeekKeysUpDown,
          _ => context.l10n.settingsSeekKeysMedia,
        },
        onPicked: (v) async {
          final prefs = await ref.read(appPreferencesProvider.future);
          await setSeekKeys(ref, v, prefs);
        },
      );
    }),
      ];

  List<Widget> _startupTiles(BuildContext context, ThemeData theme, bool isAdmin) => [
    Consumer(builder: (context, ref, _) {
      final on = ref.watch(lastChannelOnStartProvider);
      return InfoTooltip(
        id: 'settings_last_channel_on_start',
        title: context.l10n.settingsLastChannelTooltipTitle,
        body: context.l10n.settingsLastChannelBody,
        child: _ToggleTile(
          icon: Icons.live_tv_outlined,
          title: context.l10n.settingsLastChannelTitle,
          value: on,
          onChanged: (v) async {
            final prefs =
                await ref.read(appPreferencesProvider.future);
            await setLastChannelOnStart(ref, v, prefs);
          },
        ),
      );
    }),
    // TV: open the app by itself (needs "Display over other apps").
    if (PlatformHelper.isTVDevice) ...[
      Consumer(builder: (context, ref, _) {
        return InfoTooltip(
          id: 'settings_start_on_boot',
          title: context.l10n.settingsStartOnBootTitle,
          body: context.l10n.settingsStartOnBootBody,
          child: _ToggleTile(
            icon: Icons.power_settings_new_rounded,
            title: context.l10n.settingsStartOnBootTitle,
            value: ref.watch(startOnBootProvider),
            onChanged: (v) async {
              final prefs =
                  await ref.read(appPreferencesProvider.future);
              await setStartup(ref, prefs, boot: v);
              if (v && context.mounted) await _askOverlay(context);
            },
          ),
        );
      }),
      Consumer(builder: (context, ref, _) {
        return InfoTooltip(
          id: 'settings_start_on_wake',
          title: context.l10n.settingsStartOnWakeTitle,
          body: context.l10n.settingsStartOnWakeBody,
          child: _ToggleTile(
            icon: Icons.bedtime_outlined,
            title: context.l10n.settingsStartOnWakeTitle,
            value: ref.watch(startOnWakeProvider),
            onChanged: (v) async {
              final prefs =
                  await ref.read(appPreferencesProvider.future);
              await setStartup(ref, prefs, wake: v);
              if (v && context.mounted) await _askOverlay(context);
            },
          ),
        );
      }),
    ],
      ];

  List<Widget> _channelListTiles(BuildContext context, ThemeData theme, bool isAdmin) => [
    Consumer(builder: (context, ref, _) {
      final sort = ref.watch(contentSortProvider);
      return InfoTooltip(
        id: 'settings_sort_order',
        title: context.l10n.settingsSortOrderTitle,
        body: context.l10n.settingsSortOrderBody,
        child: _NavTile(
          leading: const Icon(Icons.sort),
          title: context.l10n.settingsSortOrderTitle,
          subtitle: Text(
            sort == 'az'
                ? context.l10n.settingsSortAz
                : context.l10n.settingsSortProvider,
            style: theme.textTheme.bodySmall,
          ),
          onTap: () => _showSortOrderDialog(context, ref, sort),
        ),
      );
    }),
    if (isAdmin)
      InfoTooltip(
        id: 'settings_hidden_cats',
        title: context.l10n.settingsHiddenCategoriesTitle,
        body: context.l10n.settingsHiddenCategoriesBody,
        child: _NavTile(
          leading: const Icon(Icons.visibility_off_outlined),
          title: context.l10n.settingsHiddenCategoriesTitle,
          onTap: () => _showHiddenCategoriesPage(context),
        ),
      ),
    Consumer(
      builder: (context, ref, _) => _NavTile(
        leading: const Icon(Icons.restart_alt_rounded),
        title: context.l10n.settingsResetCategoriesTitle,
        onTap: () => _resetCategories(context, ref),
      ),
    ),
    Consumer(builder: (context, ref, _) {
      final count =
          ref.watch(channelCustomProvider.select((c) => c.hidden.length));
      return InfoTooltip(
        id: 'settings_hidden_channels',
        title: context.l10n.settingsHiddenChannelsTitle,
        body: context.l10n.settingsHiddenChannelsBody,
        child: _NavTile(
          leading: const Icon(Icons.block_outlined),
          title: context.l10n.settingsHiddenChannelsTitle,
          subtitle: Text(
            count == 0
                ? context.l10n.settingsHiddenChannelsNone
                : context.l10n.settingsHiddenChannelsCount(count),
            style: theme.textTheme.bodySmall,
          ),
          onTap: () => _showHiddenChannelsPage(context),
        ),
      );
    }),
    Consumer(builder: (context, ref, _) => _liveToggle(
          ref,
          icon: Icons.star_outline_rounded,
          title: context.l10n.settingsShowFavorites,
          provider: showFavoritesCategoryProvider,
          save: (p, v) => p.setShowFavoritesCategory(v),
        )),
    Consumer(builder: (context, ref, _) => _liveToggle(
          ref,
          icon: Icons.history_rounded,
          title: context.l10n.settingsShowRecent,
          provider: showRecentCategoryProvider,
          save: (p, v) => p.setShowRecentCategory(v),
        )),
    if (PlatformHelper.isTVDevice) ...[
      Consumer(builder: (context, ref, _) => _liveToggle(
            ref,
            icon: Icons.live_tv_outlined,
            title: context.l10n.settingsShowAllChannels,
            provider: showAllCategoryProvider,
            save: (p, v) => p.setShowAllCategory(v),
          )),
    ],
      ];

  List<Widget> _guideLayoutTiles(BuildContext context, ThemeData theme, bool isAdmin) => [
    Consumer(builder: (context, ref, _) => _liveToggle(
          ref,
          icon: Icons.badge_outlined,
          title: context.l10n.settingsGuideShowNames,
          provider: guideShowNamesProvider,
          save: (p, v) => p.setGuideShowNames(v),
        )),
    Consumer(builder: (context, ref, _) => _liveToggle(
          ref,
          icon: Icons.format_line_spacing_rounded,
          title: context.l10n.settingsGuideTwoLineNames,
          provider: guideTwoLineNamesProvider,
          save: (p, v) => p.setGuideTwoLineNames(v),
        )),
    Consumer(builder: (context, ref, _) => _liveToggle(
          ref,
          icon: Icons.view_agenda_outlined,
          title: context.l10n.settingsGuideTwoLineTitles,
          provider: guideTwoLineTitlesProvider,
          save: (p, v) => p.setGuideTwoLineTitles(v),
        )),
    Consumer(builder: (context, ref, _) => _liveToggle(
          ref,
          icon: Icons.graphic_eq_rounded,
          title: context.l10n.settingsGuideHighlightPlaying,
          provider: guideHighlightPlayingProvider,
          save: (p, v) => p.setGuideHighlightPlaying(v),
        )),
      ];

  List<Widget> _appearanceTiles(BuildContext context, ThemeData theme, bool isAdmin) => [
    Consumer(builder: (context, ref, _) {
      final pref = ref.watch(languageProvider);
      return _NavTile(
        leading: const Icon(Icons.language_rounded),
        title: AppLocalizations.of(context).languageTitle,
        subtitle: Text(languageLabel(context, pref),
            style: theme.textTheme.bodySmall),
        onTap: () => showLanguagePicker(context, ref),
      );
    }),
    Consumer(builder: (context, ref, _) {
      final accent = ref.watch(accentColorProvider);
      return InfoTooltip(
        id: 'settings_accent_color',
        title: context.l10n.settingsAccentColorTitle,
        body: context.l10n.settingsAccentColorBody,
        child: _NavTile(
          leading: CircleAvatar(
            radius: 20,
            backgroundColor: accent.withValues(alpha: 0.14),
            child: CircleAvatar(backgroundColor: accent, radius: 10),
          ),
          title: context.l10n.settingsAccentColorTitle,
          subtitle: Text(
            _accentName(
                context,
                AppTheme.accentSwatches
                    .firstWhere((s) => s.color == accent,
                        orElse: () => (label: 'Custom', color: accent))
                    .label),
            style: theme.textTheme.bodySmall,
          ),
          onTap: () => _showAccentColorPicker(context, ref, accent),
        ),
      );
    }),
    Consumer(builder: (context, ref, _) {
      final scale = ref.watch(fontScaleProvider);
      return _ChoiceTile(
        icon: Icons.text_fields_rounded,
        title: context.l10n.settingsTextSizeTitle,
        options: const [0.85, 1.0, 1.15, 1.3],
        current: scale,
        label: (v) => switch (v) {
          0.85 => context.l10n.settingsTextSizeSmall,
          1.15 => context.l10n.settingsTextSizeLarge,
          1.3 => context.l10n.settingsTextSizeExtraLarge,
          _ => context.l10n.settingsTextSizeDefault,
        },
        onPicked: (v) async {
          final prefs = await ref.read(appPreferencesProvider.future);
          await setFontScale(ref, v, prefs);
        },
      );
    }),
    Consumer(builder: (context, ref, _) {
      final mode = ref.watch(overlayOpacityProvider);
      return _ChoiceTile(
        icon: Icons.opacity_rounded,
        title: context.l10n.settingsPlayerTransparencyTitle,
        options: const ['solid', 'normal', 'clear', 'veryclear'],
        current: mode,
        label: (v) => switch (v) {
          'solid' => context.l10n.settingsPlayerTransparencySolid,
          'clear' => context.l10n.settingsPlayerTransparencyClear,
          'veryclear' => context.l10n.settingsPlayerTransparencyVeryClear,
          _ => context.l10n.settingsPlayerTransparencyDefault,
        },
        onPicked: (v) async {
          final prefs = await ref.read(appPreferencesProvider.future);
          await setOverlayOpacity(ref, v, prefs);
        },
      );
    }),
    InfoTooltip(
      id: 'settings_clean_names',
      title: context.l10n.settingsCleanNamesTitle,
      body: context.l10n.settingsCleanNamesBody,
      child: Consumer(builder: (context, ref, _) {
        return _ToggleTile(
          icon: Icons.auto_fix_high_outlined,
          title: context.l10n.settingsCleanNamesTitle,
          value: ref.watch(cleanNamesProvider),
          onChanged: (v) async {
            final prefs =
                await ref.read(appPreferencesProvider.future);
            await setCleanNames(ref, v, prefs);
          },
        );
      }),
    ),
      ];

  List<Widget> _aboutTiles(BuildContext context, ThemeData theme, bool isAdmin) => [
    InfoTooltip(
      id: 'settings_about',
      title: context.l10n.settingsAboutTitle,
      body: context.l10n.settingsAboutBody,
      child: FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snap) {
          final version = snap.hasData
              ? context.l10n.settingsAboutVersion(snap.data!.version)
              : 'OpenIPTV';
          return _NavTile(
            leading: const Icon(Icons.info_outline),
            title: context.l10n.settingsAboutTitle,
            subtitle: Text(version, style: theme.textTheme.bodySmall),
            showChevron: false,
            onTap: () => _showAboutDialog(context, snap.data),
          );
        },
      ),
    ),
      ];

  List<Widget> _advancedTiles(BuildContext context, ThemeData theme, bool isAdmin) => [
    InfoTooltip(
      id: 'settings_power_tools',
      title: context.l10n.settingsPowerToolsTitle,
      body: context.l10n.settingsPowerToolsBody,
      child: _NavTile(
        leading: const Icon(Icons.tune),
        title: context.l10n.settingsPowerToolsTitle,
        subtitle: Text(context.l10n.settingsPowerToolsSubtitle,
            style: theme.textTheme.bodySmall),
        onTap: () => context.push('/settings/power-tools'),
      ),
    ),
    InfoTooltip(
      id: 'settings_anonymous_reports',
      title: context.l10n.settingsAnonReportsTitle,
      body: context.l10n.settingsAnonReportsBody,
      child: _NavTile(
        leading: const Icon(Icons.bug_report_outlined),
        title: context.l10n.settingsAnonReportsTitle,
        subtitle: Consumer(builder: (context, ref, _) {
          final on =
              ref.watch(statsChoiceProvider) == StatsChoice.on;
          return Text(on ? context.l10n.settingsOn : context.l10n.settingsOff,
              style: theme.textTheme.bodySmall);
        }),
        onTap: () => context.push('/settings/anonymous-reports'),
      ),
    ),
      ];

  void _openSourcesPage(BuildContext context) {
    // Sources management: show a simple list with delete + refresh options.
    // Full sources page is a future enhancement; for Phase 1 we show a sheet.
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _SourcesSheet(),
    );
  }

  Future<void> _showSortOrderDialog(
      BuildContext context, WidgetRef ref, String current) async {
    final prefs = await ref.read(appPreferencesProvider.future);
    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.settingsSortOrderTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DialogChoice(
              label: context.l10n.settingsSortProvider,
              selected: current == 'provider',
              onTap: () async {
                Navigator.of(ctx).pop();
                await setContentSort(ref, 'provider', prefs);
              },
            ),
            _DialogChoice(
              label: context.l10n.settingsSortAz,
              selected: current == 'az',
              onTap: () async {
                Navigator.of(ctx).pop();
                await setContentSort(ref, 'az', prefs);
              },
            ),
          ],
        ),
        actions: [
          TvActivatable(
            onTap: () => Navigator.of(ctx).pop(),
            builder: (onTap) =>
                TextButton(onPressed: onTap, child: Text(context.l10n.commonCancel)),
          ),
        ],
      ),
    );
  }

  String _refreshIntervalLabel(BuildContext context, int hours) {
    return switch (hours) {
      2 || 6 || 12 || 24 => context.l10n.settingsAutoRefreshEvery(hours),
      _ => context.l10n.settingsAutoRefreshOff,
    };
  }

  Future<void> _showAutoRefreshDialog(
      BuildContext context, WidgetRef ref, int current) async {
    final prefs = await ref.read(appPreferencesProvider.future);
    if (!context.mounted) return;
    final selected = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.settingsAutoRefreshTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final hours in [0, 2, 6, 12, 24])
              _DialogChoice(
                label: _refreshIntervalLabel(context, hours),
                selected: current == hours,
                onTap: () => Navigator.of(ctx).pop(hours),
              ),
            // Only meaningful while auto-refresh is on.
            if (current > 0) ...[
              const Divider(),
              Consumer(builder: (context, ref, _) {
                return _ToggleTile(
                  icon: Icons.notifications_outlined,
                  title: context.l10n.settingsAutoRefreshNotifyTitle,
                  value: ref.watch(refreshNotificationsEnabledProvider),
                  onChanged: (v) async {
                    await setRefreshNotificationsEnabled(ref, v, prefs);
                  },
                );
              }),
            ],
          ],
        ),
        actions: [
          TvActivatable(
            onTap: () => Navigator.of(ctx).pop(),
            builder: (onTap) =>
                TextButton(onPressed: onTap, child: Text(context.l10n.commonCancel)),
          ),
        ],
      ),
    );
    if (selected == null || selected == current) return;
    if (!context.mounted) return;

    final turningOn = current <= 0 && selected > 0;
    await setRefreshIntervalHours(ref, selected, prefs);

    if (turningOn && context.mounted) {
      await _runAutoRefreshPermissionFlow(context);
    }
  }

  /// One-time rationale + permission chain, shown only when auto-refresh is
  /// turned on from Off. Declining either permission doesn't block enabling
  /// the feature — WorkManager still runs, just less reliably without the
  /// battery exemption, and silently without a visible notification if that
  /// permission is denied.
  Future<void> _runAutoRefreshPermissionFlow(BuildContext context) async {
    final wantsNotifications = await _askPermission(
      context,
      title: context.l10n.settingsStayInformedTitle,
      body: context.l10n.settingsStayInformedBody,
      confirmLabel: context.l10n.settingsAllow,
    );
    if (wantsNotifications) {
      await requestNotificationPermission();
    }
    if (!context.mounted) return;

    final wantsBatteryExemption = await _askPermission(
      context,
      title: context.l10n.settingsReliableRefreshTitle,
      body: context.l10n.settingsReliableRefreshBody,
      confirmLabel: context.l10n.settingsContinue,
    );
    if (wantsBatteryExemption) {
      await requestBatteryOptimizationExemption();
    }
  }

  /// Rationale dialog shown before a system permission prompt: "Not Now" vs
  /// [confirmLabel]. Dismissing it counts as declining.
  Future<bool> _askPermission(
    BuildContext context, {
    required String title,
    required String body,
    required String confirmLabel,
  }) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TvActivatable(
            onTap: () => Navigator.of(ctx).pop(false),
            builder: (onTap) =>
                TextButton(onPressed: onTap, child: Text(context.l10n.commonNotNow)),
          ),
          TvActivatable(
            autofocus: true,
            onTap: () => Navigator.of(ctx).pop(true),
            builder: (onTap) =>
                FilledButton(onPressed: onTap, child: Text(confirmLabel)),
          ),
        ],
      ),
    );
    return accepted ?? false;
  }

  void _showAccentColorPicker(
      BuildContext context, WidgetRef ref, Color current) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Text(context.l10n.settingsAccentColorTitle,
                  style: Theme.of(ctx).textTheme.titleMedium),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                children: AppTheme.accentSwatches.asMap().entries.map((entry) {
                  final i = entry.key;
                  final swatch = entry.value;
                  final selected = swatch.color == current;
                  return TvFocusable(
                    // The remote starts on the current colour.
                    autofocus: AppTheme.accentSwatches.any((w) => w.color == current)
                        ? selected
                        : i == 0,
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      final prefs =
                          await ref.read(appPreferencesProvider.future);
                      await setAccentColor(ref, swatch.color, prefs);
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: swatch.color,
                            shape: BoxShape.circle,
                            border: selected
                                ? Border.all(
                                    color: Theme.of(ctx).colorScheme.onSurface,
                                    width: 3)
                                : null,
                          ),
                          child: selected
                              ? const Icon(Icons.check,
                                  color: Colors.white, size: 26)
                              : null,
                        ),
                        const SizedBox(height: 6),
                        Text(_accentName(context, swatch.label),
                            style: Theme.of(ctx).textTheme.bodySmall),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Starting the app by itself needs Android's "Display over other apps"
  /// permission. If it isn't allowed yet, explain and offer the system screen.
  Future<void> _askOverlay(BuildContext context) async {
    if (await canDrawOverOtherApps()) return;
    if (!context.mounted) return;
    final open = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.settingsOverlayDialogTitle),
        content: Text(context.l10n.settingsOverlayDialogBody),
        actions: [
          TvActivatable(
            onTap: () => Navigator.of(dialogContext).pop(false),
            builder: (onTap) =>
                TextButton(onPressed: onTap, child: Text(context.l10n.commonNotNow)),
          ),
          TvActivatable(
            autofocus: true,
            onTap: () => Navigator.of(dialogContext).pop(true),
            builder: (onTap) => FilledButton(
                onPressed: onTap, child: Text(context.l10n.settingsOverlayOpenSettings)),
          ),
        ],
      ),
    );
    if (open == true) await requestOverlayPermission();
  }

  /// Back to the provider's Live TV category names and order, for the
  /// active profile (hold OK / long-press on a category changes them).
  Future<void> _resetCategories(BuildContext context, WidgetRef ref) async {
    final profile = ref.read(activeProfileProvider).valueOrNull;
    if (profile == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.settingsResetCategoriesDialogTitle),
        content: Text(context.l10n.settingsResetCategoriesDialogBody),
        actions: [
          TvActivatable(
            autofocus: true,
            onTap: () => Navigator.of(dialogContext).pop(false),
            builder: (onTap) =>
                TextButton(onPressed: onTap, child: Text(context.l10n.commonCancel)),
          ),
          TvActivatable(
            onTap: () => Navigator.of(dialogContext).pop(true),
            builder: (onTap) =>
                FilledButton(onPressed: onTap, child: Text(context.l10n.settingsReset)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref
        .read(profileServiceProvider)
        .resetCategoryCustomisation(profile.id);
    ref.invalidate(activeProfileProvider);
  }

  /// A switch for one Live TV option, saved in preferences.
  Widget _liveToggle(
    WidgetRef ref, {
    required IconData icon,
    required String title,
    required StateProvider<bool> provider,
    required Future<void> Function(AppPreferences, bool) save,
  }) {
    return _ToggleTile(
      icon: icon,
      title: title,
      value: ref.watch(provider),
      onChanged: (v) async {
        final prefs = await ref.read(appPreferencesProvider.future);
        await setLiveOption(ref, provider, v, (b) => save(prefs, b));
      },
    );
  }

  void _showHiddenChannelsPage(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _HiddenChannelsSheet(),
    );
  }

  void _showHiddenCategoriesPage(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => const _HiddenCategoriesSheet(),
    );
  }

  void _showAboutDialog(BuildContext context, PackageInfo? info) {
    showAboutDialog(
      context: context,
      applicationName: 'OpenIPTV',
      applicationVersion: info != null ? info.version : '',
      applicationLegalese: context.l10n.settingsAboutLegalese,
      children: [
        const SizedBox(height: 16),
        Text(context.l10n.settingsAboutDescription),
      ],
    );
  }
}

/// A page of related settings opened from the main list.
class _SubPage extends StatelessWidget {
  const _SubPage({required this.title, required this.groups});

  final String title;

  /// Group heading (null = none) and its rows.
  final List<(String?, List<Widget>)> groups;

  @override
  Widget build(BuildContext context) {
    return InfoTooltipScope(
      controller: InfoTooltipController(),
      child: Scaffold(
        appBar: AppBar(title: Text(title)),
        body: TvFollowFocus(focusFirst: true, child: ListView(
          padding: EdgeInsets.only(
              bottom: 32 + MediaQuery.paddingOf(context).bottom),
          children: [
            for (final (heading, rows) in groups)
              SettingsGroup(title: heading ?? '', children: rows),
          ],
        )),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helper widgets
// ---------------------------------------------------------------------------

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final bool value;
  final void Function(bool) onChanged;

  @override
  Widget build(BuildContext context) {
    return InfoGutter(
      child: TvActivatable(
        onTap: () => onChanged(!value),
        builder: (_) => SwitchListTile(
          secondary: IconBadge(icon: icon),
          title: Text(title),
          value: value,
          onChanged: onChanged,
          focusNode: null,
        ),
      ),
    );
  }
}

/// A settings row that opens something else — icon, title, optional subtitle,
/// trailing chevron — reachable by both tap and remote OK.
class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.leading,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.autofocus = false,
    this.showChevron = true,
  });

  final Widget leading;
  final String title;
  final Widget? subtitle;
  final VoidCallback onTap;
  final bool autofocus;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return InfoGutter(
      child: TvActivatable(
        onTap: onTap,
        autofocus: autofocus,
        builder: (onTap) => ListTile(
          leading: leading is Icon
              ? IconBadge(icon: (leading as Icon).icon!)
              : leading,
          title: Text(title),
          subtitle: subtitle,
          trailing: showChevron ? const Icon(Icons.chevron_right) : null,
          onTap: onTap,
        ),
      ),
    );
  }
}

/// A settings row that shows its current choice and opens a radio-style
/// dialog to change it.
class _ChoiceTile<T> extends StatelessWidget {
  const _ChoiceTile({
    required this.icon,
    required this.title,
    required this.options,
    required this.current,
    required this.label,
    required this.onPicked,
  });

  final IconData icon;
  final String title;
  final List<T> options;
  final T current;
  final String Function(T) label;
  final Future<void> Function(T) onPicked;

  @override
  Widget build(BuildContext context) {
    return _NavTile(
      leading: Icon(icon),
      title: title,
      subtitle: Text(
        label(current),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      onTap: () async {
        final picked = await showDialog<T>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: options
                  .map((v) => _DialogChoice(
                        label: label(v),
                        selected: v == current,
                        onTap: () => Navigator.of(ctx).pop(v),
                      ))
                  .toList(),
            ),
            actions: [
              TvActivatable(
                onTap: () => Navigator.of(ctx).pop(),
                builder: (onTap) =>
                    TextButton(onPressed: onTap, child: Text(context.l10n.commonCancel)),
              ),
            ],
          ),
        );
        if (picked != null && picked != current) await onPicked(picked);
      },
    );
  }
}

/// A radio-style dialog row: the check mark is tinted on the selected option
/// and transparent (but still occupying its slot) on the others, so the
/// labels stay aligned.
class _DialogChoice extends StatelessWidget {
  const _DialogChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TvActivatable(
      // The remote starts on the current choice, not on nothing.
      autofocus: selected,
      onTap: onTap,
      builder: (onTap) => SimpleDialogOption(
        onPressed: onTap,
        child: Row(children: [
          Icon(Icons.check,
              size: 18,
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent),
          const SizedBox(width: 8),
          Text(label),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sources bottom sheet
// ---------------------------------------------------------------------------

class _SourcesSheet extends ConsumerStatefulWidget {
  const _SourcesSheet();

  @override
  ConsumerState<_SourcesSheet> createState() => _SourcesSheetState();
}

class _SourcesSheetState extends ConsumerState<_SourcesSheet> {
  final _refreshingPlaylist = <String>{};
  final _refreshingEpg = <String>{};

  /// The sheet's own messenger: a snackbar sent to the Settings page would
  /// sit behind this modal sheet, where the result can't be read.
  final _messenger = GlobalKey<ScaffoldMessengerState>();

  void _showMessage(String text) =>
      _messenger.currentState?.showSnackBar(SnackBar(content: Text(text)));

  Future<void> _refreshPlaylist(String id) async {
    if (_refreshingPlaylist.contains(id) || _refreshingEpg.contains(id)) return;
    setState(() => _refreshingPlaylist.add(id));
    try {
      final sources = await ref.read(allSourcesProvider.future);
      final source = sources.firstWhere((s) => s.id == id);
      await ref.read(sourceManagerProvider).refreshPlaylist(source);
      ref.invalidate(allSourcesProvider);
      if (mounted) {
        _showMessage(context.l10n.settingsPlaylistRefreshed(source.nickname));
      }
    } catch (e) {
      if (mounted) {
        _showMessage(
            context.l10n.settingsPlaylistRefreshFailed(
                friendlySourceErrorMessage(e, context.l10n)));
      }
    } finally {
      if (mounted) setState(() => _refreshingPlaylist.remove(id));
    }
  }

  // Closes this sheet (popped with its own context — see the lessons on
  // root-navigator sheets) and opens the editor above Settings.
  void _editSource(Source s) {
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(MaterialPageRoute<void>(
      builder: (_) => EditPlaylistScreen(source: s),
    ));
  }

  Future<void> _refreshEpg(String id) async {
    if (_refreshingPlaylist.contains(id) || _refreshingEpg.contains(id)) return;
    setState(() => _refreshingEpg.add(id));
    Source? source;
    try {
      final sources = await ref.read(allSourcesProvider.future);
      source = sources.firstWhere((s) => s.id == id);
      await ref.read(sourceManagerProvider).refreshEpgOnly(source);
      if (mounted) {
        _showMessage(context.l10n.settingsGuideRefreshed(source.nickname));
      }
    } catch (e) {
      if (mounted) {
        _showMessage(friendlyEpgErrorMessage(e, context.l10n));
      }
    } finally {
      if (mounted) setState(() => _refreshingEpg.remove(id));
    }
  }

  /// [source] null = browse every playlist together.
  Future<void> _switchSource(BuildContext context, Source? source) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.settingsSwitchPlaylistTitle),
        content: Text(
          source == null
              ? context.l10n.settingsSwitchToAllBody
              : context.l10n.settingsSwitchToOneBody(source.nickname),
        ),
        actions: [
          TvActivatable(
            onTap: () => Navigator.of(ctx).pop(false),
            builder: (onTap) =>
                TextButton(onPressed: onTap, child: Text(context.l10n.commonCancel)),
          ),
          TvActivatable(
            autofocus: true,
            onTap: () => Navigator.of(ctx).pop(true),
            builder: (onTap) =>
                FilledButton(onPressed: onTap, child: Text(context.l10n.settingsSwitch)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final prefs = await ref.read(appPreferencesProvider.future);
      await setActiveSource(ref, source?.id, prefs);
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    String id,
    String nickname,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.settingsRemovePlaylistTitle),
        content: Text(context.l10n.settingsRemovePlaylistBody(nickname)),
        actions: [
          TvActivatable(
            autofocus: true,
            onTap: () => Navigator.of(ctx).pop(false),
            builder: (onTap) =>
                TextButton(onPressed: onTap, child: Text(context.l10n.commonCancel)),
          ),
          TvActivatable(
            onTap: () => Navigator.of(ctx).pop(true),
            builder: (onTap) => FilledButton(
              onPressed: onTap,
              style: AppTheme.destructiveButtonStyle(ctx),
              child: Text(context.l10n.settingsRemove),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      // Show a professional, non-dismissible loading dialog.
      // On large playlists the DB cleanup + compact can take 10+ seconds;
      // without feedback the settings sheet looks frozen.
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Text(
                  context.l10n.settingsRemovingPlaylist(nickname),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      );
      try {
        debugPrint('[OTV-settings] Starting deletion of $id');
        await ref.read(sourceManagerProvider).deleteSource(id);
        // Clear active source if it was the deleted one.
        if (ref.read(activeSourceIdProvider) == id) {
          final prefs = await ref.read(appPreferencesProvider.future);
          await setActiveSource(ref, null, prefs);
        }
        debugPrint('[OTV-settings] Invalidating allSourcesProvider');
        ref.invalidate(allSourcesProvider);
      } catch (e) {
        debugPrint('[OTV-settings] Deletion failed: $e');
      } finally {
        if (mounted && context.mounted) {
          // Pop the loading dialog.
          Navigator.of(context, rootNavigator: true).pop();
        }
      }
    }
  }

  void _showInfoPanel(BuildContext context, Source source) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SourceInfoSheet(source: source),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sourcesAsync = ref.watch(allSourcesProvider);
    final activeSourceId = ref.watch(activeSourceIdProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (context, controller) => _withMessenger(Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(context.l10n.settingsPlaylistsTitle,
                    style: Theme.of(context).textTheme.titleLarge),
                TvActivatable(
                  // TV: something in the sheet must hold the remote, or the
                  // first key lands on an off-screen row. This is the one
                  // harmless choice (a row would switch playlists on OK).
                  autofocus: true,
                  focusScale: 1.06,
                  onTap: () {
                    // Grab the router before popping — this sheet's context
                    // is torn down by the pop.
                    final router = GoRouter.of(context);
                    Navigator.of(context).pop();
                    router.push('/onboarding');
                  },
                  builder: (onTap) => FilledButton.icon(
                    icon: const Icon(Icons.add),
                    label: Text(context.l10n.settingsAddPlaylist),
                    onPressed: onTap,
                  ),
                ),
              ],
            ),
          ),
          if ((sourcesAsync.valueOrNull?.length ?? 0) > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                context.l10n.settingsChoosePlaylistHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          const Divider(height: 1),
          Expanded(
            child: sourcesAsync.when(
              loading: () => const LoadingView(),
              error: (_, __) =>
                  Center(child: Text(context.l10n.settingsPlaylistsLoadError)),
              data: (sources) {
                if (sources.isEmpty) {
                  return Center(child: Text(context.l10n.settingsPlaylistsEmpty));
                }
                final multiSource = sources.length > 1;
                // With several playlists, a leading "All playlists" row makes
                // the no-active-playlist state (everything merged) visible
                // and selectable.
                final allOffset = multiSource ? 1 : 0;
                return TvFollowFocus(child: ListView.builder(
                  controller: controller,
                  itemCount: sources.length + allOffset,
                  itemBuilder: (context, index) {
                    if (index < allOffset) {
                      final allActive = activeSourceId == null;
                      return TvActivatable(
                        onTap: allActive
                            ? null
                            : () => _switchSource(context, null),
                        builder: (onTap) => ListTile(
                          leading: _PlaylistBadge(
                              icon: Icons.library_books_outlined,
                              active: allActive),
                          title: Text(context.l10n.settingsAllPlaylists),
                          subtitle: Text(
                            context.l10n.settingsPlaylistsCombined(sources.length),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          onTap: onTap,
                        ),
                      );
                    }
                    final s = sources[index - allOffset];
                    final isActive = activeSourceId == s.id ||
                        (!multiSource && activeSourceId == null);
                    final isPlaylistRefreshing =
                        _refreshingPlaylist.contains(s.id);
                    final isEpgRefreshing = _refreshingEpg.contains(s.id);
                    final isBusy = isPlaylistRefreshing || isEpgRefreshing;
                    return TvRevealOnFocus(
                      child: TvActivatable(
                        // A busy row stays focusable (doing nothing), or the
                        // remote's focus on its refresh button is lost.
                        onTap: multiSource && !isActive
                            ? (isBusy ? () {} : () => _switchSource(context, s))
                            : null,
                        builder: (onTap) => ListTile(
                          leading: _PlaylistBadge(
                              icon: Icons.playlist_play_rounded,
                              active: isActive),
                          title: Text(s.nickname),
                          subtitle: Text(
                            [
                              s.type == SourceType.xtream
                                  ? 'Xtream Codes'
                                  : LocalPlaylists.isLocal(s.m3uUrl)
                                      ? context.l10n.settingsSourceFile
                                      : context.l10n.settingsSourceM3u,
                              if (isActive && multiSource) context.l10n.settingsBrowsing,
                            ].join(' · '),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          onTap: onTap,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _SourceAction(
                                icon: Icons.sync_rounded,
                                tooltip: context.l10n.settingsRefreshPlaylistTooltip,
                                busy: isBusy,
                                onTap: isBusy
                                    ? null
                                    : () => _refreshPlaylist(s.id),
                              ),
                              _SourceMenu(
                                enabled: !isBusy,
                                onEdit: () => _editSource(s),
                                onInfo: () => _showInfoPanel(context, s),
                                onRefreshGuide: () => _refreshEpg(s.id),
                                onRemove: () =>
                                    _confirmDelete(context, s.id, s.nickname),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ));
              },
            ),
          ),
        ],
      )),
    );
  }

  Widget _withMessenger(Widget child) => ScaffoldMessenger(
        key: _messenger,
        child: Scaffold(backgroundColor: Colors.transparent, body: child),
      );
}

/// A playlist's icon in a tinted circle; the one being browsed gets a
/// solid accent circle with a tick.
class _PlaylistBadge extends StatelessWidget {
  const _PlaylistBadge({required this.icon, required this.active});

  final IconData icon;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    if (!active) return IconBadge(icon: icon);
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Icon(Icons.check_rounded,
          size: 22, color: Theme.of(context).colorScheme.onPrimary),
    );
  }
}

/// The less-used playlist actions, tucked into a ⋮ menu.
class _SourceMenu extends StatelessWidget {
  const _SourceMenu({
    required this.enabled,
    required this.onEdit,
    required this.onInfo,
    required this.onRefreshGuide,
    required this.onRemove,
  });

  final bool enabled;
  final VoidCallback onEdit;
  final VoidCallback onInfo;
  final VoidCallback onRefreshGuide;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final menuKey = GlobalKey<PopupMenuButtonState<int>>();
    final error = Theme.of(context).colorScheme.error;
    PopupMenuItem<int> item(int v, IconData icon, String label,
        [Color? color]) {
      final row = Row(children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: color)),
      ]);
      return PopupMenuItem(
        value: v,
        child: v == 3 ? TvInitialFocus(child: row) : row,
      );
    }

    return TvFocusable(
      wrapsGesture: false,
      borderRadius: BorderRadius.circular(20),
      onTap: () => enabled ? menuKey.currentState?.showButtonMenu() : null,
      child: TvMenuTheme(
        child: PopupMenuButton<int>(
          key: menuKey,
          enabled: enabled,
          tooltip: context.l10n.settingsMoreTooltip,
          onSelected: (v) => switch (v) {
            3 => onEdit(),
            0 => onInfo(),
            1 => onRefreshGuide(),
            _ => onRemove(),
          },
          itemBuilder: (_) => [
            item(3, Icons.edit_outlined, context.l10n.settingsEditPlaylist),
            item(0, Icons.info_outline, context.l10n.settingsPlaylistInfo),
            item(1, Icons.event_note_outlined, context.l10n.settingsRefreshTvGuide),
            const PopupMenuDivider(),
            item(2, Icons.delete_outline, context.l10n.settingsRemove, error),
          ],
        ),
      ),
    );
  }
}

/// One fixed-size slot in a playlist row's trailing action strip — an icon
/// button, or a spinner in its place while that action is running.
class _SourceAction extends StatelessWidget {
  const _SourceAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.busy = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      // The same (enabled, no-op) button shows the spinner while busy:
      // swapping it for a bare spinner removed the node the remote's focus
      // was on, and focus jumped back to another playlist's row.
      child: TvActivatable(
        round: true,
        onTap: busy ? () {} : onTap,
        builder: (onTap) => IconButton(
          icon: busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(icon, size: 20),
          tooltip: tooltip,
          onPressed: onTap,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Source info bottom sheet (#22)
// ---------------------------------------------------------------------------

class _SourceInfoSheet extends StatefulWidget {
  const _SourceInfoSheet({required this.source});

  final Source source;

  @override
  State<_SourceInfoSheet> createState() => _SourceInfoSheetState();
}

class _SourceInfoSheetState extends State<_SourceInfoSheet> {
  bool _loading = false;
  bool _failed = false;
  Map<String, dynamic>? _userInfo;
  Map<String, dynamic>? _serverInfo;

  @override
  void initState() {
    super.initState();
    if (widget.source.type == SourceType.xtream) _fetchInfo();
  }

  Future<void> _fetchInfo() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    final client = XtreamClient.fromSource(widget.source);
    try {
      final info = await client.getServerInfo();
      if (mounted) {
        setState(() {
          _userInfo = info['user_info'] as Map<String, dynamic>?;
          _serverInfo = info['server_info'] as Map<String, dynamic>?;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _failed = true;
          _loading = false;
        });
      }
    } finally {
      client.dispose();
    }
  }

  String _formatEpoch(dynamic value) {
    if (value == null) return '—';
    final epoch = int.tryParse(value.toString());
    if (epoch == null || epoch == 0) return '—';
    final dt = DateTime.fromMillisecondsSinceEpoch(epoch * 1000);
    return formatDate(dt, Localizations.localeOf(context));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final source = widget.source;
    final lastRefreshed = source.lastRefreshed;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(source.nickname, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              source.type == SourceType.xtream
                  ? 'Xtream Codes'
                  : LocalPlaylists.isLocal(source.m3uUrl)
                      ? context.l10n.settingsSourceFile
                      : context.l10n.settingsSourceM3u,
              style: theme.textTheme.bodySmall,
            ),
            const Divider(height: 28),
            if (source.type == SourceType.m3u) ...[
              LocalPlaylists.isLocal(source.m3uUrl)
                  ? _InfoRow(context.l10n.settingsInfoSource, context.l10n.settingsInfoFileSaved)
                  : _InfoRow('URL', redactUrl(source.m3uUrl ?? '—')),
              if (source.epgUrl != null)
                _InfoRow(context.l10n.settingsInfoGuideUrl, redactUrl(source.epgUrl!)),
              _InfoRow(
                context.l10n.settingsInfoLastRefreshed,
                lastRefreshed != null ? formatDate(lastRefreshed, Localizations.localeOf(context)) : context.l10n.settingsInfoNever,
              ),
            ] else if (_loading) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: CircularProgressIndicator(),
                ),
              ),
            ] else if (_failed) ...[
              Text(context.l10n.settingsInfoFetchError, style: TextStyle(color: theme.colorScheme.error)),
            ] else ...[
              _InfoRow(context.l10n.settingsInfoStatus, '${_userInfo?['status'] ?? '—'}'),
              _InfoRow(context.l10n.settingsInfoExpires, _formatEpoch(_userInfo?['exp_date'])),
              _InfoRow(
                  context.l10n.settingsInfoActiveConnections, '${_userInfo?['active_cons'] ?? '—'}'),
              _InfoRow(
                  context.l10n.settingsInfoMaxConnections, '${_userInfo?['max_connections'] ?? '—'}'),
              _InfoRow(context.l10n.settingsInfoTrial,
                  _userInfo?['is_trial'] == '1' ? context.l10n.settingsInfoYes : context.l10n.settingsInfoNo),
              const Divider(height: 24),
              _InfoRow(context.l10n.settingsInfoServer,
                  '${_serverInfo?['url'] ?? source.xtreamHost ?? '—'}'),
              _InfoRow(context.l10n.settingsInfoTimezone, '${_serverInfo?['timezone'] ?? '—'}'),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hidden categories sheet
// ---------------------------------------------------------------------------

class _HiddenCategoriesSheet extends ConsumerWidget {
  const _HiddenCategoriesSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(activeProfileProvider).valueOrNull;
    final hidden = profile?.hiddenCategories ?? [];

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(context.l10n.settingsHiddenCategoriesTitle,
                style: Theme.of(context).textTheme.titleLarge),
          ),
          const Divider(height: 1),
          Expanded(
            child: hidden.isEmpty
                ? Center(child: Text(context.l10n.settingsHiddenCategoriesNone))
                : TvFollowFocus(child: ListView.builder(
                    controller: controller,
                    itemCount: hidden.length,
                    itemBuilder: (context, i) => ListTile(
                      // Same name as in Live TV (the built-in "All Channels"
                      // row is stored under a private key).
                      title: Text(hidden[i] == '\u0001all'
                          ? context.l10n.settingsAllChannels
                          : categoryLabel(context, profile, hidden[i])),
                      trailing: TvActivatable(
                        autofocus: i == 0,
                        onTap: profile == null
                            ? null
                            : () async {
                                await ref
                                    .read(profileServiceProvider)
                                    .unhideCategory(profile.id, hidden[i]);
                                ref.invalidate(activeProfileProvider);
                              },
                        builder: (onTap) => TextButton(
                          onPressed: onTap,
                          child: Text(context.l10n.settingsShow),
                        ),
                      ),
                    ),
                  )),
          ),
        ],
      ),
    );
  }
}


/// Settings → Live TV → Hidden Channels: the channels this profile hid, with
/// a way to bring each (or all) back.
class _HiddenChannelsSheet extends ConsumerStatefulWidget {
  const _HiddenChannelsSheet();

  @override
  ConsumerState<_HiddenChannelsSheet> createState() =>
      _HiddenChannelsSheetState();
}

class _HiddenChannelsSheetState extends ConsumerState<_HiddenChannelsSheet> {
  // Channel details for the hidden ids (loaded once per change of the list).
  Map<String, Channel> _known = const {};

  Future<void> _load(Set<String> ids) async {
    final missing = ids.where((id) => !_known.containsKey(id)).take(500).toList();
    if (missing.isEmpty) return;
    final rows = await ref.read(appDatabaseProvider).getChannelsByIds(missing);
    if (!mounted) return;
    setState(() => _known = {..._known, for (final c in rows) c.id: c});
  }

  @override
  Widget build(BuildContext context) {
    final hidden = ref.watch(channelCustomProvider.select((c) => c.hidden));
    final ids = hidden.toList()..sort();
    _load(hidden);
    String nameOf(String id) {
      final c = _known[id];
      return c == null ? context.l10n.settingsChannelFromRemovedPlaylist : context.channelName(c);
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (context, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(context.l10n.settingsHiddenChannelsTitle,
                style: Theme.of(context).textTheme.titleLarge),
          ),
          const Divider(height: 1),
          Expanded(
            child: ids.isEmpty
                ? Center(child: Text(context.l10n.settingsHiddenChannelsEmpty))
                : TvFollowFocus(child: ListView.builder(
                    controller: controller,
                    itemCount: ids.length + 1,
                    itemBuilder: (context, i) {
                      if (i == ids.length) {
                        return Padding(
                          padding: const EdgeInsets.all(12),
                          child: TvActivatable(
                            onTap: () => ref
                                .read(channelCustomProvider.notifier)
                                .unhideAll(),
                            builder: (onTap) => OutlinedButton(
                              onPressed: onTap,
                              child: Text(context.l10n.settingsShowAll),
                            ),
                          ),
                        );
                      }
                      final id = ids[i];
                      return ListTile(
                        title: Text(nameOf(id)),
                        trailing: TvActivatable(
                          autofocus: i == 0,
                          onTap: () => ref
                              .read(channelCustomProvider.notifier)
                              .unhide(id),
                          builder: (onTap) => TextButton(
                            onPressed: onTap,
                            child: Text(context.l10n.settingsShow),
                          ),
                        ),
                      );
                    },
                  )),
          ),
        ],
      ),
    );
  }
}
