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
  String get colorTheme => 'Color theme';

  @override
  String get colorThemeSystemDefault => 'System Default';

  @override
  String get colorThemeBlue => 'Blue';

  @override
  String get colorThemeAmber => 'Amber';

  @override
  String get colorThemeGreen => 'Green';

  @override
  String get colorThemePurple => 'Purple';

  @override
  String get colorThemeRose => 'Rose';

  @override
  String get colorThemeWebsiteBlue => 'Website Blue';

  @override
  String get colorThemeSlate => 'Slate';

  @override
  String get colorThemeSteel => 'Steel';

  @override
  String get systemLanguage => 'System';

  @override
  String get english => 'English';

  @override
  String get simplifiedChinese => '简体中文';

  @override
  String get newTab => 'New tab';

  @override
  String get closeTabMenu => 'Close Tab';

  @override
  String closeTab(String name) {
    return 'Close $name';
  }

  @override
  String get revealInFolder => 'Show in Folder';

  @override
  String get revealInFinder => 'Show in Finder';

  @override
  String get revealFileMissing =>
      'The file no longer exists. Its original folder was opened.';

  @override
  String get revealFolderMissing =>
      'The folder containing the file could not be found.';

  @override
  String get revealFolderFailed => 'Could not open the file manager.';

  @override
  String get copyFilePath => 'Copy File Path';

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
  String get sourcePreviousPage => 'Previous source page';

  @override
  String get sourceNextPage => 'Next source page';

  @override
  String get sourceGoToPage => 'Go to source page';

  @override
  String sourcePage(int page, int total) {
    return 'Page $page of $total';
  }

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
  String get restoreFailedDescription =>
      'These files were part of the previous workspace. Their location may have changed, access may have been denied, or they may no longer be readable.';

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

  @override
  String get replaceText => 'Replace with';

  @override
  String get replace => 'Replace';

  @override
  String get replaceCurrent => 'Replace current';

  @override
  String get replaceAll => 'Replace all';

  @override
  String get matchCase => 'Match case';

  @override
  String get useRegex => 'Regular expression';

  @override
  String get ignoreWhitespace => 'Ignore whitespace';

  @override
  String get invalidRegex => 'Invalid regular expression';

  @override
  String get escapeJson => 'Escape as JSON string';

  @override
  String get unescapeJson => 'Unescape JSON string';

  @override
  String get unescapeFailed => 'Enter a valid, double-quoted JSON string.';

  @override
  String get extractSubtree => 'Extract to new tab';

  @override
  String get arrayTable => 'Array table';

  @override
  String get copyNodeValue => 'Copy JSON value';

  @override
  String get copyDecodedString => 'Copy string contents';

  @override
  String get valueCopied => 'Node value copied';

  @override
  String get filterRows => 'Filter rows';

  @override
  String get emptyArray => 'The array is empty';

  @override
  String get exportCsv => 'Export CSV';

  @override
  String get csvExported => 'CSV exported';

  @override
  String get exportFailed => 'Export failed';

  @override
  String get tableInstructions =>
      'Click a column header to sort, or a cell to copy its contents. Export uses the current filter and sort order.';

  @override
  String tableRowCount(int visible, int total) {
    return '$visible / $total rows';
  }

  @override
  String nodeCount(int count) {
    return '$count nodes';
  }

  @override
  String documentBytes(int bytes) {
    return '$bytes bytes';
  }

  @override
  String documentStatistics(int bytes, int nodes, int depth, int arrayLength) {
    return '$bytes bytes · $nodes nodes · Maximum depth $depth (root is 0) · Longest array $arrayLength items';
  }

  @override
  String get jsonQuery => 'JSONPath query';

  @override
  String get runQuery => 'Run query';

  @override
  String get queryRunning => 'Running query…';

  @override
  String get jsonQueryFailed => 'The query failed. Try again.';

  @override
  String invalidJsonQuery(int position) {
    return 'Invalid or unsupported JSONPath syntax near character $position.';
  }

  @override
  String get jsonQueryHelp =>
      'Supports fields, array indices, * wildcards and [?condition] filters. Conditions support @ paths, existence, scalar comparisons, &&, || and !. Click a result to reveal its source.';

  @override
  String queryResultCount(int count) {
    return '$count results';
  }

  @override
  String get extractQueryResults => 'Extract results to new tab';

  @override
  String get goToSource => 'Reveal in source';

  @override
  String get captureReplacementHelp =>
      '\$1 and \$2 insert capture groups. \$\$ inserts a dollar sign.';

  @override
  String get formatIndentation => 'Format indentation';

  @override
  String get indentTwo => '2 spaces';

  @override
  String get indentFour => '4 spaces';

  @override
  String get indentEight => '8 spaces';

  @override
  String get indentTabs => 'Tabs';

  @override
  String get lineEnding => 'Line endings';

  @override
  String get preserveLineEnding => 'Preserve existing';

  @override
  String get toolPreferenceFailed => 'Could not save preferences. Try again.';

  @override
  String get saveQuery => 'Save query';

  @override
  String get unsaveQuery => 'Unsave query';

  @override
  String get savedQueries => 'Saved queries';

  @override
  String get noSavedQueries => 'No saved queries';

  @override
  String get moveArrayItemUp => 'Move array item up';

  @override
  String get moveArrayItemDown => 'Move array item down';

  @override
  String get duplicateArrayItem => 'Duplicate array item';

  @override
  String get sortArray => 'Sort array';

  @override
  String get sortField => 'Sort by';

  @override
  String get sortValue => 'Element value';

  @override
  String get sortAscending => 'Ascending';

  @override
  String get sortDescending => 'Descending';

  @override
  String get sortArrayHelp =>
      'Items with missing fields stay last. Equal values retain their order.';

  @override
  String get sortArrayAmbiguous =>
      'The sort field has duplicate keys. Choose another field.';

  @override
  String get readingDisplay => 'Reading display';

  @override
  String get readingFont => 'Reading font';

  @override
  String get fontSize => 'Font size';

  @override
  String get decreaseFontSize => 'Decrease font size';

  @override
  String get increaseFontSize => 'Increase font size';

  @override
  String get lineSpacing => 'Line spacing';

  @override
  String get spacingCompact => 'Compact';

  @override
  String get spacingStandard => 'Standard';

  @override
  String get spacingSpacious => 'Spacious';

  @override
  String get readingPreview => 'Preview';

  @override
  String get resetReading => 'Reset to defaults';

  @override
  String get defaultReadingFont => 'Default monospace font';

  @override
  String get searchFonts => 'Search installed fonts';

  @override
  String get refreshFonts => 'Refresh fonts';

  @override
  String get monospaceFont => 'Monospace';

  @override
  String get fontListFailed => 'Could not load fonts. Retry.';

  @override
  String get noMatchingFonts => 'No matching fonts';

  @override
  String fontUnavailable(String name) {
    return 'The font “$name” is unavailable. Using the default font.';
  }

  @override
  String get recentFiles => 'Recent files';

  @override
  String get searchRecentFiles => 'Search file names or paths';

  @override
  String get noRecentFiles => 'No recent files';

  @override
  String get removeRecentFile => 'Remove from recent files';

  @override
  String get clearRecentFiles => 'Clear recent files';

  @override
  String get recentSaveFailed =>
      'The file was opened or saved, but recent files could not be recorded.';

  @override
  String get commandPalette => 'Command palette';

  @override
  String get searchCommands => 'Search commands…';

  @override
  String get noMatchingCommands => 'No matching commands';

  @override
  String get commandKeyboardHelp => '↑↓ Select  ·  Enter Run  ·  Esc Close';

  @override
  String get dropFilesToOpen => 'Drop files to open';

  @override
  String get noDroppedFiles => 'The drop contains no local files to open.';

  @override
  String get droppedCopyOpened =>
      'The dropped temporary copy was opened as a new document.';

  @override
  String get someFilesFailed => 'Some files could not be opened';

  @override
  String get settingsGeneral => 'General';

  @override
  String get settingsFormatting => 'Formatting';

  @override
  String get website => 'Website';

  @override
  String get schemaValidation => 'JSON Schema validation';

  @override
  String get schemaHelp =>
      'Paste or load a local schema. Select an issue to reveal its node. Internal references are supported.';

  @override
  String get loadSchema => 'Load schema';

  @override
  String get validateSchema => 'Validate';

  @override
  String get schemaChecking => 'Working…';

  @override
  String get schemaFailed => 'Validation failed';

  @override
  String get schemaValid => 'Matches schema';

  @override
  String get redactData => 'Redact data';

  @override
  String get redactHelp =>
      'Separate case-insensitive field names with commas or newlines. Matching values become the replacement string. Enter one JSONPath per line, with wildcards supported.';

  @override
  String get redactKeys => 'Field names';

  @override
  String get redactPaths => 'JSONPath (optional)';

  @override
  String get redactReplacement => 'Replacement string';

  @override
  String get openRedactedCopy => 'Open redacted copy';

  @override
  String get saveRedactedCopy => 'Save redacted copy';

  @override
  String get documentTools => 'Document tools';

  @override
  String schemaIssues(int count) {
    return '$count validation issues';
  }

  @override
  String redactCount(int count) {
    return '$count values replaced';
  }

  @override
  String get comparisonSelectAll => 'Select or clear all displayed differences';

  @override
  String comparisonSelected(int count) {
    return '$count selected';
  }

  @override
  String get comparisonPreviewChanges => 'Preview changes to left';

  @override
  String get comparisonApplyChanges => 'Apply changes';

  @override
  String get comparisonApplyPreview => 'Preview applying differences';

  @override
  String comparisonApplyTarget(String name) {
    return 'Target document · $name';
  }

  @override
  String get comparisonApplyDirection =>
      'Right → Left · Swap sides to apply in reverse';

  @override
  String get comparisonStale => 'Documents changed. Compare again.';

  @override
  String get comparisonRefresh => 'Compare again';

  @override
  String get comparisonApplyFailed =>
      'Could not prepare changes. Compare again and retry.';

  @override
  String get formatConversion => 'Format conversion';

  @override
  String get conversionDirection => 'Conversion direction';

  @override
  String get conversionInput => 'Input';

  @override
  String get conversionDocument => 'YAML document (starting at 1)';

  @override
  String get conversionDocumentError =>
      'Enter a document number starting at 1.';

  @override
  String get conversionYamlNotice =>
      'Data and exact numbers are retained in JSON. YAML comments are removed, and anchors, aliases and merge keys are expanded. Unsupported types produce an error.';

  @override
  String get conversionCsvNotice =>
      'CSV accepts an object or an array. Object fields become columns and other array items use the \$ value column. Values become text and nested structures become JSON strings. Missing fields and empty strings produce empty cells, while null becomes null. Preview to choose and reorder columns.';

  @override
  String get conversionDelimiter => 'Delimiter';

  @override
  String get conversionComma => 'Comma';

  @override
  String get conversionSemicolon => 'Semicolon';

  @override
  String get conversionHeader => 'Include header';

  @override
  String get conversionFlatten =>
      'Flatten nested structures into JSONPath columns';

  @override
  String get conversionColumns => 'Columns and order';

  @override
  String get conversionCancel => 'Cancel conversion';

  @override
  String get conversionRun => 'Convert and preview';

  @override
  String get conversionCopy => 'Copy result';

  @override
  String get conversionCopied => 'Conversion result copied';

  @override
  String get conversionOpen => 'Open in new tab';

  @override
  String get conversionExport => 'Export file';

  @override
  String contentValid(String format) {
    return 'Valid $format';
  }

  @override
  String conversionDocuments(int count) {
    return '$count YAML documents';
  }

  @override
  String get conversionColumnUp => 'Move column up';

  @override
  String get conversionColumnDown => 'Move column down';

  @override
  String get showReplace => 'Show replace';

  @override
  String get hideReplace => 'Hide replace';

  @override
  String get treeStyleStructure => 'Structure navigator';

  @override
  String get treeStyleGuides => 'Hierarchy guides';

  @override
  String get highlightPreview => 'Highlight preview';

  @override
  String get treePreview => 'Tree preview';

  @override
  String formatFailed(String error) {
    return 'Formatting failed: $error';
  }

  @override
  String get conversionCsvPath => 'Source JSONPath';

  @override
  String get conversionTomlNotice =>
      'TOML 1.0. Conversion to TOML requires an object, unique keys, no nulls, signed 64-bit integers and representable floats. Dates and times become JSON strings; comments are omitted.';

  @override
  String get conversionXmlNotice =>
      'Typed mapping preserves JSON types, number spelling and keys using the ejson namespace. Element mapping accepts one root property and @attributes, #text and #content.';

  @override
  String get conversionXmlImportNotice =>
      'Typed XML restores JSON types. Other XML uses @attributes, #text and ordered #content; text values remain strings. Comments and processing instructions are omitted.';

  @override
  String get xmlMapping => 'XML mapping';

  @override
  String get xmlTypedMapping => 'Typed JSON mapping';

  @override
  String get xmlElementMapping => 'Element mapping';

  @override
  String get xmlRootName => 'Root element name';

  @override
  String get csvImportNotice =>
      'Cells are text by default, preserving leading zeros. Choose column names and types explicitly. Empty-cell handling applies to every column.';

  @override
  String get csvHeaderRow => 'First row contains column names';

  @override
  String get csvEmptyCells => 'Empty cells';

  @override
  String get csvEmptyString => 'Empty string';

  @override
  String get csvOmitField => 'Omit field';

  @override
  String get csvImportColumns => 'Column names and types';

  @override
  String get csvColumnName => 'Column name';

  @override
  String get csvColumnType => 'Column type';

  @override
  String get csvTypeText => 'Text';

  @override
  String get csvTypeNumber => 'Number';

  @override
  String get csvTypeBoolean => 'Boolean';

  @override
  String get documentStructure => 'Structure';

  @override
  String csvVisibleColumns(int visible, int total) {
    return 'Showing $visible / $total columns';
  }

  @override
  String get csvTableHeader => 'Header row';

  @override
  String get noStructure => 'No structure available';

  @override
  String newDocument(String format) {
    return 'New $format document';
  }

  @override
  String get newDocumentFormat => 'New document format';

  @override
  String get saveAsFormat => 'File type';

  @override
  String get saveAsConversionHint =>
      'Conversion uses default settings. Review the preview before saving. For CSV columns, YAML document selection and XML mapping, use Format conversion.';

  @override
  String saveAsExtensionError(String extension) {
    return 'Use the .$extension extension for the selected file type.';
  }

  @override
  String saveAsOverwrite(String path) {
    return 'The file already exists. Replace it?\n$path';
  }

  @override
  String get autosaveDrafts => 'Auto-save recovery drafts';

  @override
  String get autosaveDescription =>
      'Saves recovery drafts after 2 seconds of inactivity, at least every 10 seconds while editing. Drafts are restored on the next launch after an unexpected exit.';

  @override
  String get autosaveDisabled => 'Recovery draft auto-save is off';

  @override
  String get autosaveWaiting => 'Waiting to save recovery drafts';

  @override
  String get autosaveSaving => 'Saving recovery drafts';

  @override
  String get autosaveSaved => 'Recovery drafts saved';

  @override
  String get autosaveFailed =>
      'Recovery drafts could not be saved. Click to retry.';

  @override
  String recoveryRestored(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Recovered unsaved changes in $count documents.',
      one: 'Recovered unsaved changes in 1 document.',
    );
    return '$_temp0';
  }

  @override
  String get autosaveUnavailable =>
      'Recovery storage could not be initialized. Draft auto-save is unavailable.';

  @override
  String get diskSyncSetting => 'Sync disk files';

  @override
  String get diskSyncDescription =>
      'Saves edits to named files after a 500 ms pause, including incomplete syntax. Checks external changes every second. Conflicts pause synchronization.';

  @override
  String get diskSyncWaiting => 'Waiting to save to disk';

  @override
  String get diskSyncSaving => 'Saving to disk';

  @override
  String get diskSyncSaved => 'Saved to disk';

  @override
  String get diskSyncFailed => 'Disk synchronization failed';

  @override
  String get diskSyncConflict => 'File synchronization conflict';

  @override
  String get diskSyncConflictDescription =>
      'The file changed on disk and has local edits. Synchronization is paused. Choose which version to keep.';

  @override
  String diskSyncError(String error) {
    return 'File synchronization is paused. $error';
  }

  @override
  String get diskSyncCompare => 'Compare versions';

  @override
  String get diskSyncLocal => 'Current edits';

  @override
  String get diskSyncDisk => 'Disk version';

  @override
  String get diskSyncReload => 'Load disk version';

  @override
  String get diskSyncOverwrite => 'Keep local edits';

  @override
  String get diskSyncRetry => 'Retry';

  @override
  String get diskSyncReloadConfirm =>
      'Load the latest disk version and discard the current local edits?';

  @override
  String get diskSyncOverwriteConfirm =>
      'Save the current local edits over the disk version? If the disk version changes again, you will need to review it again.';

  @override
  String get repairJson => 'Repair JSON';

  @override
  String get repairAlreadyValid => 'This document is already valid JSON.';

  @override
  String get repairFailed =>
      'The content could not be repaired. Complete missing values or resolve ambiguous syntax and try again.';

  @override
  String get repairBom => 'Removed BOM markers';

  @override
  String get repairComments => 'Removed comments';

  @override
  String get repairSingleQuotes => 'Converted single-quoted strings';

  @override
  String get repairUnquotedKeys => 'Quoted property names';

  @override
  String get repairTrailingCommas => 'Removed trailing commas';

  @override
  String get repairMissingCommas => 'Inserted commas';

  @override
  String get repairMissingColons => 'Inserted colons';

  @override
  String get repairClosingContainers => 'Closed objects and arrays';

  @override
  String get repairClosingStrings => 'Closed strings';

  @override
  String get repairControlCharacters => 'Escaped control characters';

  @override
  String get repairLiterals => 'Normalized literal values';

  @override
  String get jsonLinesRecords => 'Records';

  @override
  String get jsonLinesSearch => 'Search records';

  @override
  String get jsonLinesFilter => 'Records to show';

  @override
  String get jsonLinesAll => 'All records';

  @override
  String get jsonLinesValid => 'Valid records';

  @override
  String get jsonLinesInvalid => 'Invalid records';

  @override
  String get jsonLinesNoMatches => 'No matching records';

  @override
  String get jsonLinesBlank => 'Blank line';

  @override
  String get jsonLinesExport => 'Export filtered records';

  @override
  String get jsonLinesExported => 'Filtered records exported';

  @override
  String jsonLinesCount(int shown, int total, int invalid) {
    return '$shown / $total records · $invalid invalid';
  }

  @override
  String get jsonLinesConversionNotice =>
      'Each line contains one JSON value. Blank lines are invalid. JSON Lines becomes a JSON array. A JSON array exports one item per line, while other JSON values export as one record.';

  @override
  String foldPreviewMoreLines(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count more lines',
      one: '1 more line',
    );
    return '$_temp0';
  }

  @override
  String get themeCustom => 'Custom';

  @override
  String get themeWarmPaper => 'Warm Paper';

  @override
  String get themePreset => 'Theme preset';

  @override
  String get sourceFolding => 'Source folding';

  @override
  String get treeConnectors => 'Dashed tree connectors';
}
