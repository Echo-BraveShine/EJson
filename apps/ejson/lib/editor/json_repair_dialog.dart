import 'dart:isolate';

import 'package:ejson_core/ejson_core.dart';
import 'package:flutter/material.dart';

import '../design/workbench_style.dart';
import '../l10n/app_localizations.dart';
import 'code_editor.dart';
import 'json_highlight.dart';

class JsonRepairDialog extends StatefulWidget {
  const JsonRepairDialog({
    super.key,
    required this.source,
    required this.highlight,
    required this.options,
  });

  final String source;
  final JsonHighlight highlight;
  final JsonFormatOptions options;

  @override
  State<JsonRepairDialog> createState() => _JsonRepairDialogState();
}

class _JsonRepairDialogState extends State<JsonRepairDialog> {
  late final _result = _repair();

  Future<JsonRepairResult> _repair() {
    final source = widget.source;
    final options = widget.options;
    return Isolate.run(() => repairJson(source, options: options));
  }

  String _label(AppLocalizations strings, JsonRepairKind kind) =>
      switch (kind) {
        JsonRepairKind.byteOrderMark => strings.repairBom,
        JsonRepairKind.comments => strings.repairComments,
        JsonRepairKind.singleQuotes => strings.repairSingleQuotes,
        JsonRepairKind.unquotedKeys => strings.repairUnquotedKeys,
        JsonRepairKind.trailingCommas => strings.repairTrailingCommas,
        JsonRepairKind.missingCommas => strings.repairMissingCommas,
        JsonRepairKind.missingColons => strings.repairMissingColons,
        JsonRepairKind.closingContainers => strings.repairClosingContainers,
        JsonRepairKind.closingStrings => strings.repairClosingStrings,
        JsonRepairKind.controlCharacters => strings.repairControlCharacters,
        JsonRepairKind.literals => strings.repairLiterals,
      };

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return FutureBuilder<JsonRepairResult>(
      future: _result,
      builder: (context, snapshot) {
        final result = snapshot.data;
        return WorkbenchToolDialog(
          title: strings.repairJson,
          scrollable: false,
          content: SizedBox(
            width: 720,
            height: (MediaQuery.sizeOf(context).height - 180).clamp(
              220.0,
              650.0,
            ),
            child: result != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 100),
                        child: SingleChildScrollView(
                          child: result.repairs.isEmpty
                              ? Text(strings.repairAlreadyValid)
                              : Wrap(
                                  spacing: 16,
                                  runSpacing: 4,
                                  children: [
                                    for (final entry in result.repairs.entries)
                                      Text(
                                        '${_label(strings, entry.key)} · ${entry.value}',
                                        style: WorkbenchStyle.caption,
                                      ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: WorkbenchStyle.space12),
                      Expanded(
                        child: EJsonCodeEditor(
                          key: const ValueKey('json-repair-preview'),
                          source: result.source,
                          onChanged: (_) {},
                          readOnly: true,
                          highlight: widget.highlight,
                          useWorkspaceShortcuts: false,
                        ),
                      ),
                    ],
                  )
                : snapshot.hasError
                ? SingleChildScrollView(
                    child: Text(
                      '${strings.repairFailed}\n${snapshot.error}',
                      style: WorkbenchStyle.body.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  )
                : const Center(child: CircularProgressIndicator()),
          ),
          actions: [
            TextButton(
              style: workbenchDialogButtonStyle(context),
              onPressed: () => Navigator.pop(context),
              child: Text(strings.cancel),
            ),
            FilledButton(
              style: workbenchDialogButtonStyle(
                context,
                role: DialogButtonRole.primary,
              ),
              onPressed: result == null || result.repairs.isEmpty
                  ? null
                  : () => Navigator.pop(context, result.source),
              child: Text(strings.apply),
            ),
          ],
        );
      },
    );
  }
}
