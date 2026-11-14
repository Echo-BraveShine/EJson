import '../design/workbench_text_field.dart';
import 'dart:isolate';
import 'package:ejson_core/ejson_core.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import '../design/workbench_style.dart';
import '../design/reading_style.dart';
import '../l10n/app_localizations.dart';
import '../workspace/local_files.dart';

Future<List<SchemaIssue>> _validateInBackground(String source, String schema) =>
    Isolate.run(() => validateJsonSchema(source, schema));

class SchemaDialog extends StatefulWidget {
  const SchemaDialog({
    super.key,
    required this.source,
    required this.initialSchema,
    required this.onSchemaChanged,
  });
  final String source;
  final String initialSchema;
  final ValueChanged<String> onSchemaChanged;
  @override
  State<SchemaDialog> createState() => _SchemaDialogState();
}

class _SchemaDialogState extends State<SchemaDialog> {
  late final _schema = TextEditingController(text: widget.initialSchema);
  List<SchemaIssue>? _issues;
  String? _error;
  bool _busy = false;
  int _request = 0;

  @override
  void dispose() {
    _schema.dispose();
    super.dispose();
  }

  void _changed(String value) {
    widget.onSchemaChanged(value);
    setState(() {
      _request++;
      _issues = null;
      _error = null;
      _busy = false;
    });
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _busy = true;
      _error = null;
      _issues = null;
    });
    try {
      final selected = await openFile();
      if (selected == null) return;
      final file = await LocalJsonFile.read(selected.path);
      if (!mounted || request != _request) return;
      _schema.text = file.source;
      widget.onSchemaChanged(file.source);
    } catch (error) {
      if (mounted && request == _request) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted && request == _request) setState(() => _busy = false);
    }
  }

  Future<void> _validate() async {
    final request = ++_request;
    final schema = _schema.text;
    final source = widget.source;
    setState(() {
      _busy = true;
      _error = null;
      _issues = null;
    });
    try {
      final issues = await _validateInBackground(source, schema);
      if (mounted && request == _request) setState(() => _issues = issues);
    } catch (error) {
      if (mounted && request == _request) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted && request == _request) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final issues = _issues;
    return WorkbenchToolDialog(
      title: strings.schemaValidation,
      scrollable: false,
      content: SizedBox(
        width: 680,
        height: (MediaQuery.sizeOf(context).height - 180).clamp(220.0, 560.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(strings.schemaHelp, style: WorkbenchStyle.caption),
            const SizedBox(height: WorkbenchStyle.space8),
            Expanded(
              child: WorkbenchTextField(
                controller: _schema,
                expands: true,
                minLines: null,
                maxLines: null,
                style: ReadingStyle.of(context).text,
                onChanged: _changed,
                labelText: 'JSON Schema',
              ),
            ),
            const SizedBox(height: WorkbenchStyle.space8),
            Row(
              children: [
                TextButton(
                  onPressed: _busy ? null : _load,
                  child: Text(strings.loadSchema),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _busy || _schema.text.trim().isEmpty
                      ? null
                      : _validate,
                  child: Text(
                    _busy ? strings.schemaChecking : strings.validateSchema,
                  ),
                ),
              ],
            ),
            if (_error != null)
              Text(
                '${strings.schemaFailed} $_error',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: WorkbenchStyle.caption.copyWith(color: colors.error),
              ),
            if (issues != null)
              Text(
                issues.isEmpty
                    ? strings.schemaValid
                    : strings.schemaIssues(issues.length),
                style: WorkbenchStyle.body.copyWith(
                  color: issues.isEmpty ? colors.primary : colors.error,
                ),
              ),
            if (issues != null && issues.isNotEmpty) ...[
              const SizedBox(height: WorkbenchStyle.space8),
              Expanded(
                child: Material(
                  color: colors.surface,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      WorkbenchStyle.controlRadius,
                    ),
                    side: BorderSide(color: colors.outlineVariant),
                  ),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(WorkbenchStyle.space4),
                    itemCount: issues.length,
                    separatorBuilder: (_, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final issue = issues[index];
                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: WorkbenchStyle.space8,
                        ),
                        title: Text(
                          issue.path,
                          style: WorkbenchStyle.body,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          issue.message,
                          style: WorkbenchStyle.caption,
                        ),
                        onTap: () => Navigator.pop(context, issue.range),
                      );
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          style: workbenchDialogButtonStyle(context),
          onPressed: () => Navigator.pop(context),
          child: Text(strings.done),
        ),
      ],
    );
  }
}
