import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es')
  ];

  /// Tooltip of the round back arrow button (icon only)
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// Dialog button that closes the dialog without changing anything
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// Dialog button that declines for the moment
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get commonNotNow;

  /// Progress text shown while the app contacts the playlist server
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get wizardConnecting;

  /// Title of the file picker used to choose a playlist file saved on the device
  ///
  /// In en, this message translates to:
  /// **'Choose a playlist file'**
  String get wizardPickFileTitle;

  /// Error shown when the system file picker is unavailable
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the file picker on this device.'**
  String get wizardFilePickerFailed;

  /// Error shown when the user taps Load My Playlist without having picked a file
  ///
  /// In en, this message translates to:
  /// **'Choose a playlist file first.'**
  String get wizardChooseFileFirst;

  /// Missing-field noun phrase inserted into wizardEnterMissing. Include the article so the sentence reads naturally
  ///
  /// In en, this message translates to:
  /// **'the server address'**
  String get wizardFieldServerAddress;

  /// Missing-field noun phrase inserted into wizardEnterMissing. Include the article
  ///
  /// In en, this message translates to:
  /// **'the username'**
  String get wizardFieldUsername;

  /// Missing-field noun phrase inserted into wizardEnterMissing. Include the article
  ///
  /// In en, this message translates to:
  /// **'the password'**
  String get wizardFieldPassword;

  /// Missing-field noun phrase inserted into wizardEnterMissing. Include the article
  ///
  /// In en, this message translates to:
  /// **'the M3U link'**
  String get wizardFieldM3uUrl;

  /// Joins a comma-separated list with the final item, e.g. 'the server address, the username and the password'
  ///
  /// In en, this message translates to:
  /// **'{rest} and {last}'**
  String wizardListAnd(String rest, String last);

  /// Error listing which required fields are empty. {fields} is built from wizardFieldServerAddress, wizardFieldUsername, wizardFieldPassword, wizardFieldM3uUrl joined with commas and wizardListAnd
  ///
  /// In en, this message translates to:
  /// **'Enter {fields} from your provider.'**
  String wizardEnterMissing(String fields);

  /// Snackbar after restoring an empty backup. 'Get Started' refers to the button wizardGetStarted; keep them matching
  ///
  /// In en, this message translates to:
  /// **'That backup doesn\'t include a profile and a playlist, so there\'s nothing to restore yet. Tap Get Started instead.'**
  String get wizardRestoreEmpty;

  /// Playlist label during a multi-playlist restore. {nickname} is the playlist name chosen by the user
  ///
  /// In en, this message translates to:
  /// **'{nickname} ({index} of {total})'**
  String wizardRestoreProgressItem(String nickname, int index, int total);

  /// Progress line while restoring: playlist label, then a status message coming from the app
  ///
  /// In en, this message translates to:
  /// **'{label} — {message}'**
  String wizardRestoreProgressLine(String label, String message);

  /// Headline of the loading page while restoring from a backup
  ///
  /// In en, this message translates to:
  /// **'Restoring your playlists…'**
  String get wizardLoadingRestoring;

  /// Headline of the loading page while a new playlist is downloaded
  ///
  /// In en, this message translates to:
  /// **'Setting up your playlist…'**
  String get wizardLoadingSettingUp;

  /// Headline of the final page when a playlist was added from Settings
  ///
  /// In en, this message translates to:
  /// **'Playlist added!'**
  String get wizardAllSetAdded;

  /// Headline of the final page of the setup wizard. {name} is the user's first name
  ///
  /// In en, this message translates to:
  /// **'You\'re all set, {name}!'**
  String wizardAllSetHeadline(String name);

  /// Headline of the final page when the user gave no name. (Currently the app uses the English word 'there' as the name; see notes)
  ///
  /// In en, this message translates to:
  /// **'You\'re all set!'**
  String get wizardAllSetHeadlineNoName;

  /// Two-line message under the final headline. \n = line break
  ///
  /// In en, this message translates to:
  /// **'Your playlist is ready.\nEnjoy the show.'**
  String get wizardAllSetBody;

  /// Large welcome headline. \n = line break. Keep OpenIPTV on its own line
  ///
  /// In en, this message translates to:
  /// **'Welcome to\nOpenIPTV'**
  String get wizardWelcomeTitle;

  /// Welcome subtitle. \n = line break
  ///
  /// In en, this message translates to:
  /// **'Let\'s get you set up.\nIt only takes a minute.'**
  String get wizardWelcomeSubtitle;

  /// Primary button on the welcome page
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get wizardGetStarted;

  /// Text button on the welcome page that restores profiles and playlists from a backup file
  ///
  /// In en, this message translates to:
  /// **'Restore from a backup'**
  String get wizardRestoreFromBackup;

  /// Heading of the profile name page
  ///
  /// In en, this message translates to:
  /// **'What\'s your name?'**
  String get wizardNameTitle;

  /// Reassurance under the name heading. \n = line break
  ///
  /// In en, this message translates to:
  /// **'All information stays on your device.\nOpenIPTV never collects personal data.'**
  String get wizardPrivacyNote;

  /// Hint text inside the empty name field
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get wizardNameHint;

  /// Label above the emoji avatar choices
  ///
  /// In en, this message translates to:
  /// **'Pick an avatar'**
  String get wizardPickAvatar;

  /// Name of the app highlight colour setting; also the heading of the colour picker and of the wizard's colour choice
  ///
  /// In en, this message translates to:
  /// **'Accent Color'**
  String get settingsAccentColorTitle;

  /// Button that moves to the next wizard page
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get wizardContinue;

  /// Heading of the optional PIN page
  ///
  /// In en, this message translates to:
  /// **'Secure your account'**
  String get wizardPinTitle;

  /// Explanation on the PIN page. \n = line break. 'Settings' must match settingsTitle
  ///
  /// In en, this message translates to:
  /// **'Set a PIN of 4 to 8 digits to protect this admin account.\nYou can skip this and add one later in Settings.'**
  String get wizardPinBody;

  /// Button that saves the PIN
  ///
  /// In en, this message translates to:
  /// **'Set PIN'**
  String get wizardSetPin;

  /// Text button that skips the PIN page
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get wizardSkipForNow;

  /// Heading of the playlist-type page when opened from Settings (Add Playlist). \n = line break
  ///
  /// In en, this message translates to:
  /// **'What kind of playlist\nare you adding?'**
  String get wizardTypeTitleAdd;

  /// Heading of the playlist-type page during first setup. \n = line break
  ///
  /// In en, this message translates to:
  /// **'What kind of playlist\ndo you have?'**
  String get wizardTypeTitleHave;

  /// Hint under the playlist-type heading
  ///
  /// In en, this message translates to:
  /// **'Not sure? Ask your IPTV provider — they\'ll know!'**
  String get wizardTypeHelp;

  /// Card title. Product name, do not translate
  ///
  /// In en, this message translates to:
  /// **'Xtream Codes'**
  String get wizardTypeXtreamTitle;

  /// Card description for the Xtream Codes option
  ///
  /// In en, this message translates to:
  /// **'Login with a server address, username, and password.'**
  String get wizardTypeXtreamDesc;

  /// Card title for a playlist loaded from a web link
  ///
  /// In en, this message translates to:
  /// **'M3U Playlist'**
  String get wizardTypeM3uTitle;

  /// Card description for the M3U link option
  ///
  /// In en, this message translates to:
  /// **'Load from a direct playlist URL (ending in .m3u or .m3u8).'**
  String get wizardTypeM3uDesc;

  /// Card title for a playlist file saved on the device; also the page title when a file is chosen
  ///
  /// In en, this message translates to:
  /// **'Playlist File'**
  String get wizardTypeFileTitle;

  /// Card description for the playlist file option
  ///
  /// In en, this message translates to:
  /// **'Choose an .m3u file saved on this device.'**
  String get wizardTypeFileDesc;

  /// Page title for entering Xtream login details
  ///
  /// In en, this message translates to:
  /// **'Xtream Credentials'**
  String get wizardCredsTitleXtream;

  /// Subtitle under the Xtream page title
  ///
  /// In en, this message translates to:
  /// **'Enter the login details from your provider.'**
  String get wizardCredsSubXtream;

  /// Subtitle under the playlist file page title
  ///
  /// In en, this message translates to:
  /// **'Choose the playlist file saved on this device.'**
  String get wizardCredsSubFile;

  /// Subtitle under the M3U page title
  ///
  /// In en, this message translates to:
  /// **'Paste the playlist link your provider gave you.'**
  String get wizardCredsSubM3u;

  /// Field label. The nickname is just a friendly name for the playlist
  ///
  /// In en, this message translates to:
  /// **'Nickname (optional)'**
  String get wizardNicknameOptional;

  /// Field label for the playlist's friendly name
  ///
  /// In en, this message translates to:
  /// **'Nickname'**
  String get wizardNickname;

  /// Hint inside the empty nickname field
  ///
  /// In en, this message translates to:
  /// **'Uses the file name if left blank'**
  String get wizardNicknameHintFile;

  /// Example hint inside the nickname field
  ///
  /// In en, this message translates to:
  /// **'e.g. Home Server'**
  String get wizardNicknameHintExample;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Server Address'**
  String get wizardServerAddressLabel;

  /// Example address hint. Keep the URL format, only translate the host word
  ///
  /// In en, this message translates to:
  /// **'http://your-provider.com:8080'**
  String get wizardServerAddressHint;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get wizardUsernameLabel;

  /// Example hint, written like an identifier (underscores)
  ///
  /// In en, this message translates to:
  /// **'your_username'**
  String get wizardUsernameHint;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get wizardPasswordLabel;

  /// Example hint, written like an identifier (underscores)
  ///
  /// In en, this message translates to:
  /// **'your_password'**
  String get wizardPasswordHint;

  /// Tooltip of the eye button while the password is visible
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get wizardPasswordHide;

  /// Tooltip of the eye button while the password is hidden
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get wizardPasswordShow;

  /// Field label for the optional programme guide address
  ///
  /// In en, this message translates to:
  /// **'TV Guide URL (optional)'**
  String get wizardGuideUrlLabel;

  /// Example guide address hint
  ///
  /// In en, this message translates to:
  /// **'https://example.com/epg.xml'**
  String get wizardGuideUrlHint;

  /// Field label for the playlist web address
  ///
  /// In en, this message translates to:
  /// **'M3U URL'**
  String get wizardM3uUrlLabel;

  /// Example playlist address hint
  ///
  /// In en, this message translates to:
  /// **'https://example.com/playlist.m3u'**
  String get wizardM3uUrlHint;

  /// Primary button that downloads the playlist
  ///
  /// In en, this message translates to:
  /// **'Load My Playlist'**
  String get wizardLoadMyPlaylist;

  /// Label above the file chooser control
  ///
  /// In en, this message translates to:
  /// **'Playlist file'**
  String get wizardFileFieldLabel;

  /// Placeholder inside the file chooser control before a file is picked
  ///
  /// In en, this message translates to:
  /// **'Choose a file…'**
  String get wizardFileChoose;

  /// Small action label on the file chooser once a file is picked
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get wizardFileChange;

  /// Small action label on the file chooser before a file is picked
  ///
  /// In en, this message translates to:
  /// **'Browse'**
  String get wizardFileBrowse;

  /// App bar title and navigation label of the Settings tab
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Group heading in Settings for everything about watching (playback, channel lists, guide layout)
  ///
  /// In en, this message translates to:
  /// **'Watching'**
  String get settingsGroupWatching;

  /// Group heading in Settings for look and feel
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsGroupAppearance;

  /// Sub-group heading inside the Playback page
  ///
  /// In en, this message translates to:
  /// **'Player controls'**
  String get settingsGroupPlayerControls;

  /// Settings row that opens the Playback page
  ///
  /// In en, this message translates to:
  /// **'Playback'**
  String get settingsPlaybackTitle;

  /// Second line of the Playback row, summarising what's inside
  ///
  /// In en, this message translates to:
  /// **'Start over, picture-in-picture, player controls'**
  String get settingsPlaybackSubtitle;

  /// TV only: Settings row that opens the page about what happens when the app starts
  ///
  /// In en, this message translates to:
  /// **'Start-up'**
  String get settingsStartupTitle;

  /// Second line of the Start-up row (TV only)
  ///
  /// In en, this message translates to:
  /// **'Open the last channel, start on boot or wake'**
  String get settingsStartupSubtitle;

  /// Settings row that opens channel list options
  ///
  /// In en, this message translates to:
  /// **'Channel Lists'**
  String get settingsChannelListsTitle;

  /// Second line of the Channel Lists row
  ///
  /// In en, this message translates to:
  /// **'Sorting, hidden channels, which rows to show'**
  String get settingsChannelListsSubtitle;

  /// TV only: Settings row for the TV guide layout options
  ///
  /// In en, this message translates to:
  /// **'TV Guide Layout'**
  String get settingsGuideLayoutTitle;

  /// Second line of the TV Guide Layout row
  ///
  /// In en, this message translates to:
  /// **'Names, two-line titles, highlight'**
  String get settingsGuideLayoutSubtitle;

  /// Toggle: when opening a show that already began, ask whether to watch from the start. Also the tooltip title
  ///
  /// In en, this message translates to:
  /// **'Ask to Start Over'**
  String get settingsAskStartOverTitle;

  /// Info tooltip body for the Ask to Start Over toggle
  ///
  /// In en, this message translates to:
  /// **'On channels that keep recordings (catch-up), asks whether to start the show from the beginning or watch it live when you open a show that is already underway. Turn this off to always go straight to live.'**
  String get settingsAskStartOverBody;

  /// Toggle for Android's small floating video window. Also the tooltip title
  ///
  /// In en, this message translates to:
  /// **'Picture-in-Picture'**
  String get settingsPipTitle;

  /// Info tooltip body. 'Home' is the Android Home button
  ///
  /// In en, this message translates to:
  /// **'When enabled, pressing Home while a video is playing shrinks it into a small floating window so you can keep watching while using other apps.'**
  String get settingsPipBody;

  /// Toggle for the Now Playing notification. Also the tooltip title
  ///
  /// In en, this message translates to:
  /// **'Media Notification'**
  String get settingsMediaNotificationTitle;

  /// Info tooltip body
  ///
  /// In en, this message translates to:
  /// **'Shows a \"Now Playing\" notification with play/pause controls while content is playing, so you can control playback from the notification shade or lock screen.'**
  String get settingsMediaNotificationBody;

  /// Choice: how many seconds the skip forward/back buttons jump. Also the dialog title
  ///
  /// In en, this message translates to:
  /// **'Skip Buttons'**
  String get settingsSkipButtonsTitle;

  /// Option label in a choice list, e.g. '10 seconds'
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 second} other{{count} seconds}}'**
  String settingsSecondsChoice(int count);

  /// Choice: seconds of inactivity before the player's on-screen controls hide. Value shown below is e.g. '4 seconds'
  ///
  /// In en, this message translates to:
  /// **'Hide Player Controls After'**
  String get settingsHideControlsTitle;

  /// TV remote: which remote keys jump forward/back while watching
  ///
  /// In en, this message translates to:
  /// **'Remote Seek Keys'**
  String get settingsSeekKeysTitle;

  /// Option label for the seek keys choice
  ///
  /// In en, this message translates to:
  /// **'Left / Right arrows'**
  String get settingsSeekKeysLeftRight;

  /// Option label for the seek keys choice
  ///
  /// In en, this message translates to:
  /// **'Up / Down arrows'**
  String get settingsSeekKeysUpDown;

  /// Option label: the dedicated media keys on a remote
  ///
  /// In en, this message translates to:
  /// **'Rewind / Forward keys'**
  String get settingsSeekKeysMedia;

  /// Toggle row title
  ///
  /// In en, this message translates to:
  /// **'Open Last Channel on Start'**
  String get settingsLastChannelTitle;

  /// Info tooltip title for the toggle above
  ///
  /// In en, this message translates to:
  /// **'Last Channel on Start'**
  String get settingsLastChannelTooltipTitle;

  /// Info tooltip body. 'Live TV' is the name of the Live TV tab; keep it matching
  ///
  /// In en, this message translates to:
  /// **'When the app opens, it goes straight to the live channel you watched last. Turn this off to land on Live TV instead.'**
  String get settingsLastChannelBody;

  /// TV only toggle: open the app when the TV starts. Also the tooltip title
  ///
  /// In en, this message translates to:
  /// **'Start on Boot'**
  String get settingsStartOnBootTitle;

  /// Info tooltip body. "Display over other apps" is an Android system permission name: use the wording Android shows in Spanish
  ///
  /// In en, this message translates to:
  /// **'Opens OpenIPTV by itself when the TV starts. Android needs \"Display over other apps\" allowed for OpenIPTV; you will be asked.'**
  String get settingsStartOnBootBody;

  /// TV only toggle: open the app when the TV wakes from sleep. Also the tooltip title
  ///
  /// In en, this message translates to:
  /// **'Start on Wake'**
  String get settingsStartOnWakeTitle;

  /// Info tooltip body
  ///
  /// In en, this message translates to:
  /// **'Opens OpenIPTV by itself when the TV wakes from sleep. Android needs \"Display over other apps\" allowed for OpenIPTV; you will be asked.'**
  String get settingsStartOnWakeBody;

  /// Dialog title. Matches the Android permission name
  ///
  /// In en, this message translates to:
  /// **'Allow Display Over Other Apps'**
  String get settingsOverlayDialogTitle;

  /// Dialog body explaining the Android permission
  ///
  /// In en, this message translates to:
  /// **'Android only lets OpenIPTV open itself when the TV starts or wakes if \"Display over other apps\" is allowed for it. Open that screen now and switch it on for OpenIPTV.'**
  String get settingsOverlayDialogBody;

  /// Dialog button that opens the Android system settings screen
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get settingsOverlayOpenSettings;

  /// Info tooltip body for the accent colour setting
  ///
  /// In en, this message translates to:
  /// **'Changes the highlight color used throughout the app — active buttons, selected items, progress bars, and other indicators. Pick whichever color you like best.'**
  String get settingsAccentColorBody;

  /// Accent colour name
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get settingsAccentBlue;

  /// Accent colour name
  ///
  /// In en, this message translates to:
  /// **'Purple'**
  String get settingsAccentPurple;

  /// Accent colour name
  ///
  /// In en, this message translates to:
  /// **'Pink'**
  String get settingsAccentPink;

  /// Accent colour name
  ///
  /// In en, this message translates to:
  /// **'Orange'**
  String get settingsAccentOrange;

  /// Accent colour name
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get settingsAccentGreen;

  /// Accent colour name (blue-green)
  ///
  /// In en, this message translates to:
  /// **'Teal'**
  String get settingsAccentTeal;

  /// Shown when the colour is not one of the presets (e.g. restored from a backup)
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get settingsAccentCustom;

  /// Choice setting for app text size. Also the dialog title
  ///
  /// In en, this message translates to:
  /// **'Text Size'**
  String get settingsTextSizeTitle;

  /// Text size option
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get settingsTextSizeSmall;

  /// Text size option (the normal size)
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get settingsTextSizeDefault;

  /// Text size option
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get settingsTextSizeLarge;

  /// Text size option
  ///
  /// In en, this message translates to:
  /// **'Extra large'**
  String get settingsTextSizeExtraLarge;

  /// Choice setting: how see-through the player's control panels are
  ///
  /// In en, this message translates to:
  /// **'Player Transparency'**
  String get settingsPlayerTransparencyTitle;

  /// Transparency option: not see-through
  ///
  /// In en, this message translates to:
  /// **'Solid'**
  String get settingsPlayerTransparencySolid;

  /// Transparency option (the normal amount; feminine because it agrees with 'transparencia')
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get settingsPlayerTransparencyDefault;

  /// Transparency option
  ///
  /// In en, this message translates to:
  /// **'See-through'**
  String get settingsPlayerTransparencyClear;

  /// Transparency option
  ///
  /// In en, this message translates to:
  /// **'Very see-through'**
  String get settingsPlayerTransparencyVeryClear;

  /// Toggle: tidy channel/movie names sent by the provider. Also the tooltip title
  ///
  /// In en, this message translates to:
  /// **'Clean Up Names'**
  String get settingsCleanNamesTitle;

  /// Info tooltip body. The quoted tags are literal examples of provider tags; do not translate them
  ///
  /// In en, this message translates to:
  /// **'Tidies the names your provider sends — removes tags like \"|EN|\", \"US|\" or \"A+ -\" and turns ALL-CAPS names into normal capitalization. Turn off to see names exactly as your provider sends them.'**
  String get settingsCleanNamesBody;

  /// Error when the chosen file is not a playlist
  ///
  /// In en, this message translates to:
  /// **'This file isn\'t a playlist. Choose an .m3u or .m3u8 file from your provider.'**
  String get errorPlaylistNotM3u;

  /// Error when the playlist file has no channels
  ///
  /// In en, this message translates to:
  /// **'This playlist file doesn\'t have any channels in it.'**
  String get errorPlaylistEmpty;

  /// Error when a stored playlist file has disappeared
  ///
  /// In en, this message translates to:
  /// **'The playlist file is no longer on this device. Remove this playlist and add the file again.'**
  String get errorPlaylistFileMissing;

  /// Error when Xtream login fails while editing a playlist
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t sign in with these details. Check the server address, username and password with your provider.'**
  String get errorXtreamLogin;

  /// Error when the M3U link field is empty while editing a playlist
  ///
  /// In en, this message translates to:
  /// **'Enter the playlist link from your provider.'**
  String get errorM3uMissing;

  /// Error when the new playlist link cannot be opened
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open this playlist link. Check it with your provider.'**
  String get errorLinkOpenFailed;

  /// Error on timeout while loading a playlist
  ///
  /// In en, this message translates to:
  /// **'This playlist is taking too long to load. Check your internet connection and try again.'**
  String get errorPlaylistTimeout;

  /// Error for HTTP 401/403 while loading a playlist
  ///
  /// In en, this message translates to:
  /// **'Your username or password doesn\'t seem right. Check with your provider.'**
  String get errorBadCredentials;

  /// Error when the server cannot be reached (network or DNS failure)
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach this server. Check your internet connection and try again.'**
  String get errorUnreachable;

  /// Error for HTTP 5xx from the provider
  ///
  /// In en, this message translates to:
  /// **'The provider\'s server is having trouble right now. Try again later.'**
  String get errorProviderServer;

  /// Error for other HTTP failures, usually a wrong link
  ///
  /// In en, this message translates to:
  /// **'This link doesn\'t look like a valid channel list. Check the URL with your provider.'**
  String get errorInvalidLink;

  /// Catch-all error for playlist problems
  ///
  /// In en, this message translates to:
  /// **'That didn\'t work. Check your details and try again.'**
  String get errorGeneric;

  /// Error on timeout while loading a TV guide
  ///
  /// In en, this message translates to:
  /// **'The TV guide is taking too long to load. Check your internet connection and try again.'**
  String get errorGuideTimeout;

  /// Error when the guide file contains no programmes
  ///
  /// In en, this message translates to:
  /// **'The provider sent an empty TV guide. Your current guide was kept — try again in a few minutes.'**
  String get errorGuideEmpty;

  /// Error for HTTP 401/403 while loading a guide
  ///
  /// In en, this message translates to:
  /// **'The TV guide link needs a login. Check the guide URL with your provider.'**
  String get errorGuideLogin;

  /// Error when the guide server cannot be reached
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach the TV guide server for this playlist. It may not have a guide — check the guide URL with your provider.'**
  String get errorGuideUnreachable;

  /// Error for HTTP 5xx from the guide server
  ///
  /// In en, this message translates to:
  /// **'The TV guide server is having trouble right now. Try again later.'**
  String get errorGuideServer;

  /// Error for other HTTP failures while loading a guide
  ///
  /// In en, this message translates to:
  /// **'This TV guide link doesn\'t look valid. Check the URL with your provider.'**
  String get errorGuideInvalidLink;

  /// Catch-all error for guide problems
  ///
  /// In en, this message translates to:
  /// **'The TV guide couldn\'t be loaded. Check your details and try again.'**
  String get errorGuideGeneric;

  /// Title of the app language setting, its picker and the button on the welcome page
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageTitle;

  /// Picker choice: use the device language and follow it if it changes
  ///
  /// In en, this message translates to:
  /// **'Auto-detect from system'**
  String get languageAuto;

  /// Value shown while the language is on automatic; {language} is the language it resolved to, written in that language
  ///
  /// In en, this message translates to:
  /// **'Auto — {language}'**
  String languageAutoNow(String language);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
