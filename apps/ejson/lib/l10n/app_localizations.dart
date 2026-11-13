import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
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
    Locale('zh'),
  ];

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saveAs.
  ///
  /// In en, this message translates to:
  /// **'Save As'**
  String get saveAs;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @redo.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get redo;

  /// No description provided for @minify.
  ///
  /// In en, this message translates to:
  /// **'Minify'**
  String get minify;

  /// No description provided for @format.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get format;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @systemTheme.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get systemTheme;

  /// No description provided for @lightTheme.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get lightTheme;

  /// No description provided for @darkTheme.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get darkTheme;

  /// No description provided for @glassToolbar.
  ///
  /// In en, this message translates to:
  /// **'Glass toolbar'**
  String get glassToolbar;

  /// No description provided for @systemLanguage.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get systemLanguage;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @simplifiedChinese.
  ///
  /// In en, this message translates to:
  /// **'简体中文'**
  String get simplifiedChinese;

  /// No description provided for @newTab.
  ///
  /// In en, this message translates to:
  /// **'New tab'**
  String get newTab;

  /// No description provided for @closeTab.
  ///
  /// In en, this message translates to:
  /// **'Close {name}'**
  String closeTab(String name);

  /// No description provided for @untitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get untitled;

  /// No description provided for @numberedUntitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled {number}'**
  String numberedUntitled(int number);

  /// No description provided for @source.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get source;

  /// No description provided for @jsonTree.
  ///
  /// In en, this message translates to:
  /// **'JSON tree'**
  String get jsonTree;

  /// No description provided for @previousRevision.
  ///
  /// In en, this message translates to:
  /// **'Previous valid revision'**
  String get previousRevision;

  /// No description provided for @largeFile.
  ///
  /// In en, this message translates to:
  /// **'Large file · read-only'**
  String get largeFile;

  /// No description provided for @emptyDocument.
  ///
  /// In en, this message translates to:
  /// **'Empty document'**
  String get emptyDocument;

  /// No description provided for @checking.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get checking;

  /// No description provided for @validJson.
  ///
  /// In en, this message translates to:
  /// **'Valid JSON'**
  String get validJson;

  /// No description provided for @warningAt.
  ///
  /// In en, this message translates to:
  /// **'Warning at {line}:{column}  {message}'**
  String warningAt(int line, int column, String message);

  /// No description provided for @errorAt.
  ///
  /// In en, this message translates to:
  /// **'Error at {line}:{column}  {message}'**
  String errorAt(int line, int column, String message);

  /// No description provided for @treeLargeFile.
  ///
  /// In en, this message translates to:
  /// **'Tree disabled for large files'**
  String get treeLargeFile;

  /// No description provided for @treeEmpty.
  ///
  /// In en, this message translates to:
  /// **'Enter valid JSON to show the tree'**
  String get treeEmpty;

  /// No description provided for @treeLimit.
  ///
  /// In en, this message translates to:
  /// **'Showing the first 10,000 visible nodes'**
  String get treeLimit;

  /// No description provided for @rootNode.
  ///
  /// In en, this message translates to:
  /// **'root'**
  String get rootNode;

  /// No description provided for @collapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get collapse;

  /// No description provided for @expand.
  ///
  /// In en, this message translates to:
  /// **'Expand'**
  String get expand;

  /// No description provided for @editNode.
  ///
  /// In en, this message translates to:
  /// **'Edit node'**
  String get editNode;

  /// No description provided for @nodeActions.
  ///
  /// In en, this message translates to:
  /// **'Node actions'**
  String get nodeActions;

  /// No description provided for @focusSubtree.
  ///
  /// In en, this message translates to:
  /// **'Focus subtree'**
  String get focusSubtree;

  /// No description provided for @replaceValue.
  ///
  /// In en, this message translates to:
  /// **'Replace value'**
  String get replaceValue;

  /// No description provided for @replaceJsonValue.
  ///
  /// In en, this message translates to:
  /// **'Replace JSON value'**
  String get replaceJsonValue;

  /// No description provided for @renameKey.
  ///
  /// In en, this message translates to:
  /// **'Rename key'**
  String get renameKey;

  /// No description provided for @goToParent.
  ///
  /// In en, this message translates to:
  /// **'Go to parent'**
  String get goToParent;

  /// No description provided for @backToRoot.
  ///
  /// In en, this message translates to:
  /// **'Back to root'**
  String get backToRoot;

  /// No description provided for @saveBeforeQuit.
  ///
  /// In en, this message translates to:
  /// **'Save changes before quitting?'**
  String get saveBeforeQuit;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes?'**
  String get saveChanges;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @openFailed.
  ///
  /// In en, this message translates to:
  /// **'Open failed · {detail}'**
  String openFailed(String detail);

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed · {detail}'**
  String saveFailed(String detail);

  /// No description provided for @fileAlreadyOpen.
  ///
  /// In en, this message translates to:
  /// **'That file is already open in another tab.'**
  String get fileAlreadyOpen;

  /// No description provided for @staleNode.
  ///
  /// In en, this message translates to:
  /// **'The document changed. Select the node again.'**
  String get staleNode;

  /// No description provided for @quotedString.
  ///
  /// In en, this message translates to:
  /// **'Enter a quoted JSON string.'**
  String get quotedString;

  /// No description provided for @fileChanged.
  ///
  /// In en, this message translates to:
  /// **'The file changed on disk. Use Save As to keep your edits.'**
  String get fileChanged;

  /// No description provided for @fileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Files larger than 16 MiB cannot be opened.'**
  String get fileTooLarge;

  /// No description provided for @saveTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The document exceeds the 16 MiB file limit.'**
  String get saveTooLarge;

  /// No description provided for @filePermissions.
  ///
  /// In en, this message translates to:
  /// **'Could not preserve file permissions.'**
  String get filePermissions;

  /// No description provided for @invalidEncoding.
  ///
  /// In en, this message translates to:
  /// **'The file is not valid UTF-8.'**
  String get invalidEncoding;

  /// No description provided for @trailingContent.
  ///
  /// In en, this message translates to:
  /// **'Unexpected text after the JSON value.'**
  String get trailingContent;

  /// No description provided for @depthLimit.
  ///
  /// In en, this message translates to:
  /// **'JSON nesting exceeds 256 levels.'**
  String get depthLimit;

  /// No description provided for @expectedValue.
  ///
  /// In en, this message translates to:
  /// **'Expected a JSON value.'**
  String get expectedValue;

  /// No description provided for @expectedKey.
  ///
  /// In en, this message translates to:
  /// **'Expected a quoted property name.'**
  String get expectedKey;

  /// No description provided for @duplicateKey.
  ///
  /// In en, this message translates to:
  /// **'Duplicate property name.'**
  String get duplicateKey;

  /// No description provided for @expectedColon.
  ///
  /// In en, this message translates to:
  /// **'Expected a colon after the property name.'**
  String get expectedColon;

  /// No description provided for @expectedObjectDelimiter.
  ///
  /// In en, this message translates to:
  /// **'Expected a comma or closing brace.'**
  String get expectedObjectDelimiter;

  /// No description provided for @expectedArrayDelimiter.
  ///
  /// In en, this message translates to:
  /// **'Expected a comma or closing bracket.'**
  String get expectedArrayDelimiter;

  /// No description provided for @invalidLiteral.
  ///
  /// In en, this message translates to:
  /// **'Expected {token}.'**
  String invalidLiteral(String token);

  /// No description provided for @unclosedString.
  ///
  /// In en, this message translates to:
  /// **'Expected a closing quote.'**
  String get unclosedString;

  /// No description provided for @controlCharacter.
  ///
  /// In en, this message translates to:
  /// **'Escape control characters inside strings.'**
  String get controlCharacter;

  /// No description provided for @invalidUnicodeEscape.
  ///
  /// In en, this message translates to:
  /// **'Expected four hexadecimal digits after the Unicode escape prefix.'**
  String get invalidUnicodeEscape;

  /// No description provided for @invalidEscape.
  ///
  /// In en, this message translates to:
  /// **'Invalid string escape.'**
  String get invalidEscape;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @jsonHighlight.
  ///
  /// In en, this message translates to:
  /// **'JSON highlighting'**
  String get jsonHighlight;

  /// No description provided for @highlightMonochrome.
  ///
  /// In en, this message translates to:
  /// **'Monochrome'**
  String get highlightMonochrome;

  /// No description provided for @highlightAccessibility.
  ///
  /// In en, this message translates to:
  /// **'Accessibility'**
  String get highlightAccessibility;

  /// No description provided for @treeStyle.
  ///
  /// In en, this message translates to:
  /// **'JSON tree style'**
  String get treeStyle;

  /// No description provided for @treeStyleClassic.
  ///
  /// In en, this message translates to:
  /// **'Classic'**
  String get treeStyleClassic;

  /// No description provided for @treeStyleColor.
  ///
  /// In en, this message translates to:
  /// **'Color by type'**
  String get treeStyleColor;

  /// No description provided for @treeStyleStriped.
  ///
  /// In en, this message translates to:
  /// **'Striped rows'**
  String get treeStyleStriped;

  /// No description provided for @treeStyleCompact.
  ///
  /// In en, this message translates to:
  /// **'Compact'**
  String get treeStyleCompact;

  /// No description provided for @treeStyleOutline.
  ///
  /// In en, this message translates to:
  /// **'Outline'**
  String get treeStyleOutline;

  /// No description provided for @startup.
  ///
  /// In en, this message translates to:
  /// **'Startup'**
  String get startup;

  /// No description provided for @restoreWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Restore last workspace on startup'**
  String get restoreWorkspace;

  /// No description provided for @restoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not reopen some files'**
  String get restoreFailed;

  /// No description provided for @workspaceSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not remember the workspace for next launch.'**
  String get workspaceSaveFailed;

  /// No description provided for @workspacePreferenceFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the startup setting.'**
  String get workspacePreferenceFailed;

  /// No description provided for @unsavedChangesDescription.
  ///
  /// In en, this message translates to:
  /// **'Unsaved changes will be lost if you discard them.'**
  String get unsavedChangesDescription;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About EJson'**
  String get about;

  /// No description provided for @versionLabel.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String versionLabel(String version);

  /// No description provided for @checkUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get checkUpdates;

  /// No description provided for @checkingUpdates.
  ///
  /// In en, this message translates to:
  /// **'Checking for updates…'**
  String get checkingUpdates;

  /// No description provided for @updateCurrent.
  ///
  /// In en, this message translates to:
  /// **'You’re on the latest version.'**
  String get updateCurrent;

  /// No description provided for @updateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Version {version} is available.'**
  String updateAvailable(String version);

  /// No description provided for @noRelease.
  ///
  /// In en, this message translates to:
  /// **'No stable release has been published yet.'**
  String get noRelease;

  /// No description provided for @updateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not check for updates. Try again later.'**
  String get updateFailed;

  /// No description provided for @downloadRelease.
  ///
  /// In en, this message translates to:
  /// **'View release'**
  String get downloadRelease;

  /// No description provided for @buyCoffee.
  ///
  /// In en, this message translates to:
  /// **'Buy me a coffee'**
  String get buyCoffee;

  /// No description provided for @browserFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the browser.'**
  String get browserFailed;
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
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
