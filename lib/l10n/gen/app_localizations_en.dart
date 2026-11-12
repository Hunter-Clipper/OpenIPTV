// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get commonBack => 'Back';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonNotNow => 'Not now';

  @override
  String get wizardConnecting => 'Connecting…';

  @override
  String get wizardPickFileTitle => 'Choose a playlist file';

  @override
  String get wizardFilePickerFailed =>
      'Couldn\'t open the file picker on this device.';

  @override
  String get wizardChooseFileFirst => 'Choose a playlist file first.';

  @override
  String get wizardFieldServerAddress => 'the server address';

  @override
  String get wizardFieldUsername => 'the username';

  @override
  String get wizardFieldPassword => 'the password';

  @override
  String get wizardFieldM3uUrl => 'the M3U link';

  @override
  String wizardListAnd(String rest, String last) {
    return '$rest and $last';
  }

  @override
  String wizardEnterMissing(String fields) {
    return 'Enter $fields from your provider.';
  }

  @override
  String get wizardRestoreEmpty =>
      'That backup doesn\'t include a profile and a playlist, so there\'s nothing to restore yet. Tap Get Started instead.';

  @override
  String wizardRestoreProgressItem(String nickname, int index, int total) {
    return '$nickname ($index of $total)';
  }

  @override
  String wizardRestoreProgressLine(String label, String message) {
    return '$label — $message';
  }

  @override
  String get wizardLoadingRestoring => 'Restoring your playlists…';

  @override
  String get wizardLoadingSettingUp => 'Setting up your playlist…';

  @override
  String get wizardAllSetAdded => 'Playlist added!';

  @override
  String wizardAllSetHeadline(String name) {
    return 'You\'re all set, $name!';
  }

  @override
  String get wizardAllSetHeadlineNoName => 'You\'re all set!';

  @override
  String get wizardAllSetBody => 'Your playlist is ready.\nEnjoy the show.';

  @override
  String get wizardWelcomeTitle => 'Welcome to\nOpenIPTV';

  @override
  String get wizardWelcomeSubtitle =>
      'Let\'s get you set up.\nIt only takes a minute.';

  @override
  String get wizardGetStarted => 'Get Started';

  @override
  String get wizardRestoreFromBackup => 'Restore from a backup';

  @override
  String get wizardNameTitle => 'What\'s your name?';

  @override
  String get wizardPrivacyNote =>
      'All information stays on your device.\nOpenIPTV never collects personal data.';

  @override
  String get wizardNameHint => 'Your name';

  @override
  String get wizardPickAvatar => 'Pick an avatar';

  @override
  String get settingsAccentColorTitle => 'Accent Color';

  @override
  String get wizardContinue => 'Continue';

  @override
  String get wizardPinTitle => 'Secure your account';

  @override
  String get wizardPinBody =>
      'Set a PIN of 4 to 8 digits to protect this admin account.\nYou can skip this and add one later in Settings.';

  @override
  String get wizardSetPin => 'Set PIN';

  @override
  String get wizardSkipForNow => 'Skip for now';

  @override
  String get wizardTypeTitleAdd => 'What kind of playlist\nare you adding?';

  @override
  String get wizardTypeTitleHave => 'What kind of playlist\ndo you have?';

  @override
  String get wizardTypeHelp =>
      'Not sure? Ask your IPTV provider — they\'ll know!';

  @override
  String get wizardTypeXtreamTitle => 'Xtream Codes';

  @override
  String get wizardTypeXtreamDesc =>
      'Login with a server address, username, and password.';

  @override
  String get wizardTypeM3uTitle => 'M3U Playlist';

  @override
  String get wizardTypeM3uDesc =>
      'Load from a direct playlist URL (ending in .m3u or .m3u8).';

  @override
  String get wizardTypeFileTitle => 'Playlist File';

  @override
  String get wizardTypeFileDesc => 'Choose an .m3u file saved on this device.';

  @override
  String get wizardCredsTitleXtream => 'Xtream Credentials';

  @override
  String get wizardCredsSubXtream =>
      'Enter the login details from your provider.';

  @override
  String get wizardCredsSubFile =>
      'Choose the playlist file saved on this device.';

  @override
  String get wizardCredsSubM3u =>
      'Paste the playlist link your provider gave you.';

  @override
  String get wizardNicknameOptional => 'Nickname (optional)';

  @override
  String get wizardNickname => 'Nickname';

  @override
  String get wizardNicknameHintFile => 'Uses the file name if left blank';

  @override
  String get wizardNicknameHintExample => 'e.g. Home Server';

  @override
  String get wizardServerAddressLabel => 'Server Address';

  @override
  String get wizardServerAddressHint => 'http://your-provider.com:8080';

  @override
  String get wizardUsernameLabel => 'Username';

  @override
  String get wizardUsernameHint => 'your_username';

  @override
  String get wizardPasswordLabel => 'Password';

  @override
  String get wizardPasswordHint => 'your_password';

  @override
  String get wizardPasswordHide => 'Hide password';

  @override
  String get wizardPasswordShow => 'Show password';

  @override
  String get wizardGuideUrlLabel => 'TV Guide URL (optional)';

  @override
  String get wizardGuideUrlHint => 'https://example.com/epg.xml';

  @override
  String get wizardM3uUrlLabel => 'M3U URL';

  @override
  String get wizardM3uUrlHint => 'https://example.com/playlist.m3u';

  @override
  String get wizardLoadMyPlaylist => 'Load My Playlist';

  @override
  String get wizardFileFieldLabel => 'Playlist file';

  @override
  String get wizardFileChoose => 'Choose a file…';

  @override
  String get wizardFileChange => 'Change';

  @override
  String get wizardFileBrowse => 'Browse';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsGroupWatching => 'Watching';

  @override
  String get settingsGroupAppearance => 'Appearance';

  @override
  String get settingsGroupPlayerControls => 'Player controls';

  @override
  String get settingsPlaybackTitle => 'Playback';

  @override
  String get settingsPlaybackSubtitle =>
      'Start over, picture-in-picture, player controls';

  @override
  String get settingsStartupTitle => 'Start-up';

  @override
  String get settingsStartupSubtitle =>
      'Open the last channel, start on boot or wake';

  @override
  String get settingsChannelListsTitle => 'Channel Lists';

  @override
  String get settingsChannelListsSubtitle =>
      'Sorting, hidden channels, which rows to show';

  @override
  String get settingsGuideLayoutTitle => 'TV Guide Layout';

  @override
  String get settingsGuideLayoutSubtitle => 'Names, two-line titles, highlight';

  @override
  String get settingsAskStartOverTitle => 'Ask to Start Over';

  @override
  String get settingsAskStartOverBody =>
      'On channels that keep recordings (catch-up), asks whether to start the show from the beginning or watch it live when you open a show that is already underway. Turn this off to always go straight to live.';

  @override
  String get settingsPipTitle => 'Picture-in-Picture';

  @override
  String get settingsPipBody =>
      'When enabled, pressing Home while a video is playing shrinks it into a small floating window so you can keep watching while using other apps.';

  @override
  String get settingsMediaNotificationTitle => 'Media Notification';

  @override
  String get settingsMediaNotificationBody =>
      'Shows a \"Now Playing\" notification with play/pause controls while content is playing, so you can control playback from the notification shade or lock screen.';

  @override
  String get settingsSkipButtonsTitle => 'Skip Buttons';

  @override
  String settingsSecondsChoice(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seconds',
      one: '1 second',
    );
    return '$_temp0';
  }

  @override
  String get settingsHideControlsTitle => 'Hide Player Controls After';

  @override
  String get settingsSeekKeysTitle => 'Remote Seek Keys';

  @override
  String get settingsSeekKeysLeftRight => 'Left / Right arrows';

  @override
  String get settingsSeekKeysUpDown => 'Up / Down arrows';

  @override
  String get settingsSeekKeysMedia => 'Rewind / Forward keys';

  @override
  String get settingsLastChannelTitle => 'Open Last Channel on Start';

  @override
  String get settingsLastChannelTooltipTitle => 'Last Channel on Start';

  @override
  String get settingsLastChannelBody =>
      'When the app opens, it goes straight to the live channel you watched last. Turn this off to land on Live TV instead.';

  @override
  String get settingsStartOnBootTitle => 'Start on Boot';

  @override
  String get settingsStartOnBootBody =>
      'Opens OpenIPTV by itself when the TV starts. Android needs \"Display over other apps\" allowed for OpenIPTV; you will be asked.';

  @override
  String get settingsStartOnWakeTitle => 'Start on Wake';

  @override
  String get settingsStartOnWakeBody =>
      'Opens OpenIPTV by itself when the TV wakes from sleep. Android needs \"Display over other apps\" allowed for OpenIPTV; you will be asked.';

  @override
  String get settingsOverlayDialogTitle => 'Allow Display Over Other Apps';

  @override
  String get settingsOverlayDialogBody =>
      'Android only lets OpenIPTV open itself when the TV starts or wakes if \"Display over other apps\" is allowed for it. Open that screen now and switch it on for OpenIPTV.';

  @override
  String get settingsOverlayOpenSettings => 'Open Settings';

  @override
  String get settingsAccentColorBody =>
      'Changes the highlight color used throughout the app — active buttons, selected items, progress bars, and other indicators. Pick whichever color you like best.';

  @override
  String get settingsAccentBlue => 'Blue';

  @override
  String get settingsAccentPurple => 'Purple';

  @override
  String get settingsAccentPink => 'Pink';

  @override
  String get settingsAccentOrange => 'Orange';

  @override
  String get settingsAccentGreen => 'Green';

  @override
  String get settingsAccentTeal => 'Teal';

  @override
  String get settingsAccentCustom => 'Custom';

  @override
  String get settingsTextSizeTitle => 'Text Size';

  @override
  String get settingsTextSizeSmall => 'Small';

  @override
  String get settingsTextSizeDefault => 'Default';

  @override
  String get settingsTextSizeLarge => 'Large';

  @override
  String get settingsTextSizeExtraLarge => 'Extra large';

  @override
  String get settingsPlayerTransparencyTitle => 'Player Transparency';

  @override
  String get settingsPlayerTransparencySolid => 'Solid';

  @override
  String get settingsPlayerTransparencyDefault => 'Default';

  @override
  String get settingsPlayerTransparencyClear => 'See-through';

  @override
  String get settingsPlayerTransparencyVeryClear => 'Very see-through';

  @override
  String get settingsCleanNamesTitle => 'Clean Up Names';

  @override
  String get settingsCleanNamesBody =>
      'Tidies the names your provider sends — removes tags like \"|EN|\", \"US|\" or \"A+ -\" and turns ALL-CAPS names into normal capitalization. Turn off to see names exactly as your provider sends them.';

  @override
  String get errorPlaylistNotM3u =>
      'This file isn\'t a playlist. Choose an .m3u or .m3u8 file from your provider.';

  @override
  String get errorPlaylistEmpty =>
      'This playlist file doesn\'t have any channels in it.';

  @override
  String get errorPlaylistFileMissing =>
      'The playlist file is no longer on this device. Remove this playlist and add the file again.';

  @override
  String get errorXtreamLogin =>
      'Couldn\'t sign in with these details. Check the server address, username and password with your provider.';

  @override
  String get errorM3uMissing => 'Enter the playlist link from your provider.';

  @override
  String get errorLinkOpenFailed =>
      'Couldn\'t open this playlist link. Check it with your provider.';

  @override
  String get errorPlaylistTimeout =>
      'This playlist is taking too long to load. Check your internet connection and try again.';

  @override
  String get errorBadCredentials =>
      'Your username or password doesn\'t seem right. Check with your provider.';

  @override
  String get errorUnreachable =>
      'Couldn\'t reach this server. Check your internet connection and try again.';

  @override
  String get errorProviderServer =>
      'The provider\'s server is having trouble right now. Try again later.';

  @override
  String get errorInvalidLink =>
      'This link doesn\'t look like a valid channel list. Check the URL with your provider.';

  @override
  String get errorGeneric =>
      'That didn\'t work. Check your details and try again.';

  @override
  String get errorGuideTimeout =>
      'The TV guide is taking too long to load. Check your internet connection and try again.';

  @override
  String get errorGuideEmpty =>
      'The provider sent an empty TV guide. Your current guide was kept — try again in a few minutes.';

  @override
  String get errorGuideLogin =>
      'The TV guide link needs a login. Check the guide URL with your provider.';

  @override
  String get errorGuideUnreachable =>
      'Couldn\'t reach the TV guide server for this playlist. It may not have a guide — check the guide URL with your provider.';

  @override
  String get errorGuideServer =>
      'The TV guide server is having trouble right now. Try again later.';

  @override
  String get errorGuideInvalidLink =>
      'This TV guide link doesn\'t look valid. Check the URL with your provider.';

  @override
  String get errorGuideGeneric =>
      'The TV guide couldn\'t be loaded. Check your details and try again.';

  @override
  String get languageTitle => 'Language';

  @override
  String get languageAuto => 'Auto-detect from system';

  @override
  String languageAutoNow(String language) {
    return 'Auto — $language';
  }

  @override
  String get wizardAccentColor => 'Accent Color';

  @override
  String get consentTitle => 'Help improve OpenIPTV?';

  @override
  String get consentBody =>
      'OpenIPTV can send an anonymous report when the app crashes or freezes. A report holds the app version, your device model and where in the code the problem happened. It never holds your playlists, logins, links, channel names or what you watch, and it can\'t be tied to you.\n\nThis is off unless you turn it on. You can change your mind any time in Settings, where you can also see exactly what is sent. The code that does this is small and open on GitHub if you want to check it.';

  @override
  String get consentNoThanks => 'No Thanks';

  @override
  String get consentTurnOn => 'Turn On';

  @override
  String get errorStateTitle => 'Couldn\'t load this';

  @override
  String get errorStateTryAgain => 'Try Again';

  @override
  String get pinUnlock => 'Unlock';

  @override
  String get pinIncorrect => 'Incorrect PIN';

  @override
  String pinEnterAdminToUnlock(String name) {
    return 'Enter admin PIN to unlock \"$name\"';
  }

  @override
  String pinUnlockAction(String name) {
    return 'Unlock \"$name\"';
  }

  @override
  String pinSwitchToProfile(String name) {
    return 'Switch to $name';
  }

  @override
  String pinEnterForProfile(String name) {
    return 'Enter PIN for $name';
  }

  @override
  String get profilePickerLoadFailed => 'Could not load profiles.';

  @override
  String get profilePickerWhoIsWatching => 'Who\'s watching?';

  @override
  String get profilePickerKids => 'Kids';

  @override
  String get settingsGroupAccount => 'Account';

  @override
  String get settingsGroupPlaylistsGuides => 'Playlists & Guides';

  @override
  String get settingsGroupAboutAdvanced => 'About & Advanced';

  @override
  String get settingsUpdatesTitle => 'Updates';

  @override
  String get settingsUpdatesBody =>
      'Looks for a newer version of OpenIPTV on GitHub and, if there is one, shows what changed and installs it. Only the public release page is contacted — nothing about you or your device is sent. Choose whether this also happens every time the app starts.';

  @override
  String get settingsUpdatesAutoOn => 'Checks automatically';

  @override
  String get settingsUpdatesManual => 'Manual only';

  @override
  String get settingsUpdatesCheckAuto => 'Check Automatically';

  @override
  String get settingsUpdatesClose => 'Close';

  @override
  String get settingsUpdatesCheckNow => 'Check Now';

  @override
  String get settingsProfileTitle => 'Profile';

  @override
  String get settingsProfileBody =>
      'OpenIPTV supports multiple profiles on one device. Each profile has its own watch history, favorites, hidden categories, and PIN lock. Select to manage profiles.';

  @override
  String get settingsProfileNone => 'No profile selected';

  @override
  String settingsProfileSubtitle(String kind) {
    String _temp0 = intl.Intl.selectLogic(
      kind,
      {
        'admin': 'Admin',
        'kids': 'Kids profile',
        'other': 'Standard profile',
      },
    );
    return '$_temp0 · Manage profiles';
  }

  @override
  String get settingsSwitchProfileTitle => 'Switch Profile';

  @override
  String get settingsSwitchProfileBody =>
      'Quickly change the active profile without going into profile management. Useful when sharing a device with family or roommates.';

  @override
  String settingsProfilesAvailable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count profiles available',
      one: '1 profile available',
    );
    return '$_temp0';
  }

  @override
  String get settingsParentalTitle => 'Parental Controls';

  @override
  String get settingsParentalBody =>
      'Hide adult categories and lock any category you choose behind an admin PIN. Locked categories stay unlocked until the app is restarted.';

  @override
  String get settingsParentalSubtitle =>
      'PIN-protect adult and locked categories';

  @override
  String get settingsPlaylistsTitle => 'Playlists';

  @override
  String get settingsPlaylistsBody =>
      'A playlist is your provider connection — either an M3U playlist URL or Xtream Codes credentials. Playlists supply your channels, movies, and series. You can add multiple playlists and refresh them here.';

  @override
  String get settingsPlaylistsNone => 'No playlists added';

  @override
  String settingsPlaylistsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count playlists',
      one: '1 playlist',
    );
    return '$_temp0';
  }

  @override
  String get settingsBackupTitle => 'Backup & Restore';

  @override
  String get settingsBackupBody =>
      'Export your profiles and playlists to a single .zip file you can store anywhere. Restore it later to move to a new device or recover from a reset. Stream credentials are included — keep the file safe.';

  @override
  String get settingsBackupSubtitle =>
      'Export or import your profile and playlists';

  @override
  String get settingsAutoRefreshTitle => 'Auto-Refresh';

  @override
  String get settingsAutoRefreshBody =>
      'Automatically refreshes your playlists and TV guide in the background so channels and schedules stay current without manual refreshing.';

  @override
  String settingsAutoRefreshEvery(int hours) {
    return 'Every $hours hours';
  }

  @override
  String get settingsAutoRefreshOff => 'Off';

  @override
  String settingsAutoRefreshNotifies(String interval) {
    return '$interval · notifies when done';
  }

  @override
  String get settingsAutoRefreshNotifyTitle => 'Notify when done';

  @override
  String get settingsStayInformedTitle => 'Stay Informed';

  @override
  String get settingsStayInformedBody =>
      'Allow notifications so OpenIPTV can let you know when a background refresh finishes or runs into a problem?';

  @override
  String get settingsAllow => 'Allow';

  @override
  String get settingsReliableRefreshTitle => 'Reliable Background Refresh';

  @override
  String get settingsReliableRefreshBody =>
      'Some phones aggressively limit background apps to save battery, which can delay auto-refresh. Exempting OpenIPTV from battery optimization makes refreshes more reliable.';

  @override
  String get settingsContinue => 'Continue';

  @override
  String get settingsGuideDataTitle => 'Guide Data';

  @override
  String get settingsGuideDataBody =>
      'Choose how many days of TV guide are kept, whether programme descriptions are stored, see when each playlist\'s guide last updated, and clear it.';

  @override
  String get settingsGuideDataSubtitle => 'How much TV guide is stored';

  @override
  String get settingsExtraGuidesTitle => 'Extra Guides';

  @override
  String get settingsExtraGuidesBody =>
      'Add TV guide files for channels your playlist has no guide for. OpenIPTV matches them by name, and you can pick a guide for any channel yourself.';

  @override
  String get settingsExtraGuidesSubtitle =>
      'Fill in channels that have no guide';

  @override
  String get settingsSortOrderTitle => 'Content Sort Order';

  @override
  String get settingsSortOrderBody =>
      'Controls how channels, movies, and series are listed. Provider order shows them in the sequence your IPTV provider sends them. A–Z sorts them alphabetically.';

  @override
  String get settingsSortProvider => 'Provider order';

  @override
  String get settingsSortAz => 'A–Z';

  @override
  String get settingsHiddenCategoriesTitle => 'Hidden Categories';

  @override
  String get settingsHiddenCategoriesBody =>
      'Categories you\'ve hidden won\'t appear in your channel list. Your channels are still there — they\'re just out of the way. You can unhide them here at any time.';

  @override
  String get settingsHiddenCategoriesNone => 'No categories are hidden.';

  @override
  String get settingsResetCategoriesTitle => 'Reset Category Names and Order';

  @override
  String get settingsResetCategoriesDialogTitle =>
      'Reset Category Names and Order?';

  @override
  String get settingsResetCategoriesDialogBody =>
      'Live TV categories go back to the names and order your playlist gives them. Hidden categories stay hidden.';

  @override
  String get settingsReset => 'Reset';

  @override
  String get settingsHiddenChannelsTitle => 'Hidden Channels';

  @override
  String get settingsHiddenChannelsBody =>
      'Channels you hid (hold OK or long-press a channel → Hide Channel) are kept out of Live TV, the guide and search for this profile. Bring them back here.';

  @override
  String get settingsHiddenChannelsNone => 'None';

  @override
  String settingsHiddenChannelsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hidden',
      one: '1 hidden',
    );
    return '$_temp0';
  }

  @override
  String get settingsHiddenChannelsEmpty => 'No channels are hidden.';

  @override
  String get settingsChannelFromRemovedPlaylist =>
      'Channel from a removed playlist';

  @override
  String get settingsShow => 'Show';

  @override
  String get settingsShowAll => 'Show All';

  @override
  String get settingsAllChannels => 'All Channels';

  @override
  String get settingsShowFavorites => 'Show Favorites';

  @override
  String get settingsShowRecent => 'Show Recently Watched';

  @override
  String get settingsShowAllChannels => 'Show All Channels';

  @override
  String get settingsGuideShowNames => 'Guide: Show Channel Names';

  @override
  String get settingsGuideTwoLineNames => 'Guide: Two-Line Channel Names';

  @override
  String get settingsGuideTwoLineTitles => 'Guide: Two-Line Programme Titles';

  @override
  String get settingsGuideHighlightPlaying =>
      'Guide: Highlight the Playing Channel';

  @override
  String get settingsAboutTitle => 'About OpenIPTV';

  @override
  String get settingsAboutBody =>
      'Shows the current app version and license information. OpenIPTV is open-source under the GPL-3.0 license — no ads, no telemetry, no accounts. Ever.';

  @override
  String settingsAboutVersion(String version) {
    return 'Version $version';
  }

  @override
  String get settingsAboutLegalese =>
      '© 2026 OpenIPTV contributors. Licensed under GPL-3.0.';

  @override
  String get settingsAboutDescription =>
      'An open-source, ad-free, cross-platform IPTV client. No accounts required. No telemetry. No ads. Ever.';

  @override
  String get settingsPowerToolsTitle => 'Power User Tools';

  @override
  String get settingsPowerToolsBody =>
      'Tools for checking and tuning your connection: your device and public IP addresses, connection type, VPN and DNS — handy when a provider has trouble reaching you.';

  @override
  String get settingsPowerToolsSubtitle => 'Network info for troubleshooting';

  @override
  String get settingsAnonReportsTitle => 'Anonymous Reports';

  @override
  String get settingsAnonReportsBody =>
      'Optionally send an anonymous report when the app crashes or freezes, so problems get fixed faster. Off unless you turn it on, and you can see exactly what is sent.';

  @override
  String get settingsOn => 'On';

  @override
  String get settingsOff => 'Off';

  @override
  String settingsPlaylistRefreshed(String name) {
    return '\"$name\" playlist refreshed.';
  }

  @override
  String settingsPlaylistRefreshFailed(String error) {
    return 'Playlist refresh failed: $error';
  }

  @override
  String settingsGuideRefreshed(String name) {
    return '\"$name\" TV guide refreshed.';
  }

  @override
  String get settingsSwitchPlaylistTitle => 'Switch Playlist?';

  @override
  String get settingsSwitchToAllBody =>
      'Show all playlists together?\n\nThe channel list, movies, and series will include every playlist.';

  @override
  String settingsSwitchToOneBody(String name) {
    return 'Switch to \"$name\"?\n\nThe channel list, movies, and series will update to show only this playlist.';
  }

  @override
  String get settingsSwitch => 'Switch';

  @override
  String get settingsRemovePlaylistTitle => 'Remove Playlist?';

  @override
  String settingsRemovePlaylistBody(String name) {
    return 'This will remove \"$name\" and all its channels, movies, and series. This cannot be undone.';
  }

  @override
  String get settingsRemove => 'Remove';

  @override
  String settingsRemovingPlaylist(String name) {
    return 'Removing \"$name\"...';
  }

  @override
  String get settingsAddPlaylist => 'Add Playlist';

  @override
  String get settingsChoosePlaylistHint =>
      'Choose which playlist to browse, or show them all together.';

  @override
  String get settingsPlaylistsLoadError => 'Couldn\'t load playlists.';

  @override
  String get settingsPlaylistsEmpty => 'No playlists yet.';

  @override
  String get settingsAllPlaylists => 'All playlists';

  @override
  String settingsPlaylistsCombined(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count playlists combined',
      one: '1 playlist combined',
    );
    return '$_temp0';
  }

  @override
  String get settingsSourceFile => 'Playlist file';

  @override
  String get settingsSourceM3u => 'M3U playlist';

  @override
  String get settingsBrowsing => 'Browsing';

  @override
  String get settingsRefreshPlaylistTooltip => 'Refresh Playlist';

  @override
  String get settingsMoreTooltip => 'More';

  @override
  String get settingsEditPlaylist => 'Edit Playlist';

  @override
  String get settingsPlaylistInfo => 'Playlist Info';

  @override
  String get settingsRefreshTvGuide => 'Refresh TV Guide';

  @override
  String get settingsInfoFetchError => 'Could not fetch server info.';

  @override
  String get settingsInfoSource => 'Source';

  @override
  String get settingsInfoFileSaved => 'File saved on this device';

  @override
  String get settingsInfoGuideUrl => 'EPG URL';

  @override
  String get settingsInfoLastRefreshed => 'Last refreshed';

  @override
  String get settingsInfoNever => 'Never';

  @override
  String get settingsInfoStatus => 'Status';

  @override
  String get settingsInfoExpires => 'Expires';

  @override
  String get settingsInfoActiveConnections => 'Active connections';

  @override
  String get settingsInfoMaxConnections => 'Max connections';

  @override
  String get settingsInfoTrial => 'Trial';

  @override
  String get settingsInfoYes => 'Yes';

  @override
  String get settingsInfoNo => 'No';

  @override
  String get settingsInfoServer => 'Server';

  @override
  String get settingsInfoTimezone => 'Timezone';

  @override
  String get browseActionsSortedAz => 'Sorted A–Z';

  @override
  String get browseActionsProviderOrder => 'Provider order';

  @override
  String get browseActionsSwitchToList => 'Switch to list view';

  @override
  String get browseActionsSwitchToGrid => 'Switch to grid view';

  @override
  String get browseActionsSwitchToCompact => 'Switch to compact view';

  @override
  String get browseActionsSwitchToPosters => 'Switch to poster view';

  @override
  String get bufferPresetFastLabel => 'Fast start';

  @override
  String get bufferPresetFastDescription =>
      'Starts quickly and resumes right after a short hiccup. Best on a good connection.';

  @override
  String get bufferPresetBalancedLabel => 'Balanced';

  @override
  String get bufferPresetBalancedDescription =>
      'Waits a little longer before starting, for fewer interruptions on an average connection.';

  @override
  String get bufferPresetSmoothLabel => 'Smooth';

  @override
  String get bufferPresetSmoothDescription =>
      'Keeps a bigger reserve so playback rides out an unsteady connection. Slower to start and to change channels.';

  @override
  String get graphicsModeAutomaticLabel => 'Automatic';

  @override
  String get graphicsModeAutomaticDescription =>
      'Uses the compatible mode only on TVs known to need it. Recommended.';

  @override
  String get graphicsModeStandardLabel => 'Standard';

  @override
  String get graphicsModeStandardDescription =>
      'The newest drawing method. Best on most phones and TVs.';

  @override
  String get graphicsModeCompatibleLabel => 'Compatible';

  @override
  String get graphicsModeCompatibleDescription =>
      'An older, steadier drawing method. Try this if the picture looks torn (a line across it) or jittery, mostly on fast motion.';

  @override
  String get videoLayerAutomaticLabel => 'Automatic';

  @override
  String get videoLayerAutomaticDescription =>
      'Shows the picture the way TV players do, for smoother video and faster, cleaner switching. Recommended.';

  @override
  String get videoLayerOnLabel => 'On';

  @override
  String get videoLayerOnDescription => 'Always use it on this TV.';

  @override
  String get videoLayerOffLabel => 'Off';

  @override
  String get videoLayerOffDescription =>
      'Draw the picture inside the app, as before. Try this if the picture is ever missing or wrong.';

  @override
  String get speedTestVerdictPlenty => 'Plenty, even for 4K.';

  @override
  String get speedTestVerdictGood => 'Good for HD and most 4K.';

  @override
  String get speedTestVerdictFineHd => 'Fine for HD; 4K may buffer.';

  @override
  String get speedTestVerdictEnoughSd => 'Enough for SD; HD may buffer.';

  @override
  String get speedTestVerdictTooSlow => 'Too slow for smooth playback.';

  @override
  String get vpnNotWireGuardProfile => 'This isn\'t a WireGuard profile.';

  @override
  String vpnProfileProblem(String detail) {
    return 'This profile has a problem ($detail).';
  }

  @override
  String get vpnNotAvailable => 'VPN is not available on this device.';

  @override
  String get vpnNotOpenVpnProfile => 'This isn\'t an OpenVPN profile.';

  @override
  String get vpnNeedsDeviceCertificate =>
      'This profile needs a certificate stored on the device, which OpenIPTV doesn\'t support.';

  @override
  String get vpnCouldntReadProfile => 'Couldn\'t read this profile.';

  @override
  String get vpnConnected => 'VPN connected';

  @override
  String get vpnConnecting => 'Connecting the VPN…';

  @override
  String get vpnNeedsPermission =>
      'OpenIPTV needs your permission to set up a VPN. Select Connect and allow it.';

  @override
  String get vpnBadConfig => 'This profile has a problem. Import it again.';

  @override
  String get vpnConnectFailed =>
      'Couldn\'t connect the VPN. Check the profile and try again.';

  @override
  String get refreshAllSummaryEverything => 'Everything is up to date.';

  @override
  String get refreshAllSummaryPlaylists => 'All playlists are up to date.';

  @override
  String get refreshAllSummaryGuides => 'All TV guides are up to date.';

  @override
  String refreshAllProblem(String name, String message) {
    return '$name: $message';
  }

  @override
  String refreshAllSummaryFailedOne(String problems) {
    return '$problems.';
  }

  @override
  String refreshAllSummaryFailedMany(int ok, int total, String problems) {
    return '$ok of $total updated. $problems.';
  }

  @override
  String refreshAllUpdating(String name, int done, int total) {
    return 'Updating $name… ($done of $total)';
  }

  @override
  String refreshAllUpdatingGuide(String name, int done, int total) {
    return 'Updating $name\'s TV guide… ($done of $total)';
  }

  @override
  String refreshAllUpdatingExtraGuides(int done, int total) {
    return 'Updating extra guides… ($done of $total)';
  }

  @override
  String get refreshAllEverythingTitle => 'Refresh Everything';

  @override
  String get refreshAllEverythingHint =>
      'Channels, movies, series and TV guides for every playlist';

  @override
  String get refreshAllPlaylistsTitle => 'Refresh Playlists';

  @override
  String get refreshAllPlaylistsHint => 'Channels, movies and series only';

  @override
  String get refreshAllGuidesTitle => 'Refresh TV Guides';

  @override
  String get refreshAllGuidesHint =>
      'What\'s on now and next, for every playlist';

  @override
  String get refreshAllChoiceEverything => 'Everything';

  @override
  String get refreshAllChoicePlaylists => 'Playlists only';

  @override
  String get refreshAllChoicePlaylistsHint => 'Channels, movies and series';

  @override
  String get refreshAllChoiceGuides => 'TV guides only';

  @override
  String get refreshAllDialogTitle => 'Refresh';

  @override
  String get refreshAllNowTitle => 'Refresh Now';

  @override
  String get refreshAllNowIdle => 'Update your playlists and TV guides now';

  @override
  String refreshAllLastRun(String time, String summary) {
    return '$time · $summary';
  }

  @override
  String get editPlaylistTitle => 'Edit Playlist';

  @override
  String get editPlaylistName => 'Name';

  @override
  String get editPlaylistServerAddress => 'Server address';

  @override
  String get editPlaylistUsername => 'Username';

  @override
  String get editPlaylistPassword => 'Password';

  @override
  String get editPlaylistPasswordHint =>
      'Leave empty to keep the current password';

  @override
  String get editPlaylistShowPassword => 'Show password';

  @override
  String get editPlaylistHidePassword => 'Hide password';

  @override
  String get editPlaylistLink => 'Playlist link';

  @override
  String get editPlaylistGuideAddress => 'TV guide address (optional)';

  @override
  String get editPlaylistGuideAutoProvider => 'Automatic — from your provider';

  @override
  String get editPlaylistGuideAutoPlaylist => 'Automatic — from the playlist';

  @override
  String get editPlaylistFileNote =>
      'This playlist is a file on your device. To use a different file, add it as a new playlist.';

  @override
  String get editPlaylistLoginStored =>
      'Your login is stored encrypted on this device.';

  @override
  String get editPlaylistSave => 'Save';

  @override
  String get editPlaylistChecking => 'Checking your details…';

  @override
  String get editPlaylistUpdating => 'Saved. Updating channels and movies…';

  @override
  String editPlaylistSaved(String name) {
    return '\"$name\" saved.';
  }

  @override
  String editPlaylistSavedUpdated(String name) {
    return '\"$name\" saved and updated.';
  }

  @override
  String editPlaylistSavedWithSummary(String name, String summary) {
    return '\"$name\" saved. $summary';
  }

  @override
  String get editPlaylistLiveFormat => 'Live stream format';

  @override
  String get editPlaylistLiveFormatNote =>
      'Changing this updates the playlist\'s channels.';

  @override
  String get editPlaylistFormatAutoLabel => 'Automatic';

  @override
  String get editPlaylistFormatAutoDescription =>
      'Follows what your provider allows, usually TS';

  @override
  String get editPlaylistFormatTsDescription =>
      'Transport stream: fast to start, works with most providers';

  @override
  String get editPlaylistFormatHlsDescription =>
      'Adaptive playlist: for providers whose TS streams drop';

  @override
  String get parentalTitle => 'Parental Controls';

  @override
  String get parentalAdminsOnly => 'Admins only.';

  @override
  String get parentalProtectionGroup => 'Protection';

  @override
  String get parentalProtectionTitle => 'Parental Protection';

  @override
  String get parentalProtectionOn =>
      'Adult and locked categories require an admin PIN';

  @override
  String get parentalProtectionOff => 'Off — all content is visible';

  @override
  String get parentalLockedGroup => 'Locked Categories';

  @override
  String get parentalLockedDescription =>
      'Adult content is locked automatically. Categories below were added by the playlist scan.';

  @override
  String get parentalNoLocked => 'No other locked categories';

  @override
  String get parentalRemoveTooltip => 'Remove from locked list';

  @override
  String get carVideoTitle => 'Video in the Car';

  @override
  String get carVideoSubtitleMissing => 'Watch on the car screen while parked';

  @override
  String get carVideoSubtitleOutdated => 'Update available for the add-on';

  @override
  String get carVideoSubtitleInstalled => 'Add-on installed';

  @override
  String get carVideoInfoMissing =>
      'This needs a small add-on app, OpenIPTV Video (about 1 MB).';

  @override
  String get carVideoInfoInstalled => 'The add-on is installed.';

  @override
  String get carVideoInfoOutdated =>
      'A newer version of the add-on is available.';

  @override
  String carVideoInfo(String addonLine) {
    return 'Watch on your car\'s screen with Android Auto while parked. Android Auto closes the picture when you start driving; the sound keeps playing.\n\nHow to watch: pick a channel, movie or episode in OpenIPTV on the car screen, then open Video — the second OpenIPTV icon.\n\n$addonLine\n\nIf it doesn\'t show up in the car: in the Android Auto app on your phone, turn on developer settings and \"Unknown sources\".';
  }

  @override
  String get carVideoNeedsPermission =>
      'To install the add-on, OpenIPTV needs permission to install apps.\n\nSelect Open Settings, turn on \"Allow from this source\", then come back here — the install will continue automatically.';

  @override
  String get carVideoDownloading => 'Downloading…';

  @override
  String carVideoDownloadingPercent(int percent) {
    return 'Downloading… $percent%';
  }

  @override
  String get carVideoHandedOff =>
      'Follow the prompts on screen to finish installing.\n\nIf nothing appeared, or you cancelled, select Install again.';

  @override
  String get carVideoUnavailable =>
      'The add-on isn\'t available to download yet. It comes with the next OpenIPTV release.';

  @override
  String get carVideoFailed =>
      'The add-on couldn\'t be downloaded. Check your internet connection and try again.';

  @override
  String get carVideoDone => 'Done';

  @override
  String get carVideoUpdate => 'Update';

  @override
  String get carVideoInstall => 'Install';

  @override
  String get carVideoOpenSettings => 'Open Settings';

  @override
  String get carVideoClose => 'Close';

  @override
  String get carVideoInstallAgain => 'Install again';

  @override
  String get carVideoTryAgain => 'Try again';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileLoadFailed => 'Couldn\'t load profile.';

  @override
  String get profileNoActive => 'No active profile.';

  @override
  String get profileKidsAdminBlocked =>
      'Admin accounts can\'t be marked as kid accounts';

  @override
  String get profileAdultHidden => 'Adult content will be hidden';

  @override
  String get profileAllVisible => 'All content is visible';

  @override
  String get profileAccountGroup => 'Account';

  @override
  String get profileKidsProfile => 'Kids Profile';

  @override
  String get profileKidsTooltipBody =>
      'When turned on, this profile is marked as a Kids profile and adult content is automatically hidden from Live, Movies, and Series. Requires Parental Protection to be enabled.';

  @override
  String get profileSecurityGroup => 'Security';

  @override
  String get profilePinLock => 'PIN Lock';

  @override
  String get profilePinIsSet => 'PIN is set — select to change or remove';

  @override
  String get profilePinNotSet => 'No PIN — select to set one';

  @override
  String get profileAllProfilesGroup => 'All Profiles';

  @override
  String get profileAddProfile => 'Add Profile';

  @override
  String get profileEnterPinToDisableKids =>
      'Enter admin PIN to disable Kids Profile';

  @override
  String get profileDeleteTitle => 'Delete Profile?';

  @override
  String profileDeleteBody(String name) {
    return 'Deleting \"$name\" will remove all its favourites and settings. Your sources and channels are not affected.';
  }

  @override
  String get profileDelete => 'Delete';

  @override
  String get profileProtectionRequiredTitle => 'Parental Protection Required';

  @override
  String get profileProtectionRequiredBody =>
      'Kid profiles require Parental Protection to be turned on, so adult content can be hidden automatically. Enable it now?';

  @override
  String get profileEnableProtection => 'Enable Protection';

  @override
  String get profileActive => 'Active';

  @override
  String get profileKidsBadge => 'Kids';

  @override
  String get profilePinBadge => 'PIN';

  @override
  String get profileMenuEdit => 'Edit';

  @override
  String get profileEditTitle => 'Edit Profile';

  @override
  String get profileNameLabel => 'Name';

  @override
  String get profileAvatarLabel => 'Avatar';

  @override
  String get profileEnterName => 'Enter a name.';

  @override
  String get profileSaveFailed => 'Couldn\'t save changes.';

  @override
  String get profileSave => 'Save';

  @override
  String get profileNewTitle => 'New Profile';

  @override
  String get profileNameHint => 'e.g. Kids, Living Room';

  @override
  String get profileIsKidAccount => 'Is Kid Account';

  @override
  String get profileCreate => 'Create';

  @override
  String get profileCreateFailed => 'Couldn\'t create profile.';

  @override
  String get profilePinsDontMatch => 'PINs don\'t match.';

  @override
  String get profilePinTooShort => 'PIN must be at least 4 digits.';

  @override
  String get profileCurrentPinIncorrect => 'Current PIN is incorrect.';

  @override
  String get profileChangePinTitle => 'Change PIN';

  @override
  String get profileSetPinTitle => 'Set PIN';

  @override
  String get profileCurrentPin => 'Current PIN';

  @override
  String get profileNewPin => 'New PIN';

  @override
  String get profilePinDigitsHint => '4–8 digits';

  @override
  String get profileConfirmPin => 'Confirm PIN';

  @override
  String get profileRepeatNewPin => 'Repeat new PIN';

  @override
  String get profileRemovePin => 'Remove PIN';

  @override
  String get profileEnterAdminPin => 'Enter admin PIN';

  @override
  String get profileBiometricPinMessage =>
      'To turn on fingerprint and face unlock';

  @override
  String get profileContinue => 'Continue';

  @override
  String get profileIncorrectPin => 'Incorrect PIN';

  @override
  String get profileBiometricOn => 'Fingerprint and face unlock is on';

  @override
  String get profileBiometricFailed =>
      'Couldn\'t turn on fingerprint and face unlock on this device.';

  @override
  String get profileBiometricTitle => 'Unlock with Fingerprint or Face';

  @override
  String get profileBiometricBody =>
      'Use your fingerprint or face wherever the admin PIN is asked for on this device. Anyone whose fingerprint or face is set up on this device can use it, so only turn it on if that is just you. Adding a new fingerprint or face turns it off until you turn it on again. Other profiles still use their own PINs.';

  @override
  String get profileBiometricSubtitleOn =>
      'Use it instead of typing the admin PIN';

  @override
  String get profileBiometricSubtitleNeedsPin => 'Set a PIN first';

  @override
  String get powerUserTitle => 'Power User Tools';

  @override
  String get powerUserRefreshTooltip => 'Refresh';

  @override
  String get powerUserOn => 'On';

  @override
  String get powerUserOff => 'Off';

  @override
  String get powerUserYes => 'Yes';

  @override
  String get powerUserNo => 'No';

  @override
  String get powerUserAutomatic => 'Automatic';

  @override
  String powerUserInUseNow(String mode) {
    return 'In use now: $mode.';
  }

  @override
  String get powerUserNetworkTitle => 'Network';

  @override
  String get powerUserNetworkDescription =>
      'How this device is connected right now. Useful when a provider has trouble reaching you — for example to check which address it sees, or that your VPN is on.';

  @override
  String get powerUserNetworkDescriptionCopy =>
      'How this device is connected right now. Useful when a provider has trouble reaching you — for example to check which address it sees, or that your VPN is on. Tap an address to copy it.';

  @override
  String get powerUserCheckingConnection => 'Checking your connection…';

  @override
  String get powerUserConnection => 'Connection';

  @override
  String get powerUserDeviceIp => 'Device IP address';

  @override
  String get powerUserNotAvailable => 'Not available';

  @override
  String get powerUserVpnAddress => 'VPN address';

  @override
  String get powerUserDnsServers => 'DNS servers';

  @override
  String powerUserCopied(String label) {
    return '$label copied';
  }

  @override
  String get powerUserPublicIp => 'Public IP address';

  @override
  String get powerUserChecking => 'Checking…';

  @override
  String get powerUserCheckFailed => 'Couldn\'t check right now. Try again.';

  @override
  String powerUserPublicIpIdle(String service) {
    return 'The address your provider sees. Checking asks $service.';
  }

  @override
  String get powerUserCheck => 'Check';

  @override
  String get powerUserCheckAgain => 'Check again';

  @override
  String get powerUserVpnDescription =>
      'A built-in VPN — WireGuard or OpenVPN. Handy when your internet provider blocks or slows down your IPTV provider. One connects at a time.';

  @override
  String get powerUserWgImportHint =>
      'Import a WireGuard profile (.conf file) from your VPN provider.';

  @override
  String get powerUserOvpnImportHint =>
      'Import an OpenVPN profile (.ovpn file) from your VPN provider.';

  @override
  String powerUserVpnStateOff(String name, String where) {
    return 'Off — $name$where';
  }

  @override
  String powerUserWgConnected(
      String name, String where, String rx, String tx, String ago) {
    return 'Connected — $name$where\n↓ $rx  ↑ $tx · $ago';
  }

  @override
  String get powerUserHandshakeWaiting => 'waiting for the server to answer';

  @override
  String powerUserHandshakeAnswered(String when) {
    return 'server answered $when';
  }

  @override
  String get powerUserJustNow => 'just now';

  @override
  String powerUserSecondsAgo(int seconds) {
    return '${seconds}s ago';
  }

  @override
  String powerUserMinutesAgo(int minutes) {
    return '$minutes min ago';
  }

  @override
  String powerUserOvpnConnected(
      String name, String where, String rx, String tx) {
    return 'Connected — $name$where\n↓ $rx  ↑ $tx';
  }

  @override
  String powerUserOvpnConnecting(String name, String where) {
    return 'Connecting — $name$where';
  }

  @override
  String powerUserOvpnError(String name, String where) {
    return 'Couldn\'t connect — $name$where';
  }

  @override
  String get powerUserImport => 'Import';

  @override
  String get powerUserDisconnect => 'Disconnect';

  @override
  String get powerUserConnect => 'Connect';

  @override
  String get powerUserRouteApp => 'Only OpenIPTV';

  @override
  String get powerUserRouteAppHint => 'Other apps keep your normal connection';

  @override
  String get powerUserRouteDevice => 'Whole device';

  @override
  String get powerUserRouteDeviceHint =>
      'Every app uses the VPN, except Android Auto\'s car link';

  @override
  String get powerUserReconnectToApply => 'Reconnect the VPN to apply this.';

  @override
  String get powerUserAutoConnect => 'Connect when OpenIPTV opens';

  @override
  String get powerUserAutoConnectHint => 'Uses the VPN you connected last';

  @override
  String get powerUserRemoveWireGuard => 'Remove WireGuard profile';

  @override
  String get powerUserChangeOvpnLogin => 'Change OpenVPN login';

  @override
  String powerUserSignedInAs(String user) {
    return 'Signed in as $user';
  }

  @override
  String get powerUserRemoveOpenVpn => 'Remove OpenVPN profile';

  @override
  String get powerUserPickOvpn => 'Choose an OpenVPN profile';

  @override
  String get powerUserPickWireGuard => 'Choose a WireGuard profile';

  @override
  String powerUserProfileAdded(String name) {
    return 'Profile \"$name\" added';
  }

  @override
  String get powerUserVpnLoginTitle => 'VPN login';

  @override
  String get powerUserVpnLoginBody =>
      'This profile needs the username and password from your VPN provider. They are stored encrypted on this device.';

  @override
  String get powerUserUsername => 'Username';

  @override
  String get powerUserPassword => 'Password';

  @override
  String get powerUserSave => 'Save';

  @override
  String get powerUserVpnLoginSaved => 'VPN login saved';

  @override
  String get powerUserRemoveTitle => 'Remove VPN profile?';

  @override
  String get powerUserRemoveBody =>
      'The VPN disconnects and the profile is deleted from this device. You can import it again later.';

  @override
  String get powerUserRemove => 'Remove';

  @override
  String get powerUserOvpnAuthFailed =>
      'The VPN server rejected the username or password. Use \"Change OpenVPN login\" to fix it.';

  @override
  String get powerUserOvpnUnreachable =>
      'Couldn\'t reach the VPN server. Check the profile and your connection.';

  @override
  String get powerUserOvpnConnectFailed =>
      'The VPN couldn\'t connect. Check the profile and try again.';

  @override
  String get powerUserSpeedTitle => 'Speed test';

  @override
  String get powerUserSpeedDescription =>
      'Measures how fast video arrives. The provider test uses one connection to your provider — if your plan allows only one at a time, stop watching on other devices first.';

  @override
  String get powerUserSpeedProviderLabel => 'Speed to your provider';

  @override
  String get powerUserSpeedProviderIdle =>
      'Downloads from the playlist you are browsing for a few seconds.';

  @override
  String get powerUserSpeedInternetLabel => 'General internet speed';

  @override
  String powerUserSpeedInternetIdle(String host) {
    return 'Downloads a test file from $host.';
  }

  @override
  String get powerUserSpeedConnecting => 'Connecting…';

  @override
  String powerUserSpeedTesting(String mbps) {
    return 'Testing… $mbps Mbit/s';
  }

  @override
  String powerUserSpeedResult(String mbps, String verdict, int ms) {
    return '$mbps Mbit/s — $verdict\nResponse time $ms ms';
  }

  @override
  String get powerUserSpeedPacedNote =>
      'Measured on a live channel, which arrives at playback speed — this shows it keeps up, not your top speed.';

  @override
  String get powerUserSpeedNothingToTest =>
      'This playlist has nothing to test with yet.';

  @override
  String get powerUserSpeedProviderFailed =>
      'Couldn\'t download from your provider. It may be busy, or your plan may allow only one connection at a time.';

  @override
  String get powerUserSpeedInternetFailed =>
      'Couldn\'t run the test. Check your connection and try again.';

  @override
  String get powerUserRun => 'Run';

  @override
  String get powerUserRunAgain => 'Run again';

  @override
  String get powerUserDbTitle => 'Database';

  @override
  String get powerUserDbDescription =>
      'The database holds your playlists, logins and watch history, and is encrypted on the device. Turning encryption off can make very slow TVs faster.';

  @override
  String get powerUserDbSkipTitle => 'Skip Database Encryption';

  @override
  String get powerUserDbSkipQuestion => 'Skip Database Encryption?';

  @override
  String get powerUserDbTurnOnQuestion => 'Turn Database Encryption back on?';

  @override
  String get powerUserDbSkipBody =>
      'This will store your database (including playlist credentials and stream links) unencrypted on disk. Anyone with access to the device can read it. The app must be restarted for the change to take effect.';

  @override
  String get powerUserDbTurnOnBody =>
      'Your database will be encrypted again, which is safer but can be slower on older TVs. The app will restart to apply it.';

  @override
  String get powerUserDbEnable => 'Enable';

  @override
  String get powerUserDbTurnOn => 'Turn On';

  @override
  String get powerUserDbReopenTitle => 'Reopen OpenIPTV to finish';

  @override
  String get powerUserDbReopenBody =>
      'The database encryption mode has changed. OpenIPTV will close now. Open it again to apply the change.';

  @override
  String get powerUserDbClose => 'Close OpenIPTV';

  @override
  String get powerUserBufferTitle => 'Playback buffer';

  @override
  String get powerUserBufferDescription =>
      'How much video the player keeps in reserve. A bigger reserve rides out a shaky connection but takes longer to start. Applies from the next channel or video you open.';

  @override
  String get powerUserPicturesTitle => 'Pictures';

  @override
  String get powerUserPicturesDescription =>
      'Posters, channel logos and backdrops are shown in full resolution, for the sharpest pictures. Turn this off to show them at about the size they are drawn instead, which uses less memory. Try that if the app ever feels slow or restarts on a TV or phone with little memory. Takes effect straight away; no re-download needed.';

  @override
  String get powerUserFullResTitle => 'Full-Resolution Pictures';

  @override
  String get powerUserFrameRateTitle => 'Match frame rate';

  @override
  String get powerUserFrameRateDescription =>
      'Switches your screen to a refresh rate that suits the video (for example 24 Hz for films), so motion looks smoother. Only works if your screen supports it, and some TVs go black for a moment when it switches. The screen goes back to normal when you stop watching.';

  @override
  String get powerUserFrameRateSwitch => 'Match Frame Rate';

  @override
  String get powerUserPassthroughTitle => 'Surround sound passthrough';

  @override
  String get powerUserPassthroughDescription =>
      'Sends Dolby and DTS sound untouched to a soundbar, receiver or TV that decodes it. It pauses by itself while Multi-view is on.';

  @override
  String get powerUserPassthroughAuto =>
      'Uses it when your sound system says it can. Recommended.';

  @override
  String get powerUserPassthroughOn =>
      'Always send surround sound as it is. Only if a soundbar or receiver can decode it, otherwise you may get no sound.';

  @override
  String get powerUserPassthroughOff =>
      'The device always decodes the sound itself. Pick this for built-in TV speakers or if the sound cuts out or crackles.';

  @override
  String get powerUserTunnelingTitle => 'Tunneled playback';

  @override
  String get powerUserTunnelingDescription =>
      'Lets the video and sound chips work together directly, which can ease stutter on demanding streams. It pauses by itself while Multi-view is on.';

  @override
  String get powerUserTunnelingAuto =>
      'Used only on devices where it has been checked to work. Recommended.';

  @override
  String get powerUserTunnelingOn =>
      'Experimental, live channels only. If it stalls or shows a black picture, OpenIPTV switches it off by itself; you can also turn it off here.';

  @override
  String get powerUserTunnelingOff => 'Never used.';

  @override
  String get powerUserLayerTitle => 'Video layer';

  @override
  String get powerUserLayerDescription =>
      'Shows the main picture the way TV players do: smoother motion, quicker channel changes, and what tunneled playback needs. Takes effect when the app restarts.';

  @override
  String get powerUserLayerChangeFailed =>
      'Couldn\'t change the video layer setting.';

  @override
  String get powerUserRestartTitle => 'Restart to apply?';

  @override
  String get powerUserRestartLayerBody =>
      'OpenIPTV needs to restart to change how it shows the picture. Anything playing will stop.';

  @override
  String get powerUserRestartGraphicsBody =>
      'OpenIPTV needs to restart to change how it draws the screen. Anything playing will stop.';

  @override
  String get powerUserLater => 'Later';

  @override
  String get powerUserRestartNow => 'Restart now';

  @override
  String get powerUserRestartFailed =>
      'Couldn\'t restart. Close and open OpenIPTV to apply it.';

  @override
  String get powerUserGraphicsTitle => 'Graphics mode';

  @override
  String get powerUserGraphicsDescription =>
      'How OpenIPTV draws the screen and the video. If the picture looks torn (a line across it) or jittery on fast motion, try Compatible. Takes effect when the app restarts.';

  @override
  String powerUserGraphicsThisDevice(String chip) {
    return 'This device: $chip.';
  }

  @override
  String get powerUserGraphicsChangeFailed =>
      'Couldn\'t change the graphics mode.';

  @override
  String get powerUserUaTitle => 'User agent';

  @override
  String get powerUserUaDescription =>
      'How the player introduces itself to your provider. OpenIPTV sends its own name, version and device. Change it only if your provider asks for a particular one. Each extra channel in multi-view adds its own tag on the end, so your provider can tell them apart. Applies from the next channel you open.';

  @override
  String get powerUserUaRow => 'Player user agent';

  @override
  String get powerUserUaDefault => 'OpenIPTV (default)';

  @override
  String get powerUserUaEmptyNote => 'Leave it empty to use OpenIPTV\'s own.';

  @override
  String get powerUserUaHint => 'e.g. VLC/3.0.20 LibVLC/3.0.20';

  @override
  String get powerUserUseDefault => 'Use default';

  @override
  String get extraGuidesTitle => 'Extra Guides';

  @override
  String get extraGuidesModeExplicit => 'Explicit';

  @override
  String get extraGuidesModeExplicitDesc =>
      'Only when the channel\'s guide ID is exactly the same as the guide\'s. Safest; channels without an ID are left alone.';

  @override
  String get extraGuidesModeStandard => 'Standard';

  @override
  String get extraGuidesModeStandardDesc =>
      'The guide ID, or exactly the same channel name. US local stations are matched by call sign.';

  @override
  String get extraGuidesModeOptimistic => 'Optimistic';

  @override
  String get extraGuidesModeOptimisticDesc =>
      'Also channels whose names are only alike. Finds more, but some guesses will be wrong; you can fix any in Review Guide Matches.';

  @override
  String get extraGuidesMatchingModeTitle => 'Matching Mode';

  @override
  String get extraGuidesQueued =>
      'Will apply this as soon as the current update finishes.';

  @override
  String get extraGuidesStarting => 'Starting…';

  @override
  String extraGuidesUpdated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Guides updated: $count channels linked.',
      one: 'Guides updated: 1 channel linked.',
    );
    return '$_temp0';
  }

  @override
  String get extraGuidesUpdateFailed => 'The guides couldn\'t be updated.';

  @override
  String get extraGuidesChecking => 'Checking the guide…';

  @override
  String get extraGuidesAlreadyAdded => 'That guide is already in your list.';

  @override
  String extraGuidesAdded(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Added \"$name\" with $count channels. Matching channels…',
      one: 'Added \"$name\" with 1 channel. Matching channels…',
    );
    return '$_temp0';
  }

  @override
  String extraGuidesRemoveTitle(String name) {
    return 'Remove \"$name\"?';
  }

  @override
  String get extraGuidesRemoveBody =>
      'Channels that were matched to this guide lose its programmes. Your playlists are not affected.';

  @override
  String get extraGuidesRemove => 'Remove';

  @override
  String get extraGuidesUpdateNow => 'Update Now';

  @override
  String get extraGuidesTurnOff => 'Turn Off';

  @override
  String get extraGuidesTurnOn => 'Turn On';

  @override
  String get extraGuidesMoveUp => 'Move Up (Used First)';

  @override
  String get extraGuidesMoveDown => 'Move Down';

  @override
  String get extraGuidesFillTitle => 'Fill in missing guides';

  @override
  String get extraGuidesFillDescription =>
      'Your playlist\'s own TV guide is always used first. A channel it does not cover is matched by name to the guides you add here. You can also pick a guide for any channel yourself: hold OK (or long-press) a channel → Change Guide.\n\nWorks with .xml, .xml.gz and zipped guides, as long as they unpack to XML. OpenIPTV does not provide guides, but community sites publish them: a web search for \"XMLTV EPG\" is a good place to start. 😉';

  @override
  String get extraGuidesYourGuides => 'Your Guides';

  @override
  String get extraGuidesListHint => 'Guides higher in the list are used first.';

  @override
  String get extraGuidesListHintEmpty =>
      'None yet. Guides higher in the list are used first.';

  @override
  String get extraGuidesAddTitle => 'Add a Guide';

  @override
  String get extraGuidesAddSubtitle =>
      'A web address ending in .xml, .xml.gz or .zip';

  @override
  String get extraGuidesMatchingGroup => 'Matching';

  @override
  String get extraGuidesAutoMatchTitle => 'Match Channels Automatically';

  @override
  String get extraGuidesAutoMatchSubtitle =>
      'Channels without a guide are matched to the guides above. Never changes a channel that already has a guide.';

  @override
  String get extraGuidesMatchAndUpdate => 'Match and Update Now';

  @override
  String get extraGuidesReviewMatchesTitle => 'Review Guide Matches';

  @override
  String get extraGuidesNoMatchesYet => 'No channels matched yet';

  @override
  String extraGuidesMatchSummary(int auto, int manual) {
    return '$auto matched automatically · $manual chosen by you';
  }

  @override
  String extraGuidesLastError(String error, String when) {
    return '$error\nLast read $when.';
  }

  @override
  String get extraGuidesNotRead => 'Not read yet';

  @override
  String extraGuidesTileLine(int channels, int used, String when) {
    String _temp0 = intl.Intl.pluralLogic(
      channels,
      locale: localeName,
      other: '$channels channels',
      one: '1 channel',
    );
    return '$_temp0 · $used used · read $when';
  }

  @override
  String extraGuidesTileLineOff(int channels, int used, String when) {
    String _temp0 = intl.Intl.pluralLogic(
      channels,
      locale: localeName,
      other: '$channels channels',
      one: '1 channel',
    );
    return '$_temp0 · $used used · read $when · off';
  }

  @override
  String get extraGuidesNameLabel => 'Name (optional)';

  @override
  String get extraGuidesAddressLabel => 'Guide address';

  @override
  String get extraGuidesAddressInvalid =>
      'Enter the guide address, starting with http:// or https://';

  @override
  String get extraGuidesAddButton => 'Add';

  @override
  String get extraGuidesLinksTitle => 'Guide Matches';

  @override
  String get extraGuidesLinksEmpty =>
      'No channels are matched to an extra guide yet. Pick one for a channel with hold OK → Change Guide, or add a guide and let OpenIPTV match channels for you.';

  @override
  String get extraGuidesLinkNone => 'No guide (your choice)';

  @override
  String extraGuidesLinkManual(String id, String guide) {
    return '$id · $guide · your choice';
  }

  @override
  String extraGuidesLinkAuto(String id, String guide) {
    return '$id · $guide · automatic';
  }

  @override
  String get extraGuidesGuideFallback => 'guide';

  @override
  String get guideDataAgoJustNow => 'just now';

  @override
  String guideDataAgoMinutes(int count) {
    return '$count min ago';
  }

  @override
  String guideDataAgoHours(int count) {
    return '$count h ago';
  }

  @override
  String guideDataAgoDays(int count) {
    return '$count d ago';
  }

  @override
  String get guideDataTitle => 'Guide Data';

  @override
  String get guideDataDaysTitle => 'Days of guide to keep';

  @override
  String get guideDataDaysDescription =>
      'How far ahead the TV guide is stored. Fewer days makes the guide smaller and quicker to refresh. Catch-up history is kept as your provider offers it.';

  @override
  String guideDataDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String guideDataDaysDefault(int count) {
    return '$count days (default)';
  }

  @override
  String get guideDataDetailsTitle => 'Programme details';

  @override
  String get guideDataDetailsDescription =>
      'Descriptions are most of the guide\'s size. Turn them off to save space; titles and times stay. Turning them off removes the stored ones now.';

  @override
  String get guideDataStoreDescriptions => 'Store Programme Descriptions';

  @override
  String get guideDataDescriptionsBack =>
      'Descriptions come back the next time the TV guide refreshes.';

  @override
  String get guideDataLastUpdate => 'Last update';

  @override
  String get guideDataNoGuides => 'None of your playlists has a TV guide.';

  @override
  String get guideDataClearGroup => 'Clear';

  @override
  String get guideDataClearTitle => 'Clear Guide Data?';

  @override
  String get guideDataClearBody =>
      'This removes the stored TV guide for every playlist. Your playlists and channels stay. Refresh the TV guides to load it again.';

  @override
  String get guideDataClearButton => 'Clear';

  @override
  String get guideDataClearRowTitle => 'Clear Guide Data';

  @override
  String get guideDataClearRowSubtitle =>
      'Removes the stored guide for every playlist';

  @override
  String get guideDataClearing => 'Clearing…';

  @override
  String get guideDataCleared => 'Guide data cleared.';

  @override
  String guideDataLastLoaded(String error, String when, int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString programmes',
      one: '1 programme',
    );
    return '$error\nLast loaded $when, $_temp0 kept.';
  }

  @override
  String guideDataUpdated(String when, int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString programmes',
      one: '1 programme',
    );
    return 'Updated $when · $_temp0';
  }

  @override
  String guideDataStored(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString programmes stored',
      one: '1 programme stored',
    );
    return '$_temp0';
  }

  @override
  String get guideDataNotLoaded => 'Not loaded yet';

  @override
  String get changeGuideTitle => 'Change Guide';

  @override
  String get changeGuideDescribeDefault =>
      'Using the playlist\'s own guide (or a smart match, if it has none)';

  @override
  String get changeGuideDescribeNone => 'No guide, as you chose';

  @override
  String changeGuideDescribeManual(String id, String guide) {
    return 'You chose $id in $guide';
  }

  @override
  String changeGuideDescribeAuto(String id, String guide) {
    return 'Matched automatically to $id in $guide';
  }

  @override
  String get changeGuideGuideFallback => 'a guide';

  @override
  String get changeGuideLoading => 'Loading the guide, this can take a minute…';

  @override
  String get changeGuideLoaded => 'Guide changed and loaded.';

  @override
  String get changeGuideRemoved => 'Guide removed.';

  @override
  String get changeGuideBackToAuto => 'Back to automatic.';

  @override
  String get changeGuideNoGuidesTitle => 'No guides to pick from yet';

  @override
  String get changeGuideNoGuidesBody =>
      'Add one in Settings → Playlists & Guides → Extra Guides, or refresh your TV guides.';

  @override
  String get changeGuideSearchHint => 'Search the guides';

  @override
  String get changeGuideSuggested => 'Suggested';

  @override
  String get changeGuideResults => 'Results';

  @override
  String get changeGuideNothingFound => 'Nothing found';

  @override
  String get changeGuideGuideLabel => 'Guide';

  @override
  String get changeGuideNoGuideTitle => 'No Guide for This Channel';

  @override
  String get changeGuideNoGuideSubtitle =>
      'Clears its programmes and keeps it that way';

  @override
  String get changeGuideUseAutomatic => 'Use Automatic';

  @override
  String get changeGuideUseAutomaticSubtitle =>
      'The playlist\'s own guide, or a smart match';

  @override
  String get backupTitle => 'Backup & Restore';

  @override
  String get backupExportGroup => 'Export';

  @override
  String get backupExportInfoTitle => 'Export Backup';

  @override
  String get backupExportInfoBody =>
      'Exporting saves every profile, every source, and your app settings into a single .zip file. You can optionally protect it with a password.';

  @override
  String get backupExportInfoTip =>
      'Save this file somewhere safe — you\'ll need it to restore everything on a new device.';

  @override
  String get backupExportTitle => 'Export Backup';

  @override
  String get backupExportSubtitle =>
      'Save all profiles, sources, and settings as a .zip file';

  @override
  String get backupRestoreGroup => 'Restore';

  @override
  String get backupImportInfoTitle => 'Restore Backup';

  @override
  String get backupImportInfoBody =>
      'Importing reads a .zip backup file and adds its profiles and sources to this device. If the backup was password-protected, you\'ll be asked for the password used when it was exported.';

  @override
  String get backupImportInfoTip =>
      'Importing does not delete anything — your existing profiles are kept.';

  @override
  String get backupImportTitle => 'Import Backup';

  @override
  String get backupImportSubtitle => 'Open a .zip backup file';

  @override
  String get backupPreparing => 'Preparing backup…';

  @override
  String backupSavedTo(String location) {
    return 'Backup saved to $location';
  }

  @override
  String get backupShareSubject => 'OpenIPTV backup';

  @override
  String get backupCreateFailed =>
      'Couldn\'t create the backup file. Make sure you have storage permission and try again.';

  @override
  String get backupSaveTitle => 'Save Backup';

  @override
  String get backupSaveBody =>
      'Save the backup file to this device, or share it to another app (email, cloud storage, …).';

  @override
  String get backupShareButton => 'Share…';

  @override
  String get backupSaveToDownloads => 'Save to Downloads';

  @override
  String backupRestoredProfiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count profiles',
      one: '1 profile',
    );
    return '$_temp0';
  }

  @override
  String backupRestoredSources(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sources',
      one: '1 source',
    );
    return '$_temp0';
  }

  @override
  String backupRestored(String profiles, String sources) {
    return 'Restored $profiles and $sources.';
  }

  @override
  String get backupPickTitle => 'Choose a backup';

  @override
  String get backupPickerFailed =>
      'Couldn\'t open the file picker. Check that the app has file access permission and try again.';

  @override
  String get backupOpenFailed =>
      'Couldn\'t open this backup file. Make sure it\'s a valid OpenIPTV backup.';

  @override
  String get backupProtectTitle => 'Protect This Backup?';

  @override
  String get backupProtectBody =>
      'Source credentials are stored in plain text inside the backup file. Optionally set a password to encrypt it — you\'ll need the same password to restore it.';

  @override
  String get backupPasswordOptionalHint => 'Password (optional)';

  @override
  String get backupSkip => 'Skip';

  @override
  String get backupExportButton => 'Export';

  @override
  String get backupProtectedTitle => 'Backup is Protected';

  @override
  String get backupProtectedBody =>
      'This backup was protected with a password. Enter the password that was set when it was exported.';

  @override
  String get backupEnterPasswordHint => 'Enter password';

  @override
  String get backupRestoreButton => 'Restore';

  @override
  String get updateManagedByPlay =>
      'Updates for this install are managed by Google Play.';

  @override
  String get updateChecking => 'Checking for updates…';

  @override
  String get updateCheckFailed =>
      'Couldn\'t check for updates. Check your internet connection.';

  @override
  String updateUpToDate(String version) {
    return 'You\'re up to date (version $version).';
  }

  @override
  String get updateAvailableTitle => 'Update available';

  @override
  String updateVersion(String version) {
    return 'Version $version';
  }

  @override
  String updateVersionFromTo(String installed, String latest) {
    return 'Version $installed → $latest';
  }

  @override
  String get updatePermissionBody =>
      'To install updates, OpenIPTV needs permission to install apps.\n\nSelect Open Settings, turn on \"Allow from this source\", then come back here — the update will continue automatically.';

  @override
  String get updateDownloading => 'Downloading…';

  @override
  String updateDownloadingPercent(int percent) {
    return 'Downloading… $percent%';
  }

  @override
  String get updateHandedOffBody =>
      'Follow the prompts on screen to finish installing. OpenIPTV will restart on the new version.\n\nIf nothing appeared, or you cancelled, select Install again.';

  @override
  String get updateFailedBody =>
      'The update couldn\'t be downloaded. Check your internet connection and try again.';

  @override
  String get updateSkipVersion => 'Skip this version';

  @override
  String get updateLater => 'Later';

  @override
  String get updateNow => 'Update now';

  @override
  String get updateOpenSettings => 'Open Settings';

  @override
  String get updateClose => 'Close';

  @override
  String get updateInstallAgain => 'Install again';

  @override
  String get updateTryAgain => 'Try again';

  @override
  String get updateNoNotes => 'No release notes provided.';

  @override
  String get reportsTitle => 'Anonymous Reports';

  @override
  String get reportsSwitchTitle => 'Send anonymous crash reports';

  @override
  String get reportsSwitchSubtitle =>
      'Off unless you turn it on. Helps fix crashes faster.';

  @override
  String get reportsIntro =>
      'When the app crashes or freezes, a short report is saved on this device and sent in the background soon after, never more than once every 10 minutes. It cannot be tied to you or to anything you watch.';

  @override
  String get reportsContainsHeading => 'A report contains only this';

  @override
  String get reportsContainsList =>
      '• App version\n• Android version\n• Device maker and model\n• The date (no time)\n• What kind of problem (crash or freeze) and its name only\n• Where in the code it happened (up to 30 lines)';

  @override
  String get reportsNeverHeading => 'Never included';

  @override
  String get reportsNeverList =>
      '• Playlists, logins, passwords or links\n• Channel, movie or series names, or what you watch\n• Search text, profile names or settings\n• IP addresses, device IDs, or any ID that could tie reports together\n• Error messages (they can contain links or names)';

  @override
  String get reportsWaitingHeading => 'Waiting to be sent from this device';

  @override
  String get reportsNothingWaiting => 'Nothing is waiting.';

  @override
  String get reportsDeleteWaiting => 'Delete waiting reports';

  @override
  String get reportsCheckCodeHeading => 'Check the code';

  @override
  String get reportsCheckCodeBody =>
      'All of it lives in lib/telemetry/ in the OpenIPTV GitHub repository, with a short design note in docs/design/anonymous-stats.md.';

  @override
  String get playerPlay => 'Play';

  @override
  String get playerPause => 'Pause';

  @override
  String get playerChannels => 'Channels';

  @override
  String get castTitleCasting => 'Casting';

  @override
  String get castDeviceFallback => 'Cast device';

  @override
  String get castConnected => 'Connected';

  @override
  String get castStop => 'Stop casting';

  @override
  String get castPickerTitle => 'Cast to';

  @override
  String get castSearching => 'Looking for TVs and speakers on your Wi-Fi…';

  @override
  String get castConnecting => 'Connecting…';

  @override
  String get castSameWifi =>
      'Your phone and the TV need to be on the same Wi-Fi network.';

  @override
  String get castCastTooltip => 'Cast';

  @override
  String get castYourTv => 'your TV';

  @override
  String castPlayingOn(String device) {
    return 'Playing on $device';
  }

  @override
  String castCastingTo(String device) {
    return 'Casting to $device';
  }

  @override
  String castOnDevice(String device) {
    return 'On $device';
  }

  @override
  String get castBack10 => 'Back 10 seconds';

  @override
  String get castForward10 => 'Forward 10 seconds';

  @override
  String get castVolumeDown => 'Volume down';

  @override
  String get castVolumeUp => 'Volume up';

  @override
  String catchupStartedMinutesAgo(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
      one: '1 minute',
    );
    return 'This show started $_temp0 ago. Where would you like to start?';
  }

  @override
  String catchupStartedHoursAgo(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours hours',
      one: '1 hour',
    );
    return 'This show started $_temp0 ago. Where would you like to start?';
  }

  @override
  String catchupStartedHoursMinutesAgo(int hours, int minutes) {
    return 'This show started ${hours}h ${minutes}m ago. Where would you like to start?';
  }

  @override
  String get catchupStartFromBeginning => 'Start from the beginning';

  @override
  String get catchupWatchLive => 'Watch live';

  @override
  String get playerClose => 'Close';

  @override
  String get channelSwitcherBarrier => 'Close channels';

  @override
  String get channelSwitcherFavorites => 'Favorites';

  @override
  String get channelSwitcherTitle => 'Channels';

  @override
  String get channelSwitcherPrevCategory => 'Previous category';

  @override
  String get channelSwitcherNextCategory => 'Next category';

  @override
  String get channelSwitcherNowWatching => 'Now watching';

  @override
  String get channelSwitcherLive => 'Live';

  @override
  String get playerChannelUnavailableNow =>
      'This channel isn\'t available right now.';

  @override
  String get multiViewFullScreen => 'Full screen';

  @override
  String get multiViewSwap => 'Swap channel';

  @override
  String get multiViewAdd => 'Add a channel';

  @override
  String get multiViewLayout => 'Layout';

  @override
  String get multiViewEqualGrid => 'Equal grid';

  @override
  String get multiViewOneBig => 'One big';

  @override
  String get multiViewRemove => 'Remove';

  @override
  String get multiViewHintOptions => 'Double tap for options';

  @override
  String get multiViewHintHear => 'Double tap to hear this channel';

  @override
  String get multiViewNoDecoder =>
      'This device can\'t play another channel at the same time.';

  @override
  String get multiViewProviderRefused =>
      'Your provider didn\'t allow another stream.';

  @override
  String playerBackSeconds(int seconds) {
    return 'Back $seconds seconds';
  }

  @override
  String playerForwardSeconds(int seconds) {
    return 'Forward $seconds seconds';
  }

  @override
  String get playerSubtitles => 'Subtitles';

  @override
  String get playerRemoveFavorite => 'Remove from Favorites';

  @override
  String get playerAddFavorite => 'Add to Favorites';

  @override
  String get playerTvGuide => 'TV Guide';

  @override
  String get playerSettingsTooltip => 'Playback settings';

  @override
  String playerTimeLeft(String duration) {
    return '$duration left';
  }

  @override
  String playerNextProgramme(String title) {
    return 'Next: $title';
  }

  @override
  String get playerLiveBadge => 'LIVE';

  @override
  String get playerGoLive => 'Go live';

  @override
  String playerStreamDetails(String details) {
    return 'Stream details: $details';
  }

  @override
  String get playerNoticeAudioDelay =>
      'The audio delay didn\'t work with this stream, so it was set back to None. Playback carries on as normal.';

  @override
  String get playerNoticePassthrough =>
      'Surround sound passthrough didn\'t work on this device, so it was switched off and the sound is playing normally. You can try it again in Power User Tools.';

  @override
  String get playerNoticeTunneled =>
      'Tunneled playback didn\'t work on this device, so it was switched off. You can try it again in Power User Tools.';

  @override
  String get playerErrorProviderRefused =>
      'Your provider didn\'t allow this stream.';

  @override
  String get playerErrorChannelProvider =>
      'This channel isn\'t available from your provider right now.';

  @override
  String get playerErrorTitleProvider =>
      'This title isn\'t available from your provider right now.';

  @override
  String get castThisDevice => 'this device';

  @override
  String castFailedChannel(String device) {
    return 'This channel can\'t be played on $device. Stop casting to watch it here.';
  }

  @override
  String castFailedTitle(String device) {
    return 'This title can\'t be played on $device. Stop casting to watch it here.';
  }

  @override
  String get playerResumeTitle => 'Resume Watching?';

  @override
  String playerResumeBody(String position) {
    return 'Continue from $position?';
  }

  @override
  String get playerStartOver => 'Start Over';

  @override
  String get playerResume => 'Resume';

  @override
  String get playerVideoSemantics => 'Video';

  @override
  String get playerVideoSemanticsHint =>
      'Double tap to show or hide the playback controls';

  @override
  String get playerReconnecting => 'Reconnecting…';

  @override
  String playerReconnectingAttempt(int attempt, int max) {
    return 'Reconnecting… ($attempt of $max)';
  }

  @override
  String get playerUpNext => 'Up next';

  @override
  String get playerPlayNow => 'Play now';

  @override
  String get playerStreamNotPlaying => 'This stream isn\'t playing right now';

  @override
  String get playerTryAgain => 'Try again';

  @override
  String get playerGoBack => 'Go back';

  @override
  String get playerSubtitlesOff => 'Off';

  @override
  String get playerNoSubtitlesLive =>
      'No subtitles detected on this channel yet. Captions appear here as soon as the broadcast sends them.';

  @override
  String get playerNoSubtitlesVideo => 'This video has no subtitles.';

  @override
  String get playerAudio => 'Audio';

  @override
  String get playerPicture => 'Picture';

  @override
  String get playerPictureFit => 'Fit';

  @override
  String get playerPictureZoom => 'Zoom';

  @override
  String get playerPictureFill => 'Fill screen';

  @override
  String get playerClock => 'Clock';

  @override
  String get playerClockWithControls => 'With controls';

  @override
  String get playerClockAlwaysOn => 'Always on';

  @override
  String get playerAudioDelay => 'Audio delay';

  @override
  String get playerAudioDelayNone => 'None';

  @override
  String get playerStreamDetailsLabel => 'Stream details';

  @override
  String get playerShow => 'Show';

  @override
  String get playerHide => 'Hide';

  @override
  String get playerSpeed => 'Speed';

  @override
  String get playerSpeedNormal => 'Normal';

  @override
  String get playerCaptions => 'Captions';

  @override
  String playerCaptionsNumbered(int channel) {
    return 'Captions $channel';
  }

  @override
  String get playerDigitalCaptions => 'Digital captions';

  @override
  String playerDigitalCaptionsNumbered(int channel) {
    return 'Digital captions $channel';
  }

  @override
  String get playerLangEn => 'English';

  @override
  String get playerLangEs => 'Spanish';

  @override
  String get playerLangFr => 'French';

  @override
  String get playerLangDe => 'German';

  @override
  String get playerLangIt => 'Italian';

  @override
  String get playerLangPt => 'Portuguese';

  @override
  String get playerLangNl => 'Dutch';

  @override
  String get playerLangAr => 'Arabic';

  @override
  String get playerLangRu => 'Russian';

  @override
  String get playerLangTr => 'Turkish';

  @override
  String get playerLangPl => 'Polish';

  @override
  String get playerLangHi => 'Hindi';

  @override
  String get playerLangJa => 'Japanese';

  @override
  String get playerLangKo => 'Korean';

  @override
  String get playerLangZh => 'Chinese';

  @override
  String get playerLangEl => 'Greek';

  @override
  String get playerLangSv => 'Swedish';

  @override
  String get playerLangDa => 'Danish';

  @override
  String get playerLangNo => 'Norwegian';

  @override
  String get playerLangFi => 'Finnish';

  @override
  String get playerLangHe => 'Hebrew';

  @override
  String get playerLangRo => 'Romanian';

  @override
  String get carLibrarySetup => 'Open OpenIPTV on your phone to get started';

  @override
  String get carLibraryLiveTv => 'Live TV';

  @override
  String get carLibraryMovies => 'Movies';

  @override
  String get carLibrarySeries => 'Series';

  @override
  String get carLibraryFavorites => 'Favorites';

  @override
  String get carLibraryRecentlyWatched => 'Recently Watched';

  @override
  String get carLibraryContinueWatching => 'Continue Watching';

  @override
  String get categoryToolsRename => 'Rename Category';

  @override
  String get categoryToolsMoveUp => 'Move Up';

  @override
  String get categoryToolsMoveDown => 'Move Down';

  @override
  String get categoryToolsResetName => 'Reset Name';

  @override
  String get categoryToolsHide => 'Hide Category';

  @override
  String get categoryToolsNameHint => 'Category name';

  @override
  String get categoryToolsRenameNote =>
      'Only changes how it looks here. Leave it empty to go back to the original name.';

  @override
  String get categoryToolsSave => 'Save';

  @override
  String get liveTvRemoveFromRecent => 'Remove from Recently Watched';

  @override
  String get liveTvTitle => 'Live TV';

  @override
  String get liveTvLoadError =>
      'Couldn\'t load channels. Check your internet connection.';

  @override
  String get liveTvFavorites => 'Favorites';

  @override
  String get liveTvRecentlyWatched => 'Recently Watched';

  @override
  String get liveTvCategories => 'Categories';

  @override
  String get liveTvAllChannels => 'All Channels';

  @override
  String get liveTvNoChannels => 'No channels here yet.';

  @override
  String get liveTvRenameChannel => 'Rename Channel';

  @override
  String get liveTvChannelNameHint => 'Channel name';

  @override
  String get liveTvChannelHidden =>
      'Channel hidden. Bring it back in Settings → Watching → Channel Lists → Hidden Channels.';

  @override
  String get liveTvCatchupAvailable => 'Catch-up available';

  @override
  String liveTvNextProgramme(String time, String title) {
    return 'Next  $time  $title';
  }

  @override
  String get liveTvRemoveFromFavorites => 'Remove from Favorites';

  @override
  String get liveTvAddToFavorites => 'Add to Favorites';

  @override
  String get liveTvUseOriginalName => 'Use the Original Name';

  @override
  String get liveTvChangeGuide => 'Change Guide';

  @override
  String get liveTvHideChannel => 'Hide Channel';

  @override
  String get liveTvLiveBadge => 'Live';

  @override
  String get epgPanelCatchupUnavailable =>
      'Catch-up is not available for this programme.';

  @override
  String get epgPanelToday => 'Today';

  @override
  String get epgPanelLoadError =>
      'Couldn\'t load the TV guide. Your channels still work — guide info will retry automatically.';

  @override
  String get epgPanelNoInfo => 'No guide information available for this day.';

  @override
  String get epgPanelLiveBadge => 'LIVE';

  @override
  String get tvGuideCategoryLocked =>
      'This category is locked. Press OK on it to unlock it.';

  @override
  String get tvGuideStreamDenied => 'Your provider didn\'t allow this stream.';

  @override
  String get tvGuideChannelUnavailable =>
      'This channel isn\'t available right now.';

  @override
  String get tvGuidePressOkToPreview => 'Press OK to preview';

  @override
  String get tvGuideNoInfo => 'No guide information';

  @override
  String get searchLoadError => 'Couldn\'t load search results. Try again.';

  @override
  String searchNoResultsTitle(String query) {
    return 'No results for \"$query\"';
  }

  @override
  String get searchNoResultsBody =>
      'Check the spelling, or try a channel, a movie or a show name.';

  @override
  String get searchHint => 'Search channels, movies and series';

  @override
  String get searchWelcomeTitle => 'Find something to watch';

  @override
  String get searchWelcomeBody =>
      'Search Live TV channels, movies, series — and what\'s on right now.';

  @override
  String get searchRecentTitle => 'Recent searches';

  @override
  String get searchClearRecent => 'Clear recent searches';

  @override
  String searchEnterPinToUnlock(String label) {
    return 'Enter admin PIN to unlock \"$label\"';
  }

  @override
  String searchTomorrowAt(String time) {
    return 'Tomorrow $time';
  }

  @override
  String searchYesterdayAt(String time) {
    return 'Yesterday $time';
  }

  @override
  String get searchOnNow => 'On now';

  @override
  String get searchLiveTv => 'Live TV';

  @override
  String get searchLive => 'Live';

  @override
  String get searchComingUp => 'Coming up';

  @override
  String get searchEarlier => 'Earlier';

  @override
  String get searchMovies => 'Movies';

  @override
  String get searchSeries => 'Series';

  @override
  String get mediaRailSeeAll => 'See all';

  @override
  String get mediaRailEnterPin => 'Enter PIN to view';

  @override
  String get detailLess => 'Less';

  @override
  String get detailMore => 'More';

  @override
  String detailStarring(String cast) {
    return 'Starring  $cast';
  }

  @override
  String detailDirector(String director) {
    return 'Director  $director';
  }

  @override
  String get detailPlay => 'Play';

  @override
  String detailResumeFrom(String time) {
    return 'Resume from $time';
  }

  @override
  String get detailStartOver => 'Start Over';

  @override
  String get detailFavorited => 'Favorited';

  @override
  String get detailFavorite => 'Favorite';

  @override
  String get detailClearProgress => 'Clear Progress';

  @override
  String get detailMoreLikeThis => 'More Like This';

  @override
  String get detailGoBack => 'Go Back';

  @override
  String get detailMovieLoadError => 'Couldn\'t load this movie. Try again.';

  @override
  String get detailSeriesLoadError => 'Couldn\'t load this series. Try again.';

  @override
  String get seriesLoadingEpisodes => 'Loading episodes…';

  @override
  String get seriesNoEpisodesYet => 'No episodes yet';

  @override
  String seriesResumeEpisode(String label) {
    return 'Resume $label';
  }

  @override
  String seriesPlayEpisode(String label) {
    return 'Play $label';
  }

  @override
  String seriesShortEpisode(int episode, int season) {
    return 'S$season E$episode';
  }

  @override
  String seriesSeasonCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Seasons',
      one: '$count Season',
    );
    return '$_temp0';
  }

  @override
  String get seriesUpNext => 'Up Next';

  @override
  String get seriesEpisodes => 'Episodes';

  @override
  String get seriesNoEpisodesAvailable => 'No episodes available yet.';

  @override
  String seriesSeason(int number) {
    return 'Season $number';
  }

  @override
  String get detailFavorites => 'Favorites';

  @override
  String get detailContinueWatching => 'Continue Watching';

  @override
  String get detailBrowseByGenre => 'Browse by Genre';

  @override
  String get detailAllGenre => 'All';

  @override
  String get detailAddToFavorites => 'Add to Favorites';

  @override
  String get detailRemoveFromFavorites => 'Remove from Favorites';

  @override
  String get detailRemoveFromContinueWatching =>
      'Remove from Continue Watching';

  @override
  String get moviesTitle => 'Movies';

  @override
  String get moviesLoadError => 'Couldn\'t load movies. Try again.';

  @override
  String get moviesAll => 'All Movies';

  @override
  String get moviesNoneFound => 'No movies found.';

  @override
  String get seriesTitle => 'Series';

  @override
  String get seriesLoadError => 'Couldn\'t load series. Try again.';

  @override
  String get seriesAll => 'All Series';

  @override
  String get seriesNoneFound => 'No series found.';

  @override
  String get shellPressBackAgain => 'Press Back again to exit';

  @override
  String get navLiveTv => 'Live TV';

  @override
  String get navMovies => 'Movies';

  @override
  String get navSeries => 'Series';

  @override
  String get navSearch => 'Search';

  @override
  String get navSettings => 'Settings';

  @override
  String pullRefreshOne(String name, String reason) {
    return 'Couldn\'t refresh $name. $reason';
  }

  @override
  String pullRefreshMany(String names) {
    return 'Couldn\'t refresh $names. Try again later.';
  }

  @override
  String get genreActionsHideGenre => 'Hide Genre';

  @override
  String get filePickerNoFiles =>
      'No files found on this device. Copy the file to the Download folder, or to Android/data/com.openiptv.app/files, then try again.';

  @override
  String get starRemoveFavorite => 'Remove from favorites';

  @override
  String get starAddFavorite => 'Add to favorites';

  @override
  String formatRuntimeHours(int hours) {
    return '${hours}h';
  }

  @override
  String formatRuntimeMinutes(String minutes) {
    return '${minutes}m';
  }

  @override
  String formatRuntimeHoursMinutes(int hours, String minutes) {
    return '${hours}h ${minutes}m';
  }

  @override
  String get formatStateEnded => 'Ended';

  @override
  String get formatStateNext => 'Next';

  @override
  String get formatStateLive => 'Live';

  @override
  String get formatStateNotStarted => 'Not started';

  @override
  String get formatGeoBlocked => 'Geo-blocked';
}
