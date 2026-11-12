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
}
