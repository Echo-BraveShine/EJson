import 'package:ejson_core/ejson_core.dart';

import '../workspace/local_files.dart';
import '../workspace/workspace.dart';
import 'app_localizations.dart';

extension WorkspaceMessages on AppLocalizations {
  String tabName(WorkspaceTab tab) => tab.file != null
      ? tab.name
      : tab.isDefault
      ? untitled
      : numberedUntitled(tab.id);

  String diagnosticMessage(JsonDiagnostic diagnostic) =>
      switch (diagnostic.code) {
        'trailing_content' => trailingContent,
        'depth_limit' => depthLimit,
        'expected_value' => expectedValue,
        'expected_key' => expectedKey,
        'duplicate_key' => duplicateKey,
        'expected_colon' => expectedColon,
        'expected_delimiter' =>
          diagnostic.detail == 'object'
              ? expectedObjectDelimiter
              : expectedArrayDelimiter,
        'invalid_literal' =>
          diagnostic.detail == null
              ? expectedValue
              : invalidLiteral(diagnostic.detail!),
        'unclosed_string' => unclosedString,
        'control_character' => controlCharacter,
        'invalid_unicode_escape' => invalidUnicodeEscape,
        'invalid_escape' => invalidEscape,
        _ => diagnostic.message,
      };

  String fileError(Object error) => switch (error) {
    FileChangedException(:final path) => '$fileChanged\n$path',
    LocalFileException(:final reason, :final path) =>
      '${switch (reason) {
        LocalFileError.openLimit => fileTooLarge,
        LocalFileError.saveLimit => saveTooLarge,
        LocalFileError.permissions => filePermissions,
      }}\n$path',
    FormatException() => invalidEncoding,
    _ => error.toString(),
  };
}
