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

  /// No description provided for @replaceText.
  ///
  /// In en, this message translates to:
  /// **'Replace with'**
  String get replaceText;

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
