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

  /// No description provided for @compareDocuments.
  ///
  /// In en, this message translates to:
  /// **'Compare JSON documents'**
  String get compareDocuments;

  /// No description provided for @comparisonBefore.
  ///
  /// In en, this message translates to:
  /// **'Before'**
  String get comparisonBefore;

  /// No description provided for @comparisonAfter.
  ///
  /// In en, this message translates to:
  /// **'After'**
  String get comparisonAfter;

  /// No description provided for @comparisonSwap.
  ///
  /// In en, this message translates to:
  /// **'Swap comparison sides'**
  String get comparisonSwap;

  /// No description provided for @comparisonEmpty.
  ///
  /// In en, this message translates to:
  /// **'The structures match.'**
  String get comparisonEmpty;

  /// No description provided for @comparisonLimit.
  ///
  /// In en, this message translates to:
  /// **'Showing the first 1,000 differences.'**
  String get comparisonLimit;

  /// No description provided for @comparisonFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not compare these documents.'**
  String get comparisonFailed;

  /// No description provided for @comparisonAdded.
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get comparisonAdded;

  /// No description provided for @comparisonRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed'**
  String get comparisonRemoved;

  /// No description provided for @comparisonChanged.
  ///
  /// In en, this message translates to:
  /// **'Changed'**
  String get comparisonChanged;

  /// No description provided for @comparisonMissing.
  ///
  /// In en, this message translates to:
  /// **'No corresponding node'**
  String get comparisonMissing;

  /// No description provided for @goToJsonPath.
  ///
  /// In en, this message translates to:
  /// **'Go to JSONPath'**
  String get goToJsonPath;

  /// No description provided for @goToNode.
  ///
  /// In en, this message translates to:
  /// **'Go to node'**
  String get goToNode;

  /// No description provided for @invalidJsonPath.
  ///
  /// In en, this message translates to:
  /// **'Enter a single JSONPath such as \$.items[0].'**
  String get invalidJsonPath;

  /// No description provided for @missingJsonPath.
  ///
  /// In en, this message translates to:
  /// **'This path does not exist in the document.'**
  String get missingJsonPath;

  /// No description provided for @ambiguousJsonPath.
  ///
  /// In en, this message translates to:
  /// **'This path matches duplicate keys.'**
  String get ambiguousJsonPath;

  /// No description provided for @findInDocument.
  ///
  /// In en, this message translates to:
  /// **'Find in document'**
  String get findInDocument;

  /// No description provided for @searchSource.
  ///
  /// In en, this message translates to:
  /// **'Source text'**
  String get searchSource;

  /// No description provided for @searchKeys.
  ///
  /// In en, this message translates to:
  /// **'Keys'**
  String get searchKeys;

  /// No description provided for @searchValues.
  ///
  /// In en, this message translates to:
  /// **'Values'**
  String get searchValues;

  /// No description provided for @noMatches.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get noMatches;

  /// No description provided for @previousMatch.
  ///
  /// In en, this message translates to:
  /// **'Previous match'**
  String get previousMatch;

  /// No description provided for @nextMatch.
  ///
  /// In en, this message translates to:
  /// **'Next match'**
  String get nextMatch;

  /// No description provided for @closeFind.
  ///
  /// In en, this message translates to:
  /// **'Close find'**
  String get closeFind;

  /// No description provided for @findNeedsValidJson.
  ///
  /// In en, this message translates to:
  /// **'Key and value search needs valid JSON.'**
  String get findNeedsValidJson;

  /// No description provided for @addProperty.
  ///
  /// In en, this message translates to:
  /// **'Add property'**
  String get addProperty;

  /// No description provided for @addArrayItem.
  ///
  /// In en, this message translates to:
  /// **'Add array item'**
  String get addArrayItem;

  /// No description provided for @propertyName.
  ///
  /// In en, this message translates to:
  /// **'Property name'**
  String get propertyName;

  /// No description provided for @deleteNode.
  ///
  /// In en, this message translates to:
  /// **'Delete node'**
  String get deleteNode;

  /// No description provided for @copyJsonPath.
  ///
  /// In en, this message translates to:
  /// **'Copy JSONPath'**
  String get copyJsonPath;

  /// No description provided for @jsonPathCopied.
  ///
  /// In en, this message translates to:
  /// **'JSONPath copied'**
  String get jsonPathCopied;

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

  /// No description provided for @closeTabMenu.
  ///
  /// In en, this message translates to:
  /// **'Close Tab'**
  String get closeTabMenu;

  /// No description provided for @closeTab.
  ///
  /// In en, this message translates to:
  /// **'Close {name}'**
  String closeTab(String name);

  /// No description provided for @revealInFolder.
  ///
  /// In en, this message translates to:
  /// **'Show in Folder'**
  String get revealInFolder;

  /// No description provided for @revealInFinder.
  ///
  /// In en, this message translates to:
  /// **'Show in Finder'**
  String get revealInFinder;

  /// No description provided for @revealFileMissing.
  ///
  /// In en, this message translates to:
  /// **'The file no longer exists. Its original folder was opened.'**
  String get revealFileMissing;

  /// No description provided for @revealFolderMissing.
  ///
  /// In en, this message translates to:
  /// **'The folder containing the file could not be found.'**
  String get revealFolderMissing;

  /// No description provided for @revealFolderFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the file manager.'**
  String get revealFolderFailed;

  /// No description provided for @copyFilePath.
  ///
  /// In en, this message translates to:
  /// **'Copy File Path'**
  String get copyFilePath;

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

  /// No description provided for @sourcePreviousPage.
  ///
  /// In en, this message translates to:
  /// **'Previous source page'**
  String get sourcePreviousPage;

  /// No description provided for @sourceNextPage.
  ///
  /// In en, this message translates to:
  /// **'Next source page'**
  String get sourceNextPage;

  /// No description provided for @sourceGoToPage.
  ///
  /// In en, this message translates to:
  /// **'Go to source page'**
  String get sourceGoToPage;

  /// No description provided for @sourcePage.
  ///
  /// In en, this message translates to:
  /// **'Page {page} of {total}'**
  String sourcePage(int page, int total);

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

  /// No description provided for @restoreFailedDescription.
  ///
  /// In en, this message translates to:
  /// **'These files were part of the previous workspace. Their location may have changed, access may have been denied, or they may no longer be readable.'**
  String get restoreFailedDescription;

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

  /// No description provided for @replaceText.
  ///
  /// In en, this message translates to:
  /// **'Replace with'**
  String get replaceText;

  /// No description provided for @replace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get replace;

  /// No description provided for @replaceCurrent.
  ///
  /// In en, this message translates to:
  /// **'Replace current'**
  String get replaceCurrent;

  /// No description provided for @replaceAll.
  ///
  /// In en, this message translates to:
  /// **'Replace all'**
  String get replaceAll;

  /// No description provided for @matchCase.
  ///
  /// In en, this message translates to:
  /// **'Match case'**
  String get matchCase;

  /// No description provided for @useRegex.
  ///
  /// In en, this message translates to:
  /// **'Regular expression'**
  String get useRegex;

  /// No description provided for @invalidRegex.
  ///
  /// In en, this message translates to:
  /// **'Invalid regular expression'**
  String get invalidRegex;

  /// No description provided for @escapeJson.
  ///
  /// In en, this message translates to:
  /// **'Escape as JSON string'**
  String get escapeJson;

  /// No description provided for @unescapeJson.
  ///
  /// In en, this message translates to:
  /// **'Unescape JSON string'**
  String get unescapeJson;

  /// No description provided for @unescapeFailed.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid, double-quoted JSON string.'**
  String get unescapeFailed;

  /// No description provided for @extractSubtree.
  ///
  /// In en, this message translates to:
  /// **'Extract to new tab'**
  String get extractSubtree;

  /// No description provided for @arrayTable.
  ///
  /// In en, this message translates to:
  /// **'Array table'**
  String get arrayTable;

  /// No description provided for @copyNodeValue.
  ///
  /// In en, this message translates to:
  /// **'Copy JSON value'**
  String get copyNodeValue;

  /// No description provided for @copyDecodedString.
  ///
  /// In en, this message translates to:
  /// **'Copy string contents'**
  String get copyDecodedString;

  /// No description provided for @valueCopied.
  ///
  /// In en, this message translates to:
  /// **'Node value copied'**
  String get valueCopied;

  /// No description provided for @filterRows.
  ///
  /// In en, this message translates to:
  /// **'Filter rows'**
  String get filterRows;

  /// No description provided for @emptyArray.
  ///
  /// In en, this message translates to:
  /// **'The array is empty'**
  String get emptyArray;

  /// No description provided for @exportCsv.
  ///
  /// In en, this message translates to:
  /// **'Export CSV'**
  String get exportCsv;

  /// No description provided for @csvExported.
  ///
  /// In en, this message translates to:
  /// **'CSV exported'**
  String get csvExported;

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed'**
  String get exportFailed;

  /// No description provided for @tableInstructions.
  ///
  /// In en, this message translates to:
  /// **'Click a column header to sort, or a cell to copy its contents. Export uses the current filter and sort order.'**
  String get tableInstructions;

  /// No description provided for @tableRowCount.
  ///
  /// In en, this message translates to:
  /// **'{visible} / {total} rows'**
  String tableRowCount(int visible, int total);

  /// No description provided for @nodeCount.
  ///
  /// In en, this message translates to:
  /// **'{count} nodes'**
  String nodeCount(int count);

  /// No description provided for @documentBytes.
  ///
  /// In en, this message translates to:
  /// **'{bytes} bytes'**
  String documentBytes(int bytes);

  /// No description provided for @documentStatistics.
  ///
  /// In en, this message translates to:
  /// **'{bytes} bytes · {nodes} nodes · Maximum depth {depth} (root is 0) · Longest array {arrayLength} items'**
  String documentStatistics(int bytes, int nodes, int depth, int arrayLength);

  /// No description provided for @jsonQuery.
  ///
  /// In en, this message translates to:
  /// **'JSONPath query'**
  String get jsonQuery;

  /// No description provided for @runQuery.
  ///
  /// In en, this message translates to:
  /// **'Run query'**
  String get runQuery;

  /// No description provided for @queryRunning.
  ///
  /// In en, this message translates to:
  /// **'Running query…'**
  String get queryRunning;

  /// No description provided for @jsonQueryFailed.
  ///
  /// In en, this message translates to:
  /// **'The query failed. Try again.'**
  String get jsonQueryFailed;

  /// No description provided for @invalidJsonQuery.
  ///
  /// In en, this message translates to:
  /// **'Invalid or unsupported JSONPath syntax near character {position}.'**
  String invalidJsonQuery(int position);

  /// No description provided for @jsonQueryHelp.
  ///
  /// In en, this message translates to:
  /// **'Supports fields, array indices, * wildcards and [?condition] filters. Conditions support @ paths, existence, scalar comparisons, &&, || and !. Click a result to reveal its source.'**
  String get jsonQueryHelp;

  /// No description provided for @queryResultCount.
  ///
  /// In en, this message translates to:
  /// **'{count} results'**
  String queryResultCount(int count);

  /// No description provided for @extractQueryResults.
  ///
  /// In en, this message translates to:
  /// **'Extract results to new tab'**
  String get extractQueryResults;

  /// No description provided for @goToSource.
  ///
  /// In en, this message translates to:
  /// **'Reveal in source'**
  String get goToSource;

  /// No description provided for @captureReplacementHelp.
  ///
  /// In en, this message translates to:
  /// **'\$1 and \$2 insert capture groups. \$\$ inserts a dollar sign.'**
  String get captureReplacementHelp;

  /// No description provided for @formatIndentation.
  ///
  /// In en, this message translates to:
  /// **'Format indentation'**
  String get formatIndentation;

  /// No description provided for @indentTwo.
  ///
  /// In en, this message translates to:
  /// **'2 spaces'**
  String get indentTwo;

  /// No description provided for @indentFour.
  ///
  /// In en, this message translates to:
  /// **'4 spaces'**
  String get indentFour;

  /// No description provided for @indentEight.
  ///
  /// In en, this message translates to:
  /// **'8 spaces'**
  String get indentEight;

  /// No description provided for @indentTabs.
  ///
  /// In en, this message translates to:
  /// **'Tabs'**
  String get indentTabs;

  /// No description provided for @lineEnding.
  ///
  /// In en, this message translates to:
  /// **'Line endings'**
  String get lineEnding;

  /// No description provided for @preserveLineEnding.
  ///
  /// In en, this message translates to:
  /// **'Preserve existing'**
  String get preserveLineEnding;

  /// No description provided for @toolPreferenceFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save preferences. Try again.'**
  String get toolPreferenceFailed;

  /// No description provided for @saveQuery.
  ///
  /// In en, this message translates to:
  /// **'Save query'**
  String get saveQuery;

  /// No description provided for @unsaveQuery.
  ///
  /// In en, this message translates to:
  /// **'Unsave query'**
  String get unsaveQuery;

  /// No description provided for @savedQueries.
  ///
  /// In en, this message translates to:
  /// **'Saved queries'**
  String get savedQueries;

  /// No description provided for @noSavedQueries.
  ///
  /// In en, this message translates to:
  /// **'No saved queries'**
  String get noSavedQueries;

  /// No description provided for @moveArrayItemUp.
  ///
  /// In en, this message translates to:
  /// **'Move array item up'**
  String get moveArrayItemUp;

  /// No description provided for @moveArrayItemDown.
  ///
  /// In en, this message translates to:
  /// **'Move array item down'**
  String get moveArrayItemDown;

  /// No description provided for @duplicateArrayItem.
  ///
  /// In en, this message translates to:
  /// **'Duplicate array item'**
  String get duplicateArrayItem;

  /// No description provided for @sortArray.
  ///
  /// In en, this message translates to:
  /// **'Sort array'**
  String get sortArray;

  /// No description provided for @sortField.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get sortField;

  /// No description provided for @sortValue.
  ///
  /// In en, this message translates to:
  /// **'Element value'**
  String get sortValue;

  /// No description provided for @sortAscending.
  ///
  /// In en, this message translates to:
  /// **'Ascending'**
  String get sortAscending;

  /// No description provided for @sortDescending.
  ///
  /// In en, this message translates to:
  /// **'Descending'**
  String get sortDescending;

  /// No description provided for @sortArrayHelp.
  ///
  /// In en, this message translates to:
  /// **'Items with missing fields stay last. Equal values retain their order.'**
  String get sortArrayHelp;

  /// No description provided for @sortArrayAmbiguous.
  ///
  /// In en, this message translates to:
  /// **'The sort field has duplicate keys. Choose another field.'**
  String get sortArrayAmbiguous;

  /// No description provided for @readingDisplay.
  ///
  /// In en, this message translates to:
  /// **'Reading display'**
  String get readingDisplay;

  /// No description provided for @readingFont.
  ///
  /// In en, this message translates to:
  /// **'Reading font'**
  String get readingFont;

  /// No description provided for @fontSize.
  ///
  /// In en, this message translates to:
  /// **'Font size'**
  String get fontSize;

  /// No description provided for @decreaseFontSize.
  ///
  /// In en, this message translates to:
  /// **'Decrease font size'**
  String get decreaseFontSize;

  /// No description provided for @increaseFontSize.
  ///
  /// In en, this message translates to:
  /// **'Increase font size'**
  String get increaseFontSize;

  /// No description provided for @lineSpacing.
  ///
  /// In en, this message translates to:
  /// **'Line spacing'**
  String get lineSpacing;

  /// No description provided for @spacingCompact.
  ///
  /// In en, this message translates to:
  /// **'Compact'**
  String get spacingCompact;

  /// No description provided for @spacingStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get spacingStandard;

  /// No description provided for @spacingSpacious.
  ///
  /// In en, this message translates to:
  /// **'Spacious'**
  String get spacingSpacious;

  /// No description provided for @readingPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get readingPreview;

  /// No description provided for @resetReading.
  ///
  /// In en, this message translates to:
  /// **'Reset to defaults'**
  String get resetReading;

  /// No description provided for @defaultReadingFont.
  ///
  /// In en, this message translates to:
  /// **'Default monospace font'**
  String get defaultReadingFont;

  /// No description provided for @searchFonts.
  ///
  /// In en, this message translates to:
  /// **'Search installed fonts'**
  String get searchFonts;

  /// No description provided for @refreshFonts.
  ///
  /// In en, this message translates to:
  /// **'Refresh fonts'**
  String get refreshFonts;

  /// No description provided for @monospaceFont.
  ///
  /// In en, this message translates to:
  /// **'Monospace'**
  String get monospaceFont;

  /// No description provided for @fontListFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load fonts. Retry.'**
  String get fontListFailed;

  /// No description provided for @noMatchingFonts.
  ///
  /// In en, this message translates to:
  /// **'No matching fonts'**
  String get noMatchingFonts;

  /// No description provided for @fontUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The font “{name}” is unavailable. Using the default font.'**
  String fontUnavailable(String name);

  /// No description provided for @recentFiles.
  ///
  /// In en, this message translates to:
  /// **'Recent files'**
  String get recentFiles;

  /// No description provided for @searchRecentFiles.
  ///
  /// In en, this message translates to:
  /// **'Search file names or paths'**
  String get searchRecentFiles;

  /// No description provided for @noRecentFiles.
  ///
  /// In en, this message translates to:
  /// **'No recent files'**
  String get noRecentFiles;

  /// No description provided for @removeRecentFile.
  ///
  /// In en, this message translates to:
  /// **'Remove from recent files'**
  String get removeRecentFile;

  /// No description provided for @clearRecentFiles.
  ///
  /// In en, this message translates to:
  /// **'Clear recent files'**
  String get clearRecentFiles;

  /// No description provided for @recentSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'The file was opened or saved, but recent files could not be recorded.'**
  String get recentSaveFailed;

  /// No description provided for @commandPalette.
  ///
  /// In en, this message translates to:
  /// **'Command palette'**
  String get commandPalette;

  /// No description provided for @searchCommands.
  ///
  /// In en, this message translates to:
  /// **'Search commands…'**
  String get searchCommands;

  /// No description provided for @noMatchingCommands.
  ///
  /// In en, this message translates to:
  /// **'No matching commands'**
  String get noMatchingCommands;

  /// No description provided for @commandKeyboardHelp.
  ///
  /// In en, this message translates to:
  /// **'↑↓ Select  ·  Enter Run  ·  Esc Close'**
  String get commandKeyboardHelp;

  /// No description provided for @dropFilesToOpen.
  ///
  /// In en, this message translates to:
  /// **'Drop files to open'**
  String get dropFilesToOpen;

  /// No description provided for @noDroppedFiles.
  ///
  /// In en, this message translates to:
  /// **'The drop contains no local files to open.'**
  String get noDroppedFiles;

  /// No description provided for @droppedCopyOpened.
  ///
  /// In en, this message translates to:
  /// **'The dropped temporary copy was opened as a new document.'**
  String get droppedCopyOpened;

  /// No description provided for @someFilesFailed.
  ///
  /// In en, this message translates to:
  /// **'Some files could not be opened'**
  String get someFilesFailed;

  /// No description provided for @settingsGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsGeneral;

  /// No description provided for @settingsFormatting.
  ///
  /// In en, this message translates to:
  /// **'Formatting'**
  String get settingsFormatting;

  /// No description provided for @website.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get website;

  /// No description provided for @schemaValidation.
  ///
  /// In en, this message translates to:
  /// **'JSON Schema validation'**
  String get schemaValidation;

  /// No description provided for @schemaHelp.
  ///
  /// In en, this message translates to:
  /// **'Paste or load a local schema. Select an issue to reveal its node. Internal references are supported.'**
  String get schemaHelp;

  /// No description provided for @loadSchema.
  ///
  /// In en, this message translates to:
  /// **'Load schema'**
  String get loadSchema;

  /// No description provided for @validateSchema.
  ///
  /// In en, this message translates to:
  /// **'Validate'**
  String get validateSchema;

  /// No description provided for @schemaChecking.
  ///
  /// In en, this message translates to:
  /// **'Working…'**
  String get schemaChecking;

  /// No description provided for @schemaFailed.
  ///
  /// In en, this message translates to:
  /// **'Validation failed'**
  String get schemaFailed;

  /// No description provided for @schemaValid.
  ///
  /// In en, this message translates to:
  /// **'Matches schema'**
  String get schemaValid;

  /// No description provided for @redactData.
  ///
  /// In en, this message translates to:
  /// **'Redact data'**
  String get redactData;

  /// No description provided for @redactHelp.
  ///
  /// In en, this message translates to:
  /// **'Separate case-insensitive field names with commas or newlines. Matching values become the replacement string. Enter one JSONPath per line, with wildcards supported.'**
  String get redactHelp;

  /// No description provided for @redactKeys.
  ///
  /// In en, this message translates to:
  /// **'Field names'**
  String get redactKeys;

  /// No description provided for @redactPaths.
  ///
  /// In en, this message translates to:
  /// **'JSONPath (optional)'**
  String get redactPaths;

  /// No description provided for @redactReplacement.
  ///
  /// In en, this message translates to:
  /// **'Replacement string'**
  String get redactReplacement;

  /// No description provided for @openRedactedCopy.
  ///
  /// In en, this message translates to:
  /// **'Open redacted copy'**
  String get openRedactedCopy;

  /// No description provided for @saveRedactedCopy.
  ///
  /// In en, this message translates to:
  /// **'Save redacted copy'**
  String get saveRedactedCopy;

  /// No description provided for @documentTools.
  ///
  /// In en, this message translates to:
  /// **'Document tools'**
  String get documentTools;

  /// No description provided for @schemaIssues.
  ///
  /// In en, this message translates to:
  /// **'{count} validation issues'**
  String schemaIssues(int count);

  /// No description provided for @redactCount.
  ///
  /// In en, this message translates to:
  /// **'{count} values replaced'**
  String redactCount(int count);

  /// No description provided for @comparisonSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select or clear all displayed differences'**
  String get comparisonSelectAll;

  /// No description provided for @comparisonSelected.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String comparisonSelected(int count);

  /// No description provided for @comparisonPreviewChanges.
  ///
  /// In en, this message translates to:
  /// **'Preview changes to left'**
  String get comparisonPreviewChanges;

  /// No description provided for @comparisonApplyChanges.
  ///
  /// In en, this message translates to:
  /// **'Apply changes'**
  String get comparisonApplyChanges;

  /// No description provided for @comparisonApplyPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview applying differences'**
  String get comparisonApplyPreview;

  /// No description provided for @comparisonApplyTarget.
  ///
  /// In en, this message translates to:
  /// **'Target document · {name}'**
  String comparisonApplyTarget(String name);

  /// No description provided for @comparisonApplyDirection.
  ///
  /// In en, this message translates to:
  /// **'Right → Left · Swap sides to apply in reverse'**
  String get comparisonApplyDirection;

  /// No description provided for @comparisonStale.
  ///
  /// In en, this message translates to:
  /// **'Documents changed. Compare again.'**
  String get comparisonStale;

  /// No description provided for @comparisonRefresh.
  ///
  /// In en, this message translates to:
  /// **'Compare again'**
  String get comparisonRefresh;

  /// No description provided for @comparisonApplyFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not prepare changes. Compare again and retry.'**
  String get comparisonApplyFailed;

  /// No description provided for @formatConversion.
  ///
  /// In en, this message translates to:
  /// **'Format conversion'**
  String get formatConversion;

  /// No description provided for @conversionDirection.
  ///
  /// In en, this message translates to:
  /// **'Conversion direction'**
  String get conversionDirection;

  /// No description provided for @conversionInput.
  ///
  /// In en, this message translates to:
  /// **'Input'**
  String get conversionInput;

  /// No description provided for @conversionDocument.
  ///
  /// In en, this message translates to:
  /// **'YAML document (starting at 1)'**
  String get conversionDocument;

  /// No description provided for @conversionDocumentError.
  ///
  /// In en, this message translates to:
  /// **'Enter a document number starting at 1.'**
  String get conversionDocumentError;

  /// No description provided for @conversionYamlNotice.
  ///
  /// In en, this message translates to:
  /// **'Data and exact numbers are retained in JSON. YAML comments are removed, and anchors, aliases and merge keys are expanded. Unsupported types produce an error.'**
  String get conversionYamlNotice;

  /// No description provided for @conversionCsvNotice.
  ///
  /// In en, this message translates to:
  /// **'CSV accepts an object or an array. Object fields become columns and other array items use the \$ value column. Values become text and nested structures become JSON strings. Missing fields and empty strings produce empty cells, while null becomes null. Preview to choose and reorder columns.'**
  String get conversionCsvNotice;

  /// No description provided for @conversionDelimiter.
  ///
  /// In en, this message translates to:
  /// **'Delimiter'**
  String get conversionDelimiter;

  /// No description provided for @conversionComma.
  ///
  /// In en, this message translates to:
  /// **'Comma'**
  String get conversionComma;

  /// No description provided for @conversionSemicolon.
  ///
  /// In en, this message translates to:
  /// **'Semicolon'**
  String get conversionSemicolon;

  /// No description provided for @conversionHeader.
  ///
  /// In en, this message translates to:
  /// **'Include header'**
  String get conversionHeader;

  /// No description provided for @conversionFlatten.
  ///
  /// In en, this message translates to:
  /// **'Flatten nested structures into JSONPath columns'**
  String get conversionFlatten;

  /// No description provided for @conversionColumns.
  ///
  /// In en, this message translates to:
  /// **'Columns and order'**
  String get conversionColumns;

  /// No description provided for @conversionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel conversion'**
  String get conversionCancel;

  /// No description provided for @conversionRun.
  ///
  /// In en, this message translates to:
  /// **'Convert and preview'**
  String get conversionRun;

  /// No description provided for @conversionCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy result'**
  String get conversionCopy;

  /// No description provided for @conversionCopied.
  ///
  /// In en, this message translates to:
  /// **'Conversion result copied'**
  String get conversionCopied;

  /// No description provided for @conversionOpen.
  ///
  /// In en, this message translates to:
  /// **'Open in new tab'**
  String get conversionOpen;

  /// No description provided for @conversionExport.
  ///
  /// In en, this message translates to:
  /// **'Export file'**
  String get conversionExport;

  /// No description provided for @contentValid.
  ///
  /// In en, this message translates to:
  /// **'Valid {format}'**
  String contentValid(String format);

  /// No description provided for @conversionDocuments.
  ///
  /// In en, this message translates to:
  /// **'{count} YAML documents'**
  String conversionDocuments(int count);

  /// No description provided for @conversionColumnUp.
  ///
  /// In en, this message translates to:
  /// **'Move column up'**
  String get conversionColumnUp;

  /// No description provided for @conversionColumnDown.
  ///
  /// In en, this message translates to:
  /// **'Move column down'**
  String get conversionColumnDown;

  /// No description provided for @showReplace.
  ///
  /// In en, this message translates to:
  /// **'Show replace'**
  String get showReplace;

  /// No description provided for @hideReplace.
  ///
  /// In en, this message translates to:
  /// **'Hide replace'**
  String get hideReplace;

  /// No description provided for @treeStyleStructure.
  ///
  /// In en, this message translates to:
  /// **'Structure navigator'**
  String get treeStyleStructure;

  /// No description provided for @treeStyleGuides.
  ///
  /// In en, this message translates to:
  /// **'Hierarchy guides'**
  String get treeStyleGuides;

  /// No description provided for @highlightPreview.
  ///
  /// In en, this message translates to:
  /// **'Highlight preview'**
  String get highlightPreview;

  /// No description provided for @treePreview.
  ///
  /// In en, this message translates to:
  /// **'Tree preview'**
  String get treePreview;

  /// No description provided for @formatFailed.
  ///
  /// In en, this message translates to:
  /// **'Formatting failed: {error}'**
  String formatFailed(String error);

  /// No description provided for @conversionCsvPath.
  ///
  /// In en, this message translates to:
  /// **'Source JSONPath'**
  String get conversionCsvPath;

  /// No description provided for @conversionTomlNotice.
  ///
  /// In en, this message translates to:
  /// **'TOML 1.0. Conversion to TOML requires an object, unique keys, no nulls, signed 64-bit integers and representable floats. Dates and times become JSON strings; comments are omitted.'**
  String get conversionTomlNotice;

  /// No description provided for @conversionXmlNotice.
  ///
  /// In en, this message translates to:
  /// **'Typed mapping preserves JSON types, number spelling and keys using the ejson namespace. Element mapping accepts one root property and @attributes, #text and #content.'**
  String get conversionXmlNotice;

  /// No description provided for @conversionXmlImportNotice.
  ///
  /// In en, this message translates to:
  /// **'Typed XML restores JSON types. Other XML uses @attributes, #text and ordered #content; text values remain strings. Comments and processing instructions are omitted.'**
  String get conversionXmlImportNotice;

  /// No description provided for @xmlMapping.
  ///
  /// In en, this message translates to:
  /// **'XML mapping'**
  String get xmlMapping;

  /// No description provided for @xmlTypedMapping.
  ///
  /// In en, this message translates to:
  /// **'Typed JSON mapping'**
  String get xmlTypedMapping;

  /// No description provided for @xmlElementMapping.
  ///
  /// In en, this message translates to:
  /// **'Element mapping'**
  String get xmlElementMapping;

  /// No description provided for @xmlRootName.
  ///
  /// In en, this message translates to:
  /// **'Root element name'**
  String get xmlRootName;

  /// No description provided for @csvImportNotice.
  ///
  /// In en, this message translates to:
  /// **'Cells are text by default, preserving leading zeros. Choose column names and types explicitly. Empty-cell handling applies to every column.'**
  String get csvImportNotice;

  /// No description provided for @csvHeaderRow.
  ///
  /// In en, this message translates to:
  /// **'First row contains column names'**
  String get csvHeaderRow;

  /// No description provided for @csvEmptyCells.
  ///
  /// In en, this message translates to:
  /// **'Empty cells'**
  String get csvEmptyCells;

  /// No description provided for @csvEmptyString.
  ///
  /// In en, this message translates to:
  /// **'Empty string'**
  String get csvEmptyString;

  /// No description provided for @csvOmitField.
  ///
  /// In en, this message translates to:
  /// **'Omit field'**
  String get csvOmitField;

  /// No description provided for @csvImportColumns.
  ///
  /// In en, this message translates to:
  /// **'Column names and types'**
  String get csvImportColumns;

  /// No description provided for @csvColumnName.
  ///
  /// In en, this message translates to:
  /// **'Column name'**
  String get csvColumnName;

  /// No description provided for @csvColumnType.
  ///
  /// In en, this message translates to:
  /// **'Column type'**
  String get csvColumnType;

  /// No description provided for @csvTypeText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get csvTypeText;

  /// No description provided for @csvTypeNumber.
  ///
  /// In en, this message translates to:
  /// **'Number'**
  String get csvTypeNumber;

  /// No description provided for @csvTypeBoolean.
  ///
  /// In en, this message translates to:
  /// **'Boolean'**
  String get csvTypeBoolean;

  /// No description provided for @documentStructure.
  ///
  /// In en, this message translates to:
  /// **'Structure'**
  String get documentStructure;

  /// No description provided for @csvVisibleColumns.
  ///
  /// In en, this message translates to:
  /// **'Showing {visible} / {total} columns'**
  String csvVisibleColumns(int visible, int total);

  /// No description provided for @csvTableHeader.
  ///
  /// In en, this message translates to:
  /// **'Header row'**
  String get csvTableHeader;

  /// No description provided for @noStructure.
  ///
  /// In en, this message translates to:
  /// **'No structure available'**
  String get noStructure;

  /// No description provided for @newDocument.
  ///
  /// In en, this message translates to:
  /// **'New {format} document'**
  String newDocument(String format);

  /// No description provided for @newDocumentFormat.
  ///
  /// In en, this message translates to:
  /// **'New document format'**
  String get newDocumentFormat;

  /// No description provided for @saveAsFormat.
  ///
  /// In en, this message translates to:
  /// **'File type'**
  String get saveAsFormat;

  /// No description provided for @saveAsConversionHint.
  ///
  /// In en, this message translates to:
  /// **'Conversion uses default settings. Review the preview before saving. For CSV columns, YAML document selection and XML mapping, use Format conversion.'**
  String get saveAsConversionHint;

  /// No description provided for @saveAsExtensionError.
  ///
  /// In en, this message translates to:
  /// **'Use the .{extension} extension for the selected file type.'**
  String saveAsExtensionError(String extension);

  /// No description provided for @saveAsOverwrite.
  ///
  /// In en, this message translates to:
  /// **'The file already exists. Replace it?\n{path}'**
  String saveAsOverwrite(String path);

  /// No description provided for @autosaveDrafts.
  ///
  /// In en, this message translates to:
  /// **'Auto-save recovery drafts'**
  String get autosaveDrafts;

  /// No description provided for @autosaveDescription.
  ///
  /// In en, this message translates to:
  /// **'Saves recovery drafts after 2 seconds of inactivity, at least every 10 seconds while editing. Drafts are restored on the next launch after an unexpected exit.'**
  String get autosaveDescription;

  /// No description provided for @autosaveDisabled.
  ///
  /// In en, this message translates to:
  /// **'Recovery draft auto-save is off'**
  String get autosaveDisabled;

  /// No description provided for @autosaveWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting to save recovery drafts'**
  String get autosaveWaiting;

  /// No description provided for @autosaveSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving recovery drafts'**
  String get autosaveSaving;

  /// No description provided for @autosaveSaved.
  ///
  /// In en, this message translates to:
  /// **'Recovery drafts saved'**
  String get autosaveSaved;

  /// No description provided for @autosaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Recovery drafts could not be saved. Click to retry.'**
  String get autosaveFailed;

  /// No description provided for @recoveryRestored.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Recovered unsaved changes in 1 document.} other{Recovered unsaved changes in {count} documents.}}'**
  String recoveryRestored(int count);

  /// No description provided for @autosaveUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Recovery storage could not be initialized. Draft auto-save is unavailable.'**
  String get autosaveUnavailable;

  /// No description provided for @diskSyncSetting.
  ///
  /// In en, this message translates to:
  /// **'Sync disk files'**
  String get diskSyncSetting;

  /// No description provided for @diskSyncDescription.
  ///
  /// In en, this message translates to:
  /// **'Saves edits to named files after a 500 ms pause, including incomplete syntax. Checks external changes every second. Conflicts pause synchronization.'**
  String get diskSyncDescription;

  /// No description provided for @diskSyncWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting to save to disk'**
  String get diskSyncWaiting;

  /// No description provided for @diskSyncSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving to disk'**
  String get diskSyncSaving;

  /// No description provided for @diskSyncSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved to disk'**
  String get diskSyncSaved;

  /// No description provided for @diskSyncFailed.
  ///
  /// In en, this message translates to:
  /// **'Disk synchronization failed'**
  String get diskSyncFailed;

  /// No description provided for @diskSyncConflict.
  ///
  /// In en, this message translates to:
  /// **'File synchronization conflict'**
  String get diskSyncConflict;

  /// No description provided for @diskSyncConflictDescription.
  ///
  /// In en, this message translates to:
  /// **'The file changed on disk and has local edits. Synchronization is paused. Choose which version to keep.'**
  String get diskSyncConflictDescription;

  /// No description provided for @diskSyncError.
  ///
  /// In en, this message translates to:
  /// **'File synchronization is paused. {error}'**
  String diskSyncError(String error);

  /// No description provided for @diskSyncCompare.
  ///
  /// In en, this message translates to:
  /// **'Compare versions'**
  String get diskSyncCompare;

  /// No description provided for @diskSyncLocal.
  ///
  /// In en, this message translates to:
  /// **'Current edits'**
  String get diskSyncLocal;

  /// No description provided for @diskSyncDisk.
  ///
  /// In en, this message translates to:
  /// **'Disk version'**
  String get diskSyncDisk;

  /// No description provided for @diskSyncReload.
  ///
  /// In en, this message translates to:
  /// **'Load disk version'**
  String get diskSyncReload;

  /// No description provided for @diskSyncOverwrite.
  ///
  /// In en, this message translates to:
  /// **'Keep local edits'**
  String get diskSyncOverwrite;

  /// No description provided for @diskSyncRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get diskSyncRetry;

  /// No description provided for @diskSyncReloadConfirm.
  ///
  /// In en, this message translates to:
  /// **'Load the latest disk version and discard the current local edits?'**
  String get diskSyncReloadConfirm;

  /// No description provided for @diskSyncOverwriteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Save the current local edits over the disk version? If the disk version changes again, you will need to review it again.'**
  String get diskSyncOverwriteConfirm;

  /// No description provided for @repairJson.
  ///
  /// In en, this message translates to:
  /// **'Repair JSON'**
  String get repairJson;

  /// No description provided for @repairAlreadyValid.
  ///
  /// In en, this message translates to:
  /// **'This document is already valid JSON.'**
  String get repairAlreadyValid;

  /// No description provided for @repairFailed.
  ///
  /// In en, this message translates to:
  /// **'The content could not be repaired. Complete missing values or resolve ambiguous syntax and try again.'**
  String get repairFailed;

  /// No description provided for @repairBom.
  ///
  /// In en, this message translates to:
  /// **'Removed BOM markers'**
  String get repairBom;

  /// No description provided for @repairComments.
  ///
  /// In en, this message translates to:
  /// **'Removed comments'**
  String get repairComments;

  /// No description provided for @repairSingleQuotes.
  ///
  /// In en, this message translates to:
  /// **'Converted single-quoted strings'**
  String get repairSingleQuotes;

  /// No description provided for @repairUnquotedKeys.
  ///
  /// In en, this message translates to:
  /// **'Quoted property names'**
  String get repairUnquotedKeys;

  /// No description provided for @repairTrailingCommas.
  ///
  /// In en, this message translates to:
  /// **'Removed trailing commas'**
  String get repairTrailingCommas;

  /// No description provided for @repairMissingCommas.
  ///
  /// In en, this message translates to:
  /// **'Inserted commas'**
  String get repairMissingCommas;

  /// No description provided for @repairMissingColons.
  ///
  /// In en, this message translates to:
  /// **'Inserted colons'**
  String get repairMissingColons;

  /// No description provided for @repairClosingContainers.
  ///
  /// In en, this message translates to:
  /// **'Closed objects and arrays'**
  String get repairClosingContainers;

  /// No description provided for @repairClosingStrings.
  ///
  /// In en, this message translates to:
  /// **'Closed strings'**
  String get repairClosingStrings;

  /// No description provided for @repairControlCharacters.
  ///
  /// In en, this message translates to:
  /// **'Escaped control characters'**
  String get repairControlCharacters;

  /// No description provided for @repairLiterals.
  ///
  /// In en, this message translates to:
  /// **'Normalized literal values'**
  String get repairLiterals;

  /// No description provided for @jsonLinesRecords.
  ///
  /// In en, this message translates to:
  /// **'Records'**
  String get jsonLinesRecords;

  /// No description provided for @jsonLinesSearch.
  ///
  /// In en, this message translates to:
  /// **'Search records'**
  String get jsonLinesSearch;

  /// No description provided for @jsonLinesFilter.
  ///
  /// In en, this message translates to:
  /// **'Records to show'**
  String get jsonLinesFilter;

  /// No description provided for @jsonLinesAll.
  ///
  /// In en, this message translates to:
  /// **'All records'**
  String get jsonLinesAll;

  /// No description provided for @jsonLinesValid.
  ///
  /// In en, this message translates to:
  /// **'Valid records'**
  String get jsonLinesValid;

  /// No description provided for @jsonLinesInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid records'**
  String get jsonLinesInvalid;

  /// No description provided for @jsonLinesNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matching records'**
  String get jsonLinesNoMatches;

  /// No description provided for @jsonLinesBlank.
  ///
  /// In en, this message translates to:
  /// **'Blank line'**
  String get jsonLinesBlank;

  /// No description provided for @jsonLinesExport.
  ///
  /// In en, this message translates to:
  /// **'Export filtered records'**
  String get jsonLinesExport;

  /// No description provided for @jsonLinesExported.
  ///
  /// In en, this message translates to:
  /// **'Filtered records exported'**
  String get jsonLinesExported;

  /// No description provided for @jsonLinesCount.
  ///
  /// In en, this message translates to:
  /// **'{shown} / {total} records · {invalid} invalid'**
  String jsonLinesCount(int shown, int total, int invalid);

  /// No description provided for @jsonLinesConversionNotice.
  ///
  /// In en, this message translates to:
  /// **'Each line contains one JSON value. Blank lines are invalid. JSON Lines becomes a JSON array. A JSON array exports one item per line, while other JSON values export as one record.'**
  String get jsonLinesConversionNotice;

  /// No description provided for @foldPreviewMoreLines.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 more line} other{{count} more lines}}'**
  String foldPreviewMoreLines(int count);

  /// No description provided for @sourceFolding.
  ///
  /// In en, this message translates to:
  /// **'Source folding'**
  String get sourceFolding;

  /// No description provided for @treeConnectors.
  ///
  /// In en, this message translates to:
  /// **'Dashed tree connectors'**
  String get treeConnectors;
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
