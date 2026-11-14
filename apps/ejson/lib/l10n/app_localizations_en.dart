// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get compareDocuments => 'Compare JSON documents';

  @override
  String get comparisonBefore => 'Before';

  @override
  String get comparisonAfter => 'After';

  @override
  String get comparisonSwap => 'Swap comparison sides';

  @override
  String get comparisonEmpty => 'The structures match.';

  @override
  String get comparisonLimit => 'Showing the first 1,000 differences.';

  @override
  String get comparisonFailed => 'Could not compare these documents.';

  @override
  String get comparisonAdded => 'Added';

  @override
  String get comparisonRemoved => 'Removed';

  @override
  String get comparisonChanged => 'Changed';

  @override
  String get comparisonMissing => 'No corresponding node';

  @override
  String get goToJsonPath => 'Go to JSONPath';

  @override
  String get goToNode => 'Go to node';

  @override
  String get invalidJsonPath => 'Enter a single JSONPath such as \$.items[0].';

  @override
  String get missingJsonPath => 'This path does not exist in the document.';

  @override
  String get ambiguousJsonPath => 'This path matches duplicate keys.';

  @override
  String get findInDocument => 'Find in document';

  @override
  String get searchSource => 'Source text';

  @override
  String get searchKeys => 'Keys';

  @override
  String get searchValues => 'Values';

  @override
  String get noMatches => 'No matches';

  @override
  String get previousMatch => 'Previous match';

  @override
  String get nextMatch => 'Next match';

  @override
  String get closeFind => 'Close find';

  @override
  String get findNeedsValidJson => 'Key and value search needs valid JSON.';

  @override
  String get addProperty => 'Add property';

  @override
  String get addArrayItem => 'Add array item';

  @override
  String get propertyName => 'Property name';

  @override
  String get deleteNode => 'Delete node';

  @override
  String get copyJsonPath => 'Copy JSONPath';

  @override
  String get jsonPathCopied => 'JSONPath copied';

  @override
  String get open => 'Open';

  @override
  String get save => 'Save';

  @override
  String get saveAs => 'Save As';

  @override
  String get undo => 'Undo';

  @override
  String get redo => 'Redo';

  @override
  String get minify => 'Minify';

  @override
  String get format => 'Format';

  @override
  String get appearance => 'Appearance';

  @override
  String get systemTheme => 'System';

  @override
  String get lightTheme => 'Light';

  @override
  String get darkTheme => 'Dark';

  @override
  String get glassToolbar => 'Glass toolbar';

  @override
  String get systemLanguage => 'System';

  @override
  String get english => 'English';

  @override
  String get simplifiedChinese => '简体中文';

  @override
  String get newTab => 'New tab';

  @override
  String closeTab(String name) {
    return 'Close $name';
  }

  @override
  String get untitled => 'Untitled';

  @override
  String numberedUntitled(int number) {
    return 'Untitled $number';
  }

  @override
  String get source => 'Source';

  @override
  String get jsonTree => 'JSON tree';

  @override
  String get previousRevision => 'Previous valid revision';

  @override
  String get largeFile => 'Large file · read-only';

  @override
  String get emptyDocument => 'Empty document';

  @override
  String get checking => 'Checking…';

  @override
  String get validJson => 'Valid JSON';

  @override
  String warningAt(int line, int column, String message) {
    return 'Warning at $line:$column  $message';
  }

  @override
  String errorAt(int line, int column, String message) {
    return 'Error at $line:$column  $message';
  }

  @override
  String get treeLargeFile => 'Tree disabled for large files';

  @override
  String get treeEmpty => 'Enter valid JSON to show the tree';

  @override
  String get treeLimit => 'Showing the first 10,000 visible nodes';

  @override
  String get rootNode => 'root';

  @override
  String get collapse => 'Collapse';

  @override
  String get expand => 'Expand';

  @override
  String get editNode => 'Edit node';

  @override
  String get nodeActions => 'Node actions';

  @override
  String get focusSubtree => 'Focus subtree';

  @override
  String get replaceValue => 'Replace value';

  @override
  String get replaceJsonValue => 'Replace JSON value';

  @override
  String get renameKey => 'Rename key';

  @override
  String get goToParent => 'Go to parent';

  @override
  String get backToRoot => 'Back to root';

  @override
  String get saveBeforeQuit => 'Save changes before quitting?';

  @override
  String get saveChanges => 'Save changes?';

  @override
  String get cancel => 'Cancel';

  @override
  String get discard => 'Discard';

  @override
  String get apply => 'Apply';

  @override
  String openFailed(String detail) {
    return 'Open failed · $detail';
  }

  @override
  String saveFailed(String detail) {
    return 'Save failed · $detail';
  }

  @override
  String get fileAlreadyOpen => 'That file is already open in another tab.';

  @override
  String get staleNode => 'The document changed. Select the node again.';

  @override
  String get quotedString => 'Enter a quoted JSON string.';

  @override
  String get fileChanged =>
      'The file changed on disk. Use Save As to keep your edits.';

  @override
  String get fileTooLarge => 'Files larger than 16 MiB cannot be opened.';

  @override
  String get saveTooLarge => 'The document exceeds the 16 MiB file limit.';

  @override
  String get filePermissions => 'Could not preserve file permissions.';

  @override
  String get invalidEncoding => 'The file is not valid UTF-8.';

  @override
  String get trailingContent => 'Unexpected text after the JSON value.';

  @override
  String get depthLimit => 'JSON nesting exceeds 256 levels.';

  @override
  String get expectedValue => 'Expected a JSON value.';

  @override
  String get expectedKey => 'Expected a quoted property name.';

  @override
  String get duplicateKey => 'Duplicate property name.';

  @override
  String get expectedColon => 'Expected a colon after the property name.';

  @override
  String get expectedObjectDelimiter => 'Expected a comma or closing brace.';

  @override
  String get expectedArrayDelimiter => 'Expected a comma or closing bracket.';

  @override
  String invalidLiteral(String token) {
    return 'Expected $token.';
  }

  @override
  String get unclosedString => 'Expected a closing quote.';

  @override
  String get controlCharacter => 'Escape control characters inside strings.';

  @override
  String get invalidUnicodeEscape =>
      'Expected four hexadecimal digits after the Unicode escape prefix.';

  @override
  String get invalidEscape => 'Invalid string escape.';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get done => 'Done';

  @override
  String get jsonHighlight => 'JSON highlighting';

  @override
  String get highlightMonochrome => 'Monochrome';

  @override
  String get highlightAccessibility => 'Accessibility';

  @override
  String get treeStyle => 'JSON tree style';

  @override
  String get treeStyleClassic => 'Classic';

  @override
  String get treeStyleColor => 'Color by type';

  @override
  String get treeStyleStriped => 'Striped rows';

  @override
  String get treeStyleCompact => 'Compact';

  @override
  String get treeStyleOutline => 'Outline';

  @override
  String get startup => 'Startup';

  @override
  String get restoreWorkspace => 'Restore last workspace on startup';

  @override
  String get restoreFailed => 'Could not reopen some files';

  @override
  String get workspaceSaveFailed =>
      'Could not remember the workspace for next launch.';

  @override
  String get workspacePreferenceFailed => 'Could not save the startup setting.';

  @override
  String get unsavedChangesDescription =>
      'Unsaved changes will be lost if you discard them.';

  @override
  String get about => 'About EJson';

  @override
  String versionLabel(String version) {
    return 'Version $version';
  }

  @override
  String get checkUpdates => 'Check for updates';

  @override
  String get checkingUpdates => 'Checking for updates…';

  @override
  String get updateCurrent => 'You’re on the latest version.';

  @override
  String updateAvailable(String version) {
    return 'Version $version is available.';
  }

  @override
  String get noRelease => 'No stable release has been published yet.';

  @override
  String get updateFailed => 'Could not check for updates. Try again later.';

  @override
  String get downloadRelease => 'View release';

  @override
  String get buyCoffee => 'Buy me a coffee';

  @override
  String get browserFailed => 'Could not open the browser.';
}
