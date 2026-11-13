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

  /// Headline of the final page when the user gave no name (used instead of wizardAllSetHeadline)
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

  /// Label above the accent color swatches on the wizard's name page
  ///
  /// In en, this message translates to:
  /// **'Accent Color'**
  String get wizardAccentColor;

  /// Title of the one-time dialog asking permission to send anonymous crash reports
  ///
  /// In en, this message translates to:
  /// **'Help improve OpenIPTV?'**
  String get consentTitle;

  /// Body of the anonymous crash report consent dialog. Privacy wording is deliberate: keep every promise (never sends playlists, logins, links, channel names or viewing). 'Settings' is the app's Settings tab
  ///
  /// In en, this message translates to:
  /// **'OpenIPTV can send an anonymous report when the app crashes or freezes. A report holds the app version, your device model and where in the code the problem happened. It never holds your playlists, logins, links, channel names or what you watch, and it can\'t be tied to you.\n\nThis is off unless you turn it on. You can change your mind any time in Settings, where you can also see exactly what is sent. The code that does this is small and open on GitHub if you want to check it.'**
  String get consentBody;

  /// Dialog button that declines anonymous crash reports; focused first on TV so a stray OK press never opts in
  ///
  /// In en, this message translates to:
  /// **'No Thanks'**
  String get consentNoThanks;

  /// Dialog button that turns on anonymous crash reports
  ///
  /// In en, this message translates to:
  /// **'Turn On'**
  String get consentTurnOn;

  /// Default title of the load-failure placeholder shown with a retry button
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load this'**
  String get errorStateTitle;

  /// Default label of the retry button on the load-failure placeholder
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get errorStateTryAgain;

  /// Default confirm button of the PIN entry dialog
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get pinUnlock;

  /// Snackbar after a wrong PIN was typed
  ///
  /// In en, this message translates to:
  /// **'Incorrect PIN'**
  String get pinIncorrect;

  /// PIN dialog title for a parental-locked category. {name} is the category name as shown to the user
  ///
  /// In en, this message translates to:
  /// **'Enter admin PIN to unlock \"{name}\"'**
  String pinEnterAdminToUnlock(String name);

  /// Short line under the fingerprint / face prompt when unlocking a locked category. {name} is the category name
  ///
  /// In en, this message translates to:
  /// **'Unlock \"{name}\"'**
  String pinUnlockAction(String name);

  /// Line under the fingerprint / face prompt when switching into the admin profile. {name} is the profile name
  ///
  /// In en, this message translates to:
  /// **'Switch to {name}'**
  String pinSwitchToProfile(String name);

  /// PIN dialog title when choosing a profile that has a PIN. {name} is the profile name
  ///
  /// In en, this message translates to:
  /// **'Enter PIN for {name}'**
  String pinEnterForProfile(String name);

  /// Error text on the profile picker when profiles fail to load
  ///
  /// In en, this message translates to:
  /// **'Could not load profiles.'**
  String get profilePickerLoadFailed;

  /// Heading of the profile picker screen
  ///
  /// In en, this message translates to:
  /// **'Who\'s watching?'**
  String get profilePickerWhoIsWatching;

  /// Small label under a profile that is a kids profile
  ///
  /// In en, this message translates to:
  /// **'Kids'**
  String get profilePickerKids;

  /// Settings group heading: profile and parental controls
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsGroupAccount;

  /// Settings group heading: playlists, auto-refresh, TV guides, backup
  ///
  /// In en, this message translates to:
  /// **'Playlists & Guides'**
  String get settingsGroupPlaylistsGuides;

  /// Settings group heading: app info, updates, power tools
  ///
  /// In en, this message translates to:
  /// **'About & Advanced'**
  String get settingsGroupAboutAdvanced;

  /// Settings row, dialog title and info tooltip title for app updates
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get settingsUpdatesTitle;

  /// Info tooltip body for the updates row
  ///
  /// In en, this message translates to:
  /// **'Looks for a newer version of OpenIPTV on GitHub and, if there is one, shows what changed and installs it. Only the public release page is contacted — nothing about you or your device is sent. Choose whether this also happens every time the app starts.'**
  String get settingsUpdatesBody;

  /// Updates row subtitle when the app checks for updates by itself
  ///
  /// In en, this message translates to:
  /// **'Checks automatically'**
  String get settingsUpdatesAutoOn;

  /// Updates row subtitle when updates are only checked on request
  ///
  /// In en, this message translates to:
  /// **'Manual only'**
  String get settingsUpdatesManual;

  /// Switch in the updates dialog
  ///
  /// In en, this message translates to:
  /// **'Check Automatically'**
  String get settingsUpdatesCheckAuto;

  /// Button that closes the updates dialog
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get settingsUpdatesClose;

  /// Button that checks for an app update immediately
  ///
  /// In en, this message translates to:
  /// **'Check Now'**
  String get settingsUpdatesCheckNow;

  /// Settings row and tooltip title for the profile (fallback when no profile name is available)
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get settingsProfileTitle;

  /// Info tooltip body for the profile row
  ///
  /// In en, this message translates to:
  /// **'OpenIPTV supports multiple profiles on one device. Each profile has its own watch history, favorites, hidden categories, and PIN lock. Select to manage profiles.'**
  String get settingsProfileBody;

  /// Profile row subtitle when no profile is active
  ///
  /// In en, this message translates to:
  /// **'No profile selected'**
  String get settingsProfileNone;

  /// Profile row subtitle: the kind of the active profile (admin, kids or standard), then a hint that tapping manages profiles
  ///
  /// In en, this message translates to:
  /// **'{kind, select, admin{Admin} kids{Kids profile} other{Standard profile}} · Manage profiles'**
  String settingsProfileSubtitle(String kind);

  /// Settings row and tooltip title
  ///
  /// In en, this message translates to:
  /// **'Switch Profile'**
  String get settingsSwitchProfileTitle;

  /// Info tooltip body for the switch-profile row
  ///
  /// In en, this message translates to:
  /// **'Quickly change the active profile without going into profile management. Useful when sharing a device with family or roommates.'**
  String get settingsSwitchProfileBody;

  /// Subtitle of the switch-profile row
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 profile available} other{{count} profiles available}}'**
  String settingsProfilesAvailable(int count);

  /// Settings row and tooltip title
  ///
  /// In en, this message translates to:
  /// **'Parental Controls'**
  String get settingsParentalTitle;

  /// Info tooltip body for parental controls
  ///
  /// In en, this message translates to:
  /// **'Hide adult categories and lock any category you choose behind an admin PIN. Locked categories stay unlocked until the app is restarted.'**
  String get settingsParentalBody;

  /// Parental controls row subtitle
  ///
  /// In en, this message translates to:
  /// **'PIN-protect adult and locked categories'**
  String get settingsParentalSubtitle;

  /// Settings row, tooltip title and sheet title for the user's playlists
  ///
  /// In en, this message translates to:
  /// **'Playlists'**
  String get settingsPlaylistsTitle;

  /// Info tooltip body for the playlists row
  ///
  /// In en, this message translates to:
  /// **'A playlist is your provider connection — either an M3U playlist URL or Xtream Codes credentials. Playlists supply your channels, movies, and series. You can add multiple playlists and refresh them here.'**
  String get settingsPlaylistsBody;

  /// Playlists row subtitle when there are none
  ///
  /// In en, this message translates to:
  /// **'No playlists added'**
  String get settingsPlaylistsNone;

  /// Playlists row subtitle with the number of playlists
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 playlist} other{{count} playlists}}'**
  String settingsPlaylistsCount(int count);

  /// Settings row and tooltip title
  ///
  /// In en, this message translates to:
  /// **'Backup & Restore'**
  String get settingsBackupTitle;

  /// Info tooltip body for backup
  ///
  /// In en, this message translates to:
  /// **'Export your profiles and playlists to a single .zip file you can store anywhere. Restore it later to move to a new device or recover from a reset. Stream credentials are included — keep the file safe.'**
  String get settingsBackupBody;

  /// Backup row subtitle
  ///
  /// In en, this message translates to:
  /// **'Export or import your profile and playlists'**
  String get settingsBackupSubtitle;

  /// Settings row, tooltip title and dialog title
  ///
  /// In en, this message translates to:
  /// **'Auto-Refresh'**
  String get settingsAutoRefreshTitle;

  /// Info tooltip body for auto-refresh
  ///
  /// In en, this message translates to:
  /// **'Automatically refreshes your playlists and TV guide in the background so channels and schedules stay current without manual refreshing.'**
  String get settingsAutoRefreshBody;

  /// Auto-refresh interval option, e.g. Every 6 hours (always 2, 6, 12 or 24)
  ///
  /// In en, this message translates to:
  /// **'Every {hours} hours'**
  String settingsAutoRefreshEvery(int hours);

  /// Auto-refresh option meaning no automatic refresh
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get settingsAutoRefreshOff;

  /// Auto-refresh row subtitle: the interval text, then a note that a notification is sent
  ///
  /// In en, this message translates to:
  /// **'{interval} · notifies when done'**
  String settingsAutoRefreshNotifies(String interval);

  /// Switch in the auto-refresh dialog
  ///
  /// In en, this message translates to:
  /// **'Notify when done'**
  String get settingsAutoRefreshNotifyTitle;

  /// Title of a dialog asking for notification permission
  ///
  /// In en, this message translates to:
  /// **'Stay Informed'**
  String get settingsStayInformedTitle;

  /// Body of the notification permission rationale dialog
  ///
  /// In en, this message translates to:
  /// **'Allow notifications so OpenIPTV can let you know when a background refresh finishes or runs into a problem?'**
  String get settingsStayInformedBody;

  /// Confirm button of the notification permission dialog
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get settingsAllow;

  /// Title of the battery optimisation rationale dialog
  ///
  /// In en, this message translates to:
  /// **'Reliable Background Refresh'**
  String get settingsReliableRefreshTitle;

  /// Body of the battery optimisation rationale dialog
  ///
  /// In en, this message translates to:
  /// **'Some phones aggressively limit background apps to save battery, which can delay auto-refresh. Exempting OpenIPTV from battery optimization makes refreshes more reliable.'**
  String get settingsReliableRefreshBody;

  /// Confirm button of the battery optimisation dialog
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get settingsContinue;

  /// Settings row and tooltip title
  ///
  /// In en, this message translates to:
  /// **'Guide Data'**
  String get settingsGuideDataTitle;

  /// Info tooltip body for guide data
  ///
  /// In en, this message translates to:
  /// **'Choose how many days of TV guide are kept, whether programme descriptions are stored, see when each playlist\'s guide last updated, and clear it.'**
  String get settingsGuideDataBody;

  /// Guide data row subtitle
  ///
  /// In en, this message translates to:
  /// **'How much TV guide is stored'**
  String get settingsGuideDataSubtitle;

  /// Settings row and tooltip title
  ///
  /// In en, this message translates to:
  /// **'Extra Guides'**
  String get settingsExtraGuidesTitle;

  /// Info tooltip body for extra guides
  ///
  /// In en, this message translates to:
  /// **'Add TV guide files for channels your playlist has no guide for. OpenIPTV matches them by name, and you can pick a guide for any channel yourself.'**
  String get settingsExtraGuidesBody;

  /// Extra guides row subtitle
  ///
  /// In en, this message translates to:
  /// **'Fill in channels that have no guide'**
  String get settingsExtraGuidesSubtitle;

  /// Settings row, tooltip and dialog title
  ///
  /// In en, this message translates to:
  /// **'Content Sort Order'**
  String get settingsSortOrderTitle;

  /// Info tooltip body for the sort order setting. The option names it mentions must match settingsSortProvider and settingsSortAz
  ///
  /// In en, this message translates to:
  /// **'Controls how channels, movies, and series are listed. Provider order shows them in the sequence your IPTV provider sends them. A–Z sorts them alphabetically.'**
  String get settingsSortOrderBody;

  /// Sort option: keep the order the provider sends
  ///
  /// In en, this message translates to:
  /// **'Provider order'**
  String get settingsSortProvider;

  /// Sort option: alphabetical
  ///
  /// In en, this message translates to:
  /// **'A–Z'**
  String get settingsSortAz;

  /// Settings row, tooltip and sheet title
  ///
  /// In en, this message translates to:
  /// **'Hidden Categories'**
  String get settingsHiddenCategoriesTitle;

  /// Info tooltip body for hidden categories
  ///
  /// In en, this message translates to:
  /// **'Categories you\'ve hidden won\'t appear in your channel list. Your channels are still there — they\'re just out of the way. You can unhide them here at any time.'**
  String get settingsHiddenCategoriesBody;

  /// Empty state of the hidden categories sheet
  ///
  /// In en, this message translates to:
  /// **'No categories are hidden.'**
  String get settingsHiddenCategoriesNone;

  /// Settings row
  ///
  /// In en, this message translates to:
  /// **'Reset Category Names and Order'**
  String get settingsResetCategoriesTitle;

  /// Confirmation dialog title
  ///
  /// In en, this message translates to:
  /// **'Reset Category Names and Order?'**
  String get settingsResetCategoriesDialogTitle;

  /// Confirmation dialog body
  ///
  /// In en, this message translates to:
  /// **'Live TV categories go back to the names and order your playlist gives them. Hidden categories stay hidden.'**
  String get settingsResetCategoriesDialogBody;

  /// Confirm button of the reset dialog
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get settingsReset;

  /// Settings row, tooltip and sheet title
  ///
  /// In en, this message translates to:
  /// **'Hidden Channels'**
  String get settingsHiddenChannelsTitle;

  /// Info tooltip body for hidden channels
  ///
  /// In en, this message translates to:
  /// **'Channels you hid (hold OK or long-press a channel → Hide Channel) are kept out of Live TV, the guide and search for this profile. Bring them back here.'**
  String get settingsHiddenChannelsBody;

  /// Hidden channels row subtitle when no channel is hidden
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get settingsHiddenChannelsNone;

  /// Hidden channels row subtitle with a count
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hidden} other{{count} hidden}}'**
  String settingsHiddenChannelsCount(int count);

  /// Empty state of the hidden channels sheet
  ///
  /// In en, this message translates to:
  /// **'No channels are hidden.'**
  String get settingsHiddenChannelsEmpty;

  /// Name shown for a hidden channel whose playlist no longer exists
  ///
  /// In en, this message translates to:
  /// **'Channel from a removed playlist'**
  String get settingsChannelFromRemovedPlaylist;

  /// Button that unhides one category or channel
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get settingsShow;

  /// Button that unhides all hidden channels
  ///
  /// In en, this message translates to:
  /// **'Show All'**
  String get settingsShowAll;

  /// Name of the built-in all-channels category
  ///
  /// In en, this message translates to:
  /// **'All Channels'**
  String get settingsAllChannels;

  /// Switch: show the Favorites category in Live TV
  ///
  /// In en, this message translates to:
  /// **'Show Favorites'**
  String get settingsShowFavorites;

  /// Switch: show the Recently Watched category in Live TV
  ///
  /// In en, this message translates to:
  /// **'Show Recently Watched'**
  String get settingsShowRecent;

  /// Switch: show the All Channels category in Live TV
  ///
  /// In en, this message translates to:
  /// **'Show All Channels'**
  String get settingsShowAllChannels;

  /// Switch in TV guide layout
  ///
  /// In en, this message translates to:
  /// **'Guide: Show Channel Names'**
  String get settingsGuideShowNames;

  /// Switch in TV guide layout
  ///
  /// In en, this message translates to:
  /// **'Guide: Two-Line Channel Names'**
  String get settingsGuideTwoLineNames;

  /// Switch in TV guide layout
  ///
  /// In en, this message translates to:
  /// **'Guide: Two-Line Programme Titles'**
  String get settingsGuideTwoLineTitles;

  /// Switch in TV guide layout
  ///
  /// In en, this message translates to:
  /// **'Guide: Highlight the Playing Channel'**
  String get settingsGuideHighlightPlaying;

  /// Settings row, tooltip and dialog title
  ///
  /// In en, this message translates to:
  /// **'About OpenIPTV'**
  String get settingsAboutTitle;

  /// Info tooltip body for About
  ///
  /// In en, this message translates to:
  /// **'Shows the current app version and license information. OpenIPTV is open-source under the GPL-3.0 license — no ads, no telemetry, no accounts. Ever.'**
  String get settingsAboutBody;

  /// About row subtitle with the version number
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String settingsAboutVersion(String version);

  /// Copyright line in the About dialog
  ///
  /// In en, this message translates to:
  /// **'© 2026 OpenIPTV contributors. Licensed under GPL-3.0.'**
  String get settingsAboutLegalese;

  /// Description paragraph in the About dialog
  ///
  /// In en, this message translates to:
  /// **'An open-source, ad-free, cross-platform IPTV client. No accounts required. No telemetry. No ads. Ever.'**
  String get settingsAboutDescription;

  /// Settings row and tooltip title
  ///
  /// In en, this message translates to:
  /// **'Power User Tools'**
  String get settingsPowerToolsTitle;

  /// Info tooltip body for power user tools
  ///
  /// In en, this message translates to:
  /// **'Tools for checking and tuning your connection: your device and public IP addresses, connection type, VPN and DNS — handy when a provider has trouble reaching you.'**
  String get settingsPowerToolsBody;

  /// Power user tools row subtitle
  ///
  /// In en, this message translates to:
  /// **'Network info for troubleshooting'**
  String get settingsPowerToolsSubtitle;

  /// Settings row and tooltip title
  ///
  /// In en, this message translates to:
  /// **'Anonymous Reports'**
  String get settingsAnonReportsTitle;

  /// Info tooltip body for anonymous reports
  ///
  /// In en, this message translates to:
  /// **'Optionally send an anonymous report when the app crashes or freezes, so problems get fixed faster. Off unless you turn it on, and you can see exactly what is sent.'**
  String get settingsAnonReportsBody;

  /// Value shown for a setting that is on
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get settingsOn;

  /// Value shown for a setting that is off
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get settingsOff;

  /// Snackbar after a playlist refresh; name is the user's playlist name
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" playlist refreshed.'**
  String settingsPlaylistRefreshed(String name);

  /// Snackbar; error is an already-translated friendly message
  ///
  /// In en, this message translates to:
  /// **'Playlist refresh failed: {error}'**
  String settingsPlaylistRefreshFailed(String error);

  /// Snackbar after a TV guide refresh
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" TV guide refreshed.'**
  String settingsGuideRefreshed(String name);

  /// Confirmation dialog title
  ///
  /// In en, this message translates to:
  /// **'Switch Playlist?'**
  String get settingsSwitchPlaylistTitle;

  /// Confirmation dialog body for browsing all playlists
  ///
  /// In en, this message translates to:
  /// **'Show all playlists together?\n\nThe channel list, movies, and series will include every playlist.'**
  String get settingsSwitchToAllBody;

  /// Confirmation dialog body for browsing one playlist
  ///
  /// In en, this message translates to:
  /// **'Switch to \"{name}\"?\n\nThe channel list, movies, and series will update to show only this playlist.'**
  String settingsSwitchToOneBody(String name);

  /// Confirm button of the switch playlist dialog
  ///
  /// In en, this message translates to:
  /// **'Switch'**
  String get settingsSwitch;

  /// Confirmation dialog title
  ///
  /// In en, this message translates to:
  /// **'Remove Playlist?'**
  String get settingsRemovePlaylistTitle;

  /// Confirmation dialog body
  ///
  /// In en, this message translates to:
  /// **'This will remove \"{name}\" and all its channels, movies, and series. This cannot be undone.'**
  String settingsRemovePlaylistBody(String name);

  /// Destructive confirm button
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get settingsRemove;

  /// Progress text while a playlist is being removed
  ///
  /// In en, this message translates to:
  /// **'Removing \"{name}\"...'**
  String settingsRemovingPlaylist(String name);

  /// Button at the top of the playlists sheet
  ///
  /// In en, this message translates to:
  /// **'Add Playlist'**
  String get settingsAddPlaylist;

  /// Hint under the playlists sheet title when there are several playlists
  ///
  /// In en, this message translates to:
  /// **'Choose which playlist to browse, or show them all together.'**
  String get settingsChoosePlaylistHint;

  /// Error state of the playlists sheet
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load playlists.'**
  String get settingsPlaylistsLoadError;

  /// Empty state of the playlists sheet
  ///
  /// In en, this message translates to:
  /// **'No playlists yet.'**
  String get settingsPlaylistsEmpty;

  /// Row that browses every playlist together
  ///
  /// In en, this message translates to:
  /// **'All playlists'**
  String get settingsAllPlaylists;

  /// Subtitle of the All playlists row
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 playlist combined} other{{count} playlists combined}}'**
  String settingsPlaylistsCombined(int count);

  /// Playlist type: a file stored on the device
  ///
  /// In en, this message translates to:
  /// **'Playlist file'**
  String get settingsSourceFile;

  /// Playlist type: an M3U link
  ///
  /// In en, this message translates to:
  /// **'M3U playlist'**
  String get settingsSourceM3u;

  /// Marks the playlist currently being browsed; appears after the playlist type in a subtitle
  ///
  /// In en, this message translates to:
  /// **'Browsing'**
  String get settingsBrowsing;

  /// Tooltip of the refresh button on a playlist row
  ///
  /// In en, this message translates to:
  /// **'Refresh Playlist'**
  String get settingsRefreshPlaylistTooltip;

  /// Tooltip of the three-dot menu button
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get settingsMoreTooltip;

  /// Menu item
  ///
  /// In en, this message translates to:
  /// **'Edit Playlist'**
  String get settingsEditPlaylist;

  /// Menu item
  ///
  /// In en, this message translates to:
  /// **'Playlist Info'**
  String get settingsPlaylistInfo;

  /// Menu item
  ///
  /// In en, this message translates to:
  /// **'Refresh TV Guide'**
  String get settingsRefreshTvGuide;

  /// Error in the playlist info sheet
  ///
  /// In en, this message translates to:
  /// **'Could not fetch server info.'**
  String get settingsInfoFetchError;

  /// Label in the playlist info sheet
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get settingsInfoSource;

  /// Value in the playlist info sheet
  ///
  /// In en, this message translates to:
  /// **'File saved on this device'**
  String get settingsInfoFileSaved;

  /// Label in the playlist info sheet: link of the TV guide (EPG) file
  ///
  /// In en, this message translates to:
  /// **'EPG URL'**
  String get settingsInfoGuideUrl;

  /// Label in the playlist info sheet
  ///
  /// In en, this message translates to:
  /// **'Last refreshed'**
  String get settingsInfoLastRefreshed;

  /// Value for a playlist that was never refreshed
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get settingsInfoNever;

  /// Label in the playlist info sheet (account status)
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get settingsInfoStatus;

  /// Label in the playlist info sheet (account expiry date)
  ///
  /// In en, this message translates to:
  /// **'Expires'**
  String get settingsInfoExpires;

  /// Label in the playlist info sheet
  ///
  /// In en, this message translates to:
  /// **'Active connections'**
  String get settingsInfoActiveConnections;

  /// Label in the playlist info sheet
  ///
  /// In en, this message translates to:
  /// **'Max connections'**
  String get settingsInfoMaxConnections;

  /// Label in the playlist info sheet: whether the account is a trial
  ///
  /// In en, this message translates to:
  /// **'Trial'**
  String get settingsInfoTrial;

  /// Value in the playlist info sheet
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get settingsInfoYes;

  /// Value in the playlist info sheet
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get settingsInfoNo;

  /// Label in the playlist info sheet
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get settingsInfoServer;

  /// Label in the playlist info sheet
  ///
  /// In en, this message translates to:
  /// **'Timezone'**
  String get settingsInfoTimezone;

  /// Tooltip of the sort button when sorted alphabetically
  ///
  /// In en, this message translates to:
  /// **'Sorted A–Z'**
  String get browseActionsSortedAz;

  /// Tooltip of the sort button when in the provider's order
  ///
  /// In en, this message translates to:
  /// **'Provider order'**
  String get browseActionsProviderOrder;

  /// Tooltip of the view toggle
  ///
  /// In en, this message translates to:
  /// **'Switch to list view'**
  String get browseActionsSwitchToList;

  /// Tooltip of the view toggle
  ///
  /// In en, this message translates to:
  /// **'Switch to grid view'**
  String get browseActionsSwitchToGrid;

  /// Tooltip of the Movies/Series layout toggle
  ///
  /// In en, this message translates to:
  /// **'Switch to compact view'**
  String get browseActionsSwitchToCompact;

  /// Tooltip of the Movies/Series layout toggle
  ///
  /// In en, this message translates to:
  /// **'Switch to poster view'**
  String get browseActionsSwitchToPosters;

  /// Name of the playback buffer preset that starts quickly (Power User Tools)
  ///
  /// In en, this message translates to:
  /// **'Fast start'**
  String get bufferPresetFastLabel;

  /// Explains the Fast start buffer preset
  ///
  /// In en, this message translates to:
  /// **'Starts quickly and resumes right after a short hiccup. Best on a good connection.'**
  String get bufferPresetFastDescription;

  /// Name of the middle playback buffer preset
  ///
  /// In en, this message translates to:
  /// **'Balanced'**
  String get bufferPresetBalancedLabel;

  /// Explains the Balanced buffer preset
  ///
  /// In en, this message translates to:
  /// **'Waits a little longer before starting, for fewer interruptions on an average connection.'**
  String get bufferPresetBalancedDescription;

  /// Name of the playback buffer preset with the biggest reserve
  ///
  /// In en, this message translates to:
  /// **'Smooth'**
  String get bufferPresetSmoothLabel;

  /// Explains the Smooth buffer preset
  ///
  /// In en, this message translates to:
  /// **'Keeps a bigger reserve so playback rides out an unsteady connection. Slower to start and to change channels.'**
  String get bufferPresetSmoothDescription;

  /// Graphics mode option: the app decides
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get graphicsModeAutomaticLabel;

  /// Explains the Automatic graphics mode
  ///
  /// In en, this message translates to:
  /// **'Uses the compatible mode only on TVs known to need it. Recommended.'**
  String get graphicsModeAutomaticDescription;

  /// Graphics mode option: the newest drawing method
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get graphicsModeStandardLabel;

  /// Explains the Standard graphics mode
  ///
  /// In en, this message translates to:
  /// **'The newest drawing method. Best on most phones and TVs.'**
  String get graphicsModeStandardDescription;

  /// Graphics mode option: an older, steadier drawing method
  ///
  /// In en, this message translates to:
  /// **'Compatible'**
  String get graphicsModeCompatibleLabel;

  /// Explains the Compatible graphics mode; "torn" means a horizontal tear line across the picture
  ///
  /// In en, this message translates to:
  /// **'An older, steadier drawing method. Try this if the picture looks torn (a line across it) or jittery, mostly on fast motion.'**
  String get graphicsModeCompatibleDescription;

  /// Video layer option: the app decides
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get videoLayerAutomaticLabel;

  /// Explains the Automatic video layer option
  ///
  /// In en, this message translates to:
  /// **'Shows the picture the way TV players do, for smoother video and faster, cleaner switching. Recommended.'**
  String get videoLayerAutomaticDescription;

  /// Video layer option: always on
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get videoLayerOnLabel;

  /// Explains the On video layer option. "it" is the video layer (feminine in Spanish)
  ///
  /// In en, this message translates to:
  /// **'Always use it on this TV.'**
  String get videoLayerOnDescription;

  /// Video layer option: off
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get videoLayerOffLabel;

  /// Explains the Off video layer option
  ///
  /// In en, this message translates to:
  /// **'Draw the picture inside the app, as before. Try this if the picture is ever missing or wrong.'**
  String get videoLayerOffDescription;

  /// Verdict after a speed test of 25 Mbit/s or more. Follows "{speed} Mbit/s — "
  ///
  /// In en, this message translates to:
  /// **'Plenty, even for 4K.'**
  String get speedTestVerdictPlenty;

  /// Speed test verdict, 10 Mbit/s or more
  ///
  /// In en, this message translates to:
  /// **'Good for HD and most 4K.'**
  String get speedTestVerdictGood;

  /// Speed test verdict, 5 Mbit/s or more
  ///
  /// In en, this message translates to:
  /// **'Fine for HD; 4K may buffer.'**
  String get speedTestVerdictFineHd;

  /// Speed test verdict, 2.5 Mbit/s or more
  ///
  /// In en, this message translates to:
  /// **'Enough for SD; HD may buffer.'**
  String get speedTestVerdictEnoughSd;

  /// Speed test verdict for a slow connection
  ///
  /// In en, this message translates to:
  /// **'Too slow for smooth playback.'**
  String get speedTestVerdictTooSlow;

  /// Error when the chosen file is not a WireGuard profile
  ///
  /// In en, this message translates to:
  /// **'This isn\'t a WireGuard profile.'**
  String get vpnNotWireGuardProfile;

  /// Error when a VPN profile is invalid. {detail} is a short technical reason in English, not translated
  ///
  /// In en, this message translates to:
  /// **'This profile has a problem ({detail}).'**
  String vpnProfileProblem(String detail);

  /// Error when the device cannot run a VPN
  ///
  /// In en, this message translates to:
  /// **'VPN is not available on this device.'**
  String get vpnNotAvailable;

  /// Error when the chosen file is not an OpenVPN profile
  ///
  /// In en, this message translates to:
  /// **'This isn\'t an OpenVPN profile.'**
  String get vpnNotOpenVpnProfile;

  /// Error for an OpenVPN profile that relies on a certificate in the Android keystore
  ///
  /// In en, this message translates to:
  /// **'This profile needs a certificate stored on the device, which OpenIPTV doesn\'t support.'**
  String get vpnNeedsDeviceCertificate;

  /// Error when a VPN profile file cannot be read
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read this profile.'**
  String get vpnCouldntReadProfile;

  /// Snackbar when the VPN is up
  ///
  /// In en, this message translates to:
  /// **'VPN connected'**
  String get vpnConnected;

  /// Snackbar while the VPN is starting
  ///
  /// In en, this message translates to:
  /// **'Connecting the VPN…'**
  String get vpnConnecting;

  /// Snackbar when Android refused the VPN permission prompt. "Connect" is the button label powerUserConnect
  ///
  /// In en, this message translates to:
  /// **'OpenIPTV needs your permission to set up a VPN. Select Connect and allow it.'**
  String get vpnNeedsPermission;

  /// Snackbar when the VPN profile is invalid
  ///
  /// In en, this message translates to:
  /// **'This profile has a problem. Import it again.'**
  String get vpnBadConfig;

  /// Snackbar when connecting the VPN failed
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t connect the VPN. Check the profile and try again.'**
  String get vpnConnectFailed;

  /// Summary after refreshing everything with no failures
  ///
  /// In en, this message translates to:
  /// **'Everything is up to date.'**
  String get refreshAllSummaryEverything;

  /// Summary after refreshing playlists with no failures
  ///
  /// In en, this message translates to:
  /// **'All playlists are up to date.'**
  String get refreshAllSummaryPlaylists;

  /// Summary after refreshing TV guides with no failures
  ///
  /// In en, this message translates to:
  /// **'All TV guides are up to date.'**
  String get refreshAllSummaryGuides;

  /// One failed playlist in the summary. {name} is the playlist name, {message} a plain-language error
  ///
  /// In en, this message translates to:
  /// **'{name}: {message}'**
  String refreshAllProblem(String name, String message);

  /// Summary when the only playlist failed. {problems} is the error text
  ///
  /// In en, this message translates to:
  /// **'{problems}.'**
  String refreshAllSummaryFailedOne(String problems);

  /// Summary when some of several playlists failed. {problems} lists each failure separated by semicolons
  ///
  /// In en, this message translates to:
  /// **'{ok} of {total} updated. {problems}.'**
  String refreshAllSummaryFailedMany(int ok, int total, String problems);

  /// Progress line while a playlist is refreshing. {name} is the playlist name
  ///
  /// In en, this message translates to:
  /// **'Updating {name}… ({done} of {total})'**
  String refreshAllUpdating(String name, int done, int total);

  /// Progress line while a playlist's TV guide is refreshing
  ///
  /// In en, this message translates to:
  /// **'Updating {name}\'s TV guide… ({done} of {total})'**
  String refreshAllUpdatingGuide(String name, int done, int total);

  /// Progress line while the extra TV guides added by the user are refreshing
  ///
  /// In en, this message translates to:
  /// **'Updating extra guides… ({done} of {total})'**
  String refreshAllUpdatingExtraGuides(int done, int total);

  /// Settings row title
  ///
  /// In en, this message translates to:
  /// **'Refresh Everything'**
  String get refreshAllEverythingTitle;

  /// Settings row subtitle
  ///
  /// In en, this message translates to:
  /// **'Channels, movies, series and TV guides for every playlist'**
  String get refreshAllEverythingHint;

  /// Settings row title
  ///
  /// In en, this message translates to:
  /// **'Refresh Playlists'**
  String get refreshAllPlaylistsTitle;

  /// Settings row subtitle
  ///
  /// In en, this message translates to:
  /// **'Channels, movies and series only'**
  String get refreshAllPlaylistsHint;

  /// Settings row title
  ///
  /// In en, this message translates to:
  /// **'Refresh TV Guides'**
  String get refreshAllGuidesTitle;

  /// Settings row subtitle
  ///
  /// In en, this message translates to:
  /// **'What\'s on now and next, for every playlist'**
  String get refreshAllGuidesHint;

  /// Option in the Refresh dialog
  ///
  /// In en, this message translates to:
  /// **'Everything'**
  String get refreshAllChoiceEverything;

  /// Option in the Refresh dialog
  ///
  /// In en, this message translates to:
  /// **'Playlists only'**
  String get refreshAllChoicePlaylists;

  /// Subtitle of the playlists-only option in the Refresh dialog
  ///
  /// In en, this message translates to:
  /// **'Channels, movies and series'**
  String get refreshAllChoicePlaylistsHint;

  /// Option in the Refresh dialog
  ///
  /// In en, this message translates to:
  /// **'TV guides only'**
  String get refreshAllChoiceGuides;

  /// Title of the dialog that asks what to refresh
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refreshAllDialogTitle;

  /// Settings row title
  ///
  /// In en, this message translates to:
  /// **'Refresh Now'**
  String get refreshAllNowTitle;

  /// Settings row subtitle when idle
  ///
  /// In en, this message translates to:
  /// **'Update your playlists and TV guides now'**
  String get refreshAllNowIdle;

  /// Subtitle after a refresh: clock time of the run, then its summary
  ///
  /// In en, this message translates to:
  /// **'{time} · {summary}'**
  String refreshAllLastRun(String time, String summary);

  /// Screen title
  ///
  /// In en, this message translates to:
  /// **'Edit Playlist'**
  String get editPlaylistTitle;

  /// Field label: the playlist's friendly name
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get editPlaylistName;

  /// Field label for the Xtream server address
  ///
  /// In en, this message translates to:
  /// **'Server address'**
  String get editPlaylistServerAddress;

  /// Field label and hint for the playlist login username
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get editPlaylistUsername;

  /// Field label for the playlist login password
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get editPlaylistPassword;

  /// Hint inside the password field
  ///
  /// In en, this message translates to:
  /// **'Leave empty to keep the current password'**
  String get editPlaylistPasswordHint;

  /// Tooltip of the eye button
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get editPlaylistShowPassword;

  /// Tooltip of the eye button
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get editPlaylistHidePassword;

  /// Field label for an M3U playlist URL
  ///
  /// In en, this message translates to:
  /// **'Playlist link'**
  String get editPlaylistLink;

  /// Field label for the XMLTV guide URL
  ///
  /// In en, this message translates to:
  /// **'TV guide address (optional)'**
  String get editPlaylistGuideAddress;

  /// Hint in the guide field for Xtream playlists
  ///
  /// In en, this message translates to:
  /// **'Automatic — from your provider'**
  String get editPlaylistGuideAutoProvider;

  /// Hint in the guide field for M3U playlists
  ///
  /// In en, this message translates to:
  /// **'Automatic — from the playlist'**
  String get editPlaylistGuideAutoPlaylist;

  /// Note shown for playlists loaded from a device file
  ///
  /// In en, this message translates to:
  /// **'This playlist is a file on your device. To use a different file, add it as a new playlist.'**
  String get editPlaylistFileNote;

  /// Reassurance under the form
  ///
  /// In en, this message translates to:
  /// **'Your login is stored encrypted on this device.'**
  String get editPlaylistLoginStored;

  /// Save button
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get editPlaylistSave;

  /// Progress text while the new details are validated
  ///
  /// In en, this message translates to:
  /// **'Checking your details…'**
  String get editPlaylistChecking;

  /// Progress text while the playlist refreshes after saving
  ///
  /// In en, this message translates to:
  /// **'Saved. Updating channels and movies…'**
  String get editPlaylistUpdating;

  /// Snackbar after saving. {name} is the playlist name
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" saved.'**
  String editPlaylistSaved(String name);

  /// Snackbar after saving and a successful refresh
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" saved and updated.'**
  String editPlaylistSavedUpdated(String name);

  /// Snackbar after saving when the refresh had problems. {summary} is a plain-language sentence
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" saved. {summary}'**
  String editPlaylistSavedWithSummary(String name, String summary);

  /// Heading of the live stream format choice
  ///
  /// In en, this message translates to:
  /// **'Live stream format'**
  String get editPlaylistLiveFormat;

  /// Note under the live stream format heading
  ///
  /// In en, this message translates to:
  /// **'Changing this updates the playlist\'s channels.'**
  String get editPlaylistLiveFormatNote;

  /// Live stream format option
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get editPlaylistFormatAutoLabel;

  /// Explains the Automatic live format. TS is a technical term
  ///
  /// In en, this message translates to:
  /// **'Follows what your provider allows, usually TS'**
  String get editPlaylistFormatAutoDescription;

  /// Explains the TS live format
  ///
  /// In en, this message translates to:
  /// **'Transport stream: fast to start, works with most providers'**
  String get editPlaylistFormatTsDescription;

  /// Explains the HLS live format
  ///
  /// In en, this message translates to:
  /// **'Adaptive playlist: for providers whose TS streams drop'**
  String get editPlaylistFormatHlsDescription;

  /// Screen title
  ///
  /// In en, this message translates to:
  /// **'Parental Controls'**
  String get parentalTitle;

  /// Shown to non-admin profiles
  ///
  /// In en, this message translates to:
  /// **'Admins only.'**
  String get parentalAdminsOnly;

  /// Settings group heading
  ///
  /// In en, this message translates to:
  /// **'Protection'**
  String get parentalProtectionGroup;

  /// Switch title
  ///
  /// In en, this message translates to:
  /// **'Parental Protection'**
  String get parentalProtectionTitle;

  /// Switch subtitle when on
  ///
  /// In en, this message translates to:
  /// **'Adult and locked categories require an admin PIN'**
  String get parentalProtectionOn;

  /// Switch subtitle when off
  ///
  /// In en, this message translates to:
  /// **'Off — all content is visible'**
  String get parentalProtectionOff;

  /// Settings group heading
  ///
  /// In en, this message translates to:
  /// **'Locked Categories'**
  String get parentalLockedGroup;

  /// Description under the Locked Categories heading
  ///
  /// In en, this message translates to:
  /// **'Adult content is locked automatically. Categories below were added by the playlist scan.'**
  String get parentalLockedDescription;

  /// Empty state
  ///
  /// In en, this message translates to:
  /// **'No other locked categories'**
  String get parentalNoLocked;

  /// Tooltip of the delete button on a locked category
  ///
  /// In en, this message translates to:
  /// **'Remove from locked list'**
  String get parentalRemoveTooltip;

  /// Settings row title and dialog title for the Android Auto video add-on
  ///
  /// In en, this message translates to:
  /// **'Video in the Car'**
  String get carVideoTitle;

  /// Row subtitle when the add-on is not installed
  ///
  /// In en, this message translates to:
  /// **'Watch on the car screen while parked'**
  String get carVideoSubtitleMissing;

  /// Row subtitle when the add-on can be updated
  ///
  /// In en, this message translates to:
  /// **'Update available for the add-on'**
  String get carVideoSubtitleOutdated;

  /// Row subtitle when the add-on is installed
  ///
  /// In en, this message translates to:
  /// **'Add-on installed'**
  String get carVideoSubtitleInstalled;

  /// Line inside the info dialog when the add-on is missing
  ///
  /// In en, this message translates to:
  /// **'This needs a small add-on app, OpenIPTV Video (about 1 MB).'**
  String get carVideoInfoMissing;

  /// Line inside the info dialog when the add-on is installed
  ///
  /// In en, this message translates to:
  /// **'The add-on is installed.'**
  String get carVideoInfoInstalled;

  /// Line inside the info dialog when the add-on is outdated
  ///
  /// In en, this message translates to:
  /// **'A newer version of the add-on is available.'**
  String get carVideoInfoOutdated;

  /// Body of the car video info dialog. {addonLine} is one of carVideoInfoMissing / carVideoInfoInstalled / carVideoInfoOutdated. "Video" is the label of the second app icon in the car; "Unknown sources" is an Android Auto developer setting name
  ///
  /// In en, this message translates to:
  /// **'Watch on your car\'s screen with Android Auto while parked. Android Auto closes the picture when you start driving; the sound keeps playing.\n\nHow to watch: pick a channel, movie or episode in OpenIPTV on the car screen, then open Video — the second OpenIPTV icon.\n\n{addonLine}\n\nIf it doesn\'t show up in the car: in the Android Auto app on your phone, turn on developer settings and \"Unknown sources\".'**
  String carVideoInfo(String addonLine);

  /// Dialog body asking for the install-apps permission. "Allow from this source" is an Android system switch
  ///
  /// In en, this message translates to:
  /// **'To install the add-on, OpenIPTV needs permission to install apps.\n\nSelect Open Settings, turn on \"Allow from this source\", then come back here — the install will continue automatically.'**
  String get carVideoNeedsPermission;

  /// Download progress before the percentage is known
  ///
  /// In en, this message translates to:
  /// **'Downloading…'**
  String get carVideoDownloading;

  /// Download progress with a percentage
  ///
  /// In en, this message translates to:
  /// **'Downloading… {percent}%'**
  String carVideoDownloadingPercent(int percent);

  /// Dialog body after handing the APK to the system installer
  ///
  /// In en, this message translates to:
  /// **'Follow the prompts on screen to finish installing.\n\nIf nothing appeared, or you cancelled, select Install again.'**
  String get carVideoHandedOff;

  /// Dialog body when no add-on file exists
  ///
  /// In en, this message translates to:
  /// **'The add-on isn\'t available to download yet. It comes with the next OpenIPTV release.'**
  String get carVideoUnavailable;

  /// Dialog body when the download failed
  ///
  /// In en, this message translates to:
  /// **'The add-on couldn\'t be downloaded. Check your internet connection and try again.'**
  String get carVideoFailed;

  /// Dialog button
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get carVideoDone;

  /// Dialog button to update the add-on
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get carVideoUpdate;

  /// Dialog button to install the add-on
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get carVideoInstall;

  /// Dialog button that opens the Android install-permission screen
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get carVideoOpenSettings;

  /// Dialog button
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get carVideoClose;

  /// Dialog button
  ///
  /// In en, this message translates to:
  /// **'Install again'**
  String get carVideoInstallAgain;

  /// Dialog button
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get carVideoTryAgain;

  /// Screen title
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// Error state
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load profile.'**
  String get profileLoadFailed;

  /// Empty state
  ///
  /// In en, this message translates to:
  /// **'No active profile.'**
  String get profileNoActive;

  /// Subtitle of the Kids Profile switch for an admin
  ///
  /// In en, this message translates to:
  /// **'Admin accounts can\'t be marked as kid accounts'**
  String get profileKidsAdminBlocked;

  /// Subtitle of the Kids Profile switch when on
  ///
  /// In en, this message translates to:
  /// **'Adult content will be hidden'**
  String get profileAdultHidden;

  /// Subtitle of the Kids Profile switch when off
  ///
  /// In en, this message translates to:
  /// **'All content is visible'**
  String get profileAllVisible;

  /// Settings group heading
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get profileAccountGroup;

  /// Switch title and tooltip title
  ///
  /// In en, this message translates to:
  /// **'Kids Profile'**
  String get profileKidsProfile;

  /// Info tooltip body. Live, Movies and Series are the app tab names
  ///
  /// In en, this message translates to:
  /// **'When turned on, this profile is marked as a Kids profile and adult content is automatically hidden from Live, Movies, and Series. Requires Parental Protection to be enabled.'**
  String get profileKidsTooltipBody;

  /// Settings group heading
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get profileSecurityGroup;

  /// Row title
  ///
  /// In en, this message translates to:
  /// **'PIN Lock'**
  String get profilePinLock;

  /// Row subtitle when a PIN exists
  ///
  /// In en, this message translates to:
  /// **'PIN is set — select to change or remove'**
  String get profilePinIsSet;

  /// Row subtitle when no PIN exists
  ///
  /// In en, this message translates to:
  /// **'No PIN — select to set one'**
  String get profilePinNotSet;

  /// Settings group heading (admin only)
  ///
  /// In en, this message translates to:
  /// **'All Profiles'**
  String get profileAllProfilesGroup;

  /// Row title
  ///
  /// In en, this message translates to:
  /// **'Add Profile'**
  String get profileAddProfile;

  /// Prompt of the admin PIN dialog
  ///
  /// In en, this message translates to:
  /// **'Enter admin PIN to disable Kids Profile'**
  String get profileEnterPinToDisableKids;

  /// Dialog title
  ///
  /// In en, this message translates to:
  /// **'Delete Profile?'**
  String get profileDeleteTitle;

  /// Dialog body. {name} is the profile name. "sources" means playlists
  ///
  /// In en, this message translates to:
  /// **'Deleting \"{name}\" will remove all its favourites and settings. Your sources and channels are not affected.'**
  String profileDeleteBody(String name);

  /// Delete button / menu item
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get profileDelete;

  /// Dialog title
  ///
  /// In en, this message translates to:
  /// **'Parental Protection Required'**
  String get profileProtectionRequiredTitle;

  /// Dialog body
  ///
  /// In en, this message translates to:
  /// **'Kid profiles require Parental Protection to be turned on, so adult content can be hidden automatically. Enable it now?'**
  String get profileProtectionRequiredBody;

  /// Dialog button
  ///
  /// In en, this message translates to:
  /// **'Enable Protection'**
  String get profileEnableProtection;

  /// Badge on the current profile
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get profileActive;

  /// Small badge on a kids profile
  ///
  /// In en, this message translates to:
  /// **'Kids'**
  String get profileKidsBadge;

  /// Small badge on a profile that has a PIN
  ///
  /// In en, this message translates to:
  /// **'PIN'**
  String get profilePinBadge;

  /// Popup menu item
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get profileMenuEdit;

  /// Dialog title
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get profileEditTitle;

  /// Label above the name field
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get profileNameLabel;

  /// Label above the avatar picker
  ///
  /// In en, this message translates to:
  /// **'Avatar'**
  String get profileAvatarLabel;

  /// Validation error
  ///
  /// In en, this message translates to:
  /// **'Enter a name.'**
  String get profileEnterName;

  /// Error in the edit dialog
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save changes.'**
  String get profileSaveFailed;

  /// Dialog button
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get profileSave;

  /// Dialog title
  ///
  /// In en, this message translates to:
  /// **'New Profile'**
  String get profileNewTitle;

  /// Hint in the new profile name field
  ///
  /// In en, this message translates to:
  /// **'e.g. Kids, Living Room'**
  String get profileNameHint;

  /// Switch title in the new profile dialog
  ///
  /// In en, this message translates to:
  /// **'Is Kid Account'**
  String get profileIsKidAccount;

  /// Dialog button
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get profileCreate;

  /// Error in the new profile dialog
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t create profile.'**
  String get profileCreateFailed;

  /// PIN dialog error
  ///
  /// In en, this message translates to:
  /// **'PINs don\'t match.'**
  String get profilePinsDontMatch;

  /// PIN dialog error
  ///
  /// In en, this message translates to:
  /// **'PIN must be at least 4 digits.'**
  String get profilePinTooShort;

  /// PIN dialog error
  ///
  /// In en, this message translates to:
  /// **'Current PIN is incorrect.'**
  String get profileCurrentPinIncorrect;

  /// PIN dialog title when a PIN exists
  ///
  /// In en, this message translates to:
  /// **'Change PIN'**
  String get profileChangePinTitle;

  /// PIN dialog title when no PIN exists
  ///
  /// In en, this message translates to:
  /// **'Set PIN'**
  String get profileSetPinTitle;

  /// Label and hint of the current PIN field
  ///
  /// In en, this message translates to:
  /// **'Current PIN'**
  String get profileCurrentPin;

  /// Label above the new PIN field
  ///
  /// In en, this message translates to:
  /// **'New PIN'**
  String get profileNewPin;

  /// Hint inside the new PIN field
  ///
  /// In en, this message translates to:
  /// **'4–8 digits'**
  String get profilePinDigitsHint;

  /// Label above the confirm PIN field
  ///
  /// In en, this message translates to:
  /// **'Confirm PIN'**
  String get profileConfirmPin;

  /// Hint inside the confirm PIN field
  ///
  /// In en, this message translates to:
  /// **'Repeat new PIN'**
  String get profileRepeatNewPin;

  /// Destructive dialog button
  ///
  /// In en, this message translates to:
  /// **'Remove PIN'**
  String get profileRemovePin;

  /// Title of the admin PIN prompt
  ///
  /// In en, this message translates to:
  /// **'Enter admin PIN'**
  String get profileEnterAdminPin;

  /// Message under the admin PIN prompt
  ///
  /// In en, this message translates to:
  /// **'To turn on fingerprint and face unlock'**
  String get profileBiometricPinMessage;

  /// Confirm button of the admin PIN prompt
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get profileContinue;

  /// Snackbar
  ///
  /// In en, this message translates to:
  /// **'Incorrect PIN'**
  String get profileIncorrectPin;

  /// Snackbar
  ///
  /// In en, this message translates to:
  /// **'Fingerprint and face unlock is on'**
  String get profileBiometricOn;

  /// Snackbar
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t turn on fingerprint and face unlock on this device.'**
  String get profileBiometricFailed;

  /// Switch title and tooltip title
  ///
  /// In en, this message translates to:
  /// **'Unlock with Fingerprint or Face'**
  String get profileBiometricTitle;

  /// Info tooltip body
  ///
  /// In en, this message translates to:
  /// **'Use your fingerprint or face wherever the admin PIN is asked for on this device. Anyone whose fingerprint or face is set up on this device can use it, so only turn it on if that is just you. Adding a new fingerprint or face turns it off until you turn it on again. Other profiles still use their own PINs.'**
  String get profileBiometricBody;

  /// Switch subtitle when a PIN exists
  ///
  /// In en, this message translates to:
  /// **'Use it instead of typing the admin PIN'**
  String get profileBiometricSubtitleOn;

  /// Switch subtitle when no PIN exists
  ///
  /// In en, this message translates to:
  /// **'Set a PIN first'**
  String get profileBiometricSubtitleNeedsPin;

  /// Screen title
  ///
  /// In en, this message translates to:
  /// **'Power User Tools'**
  String get powerUserTitle;

  /// Tooltip of the refresh button
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get powerUserRefreshTooltip;

  /// Value of a state or an option
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get powerUserOn;

  /// Value of a state or an option
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get powerUserOff;

  /// Used in "In use now: Yes."
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get powerUserYes;

  /// Used in "In use now: No."
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get powerUserNo;

  /// Option label
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get powerUserAutomatic;

  /// Line in a description. {mode} is the active mode name or Yes/No
  ///
  /// In en, this message translates to:
  /// **'In use now: {mode}.'**
  String powerUserInUseNow(String mode);

  /// Group heading
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get powerUserNetworkTitle;

  /// Description of the Network group on TV
  ///
  /// In en, this message translates to:
  /// **'How this device is connected right now. Useful when a provider has trouble reaching you — for example to check which address it sees, or that your VPN is on.'**
  String get powerUserNetworkDescription;

  /// Description of the Network group on phones (adds the copy hint)
  ///
  /// In en, this message translates to:
  /// **'How this device is connected right now. Useful when a provider has trouble reaching you — for example to check which address it sees, or that your VPN is on. Tap an address to copy it.'**
  String get powerUserNetworkDescriptionCopy;

  /// Placeholder while network info loads
  ///
  /// In en, this message translates to:
  /// **'Checking your connection…'**
  String get powerUserCheckingConnection;

  /// Row label
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get powerUserConnection;

  /// Row label
  ///
  /// In en, this message translates to:
  /// **'Device IP address'**
  String get powerUserDeviceIp;

  /// Row value
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get powerUserNotAvailable;

  /// Row label for the address on the VPN tunnel
  ///
  /// In en, this message translates to:
  /// **'VPN address'**
  String get powerUserVpnAddress;

  /// Row label
  ///
  /// In en, this message translates to:
  /// **'DNS servers'**
  String get powerUserDnsServers;

  /// Snackbar after copying a value. {label} is the row label such as "Device IP address"
  ///
  /// In en, this message translates to:
  /// **'{label} copied'**
  String powerUserCopied(String label);

  /// Row label
  ///
  /// In en, this message translates to:
  /// **'Public IP address'**
  String get powerUserPublicIp;

  /// Row value while the public address is being looked up
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get powerUserChecking;

  /// Row value when the lookup failed
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t check right now. Try again.'**
  String get powerUserCheckFailed;

  /// Row value before checking. {service} is a web address of an outside service
  ///
  /// In en, this message translates to:
  /// **'The address your provider sees. Checking asks {service}.'**
  String powerUserPublicIpIdle(String service);

  /// Button
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get powerUserCheck;

  /// Button
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get powerUserCheckAgain;

  /// Description of the VPN group
  ///
  /// In en, this message translates to:
  /// **'A built-in VPN — WireGuard or OpenVPN. Handy when your internet provider blocks or slows down your IPTV provider. One connects at a time.'**
  String get powerUserVpnDescription;

  /// Row value when no WireGuard profile exists
  ///
  /// In en, this message translates to:
  /// **'Import a WireGuard profile (.conf file) from your VPN provider.'**
  String get powerUserWgImportHint;

  /// Row value when no OpenVPN profile exists
  ///
  /// In en, this message translates to:
  /// **'Import an OpenVPN profile (.ovpn file) from your VPN provider.'**
  String get powerUserOvpnImportHint;

  /// Row value for a disconnected profile. {name} is the profile name, {where} is " · server:port" or empty
  ///
  /// In en, this message translates to:
  /// **'Off — {name}{where}'**
  String powerUserVpnStateOff(String name, String where);

  /// Row value for a connected WireGuard profile. {rx}/{tx} are data amounts such as 1.5 MB, {ago} is handshakeWaiting or handshakeAnswered
  ///
  /// In en, this message translates to:
  /// **'Connected — {name}{where}\n↓ {rx}  ↑ {tx} · {ago}'**
  String powerUserWgConnected(
      String name, String where, String rx, String tx, String ago);

  /// Fragment of the WireGuard status line
  ///
  /// In en, this message translates to:
  /// **'waiting for the server to answer'**
  String get powerUserHandshakeWaiting;

  /// Fragment of the WireGuard status line. {when} is justNow / secondsAgo / minutesAgo
  ///
  /// In en, this message translates to:
  /// **'server answered {when}'**
  String powerUserHandshakeAnswered(String when);

  /// Fragment: time since the VPN server answered
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get powerUserJustNow;

  /// Fragment: time since the VPN server answered
  ///
  /// In en, this message translates to:
  /// **'{seconds}s ago'**
  String powerUserSecondsAgo(int seconds);

  /// Fragment: time since the VPN server answered
  ///
  /// In en, this message translates to:
  /// **'{minutes} min ago'**
  String powerUserMinutesAgo(int minutes);

  /// Row value for a connected OpenVPN profile
  ///
  /// In en, this message translates to:
  /// **'Connected — {name}{where}\n↓ {rx}  ↑ {tx}'**
  String powerUserOvpnConnected(
      String name, String where, String rx, String tx);

  /// Row value while OpenVPN connects
  ///
  /// In en, this message translates to:
  /// **'Connecting — {name}{where}'**
  String powerUserOvpnConnecting(String name, String where);

  /// Row value when OpenVPN failed
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t connect — {name}{where}'**
  String powerUserOvpnError(String name, String where);

  /// Button
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get powerUserImport;

  /// Button
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get powerUserDisconnect;

  /// Button
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get powerUserConnect;

  /// VPN route option
  ///
  /// In en, this message translates to:
  /// **'Only OpenIPTV'**
  String get powerUserRouteApp;

  /// Explains the Only OpenIPTV route
  ///
  /// In en, this message translates to:
  /// **'Other apps keep your normal connection'**
  String get powerUserRouteAppHint;

  /// VPN route option
  ///
  /// In en, this message translates to:
  /// **'Whole device'**
  String get powerUserRouteDevice;

  /// Explains the Whole device route
  ///
  /// In en, this message translates to:
  /// **'Every app uses the VPN, except Android Auto\'s car link'**
  String get powerUserRouteDeviceHint;

  /// Snackbar after changing the route while connected
  ///
  /// In en, this message translates to:
  /// **'Reconnect the VPN to apply this.'**
  String get powerUserReconnectToApply;

  /// Switch title
  ///
  /// In en, this message translates to:
  /// **'Connect when OpenIPTV opens'**
  String get powerUserAutoConnect;

  /// Switch subtitle
  ///
  /// In en, this message translates to:
  /// **'Uses the VPN you connected last'**
  String get powerUserAutoConnectHint;

  /// Row title
  ///
  /// In en, this message translates to:
  /// **'Remove WireGuard profile'**
  String get powerUserRemoveWireGuard;

  /// Row title
  ///
  /// In en, this message translates to:
  /// **'Change OpenVPN login'**
  String get powerUserChangeOvpnLogin;

  /// Row subtitle. {user} is the VPN username
  ///
  /// In en, this message translates to:
  /// **'Signed in as {user}'**
  String powerUserSignedInAs(String user);

  /// Row title
  ///
  /// In en, this message translates to:
  /// **'Remove OpenVPN profile'**
  String get powerUserRemoveOpenVpn;

  /// Title of the file picker
  ///
  /// In en, this message translates to:
  /// **'Choose an OpenVPN profile'**
  String get powerUserPickOvpn;

  /// Title of the file picker
  ///
  /// In en, this message translates to:
  /// **'Choose a WireGuard profile'**
  String get powerUserPickWireGuard;

  /// Snackbar after importing a VPN profile
  ///
  /// In en, this message translates to:
  /// **'Profile \"{name}\" added'**
  String powerUserProfileAdded(String name);

  /// Dialog title
  ///
  /// In en, this message translates to:
  /// **'VPN login'**
  String get powerUserVpnLoginTitle;

  /// Dialog body
  ///
  /// In en, this message translates to:
  /// **'This profile needs the username and password from your VPN provider. They are stored encrypted on this device.'**
  String get powerUserVpnLoginBody;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get powerUserUsername;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get powerUserPassword;

  /// Dialog button
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get powerUserSave;

  /// Snackbar
  ///
  /// In en, this message translates to:
  /// **'VPN login saved'**
  String get powerUserVpnLoginSaved;

  /// Dialog title
  ///
  /// In en, this message translates to:
  /// **'Remove VPN profile?'**
  String get powerUserRemoveTitle;

  /// Dialog body
  ///
  /// In en, this message translates to:
  /// **'The VPN disconnects and the profile is deleted from this device. You can import it again later.'**
  String get powerUserRemoveBody;

  /// Dialog button
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get powerUserRemove;

  /// Snackbar. The quoted name is the row title powerUserChangeOvpnLogin
  ///
  /// In en, this message translates to:
  /// **'The VPN server rejected the username or password. Use \"Change OpenVPN login\" to fix it.'**
  String get powerUserOvpnAuthFailed;

  /// Snackbar
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach the VPN server. Check the profile and your connection.'**
  String get powerUserOvpnUnreachable;

  /// Snackbar
  ///
  /// In en, this message translates to:
  /// **'The VPN couldn\'t connect. Check the profile and try again.'**
  String get powerUserOvpnConnectFailed;

  /// Group heading
  ///
  /// In en, this message translates to:
  /// **'Speed test'**
  String get powerUserSpeedTitle;

  /// Group description
  ///
  /// In en, this message translates to:
  /// **'Measures how fast video arrives. The provider test uses one connection to your provider — if your plan allows only one at a time, stop watching on other devices first.'**
  String get powerUserSpeedDescription;

  /// Row label
  ///
  /// In en, this message translates to:
  /// **'Speed to your provider'**
  String get powerUserSpeedProviderLabel;

  /// Row value before running
  ///
  /// In en, this message translates to:
  /// **'Downloads from the playlist you are browsing for a few seconds.'**
  String get powerUserSpeedProviderIdle;

  /// Row label
  ///
  /// In en, this message translates to:
  /// **'General internet speed'**
  String get powerUserSpeedInternetLabel;

  /// Row value before running. {host} is a web host name
  ///
  /// In en, this message translates to:
  /// **'Downloads a test file from {host}.'**
  String powerUserSpeedInternetIdle(String host);

  /// Row value while the test is starting
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get powerUserSpeedConnecting;

  /// Row value while the test runs. {mbps} is a number such as 12.3
  ///
  /// In en, this message translates to:
  /// **'Testing… {mbps} Mbit/s'**
  String powerUserSpeedTesting(String mbps);

  /// Row value with the result. {verdict} is a speedTestVerdict sentence
  ///
  /// In en, this message translates to:
  /// **'{mbps} Mbit/s — {verdict}\nResponse time {ms} ms'**
  String powerUserSpeedResult(String mbps, String verdict, int ms);

  /// Extra note under a speed result measured on a live channel
  ///
  /// In en, this message translates to:
  /// **'Measured on a live channel, which arrives at playback speed — this shows it keeps up, not your top speed.'**
  String get powerUserSpeedPacedNote;

  /// Row value (error)
  ///
  /// In en, this message translates to:
  /// **'This playlist has nothing to test with yet.'**
  String get powerUserSpeedNothingToTest;

  /// Row value (error)
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t download from your provider. It may be busy, or your plan may allow only one connection at a time.'**
  String get powerUserSpeedProviderFailed;

  /// Row value (error)
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t run the test. Check your connection and try again.'**
  String get powerUserSpeedInternetFailed;

  /// Button that starts a speed test
  ///
  /// In en, this message translates to:
  /// **'Run'**
  String get powerUserRun;

  /// Button that repeats a speed test
  ///
  /// In en, this message translates to:
  /// **'Run again'**
  String get powerUserRunAgain;

  /// Group heading
  ///
  /// In en, this message translates to:
  /// **'Database'**
  String get powerUserDbTitle;

  /// Group description
  ///
  /// In en, this message translates to:
  /// **'The database holds your playlists, logins and watch history, and is encrypted on the device. Turning encryption off can make very slow TVs faster.'**
  String get powerUserDbDescription;

  /// Switch title
  ///
  /// In en, this message translates to:
  /// **'Skip Database Encryption'**
  String get powerUserDbSkipTitle;

  /// Dialog title
  ///
  /// In en, this message translates to:
  /// **'Skip Database Encryption?'**
  String get powerUserDbSkipQuestion;

  /// Dialog title
  ///
  /// In en, this message translates to:
  /// **'Turn Database Encryption back on?'**
  String get powerUserDbTurnOnQuestion;

  /// Dialog body
  ///
  /// In en, this message translates to:
  /// **'This will store your database (including playlist credentials and stream links) unencrypted on disk. Anyone with access to the device can read it. The app must be restarted for the change to take effect.'**
  String get powerUserDbSkipBody;

  /// Dialog body
  ///
  /// In en, this message translates to:
  /// **'Your database will be encrypted again, which is safer but can be slower on older TVs. The app will restart to apply it.'**
  String get powerUserDbTurnOnBody;

  /// Dialog button that confirms skipping encryption (the English label is ambiguous; it enables the skip)
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get powerUserDbEnable;

  /// Dialog button that turns encryption back on
  ///
  /// In en, this message translates to:
  /// **'Turn On'**
  String get powerUserDbTurnOn;

  /// Dialog title
  ///
  /// In en, this message translates to:
  /// **'Reopen OpenIPTV to finish'**
  String get powerUserDbReopenTitle;

  /// Dialog body
  ///
  /// In en, this message translates to:
  /// **'The database encryption mode has changed. OpenIPTV will close now. Open it again to apply the change.'**
  String get powerUserDbReopenBody;

  /// Dialog button
  ///
  /// In en, this message translates to:
  /// **'Close OpenIPTV'**
  String get powerUserDbClose;

  /// Group heading
  ///
  /// In en, this message translates to:
  /// **'Playback buffer'**
  String get powerUserBufferTitle;

  /// Group description
  ///
  /// In en, this message translates to:
  /// **'How much video the player keeps in reserve. A bigger reserve rides out a shaky connection but takes longer to start. Applies from the next channel or video you open.'**
  String get powerUserBufferDescription;

  /// Group heading
  ///
  /// In en, this message translates to:
  /// **'Pictures'**
  String get powerUserPicturesTitle;

  /// Group description
  ///
  /// In en, this message translates to:
  /// **'Posters, channel logos and backdrops are shown in full resolution, for the sharpest pictures. Turn this off to show them at about the size they are drawn instead, which uses less memory. Try that if the app ever feels slow or restarts on a TV or phone with little memory. Takes effect straight away; no re-download needed.'**
  String get powerUserPicturesDescription;

  /// Switch title
  ///
  /// In en, this message translates to:
  /// **'Full-Resolution Pictures'**
  String get powerUserFullResTitle;

  /// Group heading
  ///
  /// In en, this message translates to:
  /// **'Match frame rate'**
  String get powerUserFrameRateTitle;

  /// Group description
  ///
  /// In en, this message translates to:
  /// **'Switches your screen to a refresh rate that suits the video (for example 24 Hz for films), so motion looks smoother. Only works if your screen supports it, and some TVs go black for a moment when it switches. The screen goes back to normal when you stop watching.'**
  String get powerUserFrameRateDescription;

  /// Switch title
  ///
  /// In en, this message translates to:
  /// **'Match Frame Rate'**
  String get powerUserFrameRateSwitch;

  /// Group heading
  ///
  /// In en, this message translates to:
  /// **'Surround sound passthrough'**
  String get powerUserPassthroughTitle;

  /// Group description. Multi-view is a feature name (several channels on one screen)
  ///
  /// In en, this message translates to:
  /// **'Sends Dolby and DTS sound untouched to a soundbar, receiver or TV that decodes it. It pauses by itself while Multi-view is on.'**
  String get powerUserPassthroughDescription;

  /// Option description
  ///
  /// In en, this message translates to:
  /// **'Uses it when your sound system says it can. Recommended.'**
  String get powerUserPassthroughAuto;

  /// Option description
  ///
  /// In en, this message translates to:
  /// **'Always send surround sound as it is. Only if a soundbar or receiver can decode it, otherwise you may get no sound.'**
  String get powerUserPassthroughOn;

  /// Option description
  ///
  /// In en, this message translates to:
  /// **'The device always decodes the sound itself. Pick this for built-in TV speakers or if the sound cuts out or crackles.'**
  String get powerUserPassthroughOff;

  /// Group heading
  ///
  /// In en, this message translates to:
  /// **'Tunneled playback'**
  String get powerUserTunnelingTitle;

  /// Group description
  ///
  /// In en, this message translates to:
  /// **'Lets the video and sound chips work together directly, which can ease stutter on demanding streams. It pauses by itself while Multi-view is on.'**
  String get powerUserTunnelingDescription;

  /// Option description
  ///
  /// In en, this message translates to:
  /// **'Used only on devices where it has been checked to work. Recommended.'**
  String get powerUserTunnelingAuto;

  /// Option description
  ///
  /// In en, this message translates to:
  /// **'Experimental, live channels only. If it stalls or shows a black picture, OpenIPTV switches it off by itself; you can also turn it off here.'**
  String get powerUserTunnelingOn;

  /// Option description
  ///
  /// In en, this message translates to:
  /// **'Never used.'**
  String get powerUserTunnelingOff;

  /// Group heading
  ///
  /// In en, this message translates to:
  /// **'Video layer'**
  String get powerUserLayerTitle;

  /// Group description
  ///
  /// In en, this message translates to:
  /// **'Shows the main picture the way TV players do: smoother motion, quicker channel changes, and what tunneled playback needs. Takes effect when the app restarts.'**
  String get powerUserLayerDescription;

  /// Snackbar
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t change the video layer setting.'**
  String get powerUserLayerChangeFailed;

  /// Dialog title
  ///
  /// In en, this message translates to:
  /// **'Restart to apply?'**
  String get powerUserRestartTitle;

  /// Dialog body
  ///
  /// In en, this message translates to:
  /// **'OpenIPTV needs to restart to change how it shows the picture. Anything playing will stop.'**
  String get powerUserRestartLayerBody;

  /// Dialog body
  ///
  /// In en, this message translates to:
  /// **'OpenIPTV needs to restart to change how it draws the screen. Anything playing will stop.'**
  String get powerUserRestartGraphicsBody;

  /// Dialog button
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get powerUserLater;

  /// Dialog button
  ///
  /// In en, this message translates to:
  /// **'Restart now'**
  String get powerUserRestartNow;

  /// Snackbar
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t restart. Close and open OpenIPTV to apply it.'**
  String get powerUserRestartFailed;

  /// Group heading
  ///
  /// In en, this message translates to:
  /// **'Graphics mode'**
  String get powerUserGraphicsTitle;

  /// Group description. "Compatible" is the option graphicsModeCompatibleLabel
  ///
  /// In en, this message translates to:
  /// **'How OpenIPTV draws the screen and the video. If the picture looks torn (a line across it) or jittery on fast motion, try Compatible. Takes effect when the app restarts.'**
  String get powerUserGraphicsDescription;

  /// Line in the description. {chip} is the chip model name, not translated
  ///
  /// In en, this message translates to:
  /// **'This device: {chip}.'**
  String powerUserGraphicsThisDevice(String chip);

  /// Snackbar
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t change the graphics mode.'**
  String get powerUserGraphicsChangeFailed;

  /// Group heading, dialog title and field label. A user agent is the name a program sends to a server to identify itself
  ///
  /// In en, this message translates to:
  /// **'User agent'**
  String get powerUserUaTitle;

  /// Group description
  ///
  /// In en, this message translates to:
  /// **'How the player introduces itself to your provider. OpenIPTV sends its own name, version and device. Change it only if your provider asks for a particular one. Each extra channel in multi-view adds its own tag on the end, so your provider can tell them apart. Applies from the next channel you open.'**
  String get powerUserUaDescription;

  /// Row title
  ///
  /// In en, this message translates to:
  /// **'Player user agent'**
  String get powerUserUaRow;

  /// Row value when no custom user agent is set
  ///
  /// In en, this message translates to:
  /// **'OpenIPTV (default)'**
  String get powerUserUaDefault;

  /// Note in the user agent dialog
  ///
  /// In en, this message translates to:
  /// **'Leave it empty to use OpenIPTV\'s own.'**
  String get powerUserUaEmptyNote;

  /// Example value in the user agent field
  ///
  /// In en, this message translates to:
  /// **'e.g. VLC/3.0.20 LibVLC/3.0.20'**
  String get powerUserUaHint;

  /// Dialog button that clears the custom user agent
  ///
  /// In en, this message translates to:
  /// **'Use default'**
  String get powerUserUseDefault;

  /// App bar title of the Extra Guides settings page (TV guide files the user adds)
  ///
  /// In en, this message translates to:
  /// **'Extra Guides'**
  String get extraGuidesTitle;

  /// Matching mode name (strictest)
  ///
  /// In en, this message translates to:
  /// **'Explicit'**
  String get extraGuidesModeExplicit;

  /// Description of the Explicit matching mode
  ///
  /// In en, this message translates to:
  /// **'Only when the channel\'s guide ID is exactly the same as the guide\'s. Safest; channels without an ID are left alone.'**
  String get extraGuidesModeExplicitDesc;

  /// Matching mode name (default)
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get extraGuidesModeStandard;

  /// Description of the Standard matching mode. Call sign = US station code such as WABC
  ///
  /// In en, this message translates to:
  /// **'The guide ID, or exactly the same channel name. US local stations are matched by call sign.'**
  String get extraGuidesModeStandardDesc;

  /// Matching mode name (loosest)
  ///
  /// In en, this message translates to:
  /// **'Optimistic'**
  String get extraGuidesModeOptimistic;

  /// Description of the Optimistic matching mode. Review Guide Matches is the row extraGuidesReviewMatchesTitle
  ///
  /// In en, this message translates to:
  /// **'Also channels whose names are only alike. Finds more, but some guesses will be wrong; you can fix any in Review Guide Matches.'**
  String get extraGuidesModeOptimisticDesc;

  /// Row title and dialog title for choosing how strictly channels are matched to guides
  ///
  /// In en, this message translates to:
  /// **'Matching Mode'**
  String get extraGuidesMatchingModeTitle;

  /// Snackbar when the user changes a setting while a guide update is already running
  ///
  /// In en, this message translates to:
  /// **'Will apply this as soon as the current update finishes.'**
  String get extraGuidesQueued;

  /// Snackbar when a guide update starts on the Extra Guides page
  ///
  /// In en, this message translates to:
  /// **'Updating your guides. This can take a few minutes; the buttons come back when it\'s done.'**
  String get extraGuidesWorkingToast;

  /// Status line shown when a guide update begins
  ///
  /// In en, this message translates to:
  /// **'Starting…'**
  String get extraGuidesStarting;

  /// Snackbar after the guides were read and channels matched
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Guides updated: 1 channel linked.} other{Guides updated: {count} channels linked.}}'**
  String extraGuidesUpdated(int count);

  /// Snackbar when updating the guides failed
  ///
  /// In en, this message translates to:
  /// **'The guides couldn\'t be updated.'**
  String get extraGuidesUpdateFailed;

  /// Status line while a newly added guide is being downloaded and checked
  ///
  /// In en, this message translates to:
  /// **'Checking the guide…'**
  String get extraGuidesChecking;

  /// Snackbar when the user adds a guide address that is already added
  ///
  /// In en, this message translates to:
  /// **'That guide is already in your list.'**
  String get extraGuidesAlreadyAdded;

  /// Snackbar after a guide was added. name is the guide name; count the number of channels it lists
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Added \"{name}\" with 1 channel. Matching channels…} other{Added \"{name}\" with {count} channels. Matching channels…}}'**
  String extraGuidesAdded(String name, int count);

  /// Confirmation dialog title for removing an extra guide
  ///
  /// In en, this message translates to:
  /// **'Remove \"{name}\"?'**
  String extraGuidesRemoveTitle(String name);

  /// Body of the remove-guide confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Channels that were matched to this guide lose its programmes. Your playlists are not affected.'**
  String get extraGuidesRemoveBody;

  /// Button / menu item that removes an extra guide
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get extraGuidesRemove;

  /// Menu item: update this guide now
  ///
  /// In en, this message translates to:
  /// **'Update Now'**
  String get extraGuidesUpdateNow;

  /// Menu item: stop using this guide
  ///
  /// In en, this message translates to:
  /// **'Turn Off'**
  String get extraGuidesTurnOff;

  /// Menu item: use this guide again
  ///
  /// In en, this message translates to:
  /// **'Turn On'**
  String get extraGuidesTurnOn;

  /// Menu item: move the guide up the list; guides higher up are used first
  ///
  /// In en, this message translates to:
  /// **'Move Up (Used First)'**
  String get extraGuidesMoveUp;

  /// Menu item: move the guide down the list
  ///
  /// In en, this message translates to:
  /// **'Move Down'**
  String get extraGuidesMoveDown;

  /// Group heading on the Extra Guides page
  ///
  /// In en, this message translates to:
  /// **'Fill in missing guides'**
  String get extraGuidesFillTitle;

  /// Explanatory paragraph at the top of Extra Guides. "Change Guide" is the menu item changeGuideTitle. The wink emoji is intentional (hint, not a recommendation); keep the search phrase "XMLTV EPG" untranslated
  ///
  /// In en, this message translates to:
  /// **'Your playlist\'s own TV guide is always used first. A channel it does not cover is matched by name to the guides you add here. You can also pick a guide for any channel yourself: hold OK (or long-press) a channel → Change Guide.\n\nWorks with .xml, .xml.gz and zipped guides, as long as they unpack to XML. OpenIPTV does not provide guides, but community sites publish them: a web search for \"XMLTV EPG\" is a good place to start. 😉'**
  String get extraGuidesFillDescription;

  /// Group heading listing the guides the user added
  ///
  /// In en, this message translates to:
  /// **'Your Guides'**
  String get extraGuidesYourGuides;

  /// Hint under the Your Guides heading
  ///
  /// In en, this message translates to:
  /// **'Guides higher in the list are used first.'**
  String get extraGuidesListHint;

  /// Hint under the Your Guides heading when no guide was added yet
  ///
  /// In en, this message translates to:
  /// **'None yet. Guides higher in the list are used first.'**
  String get extraGuidesListHintEmpty;

  /// Row title and dialog title for adding a guide
  ///
  /// In en, this message translates to:
  /// **'Add a Guide'**
  String get extraGuidesAddTitle;

  /// Subtitle of the Add a Guide row
  ///
  /// In en, this message translates to:
  /// **'A web address ending in .xml, .xml.gz or .zip'**
  String get extraGuidesAddSubtitle;

  /// Group heading for the matching options
  ///
  /// In en, this message translates to:
  /// **'Matching'**
  String get extraGuidesMatchingGroup;

  /// Switch title
  ///
  /// In en, this message translates to:
  /// **'Match Channels Automatically'**
  String get extraGuidesAutoMatchTitle;

  /// Switch subtitle
  ///
  /// In en, this message translates to:
  /// **'Channels without a guide are matched to the guides above. Never changes a channel that already has a guide.'**
  String get extraGuidesAutoMatchSubtitle;

  /// Row title: run matching and update the guides immediately
  ///
  /// In en, this message translates to:
  /// **'Match and Update Now'**
  String get extraGuidesMatchAndUpdate;

  /// Row title opening the list of channels that were matched to a guide
  ///
  /// In en, this message translates to:
  /// **'Review Guide Matches'**
  String get extraGuidesReviewMatchesTitle;

  /// Subtitle when no channel is linked to an extra guide
  ///
  /// In en, this message translates to:
  /// **'No channels matched yet'**
  String get extraGuidesNoMatchesYet;

  /// Subtitle with the numbers of channels matched automatically and by hand
  ///
  /// In en, this message translates to:
  /// **'{auto} matched automatically · {manual} chosen by you'**
  String extraGuidesMatchSummary(int auto, int manual);

  /// Guide row subtitle: error message, then when the guide was last read successfully. when is a phrase such as "5 min ago"
  ///
  /// In en, this message translates to:
  /// **'{error}\nLast read {when}.'**
  String extraGuidesLastError(String error, String when);

  /// Guide row subtitle before the first successful read
  ///
  /// In en, this message translates to:
  /// **'Not read yet'**
  String get extraGuidesNotRead;

  /// Guide row subtitle: how many channels the guide lists, how many are used, and when it was read. when is a phrase such as "5 min ago"
  ///
  /// In en, this message translates to:
  /// **'{channels, plural, =1{1 channel} other{{channels} channels}} · {used} used · read {when}'**
  String extraGuidesTileLine(int channels, int used, String when);

  /// Same as extraGuidesTileLine for a guide that is turned off
  ///
  /// In en, this message translates to:
  /// **'{channels, plural, =1{1 channel} other{{channels} channels}} · {used} used · read {when} · off'**
  String extraGuidesTileLineOff(int channels, int used, String when);

  /// Text field label in the Add a Guide dialog
  ///
  /// In en, this message translates to:
  /// **'Name (optional)'**
  String get extraGuidesNameLabel;

  /// Text field label for the guide web address
  ///
  /// In en, this message translates to:
  /// **'Guide address'**
  String get extraGuidesAddressLabel;

  /// Error under the address field when it is not a web address
  ///
  /// In en, this message translates to:
  /// **'Enter the guide address, starting with http:// or https://'**
  String get extraGuidesAddressInvalid;

  /// Confirm button of the Add a Guide dialog
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get extraGuidesAddButton;

  /// App bar title of the list of channels matched to guides
  ///
  /// In en, this message translates to:
  /// **'Guide Matches'**
  String get extraGuidesLinksTitle;

  /// Empty state of the Guide Matches list. Change Guide = changeGuideTitle
  ///
  /// In en, this message translates to:
  /// **'No channels are matched to an extra guide yet. Pick one for a channel with hold OK → Change Guide, or add a guide and let OpenIPTV match channels for you.'**
  String get extraGuidesLinksEmpty;

  /// Row subtitle: the user chose that this channel has no guide
  ///
  /// In en, this message translates to:
  /// **'No guide (your choice)'**
  String get extraGuidesLinkNone;

  /// Row subtitle: guide channel id, guide name, chosen by the user
  ///
  /// In en, this message translates to:
  /// **'{id} · {guide} · your choice'**
  String extraGuidesLinkManual(String id, String guide);

  /// Row subtitle: guide channel id, guide name, matched automatically
  ///
  /// In en, this message translates to:
  /// **'{id} · {guide} · automatic'**
  String extraGuidesLinkAuto(String id, String guide);

  /// Lowercase fallback word used where a guide name is unknown
  ///
  /// In en, this message translates to:
  /// **'guide'**
  String get extraGuidesGuideFallback;

  /// Relative time: less than a minute ago. Used inside sentences
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get guideDataAgoJustNow;

  /// Relative time in minutes
  ///
  /// In en, this message translates to:
  /// **'{count} min ago'**
  String guideDataAgoMinutes(int count);

  /// Relative time in hours
  ///
  /// In en, this message translates to:
  /// **'{count} h ago'**
  String guideDataAgoHours(int count);

  /// Relative time in days
  ///
  /// In en, this message translates to:
  /// **'{count} d ago'**
  String guideDataAgoDays(int count);

  /// App bar title of the Guide Data settings page
  ///
  /// In en, this message translates to:
  /// **'Guide Data'**
  String get guideDataTitle;

  /// Group heading
  ///
  /// In en, this message translates to:
  /// **'Days of guide to keep'**
  String get guideDataDaysTitle;

  /// Group description. Catch-up = watching past programmes
  ///
  /// In en, this message translates to:
  /// **'How far ahead the TV guide is stored. Fewer days makes the guide smaller and quicker to refresh. Catch-up history is kept as your provider offers it.'**
  String get guideDataDaysDescription;

  /// Option label for a number of days
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String guideDataDays(int count);

  /// Option label for the default number of days
  ///
  /// In en, this message translates to:
  /// **'{count} days (default)'**
  String guideDataDaysDefault(int count);

  /// Group heading
  ///
  /// In en, this message translates to:
  /// **'Programme details'**
  String get guideDataDetailsTitle;

  /// Group description
  ///
  /// In en, this message translates to:
  /// **'Descriptions are most of the guide\'s size. Turn them off to save space; titles and times stay. Turning them off removes the stored ones now.'**
  String get guideDataDetailsDescription;

  /// Switch title
  ///
  /// In en, this message translates to:
  /// **'Store Programme Descriptions'**
  String get guideDataStoreDescriptions;

  /// Snackbar after turning descriptions back on
  ///
  /// In en, this message translates to:
  /// **'Descriptions come back the next time the TV guide refreshes.'**
  String get guideDataDescriptionsBack;

  /// Group heading showing when each playlist guide was last updated
  ///
  /// In en, this message translates to:
  /// **'Last update'**
  String get guideDataLastUpdate;

  /// Group description when no playlist has a guide
  ///
  /// In en, this message translates to:
  /// **'None of your playlists has a TV guide.'**
  String get guideDataNoGuides;

  /// Group heading
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get guideDataClearGroup;

  /// Confirmation dialog title
  ///
  /// In en, this message translates to:
  /// **'Clear Guide Data?'**
  String get guideDataClearTitle;

  /// Confirmation dialog body
  ///
  /// In en, this message translates to:
  /// **'This removes the stored TV guide for every playlist. Your playlists and channels stay. Refresh the TV guides to load it again.'**
  String get guideDataClearBody;

  /// Confirm button of the clear dialog
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get guideDataClearButton;

  /// Row title
  ///
  /// In en, this message translates to:
  /// **'Clear Guide Data'**
  String get guideDataClearRowTitle;

  /// Row subtitle
  ///
  /// In en, this message translates to:
  /// **'Removes the stored guide for every playlist'**
  String get guideDataClearRowSubtitle;

  /// Row subtitle while clearing
  ///
  /// In en, this message translates to:
  /// **'Clearing…'**
  String get guideDataClearing;

  /// Snackbar after clearing
  ///
  /// In en, this message translates to:
  /// **'Guide data cleared.'**
  String get guideDataCleared;

  /// Playlist row subtitle after a failed update: error message, when it last loaded, how many programmes remain. when is a phrase such as "5 min ago"
  ///
  /// In en, this message translates to:
  /// **'{error}\nLast loaded {when}, {count, plural, =1{1 programme} other{{count} programmes}} kept.'**
  String guideDataLastLoaded(String error, String when, int count);

  /// Playlist row subtitle: when the guide was updated and how many programmes it holds. when is a phrase such as "5 min ago"
  ///
  /// In en, this message translates to:
  /// **'Updated {when} · {count, plural, =1{1 programme} other{{count} programmes}}'**
  String guideDataUpdated(String when, int count);

  /// Playlist row subtitle when the guide has data but no recorded update time
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 programme stored} other{{count} programmes stored}}'**
  String guideDataStored(int count);

  /// Playlist row subtitle when no guide data exists
  ///
  /// In en, this message translates to:
  /// **'Not loaded yet'**
  String get guideDataNotLoaded;

  /// Menu item and app bar title for picking which guide supplies a channel's programmes
  ///
  /// In en, this message translates to:
  /// **'Change Guide'**
  String get changeGuideTitle;

  /// Subtitle: the channel has no manual choice
  ///
  /// In en, this message translates to:
  /// **'Using the playlist\'s own guide (or a smart match, if it has none)'**
  String get changeGuideDescribeDefault;

  /// Subtitle: the user chose no guide for this channel
  ///
  /// In en, this message translates to:
  /// **'No guide, as you chose'**
  String get changeGuideDescribeNone;

  /// Subtitle: manual choice. id = guide channel id; guide = guide name or changeGuideGuideFallback
  ///
  /// In en, this message translates to:
  /// **'You chose {id} in {guide}'**
  String changeGuideDescribeManual(String id, String guide);

  /// Subtitle: automatic match. id = guide channel id; guide = guide name or changeGuideGuideFallback
  ///
  /// In en, this message translates to:
  /// **'Matched automatically to {id} in {guide}'**
  String changeGuideDescribeAuto(String id, String guide);

  /// Used in place of a guide name when unknown: "… in a guide"
  ///
  /// In en, this message translates to:
  /// **'a guide'**
  String get changeGuideGuideFallback;

  /// Snackbar while a chosen guide is being downloaded
  ///
  /// In en, this message translates to:
  /// **'Loading the guide, this can take a minute…'**
  String get changeGuideLoading;

  /// Snackbar when the chosen guide loaded
  ///
  /// In en, this message translates to:
  /// **'Guide changed and loaded.'**
  String get changeGuideLoaded;

  /// Snackbar after choosing no guide
  ///
  /// In en, this message translates to:
  /// **'Guide removed.'**
  String get changeGuideRemoved;

  /// Snackbar after resetting the channel guide to automatic
  ///
  /// In en, this message translates to:
  /// **'Back to automatic.'**
  String get changeGuideBackToAuto;

  /// Empty state title
  ///
  /// In en, this message translates to:
  /// **'No guides to pick from yet'**
  String get changeGuideNoGuidesTitle;

  /// Empty state body. Names must match the Settings labels
  ///
  /// In en, this message translates to:
  /// **'Add one in Settings → Playlists & Guides → Extra Guides, or refresh your TV guides.'**
  String get changeGuideNoGuidesBody;

  /// Search field hint
  ///
  /// In en, this message translates to:
  /// **'Search the guides'**
  String get changeGuideSearchHint;

  /// Section heading above suggested guide channels
  ///
  /// In en, this message translates to:
  /// **'Suggested'**
  String get changeGuideSuggested;

  /// Section heading above search results
  ///
  /// In en, this message translates to:
  /// **'Results'**
  String get changeGuideResults;

  /// Shown when search has no results
  ///
  /// In en, this message translates to:
  /// **'Nothing found'**
  String get changeGuideNothingFound;

  /// Fallback guide name shown before the guide channel id in a result row
  ///
  /// In en, this message translates to:
  /// **'Guide'**
  String get changeGuideGuideLabel;

  /// Row title
  ///
  /// In en, this message translates to:
  /// **'No Guide for This Channel'**
  String get changeGuideNoGuideTitle;

  /// Row subtitle
  ///
  /// In en, this message translates to:
  /// **'Clears its programmes and keeps it that way'**
  String get changeGuideNoGuideSubtitle;

  /// Row title: go back to automatic guide assignment
  ///
  /// In en, this message translates to:
  /// **'Use Automatic'**
  String get changeGuideUseAutomatic;

  /// Row subtitle
  ///
  /// In en, this message translates to:
  /// **'The playlist\'s own guide, or a smart match'**
  String get changeGuideUseAutomaticSubtitle;

  /// App bar title
  ///
  /// In en, this message translates to:
  /// **'Backup & Restore'**
  String get backupTitle;

  /// Group heading
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get backupExportGroup;

  /// Info tooltip title
  ///
  /// In en, this message translates to:
  /// **'Export Backup'**
  String get backupExportInfoTitle;

  /// Info tooltip body
  ///
  /// In en, this message translates to:
  /// **'Exporting saves every profile, every source, and your app settings into a single .zip file. You can optionally protect it with a password.'**
  String get backupExportInfoBody;

  /// Info tooltip tip
  ///
  /// In en, this message translates to:
  /// **'Save this file somewhere safe — you\'ll need it to restore everything on a new device.'**
  String get backupExportInfoTip;

  /// Row title
  ///
  /// In en, this message translates to:
  /// **'Export Backup'**
  String get backupExportTitle;

  /// Row subtitle
  ///
  /// In en, this message translates to:
  /// **'Save all profiles, sources, and settings as a .zip file'**
  String get backupExportSubtitle;

  /// Group heading
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get backupRestoreGroup;

  /// Info tooltip title
  ///
  /// In en, this message translates to:
  /// **'Restore Backup'**
  String get backupImportInfoTitle;

  /// Info tooltip body
  ///
  /// In en, this message translates to:
  /// **'Importing reads a .zip backup file and adds its profiles and sources to this device. If the backup was password-protected, you\'ll be asked for the password used when it was exported.'**
  String get backupImportInfoBody;

  /// Info tooltip tip
  ///
  /// In en, this message translates to:
  /// **'Importing does not delete anything — your existing profiles are kept.'**
  String get backupImportInfoTip;

  /// Row title
  ///
  /// In en, this message translates to:
  /// **'Import Backup'**
  String get backupImportTitle;

  /// Row subtitle
  ///
  /// In en, this message translates to:
  /// **'Open a .zip backup file'**
  String get backupImportSubtitle;

  /// Snackbar while the backup is being created
  ///
  /// In en, this message translates to:
  /// **'Preparing backup…'**
  String get backupPreparing;

  /// Snackbar after saving. location is a folder or file path
  ///
  /// In en, this message translates to:
  /// **'Backup saved to {location}'**
  String backupSavedTo(String location);

  /// Subject line of the share sheet / email when sharing the backup file
  ///
  /// In en, this message translates to:
  /// **'OpenIPTV backup'**
  String get backupShareSubject;

  /// Error snackbar
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t create the backup file. Make sure you have storage permission and try again.'**
  String get backupCreateFailed;

  /// Dialog title: where to put the backup file
  ///
  /// In en, this message translates to:
  /// **'Save Backup'**
  String get backupSaveTitle;

  /// Dialog body
  ///
  /// In en, this message translates to:
  /// **'Save the backup file to this device, or share it to another app (email, cloud storage, …).'**
  String get backupSaveBody;

  /// Dialog button opening the system share sheet
  ///
  /// In en, this message translates to:
  /// **'Share…'**
  String get backupShareButton;

  /// Dialog button saving to the Downloads folder
  ///
  /// In en, this message translates to:
  /// **'Save to Downloads'**
  String get backupSaveToDownloads;

  /// Part of the restore summary: number of profiles
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 profile} other{{count} profiles}}'**
  String backupRestoredProfiles(int count);

  /// Part of the restore summary: number of sources (playlists)
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 source} other{{count} sources}}'**
  String backupRestoredSources(int count);

  /// Snackbar after restoring. profiles and sources are phrases from backupRestoredProfiles / backupRestoredSources
  ///
  /// In en, this message translates to:
  /// **'Restored {profiles} and {sources}.'**
  String backupRestored(String profiles, String sources);

  /// Title of the file picker
  ///
  /// In en, this message translates to:
  /// **'Choose a backup'**
  String get backupPickTitle;

  /// Error snackbar
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the file picker. Check that the app has file access permission and try again.'**
  String get backupPickerFailed;

  /// Error snackbar
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open this backup file. Make sure it\'s a valid OpenIPTV backup.'**
  String get backupOpenFailed;

  /// Dialog title
  ///
  /// In en, this message translates to:
  /// **'Protect This Backup?'**
  String get backupProtectTitle;

  /// Dialog body
  ///
  /// In en, this message translates to:
  /// **'Source credentials are stored in plain text inside the backup file. Optionally set a password to encrypt it — you\'ll need the same password to restore it.'**
  String get backupProtectBody;

  /// Password field hint
  ///
  /// In en, this message translates to:
  /// **'Password (optional)'**
  String get backupPasswordOptionalHint;

  /// Dialog button: export without a password
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get backupSkip;

  /// Dialog button
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get backupExportButton;

  /// Dialog title
  ///
  /// In en, this message translates to:
  /// **'Backup is Protected'**
  String get backupProtectedTitle;

  /// Dialog body
  ///
  /// In en, this message translates to:
  /// **'This backup was protected with a password. Enter the password that was set when it was exported.'**
  String get backupProtectedBody;

  /// Password field hint
  ///
  /// In en, this message translates to:
  /// **'Enter password'**
  String get backupEnterPasswordHint;

  /// Dialog button
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get backupRestoreButton;

  /// Snackbar on Check for Updates when the app came from the Play Store
  ///
  /// In en, this message translates to:
  /// **'Updates for this install are managed by Google Play.'**
  String get updateManagedByPlay;

  /// Snackbar while checking
  ///
  /// In en, this message translates to:
  /// **'Checking for updates…'**
  String get updateChecking;

  /// Snackbar
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t check for updates. Check your internet connection.'**
  String get updateCheckFailed;

  /// Snackbar when no newer version exists
  ///
  /// In en, this message translates to:
  /// **'You\'re up to date (version {version}).'**
  String updateUpToDate(String version);

  /// Update dialog title
  ///
  /// In en, this message translates to:
  /// **'Update available'**
  String get updateAvailableTitle;

  /// Dialog subtitle with the new version number
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String updateVersion(String version);

  /// Dialog subtitle: installed version → new version
  ///
  /// In en, this message translates to:
  /// **'Version {installed} → {latest}'**
  String updateVersionFromTo(String installed, String latest);

  /// Dialog body. Open Settings = updateOpenSettings; "Allow from this source" is Android's own switch label (use the Spanish Android wording)
  ///
  /// In en, this message translates to:
  /// **'To install updates, OpenIPTV needs permission to install apps.\n\nSelect Open Settings, turn on \"Allow from this source\", then come back here — the update will continue automatically.'**
  String get updatePermissionBody;

  /// Progress text without a percentage
  ///
  /// In en, this message translates to:
  /// **'Downloading…'**
  String get updateDownloading;

  /// Progress text with a percentage
  ///
  /// In en, this message translates to:
  /// **'Downloading… {percent}%'**
  String updateDownloadingPercent(int percent);

  /// Dialog body. Install again = updateInstallAgain
  ///
  /// In en, this message translates to:
  /// **'Follow the prompts on screen to finish installing. OpenIPTV will restart on the new version.\n\nIf nothing appeared, or you cancelled, select Install again.'**
  String get updateHandedOffBody;

  /// Dialog body
  ///
  /// In en, this message translates to:
  /// **'The update couldn\'t be downloaded. Check your internet connection and try again.'**
  String get updateFailedBody;

  /// Dialog button
  ///
  /// In en, this message translates to:
  /// **'Skip this version'**
  String get updateSkipVersion;

  /// Dialog button
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get updateLater;

  /// Dialog button
  ///
  /// In en, this message translates to:
  /// **'Update now'**
  String get updateNow;

  /// Dialog button opening Android settings
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get updateOpenSettings;

  /// Dialog button
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get updateClose;

  /// Dialog button
  ///
  /// In en, this message translates to:
  /// **'Install again'**
  String get updateInstallAgain;

  /// Dialog button
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get updateTryAgain;

  /// Shown when a release has no notes
  ///
  /// In en, this message translates to:
  /// **'No release notes provided.'**
  String get updateNoNotes;

  /// App bar title
  ///
  /// In en, this message translates to:
  /// **'Anonymous Reports'**
  String get reportsTitle;

  /// Switch title
  ///
  /// In en, this message translates to:
  /// **'Send anonymous crash reports'**
  String get reportsSwitchTitle;

  /// Switch subtitle
  ///
  /// In en, this message translates to:
  /// **'Off unless you turn it on. Helps fix crashes faster.'**
  String get reportsSwitchSubtitle;

  /// Intro paragraph
  ///
  /// In en, this message translates to:
  /// **'When the app crashes or freezes, a short report is saved on this device and sent in the background soon after, never more than once every 10 minutes. It cannot be tied to you or to anything you watch.'**
  String get reportsIntro;

  /// Heading
  ///
  /// In en, this message translates to:
  /// **'A report contains only this'**
  String get reportsContainsHeading;

  /// Bullet list; keep the "• " bullets and line breaks
  ///
  /// In en, this message translates to:
  /// **'• App version\n• Android version\n• Device maker and model\n• The date (no time)\n• What kind of problem (crash or freeze) and its name only\n• Where in the code it happened (up to 30 lines)'**
  String get reportsContainsList;

  /// Heading
  ///
  /// In en, this message translates to:
  /// **'Never included'**
  String get reportsNeverHeading;

  /// Bullet list; keep the "• " bullets and line breaks
  ///
  /// In en, this message translates to:
  /// **'• Playlists, logins, passwords or links\n• Channel, movie or series names, or what you watch\n• Search text, profile names or settings\n• IP addresses, device IDs, or any ID that could tie reports together\n• Error messages (they can contain links or names)'**
  String get reportsNeverList;

  /// Heading
  ///
  /// In en, this message translates to:
  /// **'Waiting to be sent from this device'**
  String get reportsWaitingHeading;

  /// Shown when no report is queued
  ///
  /// In en, this message translates to:
  /// **'Nothing is waiting.'**
  String get reportsNothingWaiting;

  /// Button
  ///
  /// In en, this message translates to:
  /// **'Delete waiting reports'**
  String get reportsDeleteWaiting;

  /// Heading
  ///
  /// In en, this message translates to:
  /// **'Check the code'**
  String get reportsCheckCodeHeading;

  /// Body; keep file paths as is
  ///
  /// In en, this message translates to:
  /// **'All of it lives in lib/telemetry/ in the OpenIPTV GitHub repository, with a short design note in docs/design/anonymous-stats.md.'**
  String get reportsCheckCodeBody;

  /// Tooltip of the play button in the player and cast remote (icon only)
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get playerPlay;

  /// Tooltip of the pause button in the player and cast remote (icon only)
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get playerPause;

  /// Tooltip / label of the button that opens the channel list inside the player
  ///
  /// In en, this message translates to:
  /// **'Channels'**
  String get playerChannels;

  /// Title of the sheet shown while connected to a cast device; also the fallback title of what is being cast
  ///
  /// In en, this message translates to:
  /// **'Casting'**
  String get castTitleCasting;

  /// Name shown when the connected cast device has no name
  ///
  /// In en, this message translates to:
  /// **'Cast device'**
  String get castDeviceFallback;

  /// Status line under the connected cast device name
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get castConnected;

  /// Button and tooltip that disconnects from the cast device
  ///
  /// In en, this message translates to:
  /// **'Stop casting'**
  String get castStop;

  /// Title of the sheet that lists TVs and speakers to cast to
  ///
  /// In en, this message translates to:
  /// **'Cast to'**
  String get castPickerTitle;

  /// Shown while the app searches the local network for cast devices
  ///
  /// In en, this message translates to:
  /// **'Looking for TVs and speakers on your Wi-Fi…'**
  String get castSearching;

  /// Shown under the cast device the user picked while connecting
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get castConnecting;

  /// Hint at the bottom of the cast device list
  ///
  /// In en, this message translates to:
  /// **'Your phone and the TV need to be on the same Wi-Fi network.'**
  String get castSameWifi;

  /// Tooltip of the cast button (icon only)
  ///
  /// In en, this message translates to:
  /// **'Cast'**
  String get castCastTooltip;

  /// Fallback device name inserted into castPlayingOn / castOn when the cast device name is unknown
  ///
  /// In en, this message translates to:
  /// **'your TV'**
  String get castYourTv;

  /// Heading of the cast remote screen. {device} is the cast device name or castYourTv
  ///
  /// In en, this message translates to:
  /// **'Playing on {device}'**
  String castPlayingOn(String device);

  /// Tooltip of the cast button while connected
  ///
  /// In en, this message translates to:
  /// **'Casting to {device}'**
  String castCastingTo(String device);

  /// Second line of the now-casting bar. {device} is the cast device name or castYourTv
  ///
  /// In en, this message translates to:
  /// **'On {device}'**
  String castOnDevice(String device);

  /// Tooltip of the rewind 10 seconds button on the cast remote
  ///
  /// In en, this message translates to:
  /// **'Back 10 seconds'**
  String get castBack10;

  /// Tooltip of the forward 10 seconds button on the cast remote
  ///
  /// In en, this message translates to:
  /// **'Forward 10 seconds'**
  String get castForward10;

  /// Tooltip of the volume down button on the cast remote
  ///
  /// In en, this message translates to:
  /// **'Volume down'**
  String get castVolumeDown;

  /// Tooltip of the volume up button on the cast remote
  ///
  /// In en, this message translates to:
  /// **'Volume up'**
  String get castVolumeUp;

  /// Body of the dialog asked when opening a channel whose current show already started and can be watched from the start. {minutes} is how long ago it began (under an hour)
  ///
  /// In en, this message translates to:
  /// **'This show started {minutes, plural, =1{1 minute} other{{minutes} minutes}} ago. Where would you like to start?'**
  String catchupStartedMinutesAgo(int minutes);

  /// Body of the dialog asked when opening a channel whose current show already started and can be watched from the start. Whole hours ago
  ///
  /// In en, this message translates to:
  /// **'This show started {hours, plural, =1{1 hour} other{{hours} hours}} ago. Where would you like to start?'**
  String catchupStartedHoursAgo(int hours);

  /// Body of the dialog asked when opening a channel whose current show already started and can be watched from the start. Hours and minutes ago, compact
  ///
  /// In en, this message translates to:
  /// **'This show started {hours}h {minutes}m ago. Where would you like to start?'**
  String catchupStartedHoursMinutesAgo(int hours, int minutes);

  /// Dialog button: play the show from its start (catch-up)
  ///
  /// In en, this message translates to:
  /// **'Start from the beginning'**
  String get catchupStartFromBeginning;

  /// Dialog button: watch the live broadcast
  ///
  /// In en, this message translates to:
  /// **'Watch live'**
  String get catchupWatchLive;

  /// Tooltip of a round close (X) button in the player and its panels (icon only)
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get playerClose;

  /// Accessibility label of the area outside the channel panel that closes it
  ///
  /// In en, this message translates to:
  /// **'Close channels'**
  String get channelSwitcherBarrier;

  /// Name of the favourite channels category in the in-player channel panel
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get channelSwitcherFavorites;

  /// Title of the channel panel that slides in over the video
  ///
  /// In en, this message translates to:
  /// **'Channels'**
  String get channelSwitcherTitle;

  /// Tooltip of the arrow that goes to the previous channel category
  ///
  /// In en, this message translates to:
  /// **'Previous category'**
  String get channelSwitcherPrevCategory;

  /// Tooltip of the arrow that goes to the next channel category
  ///
  /// In en, this message translates to:
  /// **'Next category'**
  String get channelSwitcherNextCategory;

  /// Subtitle of the channel that is currently playing in the channel panel
  ///
  /// In en, this message translates to:
  /// **'Now watching'**
  String get channelSwitcherNowWatching;

  /// Subtitle of a channel with no programme information
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get channelSwitcherLive;

  /// Plain-English error shown over a channel that cannot play (player and multi-view tiles)
  ///
  /// In en, this message translates to:
  /// **'This channel isn\'t available right now.'**
  String get playerChannelUnavailableNow;

  /// Option in the multi-view tile menu: show this channel full screen
  ///
  /// In en, this message translates to:
  /// **'Full screen'**
  String get multiViewFullScreen;

  /// Option in the multi-view tile menu: replace this tile with another channel
  ///
  /// In en, this message translates to:
  /// **'Swap channel'**
  String get multiViewSwap;

  /// Option in the multi-view tile menu: add another channel tile; also the tooltip of the player button that starts multi-view
  ///
  /// In en, this message translates to:
  /// **'Add a channel'**
  String get multiViewAdd;

  /// Label of the multi-view layout choice (equal grid or one big tile)
  ///
  /// In en, this message translates to:
  /// **'Layout'**
  String get multiViewLayout;

  /// Multi-view layout choice: all tiles the same size
  ///
  /// In en, this message translates to:
  /// **'Equal grid'**
  String get multiViewEqualGrid;

  /// Multi-view layout choice: one large tile and the rest small
  ///
  /// In en, this message translates to:
  /// **'One big'**
  String get multiViewOneBig;

  /// Option in the multi-view tile menu: remove this tile
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get multiViewRemove;

  /// Screen reader hint on the highlighted multi-view tile
  ///
  /// In en, this message translates to:
  /// **'Double tap for options'**
  String get multiViewHintOptions;

  /// Screen reader hint on a multi-view tile that is not playing sound
  ///
  /// In en, this message translates to:
  /// **'Double tap to hear this channel'**
  String get multiViewHintHear;

  /// Error on a multi-view tile when the device has no free video decoder
  ///
  /// In en, this message translates to:
  /// **'This device can\'t play another channel at the same time.'**
  String get multiViewNoDecoder;

  /// Error on a multi-view tile when the provider refuses an extra connection
  ///
  /// In en, this message translates to:
  /// **'Your provider didn\'t allow another stream.'**
  String get multiViewProviderRefused;

  /// Tooltip of the rewind button; {seconds} is 5, 10 or 30
  ///
  /// In en, this message translates to:
  /// **'Back {seconds} seconds'**
  String playerBackSeconds(int seconds);

  /// Tooltip of the fast-forward button; {seconds} is 5, 10 or 30
  ///
  /// In en, this message translates to:
  /// **'Forward {seconds} seconds'**
  String playerForwardSeconds(int seconds);

  /// Tooltip of the subtitles button in the player; also the title of the subtitles sheet and the row label
  ///
  /// In en, this message translates to:
  /// **'Subtitles'**
  String get playerSubtitles;

  /// Tooltip of the star button when the channel is already a favourite
  ///
  /// In en, this message translates to:
  /// **'Remove from Favorites'**
  String get playerRemoveFavorite;

  /// Tooltip of the star button when the channel is not a favourite
  ///
  /// In en, this message translates to:
  /// **'Add to Favorites'**
  String get playerAddFavorite;

  /// Tooltip of the button that opens the programme guide for this channel
  ///
  /// In en, this message translates to:
  /// **'TV Guide'**
  String get playerTvGuide;

  /// Tooltip of the gear button in the player; also the title of the settings sheet
  ///
  /// In en, this message translates to:
  /// **'Playback settings'**
  String get playerSettingsTooltip;

  /// Time remaining in the programme on air. {duration} is a compact duration such as 45m or 1h 5m
  ///
  /// In en, this message translates to:
  /// **'{duration} left'**
  String playerTimeLeft(String duration);

  /// Name of the programme that follows the current one. {title} is the programme title
  ///
  /// In en, this message translates to:
  /// **'Next: {title}'**
  String playerNextProgramme(String title);

  /// Small badge in the player shown while watching the live edge of a channel (all caps)
  ///
  /// In en, this message translates to:
  /// **'LIVE'**
  String get playerLiveBadge;

  /// Small button in the player that jumps back to the live broadcast after pausing or rewinding
  ///
  /// In en, this message translates to:
  /// **'Go live'**
  String get playerGoLive;

  /// Screen reader label of the quality chip. {details} is e.g. 1080p HD, 50 FPS
  ///
  /// In en, this message translates to:
  /// **'Stream details: {details}'**
  String playerStreamDetails(String details);

  /// Snackbar shown when the audio delay setting could not be applied. "None" is the name of the zero choice in the audio delay setting (playerAudioDelayNone)
  ///
  /// In en, this message translates to:
  /// **'The audio delay didn\'t work with this stream, so it was set back to None. Playback carries on as normal.'**
  String get playerNoticeAudioDelay;

  /// Snackbar when surround sound passthrough failed. "Power User Tools" is the name of an advanced settings page
  ///
  /// In en, this message translates to:
  /// **'Surround sound passthrough didn\'t work on this device, so it was switched off and the sound is playing normally. You can try it again in Power User Tools.'**
  String get playerNoticePassthrough;

  /// Snackbar when tunneled video playback failed. "Power User Tools" is the name of an advanced settings page
  ///
  /// In en, this message translates to:
  /// **'Tunneled playback didn\'t work on this device, so it was switched off. You can try it again in Power User Tools.'**
  String get playerNoticeTunneled;

  /// Error when the provider rejected the stream with a permission error
  ///
  /// In en, this message translates to:
  /// **'Your provider didn\'t allow this stream.'**
  String get playerErrorProviderRefused;

  /// Error when the provider cannot deliver this channel
  ///
  /// In en, this message translates to:
  /// **'This channel isn\'t available from your provider right now.'**
  String get playerErrorChannelProvider;

  /// Error when the provider cannot deliver this movie or episode
  ///
  /// In en, this message translates to:
  /// **'This title isn\'t available from your provider right now.'**
  String get playerErrorTitleProvider;

  /// Fallback device name used in castFailedChannel / castFailedTitle
  ///
  /// In en, this message translates to:
  /// **'this device'**
  String get castThisDevice;

  /// Error shown on the cast remote when the cast device cannot play a channel
  ///
  /// In en, this message translates to:
  /// **'This channel can\'t be played on {device}. Stop casting to watch it here.'**
  String castFailedChannel(String device);

  /// Error shown on the cast remote when the cast device cannot play a movie or episode
  ///
  /// In en, this message translates to:
  /// **'This title can\'t be played on {device}. Stop casting to watch it here.'**
  String castFailedTitle(String device);

  /// Title of the dialog offering to continue a movie or episode where it was left
  ///
  /// In en, this message translates to:
  /// **'Resume Watching?'**
  String get playerResumeTitle;

  /// Body of the resume dialog. {position} is a clock time such as 12:34
  ///
  /// In en, this message translates to:
  /// **'Continue from {position}?'**
  String playerResumeBody(String position);

  /// Resume dialog button: play from the start
  ///
  /// In en, this message translates to:
  /// **'Start Over'**
  String get playerStartOver;

  /// Resume dialog button: continue from the saved position
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get playerResume;

  /// Screen reader label of the whole video area
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get playerVideoSemantics;

  /// Screen reader hint of the whole video area
  ///
  /// In en, this message translates to:
  /// **'Double tap to show or hide the playback controls'**
  String get playerVideoSemanticsHint;

  /// Status shown over the video while the app reconnects to the stream
  ///
  /// In en, this message translates to:
  /// **'Reconnecting…'**
  String get playerReconnecting;

  /// Status shown while reconnecting a stream that has not played yet
  ///
  /// In en, this message translates to:
  /// **'Reconnecting… ({attempt} of {max})'**
  String playerReconnectingAttempt(int attempt, int max);

  /// Heading of the banner offering the next episode
  ///
  /// In en, this message translates to:
  /// **'Up next'**
  String get playerUpNext;

  /// Button on the next-episode banner that starts it immediately
  ///
  /// In en, this message translates to:
  /// **'Play now'**
  String get playerPlayNow;

  /// Default headline of the player error screen
  ///
  /// In en, this message translates to:
  /// **'This stream isn\'t playing right now'**
  String get playerStreamNotPlaying;

  /// Player error screen button that retries the stream
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get playerTryAgain;

  /// Player error screen button that leaves the player
  ///
  /// In en, this message translates to:
  /// **'Go back'**
  String get playerGoBack;

  /// Choice in the subtitles row: no subtitles
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get playerSubtitlesOff;

  /// Hint under the subtitles row when a live channel has no subtitle tracks yet
  ///
  /// In en, this message translates to:
  /// **'No subtitles detected on this channel yet. Captions appear here as soon as the broadcast sends them.'**
  String get playerNoSubtitlesLive;

  /// Hint under the subtitles row when a movie or episode has no subtitle tracks
  ///
  /// In en, this message translates to:
  /// **'This video has no subtitles.'**
  String get playerNoSubtitlesVideo;

  /// Label of the audio track row in the player settings; also the fallback name of an unlabelled audio track
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get playerAudio;

  /// Label of the picture fit row in the player settings
  ///
  /// In en, this message translates to:
  /// **'Picture'**
  String get playerPicture;

  /// Picture choice: whole picture visible with bars if needed
  ///
  /// In en, this message translates to:
  /// **'Fit'**
  String get playerPictureFit;

  /// Picture choice: enlarge to fill the screen, cropping the edges
  ///
  /// In en, this message translates to:
  /// **'Zoom'**
  String get playerPictureZoom;

  /// Picture choice: stretch to fill the whole screen
  ///
  /// In en, this message translates to:
  /// **'Fill screen'**
  String get playerPictureFill;

  /// Label of the clock row in the player settings
  ///
  /// In en, this message translates to:
  /// **'Clock'**
  String get playerClock;

  /// Clock choice: shown only when the controls are visible
  ///
  /// In en, this message translates to:
  /// **'With controls'**
  String get playerClockWithControls;

  /// Clock choice: always shown
  ///
  /// In en, this message translates to:
  /// **'Always on'**
  String get playerClockAlwaysOn;

  /// Label of the audio delay row in the player settings
  ///
  /// In en, this message translates to:
  /// **'Audio delay'**
  String get playerAudioDelay;

  /// Audio delay choice: no delay
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get playerAudioDelayNone;

  /// Label of the row that shows or hides the quality chip
  ///
  /// In en, this message translates to:
  /// **'Stream details'**
  String get playerStreamDetailsLabel;

  /// Choice: show something
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get playerShow;

  /// Choice: hide something
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get playerHide;

  /// Label of the playback speed row (movies and episodes)
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get playerSpeed;

  /// Playback speed choice for 1x
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get playerSpeedNormal;

  /// Name of the broadcast caption track (CEA-608)
  ///
  /// In en, this message translates to:
  /// **'Captions'**
  String get playerCaptions;

  /// Name of an extra broadcast caption channel
  ///
  /// In en, this message translates to:
  /// **'Captions {channel}'**
  String playerCaptionsNumbered(int channel);

  /// Name of the broadcast digital caption track (CEA-708)
  ///
  /// In en, this message translates to:
  /// **'Digital captions'**
  String get playerDigitalCaptions;

  /// Name of an extra digital caption service
  ///
  /// In en, this message translates to:
  /// **'Digital captions {channel}'**
  String playerDigitalCaptionsNumbered(int channel);

  /// Name of a language, shown as the name of an audio or subtitle track
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get playerLangEn;

  /// Name of a language, shown as the name of an audio or subtitle track
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get playerLangEs;

  /// Name of a language, shown as the name of an audio or subtitle track
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get playerLangFr;

  /// Name of a language, shown as the name of an audio or subtitle track
  ///
  /// In en, this message translates to:
  /// **'German'**
  String get playerLangDe;

  /// Name of a language, shown as the name of an audio or subtitle track
  ///
  /// In en, this message translates to:
  /// **'Italian'**
  String get playerLangIt;

  /// Name of a language, shown as the name of an audio or subtitle track
  ///
  /// In en, this message translates to:
  /// **'Portuguese'**
  String get playerLangPt;

  /// Name of a language, shown as the name of an audio or subtitle track
  ///
  /// In en, this message translates to:
  /// **'Dutch'**
  String get playerLangNl;

  /// Name of a language, shown as the name of an audio or subtitle track
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get playerLangAr;

  /// Name of a language, shown as the name of an audio or subtitle track
  ///
  /// In en, this message translates to:
  /// **'Russian'**
  String get playerLangRu;

  /// Name of a language, shown as the name of an audio or subtitle track
  ///
  /// In en, this message translates to:
  /// **'Turkish'**
  String get playerLangTr;

  /// Name of a language, shown as the name of an audio or subtitle track
  ///
  /// In en, this message translates to:
  /// **'Polish'**
  String get playerLangPl;

  /// Name of a language, shown as the name of an audio or subtitle track
  ///
  /// In en, this message translates to:
  /// **'Hindi'**
  String get playerLangHi;

  /// Name of a language, shown as the name of an audio or subtitle track
  ///
  /// In en, this message translates to:
  /// **'Japanese'**
  String get playerLangJa;

  /// Name of a language, shown as the name of an audio or subtitle track
  ///
  /// In en, this message translates to:
  /// **'Korean'**
  String get playerLangKo;

  /// Name of a language, shown as the name of an audio or subtitle track
  ///
  /// In en, this message translates to:
  /// **'Chinese'**
  String get playerLangZh;

  /// Name of a language, shown as the name of an audio or subtitle track
  ///
  /// In en, this message translates to:
  /// **'Greek'**
  String get playerLangEl;

  /// Name of a language, shown as the name of an audio or subtitle track
  ///
  /// In en, this message translates to:
  /// **'Swedish'**
  String get playerLangSv;

  /// Name of a language, shown as the name of an audio or subtitle track
  ///
  /// In en, this message translates to:
  /// **'Danish'**
  String get playerLangDa;

  /// Name of a language, shown as the name of an audio or subtitle track
  ///
  /// In en, this message translates to:
  /// **'Norwegian'**
  String get playerLangNo;

  /// Name of a language, shown as the name of an audio or subtitle track
  ///
  /// In en, this message translates to:
  /// **'Finnish'**
  String get playerLangFi;

  /// Name of a language, shown as the name of an audio or subtitle track
  ///
  /// In en, this message translates to:
  /// **'Hebrew'**
  String get playerLangHe;

  /// Name of a language, shown as the name of an audio or subtitle track
  ///
  /// In en, this message translates to:
  /// **'Romanian'**
  String get playerLangRo;

  /// Message shown in the car (Android Auto) when the app has not been set up on the phone yet
  ///
  /// In en, this message translates to:
  /// **'Open OpenIPTV on your phone to get started'**
  String get carLibrarySetup;

  /// Android Auto browse tab name for live channels
  ///
  /// In en, this message translates to:
  /// **'Live TV'**
  String get carLibraryLiveTv;

  /// Android Auto browse tab name for movies
  ///
  /// In en, this message translates to:
  /// **'Movies'**
  String get carLibraryMovies;

  /// Android Auto browse tab name for series
  ///
  /// In en, this message translates to:
  /// **'Series'**
  String get carLibrarySeries;

  /// Android Auto folder of favourite channels, movies or series
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get carLibraryFavorites;

  /// Android Auto folder of recently watched channels
  ///
  /// In en, this message translates to:
  /// **'Recently Watched'**
  String get carLibraryRecentlyWatched;

  /// Android Auto folder of movies or episodes in progress
  ///
  /// In en, this message translates to:
  /// **'Continue Watching'**
  String get carLibraryContinueWatching;

  /// Menu action and dialog title: rename a Live TV category
  ///
  /// In en, this message translates to:
  /// **'Rename Category'**
  String get categoryToolsRename;

  /// Menu action: move a category one place up the list
  ///
  /// In en, this message translates to:
  /// **'Move Up'**
  String get categoryToolsMoveUp;

  /// Menu action: move a category one place down the list
  ///
  /// In en, this message translates to:
  /// **'Move Down'**
  String get categoryToolsMoveDown;

  /// Menu action: go back to the original category name
  ///
  /// In en, this message translates to:
  /// **'Reset Name'**
  String get categoryToolsResetName;

  /// Menu action: hide a category from the list
  ///
  /// In en, this message translates to:
  /// **'Hide Category'**
  String get categoryToolsHide;

  /// Hint in the text field when renaming a category
  ///
  /// In en, this message translates to:
  /// **'Category name'**
  String get categoryToolsNameHint;

  /// Helper text under the rename field
  ///
  /// In en, this message translates to:
  /// **'Only changes how it looks here. Leave it empty to go back to the original name.'**
  String get categoryToolsRenameNote;

  /// Dialog button that saves the new name
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get categoryToolsSave;

  /// Menu action: remove a channel from the Recently Watched list
  ///
  /// In en, this message translates to:
  /// **'Remove from Recently Watched'**
  String get liveTvRemoveFromRecent;

  /// Title of the Live TV screen
  ///
  /// In en, this message translates to:
  /// **'Live TV'**
  String get liveTvTitle;

  /// Error shown when the channel list fails to load
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load channels. Check your internet connection.'**
  String get liveTvLoadError;

  /// Live TV row and category title for favorite channels
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get liveTvFavorites;

  /// Live TV row and category title for recently watched channels
  ///
  /// In en, this message translates to:
  /// **'Recently Watched'**
  String get liveTvRecentlyWatched;

  /// Heading above the list of Live TV categories
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get liveTvCategories;

  /// Category that lists every channel
  ///
  /// In en, this message translates to:
  /// **'All Channels'**
  String get liveTvAllChannels;

  /// Empty state when a category has no channels
  ///
  /// In en, this message translates to:
  /// **'No channels here yet.'**
  String get liveTvNoChannels;

  /// Menu action and dialog title: rename a channel
  ///
  /// In en, this message translates to:
  /// **'Rename Channel'**
  String get liveTvRenameChannel;

  /// Hint in the text field when renaming a channel
  ///
  /// In en, this message translates to:
  /// **'Channel name'**
  String get liveTvChannelNameHint;

  /// Snackbar after hiding a channel; the path names Settings screens, keep them in sync with the settings strings
  ///
  /// In en, this message translates to:
  /// **'Channel hidden. Bring it back in Settings → Watching → Channel Lists → Hidden Channels.'**
  String get liveTvChannelHidden;

  /// Tooltip on the history icon of a channel that offers catch-up (watching past programmes)
  ///
  /// In en, this message translates to:
  /// **'Catch-up available'**
  String get liveTvCatchupAvailable;

  /// Line under a channel showing the next programme; time is a clock time, title the programme name
  ///
  /// In en, this message translates to:
  /// **'Next  {time}  {title}'**
  String liveTvNextProgramme(String time, String title);

  /// Menu action / tooltip: remove a channel from favorites
  ///
  /// In en, this message translates to:
  /// **'Remove from Favorites'**
  String get liveTvRemoveFromFavorites;

  /// Menu action / tooltip: add a channel to favorites
  ///
  /// In en, this message translates to:
  /// **'Add to Favorites'**
  String get liveTvAddToFavorites;

  /// Menu action: undo a channel rename
  ///
  /// In en, this message translates to:
  /// **'Use the Original Name'**
  String get liveTvUseOriginalName;

  /// Menu action: choose which TV guide a channel uses
  ///
  /// In en, this message translates to:
  /// **'Change Guide'**
  String get liveTvChangeGuide;

  /// Menu action: hide a channel
  ///
  /// In en, this message translates to:
  /// **'Hide Channel'**
  String get liveTvHideChannel;

  /// Shown under a channel card when no programme information is available
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get liveTvLiveBadge;

  /// Snackbar when tapping a past programme that cannot be replayed
  ///
  /// In en, this message translates to:
  /// **'Catch-up is not available for this programme.'**
  String get epgPanelCatchupUnavailable;

  /// Day label in the programme panel for the current day
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get epgPanelToday;

  /// Error in the programme panel when the guide fails to load
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the TV guide. Your channels still work — guide info will retry automatically.'**
  String get epgPanelLoadError;

  /// Empty state in the programme panel
  ///
  /// In en, this message translates to:
  /// **'No guide information available for this day.'**
  String get epgPanelNoInfo;

  /// Small badge on the programme that is airing now; keep very short
  ///
  /// In en, this message translates to:
  /// **'LIVE'**
  String get epgPanelLiveBadge;

  /// Message in the TV guide when the selected category is parental-locked; OK is the remote button
  ///
  /// In en, this message translates to:
  /// **'This category is locked. Press OK on it to unlock it.'**
  String get tvGuideCategoryLocked;

  /// Shown over the guide preview when the provider rejects the stream (401/403)
  ///
  /// In en, this message translates to:
  /// **'Your provider didn\'t allow this stream.'**
  String get tvGuideStreamDenied;

  /// Shown over the guide preview when the channel cannot play
  ///
  /// In en, this message translates to:
  /// **'This channel isn\'t available right now.'**
  String get tvGuideChannelUnavailable;

  /// Hint over the guide preview area; OK is the remote button
  ///
  /// In en, this message translates to:
  /// **'Press OK to preview'**
  String get tvGuidePressOkToPreview;

  /// Guide cell / info line for a channel with no programme data
  ///
  /// In en, this message translates to:
  /// **'No guide information'**
  String get tvGuideNoInfo;

  /// Error when a search fails
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load search results. Try again.'**
  String get searchLoadError;

  /// Empty-state title; query is what the user typed
  ///
  /// In en, this message translates to:
  /// **'No results for \"{query}\"'**
  String searchNoResultsTitle(String query);

  /// Empty-state hint under "No results"
  ///
  /// In en, this message translates to:
  /// **'Check the spelling, or try a channel, a movie or a show name.'**
  String get searchNoResultsBody;

  /// Placeholder text in the search field
  ///
  /// In en, this message translates to:
  /// **'Search channels, movies and series'**
  String get searchHint;

  /// Title of the search screen before typing
  ///
  /// In en, this message translates to:
  /// **'Find something to watch'**
  String get searchWelcomeTitle;

  /// Hint on the search screen before typing
  ///
  /// In en, this message translates to:
  /// **'Search Live TV channels, movies, series — and what\'s on right now.'**
  String get searchWelcomeBody;

  /// Heading above the user's recent search chips
  ///
  /// In en, this message translates to:
  /// **'Recent searches'**
  String get searchRecentTitle;

  /// Button that clears the recent searches
  ///
  /// In en, this message translates to:
  /// **'Clear recent searches'**
  String get searchClearRecent;

  /// Prompt in the PIN dialog; label is the name of a locked channel, movie or series
  ///
  /// In en, this message translates to:
  /// **'Enter admin PIN to unlock \"{label}\"'**
  String searchEnterPinToUnlock(String label);

  /// Programme start in search results; time is a clock time
  ///
  /// In en, this message translates to:
  /// **'Tomorrow {time}'**
  String searchTomorrowAt(String time);

  /// Programme start in search results; time is a clock time
  ///
  /// In en, this message translates to:
  /// **'Yesterday {time}'**
  String searchYesterdayAt(String time);

  /// Row title: programmes airing right now
  ///
  /// In en, this message translates to:
  /// **'On now'**
  String get searchOnNow;

  /// Row title: matching channels
  ///
  /// In en, this message translates to:
  /// **'Live TV'**
  String get searchLiveTv;

  /// Subtitle under a channel result with no programme information
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get searchLive;

  /// Row title: programmes that start later
  ///
  /// In en, this message translates to:
  /// **'Coming up'**
  String get searchComingUp;

  /// Row title: programmes that already aired (catch-up)
  ///
  /// In en, this message translates to:
  /// **'Earlier'**
  String get searchEarlier;

  /// Row title: matching movies
  ///
  /// In en, this message translates to:
  /// **'Movies'**
  String get searchMovies;

  /// Row title: matching series
  ///
  /// In en, this message translates to:
  /// **'Series'**
  String get searchSeries;

  /// Button at the right of a row heading that opens the full list; keep short
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get mediaRailSeeAll;

  /// Card in a parental-locked row; tapping asks for the PIN
  ///
  /// In en, this message translates to:
  /// **'Enter PIN to view'**
  String get mediaRailEnterPin;

  /// Button that collapses a long synopsis
  ///
  /// In en, this message translates to:
  /// **'Less'**
  String get detailLess;

  /// Button that expands a long synopsis
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get detailMore;

  /// Cast line on a movie/series page; cast is a list of actor names
  ///
  /// In en, this message translates to:
  /// **'Starring  {cast}'**
  String detailStarring(String cast);

  /// Director line on a movie/series page; director is a name
  ///
  /// In en, this message translates to:
  /// **'Director  {director}'**
  String detailDirector(String director);

  /// Main button on a movie page to start playing
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get detailPlay;

  /// Main button on a movie page when partly watched; time is like 12:34
  ///
  /// In en, this message translates to:
  /// **'Resume from {time}'**
  String detailResumeFrom(String time);

  /// Round button label: play from the beginning
  ///
  /// In en, this message translates to:
  /// **'Start Over'**
  String get detailStartOver;

  /// Round button label when the title is already a favorite
  ///
  /// In en, this message translates to:
  /// **'Favorited'**
  String get detailFavorited;

  /// Round button label to add the title to favorites
  ///
  /// In en, this message translates to:
  /// **'Favorite'**
  String get detailFavorite;

  /// Button/menu action that forgets how much has been watched
  ///
  /// In en, this message translates to:
  /// **'Clear Progress'**
  String get detailClearProgress;

  /// Row title: similar movies or series
  ///
  /// In en, this message translates to:
  /// **'More Like This'**
  String get detailMoreLikeThis;

  /// Retry button on the movie/series error screen; goes back
  ///
  /// In en, this message translates to:
  /// **'Go Back'**
  String get detailGoBack;

  /// Error on the movie page
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load this movie. Try again.'**
  String get detailMovieLoadError;

  /// Error on the series page
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load this series. Try again.'**
  String get detailSeriesLoadError;

  /// Main button text on a series page while episodes load
  ///
  /// In en, this message translates to:
  /// **'Loading episodes…'**
  String get seriesLoadingEpisodes;

  /// Main button text on a series page with no episodes
  ///
  /// In en, this message translates to:
  /// **'No episodes yet'**
  String get seriesNoEpisodesYet;

  /// Main button: continue an episode; label is like "S1 E2"
  ///
  /// In en, this message translates to:
  /// **'Resume {label}'**
  String seriesResumeEpisode(String label);

  /// Main button: play an episode; label is like "S1 E2"
  ///
  /// In en, this message translates to:
  /// **'Play {label}'**
  String seriesPlayEpisode(String label);

  /// Short episode label, S = season, E = episode; numbers are integers
  ///
  /// In en, this message translates to:
  /// **'S{season} E{episode}'**
  String seriesShortEpisode(int episode, int season);

  /// Number of seasons in the series info line
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} Season} other{{count} Seasons}}'**
  String seriesSeasonCount(int count);

  /// Heading above the next episode to watch
  ///
  /// In en, this message translates to:
  /// **'Up Next'**
  String get seriesUpNext;

  /// Heading above the list of episodes
  ///
  /// In en, this message translates to:
  /// **'Episodes'**
  String get seriesEpisodes;

  /// Empty state under the season picker
  ///
  /// In en, this message translates to:
  /// **'No episodes available yet.'**
  String get seriesNoEpisodesAvailable;

  /// Season chip label
  ///
  /// In en, this message translates to:
  /// **'Season {number}'**
  String seriesSeason(int number);

  /// Row title for the user's favorite movies or series
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get detailFavorites;

  /// Row title for partly watched movies or episodes
  ///
  /// In en, this message translates to:
  /// **'Continue Watching'**
  String get detailContinueWatching;

  /// Heading above the compact list of genres
  ///
  /// In en, this message translates to:
  /// **'Browse by Genre'**
  String get detailBrowseByGenre;

  /// First entry in the genre list, meaning every title
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get detailAllGenre;

  /// Menu action / tooltip: add a movie or series to favorites
  ///
  /// In en, this message translates to:
  /// **'Add to Favorites'**
  String get detailAddToFavorites;

  /// Menu action / tooltip: remove a movie or series from favorites
  ///
  /// In en, this message translates to:
  /// **'Remove from Favorites'**
  String get detailRemoveFromFavorites;

  /// Menu action: remove an item from the Continue Watching row
  ///
  /// In en, this message translates to:
  /// **'Remove from Continue Watching'**
  String get detailRemoveFromContinueWatching;

  /// Title of the Movies screen
  ///
  /// In en, this message translates to:
  /// **'Movies'**
  String get moviesTitle;

  /// Error when the movie list fails to load
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load movies. Try again.'**
  String get moviesLoadError;

  /// Row/screen title listing every movie
  ///
  /// In en, this message translates to:
  /// **'All Movies'**
  String get moviesAll;

  /// Empty state for a movie genre
  ///
  /// In en, this message translates to:
  /// **'No movies found.'**
  String get moviesNoneFound;

  /// Title of the Series screen
  ///
  /// In en, this message translates to:
  /// **'Series'**
  String get seriesTitle;

  /// Error when the series list fails to load
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load series. Try again.'**
  String get seriesLoadError;

  /// Row/screen title listing every series
  ///
  /// In en, this message translates to:
  /// **'All Series'**
  String get seriesAll;

  /// Empty state for a series genre
  ///
  /// In en, this message translates to:
  /// **'No series found.'**
  String get seriesNoneFound;

  /// Snackbar on the TV/phone home screen after the first Back press; a second Back within two seconds leaves the app
  ///
  /// In en, this message translates to:
  /// **'Press Back again to exit'**
  String get shellPressBackAgain;

  /// Navigation bar / TV side rail label for the live channels tab (keep short)
  ///
  /// In en, this message translates to:
  /// **'Live TV'**
  String get navLiveTv;

  /// Navigation label for the movies tab (keep short)
  ///
  /// In en, this message translates to:
  /// **'Movies'**
  String get navMovies;

  /// Navigation label for the TV series tab (keep short)
  ///
  /// In en, this message translates to:
  /// **'Series'**
  String get navSeries;

  /// Navigation label for the search tab (keep short)
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get navSearch;

  /// Navigation label for the settings tab (keep short)
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// Snackbar after pull-to-refresh failed for one playlist. {name} is the playlist's name, {reason} is a full sentence explaining why
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t refresh {name}. {reason}'**
  String pullRefreshOne(String name, String reason);

  /// Snackbar after pull-to-refresh failed for several playlists. {names} is a comma-separated list of playlist names
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t refresh {names}. Try again later.'**
  String pullRefreshMany(String names);

  /// Title of the bottom-sheet action that hides a genre (category) for the current profile
  ///
  /// In en, this message translates to:
  /// **'Hide Genre'**
  String get genreActionsHideGenre;

  /// Message in the file list dialog (used on TVs without a system file picker) when no matching file exists. Keep the folder paths exactly as written
  ///
  /// In en, this message translates to:
  /// **'No files found on this device. Copy the file to the Download folder, or to Android/data/com.openiptv.app/files, then try again.'**
  String get filePickerNoFiles;

  /// Screen-reader label of the star button when the item is already a favorite
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get starRemoveFavorite;

  /// Screen-reader label of the star button when the item is not yet a favorite
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get starAddFavorite;

  /// Runtime of exactly whole hours, e.g. 2h. Short unit
  ///
  /// In en, this message translates to:
  /// **'{hours}h'**
  String formatRuntimeHours(int hours);

  /// Runtime under an hour, e.g. 45m. {minutes} may be zero-padded text such as 05
  ///
  /// In en, this message translates to:
  /// **'{minutes}m'**
  String formatRuntimeMinutes(String minutes);

  /// Runtime with hours and minutes, e.g. 1h 5m. {minutes} may be zero-padded text such as 05
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes}m'**
  String formatRuntimeHoursMinutes(int hours, String minutes);

  /// Appended to a cleaned-up channel name for a live event that has ended
  ///
  /// In en, this message translates to:
  /// **'Ended'**
  String get formatStateEnded;

  /// Appended to a cleaned-up channel name for a live event that comes next
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get formatStateNext;

  /// Appended to a cleaned-up channel name for an event that is live now
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get formatStateLive;

  /// Appended to a cleaned-up channel name for an event that has not started yet
  ///
  /// In en, this message translates to:
  /// **'Not started'**
  String get formatStateNotStarted;

  /// Shown in brackets after a channel name that the provider blocks outside certain countries
  ///
  /// In en, this message translates to:
  /// **'Geo-blocked'**
  String get formatGeoBlocked;
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
