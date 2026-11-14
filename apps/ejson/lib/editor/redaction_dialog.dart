import '../design/workbench_text_field.dart';
import 'dart:isolate';
import 'package:ejson_core/ejson_core.dart';
import 'package:flutter/material.dart';
import '../design/workbench_style.dart';
import '../l10n/app_localizations.dart';
import 'code_editor.dart';
import 'json_highlight.dart';

Future<RedactedJson> _redactInBackground(
  String source,
  Set<String> keys,
  List<String> paths,
  String replacement,
) => Isolate.run(
  () => redactJson(source, keys: keys, paths: paths, replacement: replacement),
);

class RedactionResult {
  const RedactionResult(this.source, {required this.save});
  final String source;
  final bool save;
}

class RedactionDialog extends StatefulWidget {
  const RedactionDialog({
    super.key,
    required this.source,
    required this.highlight,
  });
  final String source;
  final JsonHighlight highlight;
  @override
  State<RedactionDialog> createState() => _RedactionDialogState();
}

class _RedactionDialogState extends State<RedactionDialog> {
  final _keys = TextEditingController(
    text: 'password, token, secret, phone, email',
  );
  final _paths = TextEditingController();
  final _replacement = TextEditingController(text: '***');
  RedactedJson? _result;
  String? _error;
  bool _busy = false;
  int _request = 0;

  @override
  void dispose() {
    _keys.dispose();
    _paths.dispose();
    _replacement.dispose();
    super.dispose();
  }

  void _changed(String _) => setState(() {
    _request++;
    _result = null;
    _error = null;
    _busy = false;
  });

  Future<void> _preview() async {
    final request = ++_request;
    final source = widget.source;
    final keys = _keys.text
        .split(RegExp(r'[,，\n]'))
        .map((k) => k.trim())
        .where((k) => k.isNotEmpty)
        .toSet();
    final paths = _paths.text
        .split('\n')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    final replacement = _replacement.text;
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    try {
      final result = await _redactInBackground(
        source,
        keys,
        paths,
        replacement,
      );
      if (mounted && request == _request) setState(() => _result = result);
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
    final result = _result;
    return WorkbenchToolDialog(
      title: strings.redactData,
      content: SizedBox(
        width: 640,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(strings.redactHelp, style: WorkbenchStyle.caption),
            const SizedBox(height: WorkbenchStyle.space12),
            WorkbenchTextField(
              controller: _keys,
              onChanged: _changed,
              labelText: strings.redactKeys,
            ),
            const SizedBox(height: WorkbenchStyle.space12),
            WorkbenchTextField(
              controller: _paths,
              onChanged: _changed,
              minLines: 2,
              maxLines: 4,
              labelText: strings.redactPaths,
            ),
            const SizedBox(height: WorkbenchStyle.space12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: WorkbenchTextField(
                    controller: _replacement,
                    onChanged: _changed,
                    labelText: strings.redactReplacement,
                  ),
                ),
                const SizedBox(width: WorkbenchStyle.space8),
                TextButton(
                  style: workbenchDialogButtonStyle(context).copyWith(
                    fixedSize: WidgetStatePropertyAll(
                      Size.fromHeight(
                        WorkbenchStyle.inputHeightFor(
                          context,
                          Theme.of(context).textTheme.bodyMedium!,
                        ),
                      ),
                    ),
                  ),
                  onPressed: _busy ? null : _preview,
                  child: Text(
                    _busy ? strings.schemaChecking : strings.readingPreview,
                  ),
                ),
              ],
            ),
            const SizedBox(height: WorkbenchStyle.space8),
            if (_error != null)
              Text(
                _error!,
                style: WorkbenchStyle.caption.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            if (result != null) ...[
              Text(strings.redactCount(result.count)),
              const SizedBox(height: WorkbenchStyle.space8),
              SizedBox(
                height: 180,
                child: EJsonCodeEditor(
                  source: result.source,
                  highlight: widget.highlight,
                  onChanged: (_) {},
                  readOnly: true,
                  useWorkspaceShortcuts: false,
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
          child: Text(strings.cancel),
        ),
        TextButton(
          style: workbenchDialogButtonStyle(context),
          onPressed: result == null || result.count == 0
              ? null
              : () => Navigator.pop(
                  context,
                  RedactionResult(result.source, save: false),
                ),
          child: Text(strings.openRedactedCopy),
        ),
        FilledButton(
          style: workbenchDialogButtonStyle(
            context,
            role: DialogButtonRole.primary,
          ),
          onPressed: result == null || result.count == 0
              ? null
              : () => Navigator.pop(
                  context,
                  RedactionResult(result.source, save: true),
                ),
          child: Text(strings.saveRedactedCopy),
        ),
      ],
    );
  }
}
