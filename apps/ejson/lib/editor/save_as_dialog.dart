import 'package:ejson_core/ejson_core.dart';
import 'package:flutter/material.dart';

import '../design/workbench_style.dart';
import '../l10n/app_localizations.dart';
import 'code_editor.dart';
import 'conversion_job.dart';
import 'json_highlight.dart';

class SaveAsDialog extends StatefulWidget {
  const SaveAsDialog({
    super.key,
    required this.source,
    required this.format,
    required this.bom,
    required this.highlight,
  });

  final String source;
  final DocumentFormat format;
  final bool bom;
  final JsonHighlight highlight;

  @override
  State<SaveAsDialog> createState() => _SaveAsDialogState();
}

class _SaveAsDialogState extends State<SaveAsDialog> {
  late DocumentFormat _format = widget.format;
  late ConversionOutput? _output = ConversionOutput(
    widget.source,
    widget.format,
    bom: widget.bom,
  );
  ConversionJob? _job;
  String? _error;

  Future<void> _selectFormat(DocumentFormat format) async {
    _job?.cancel();
    _job = null;
    setState(() {
      _format = format;
      _output = null;
      _error = null;
    });
    if (format == widget.format) {
      setState(() {
        _output = ConversionOutput(widget.source, format, bom: widget.bom);
      });
      return;
    }
    final job = ConversionJob();
    _job = job;
    final direction = ConversionDirection.values.firstWhere(
      (direction) =>
          direction.sourceFormat == widget.format &&
          (widget.format != DocumentFormat.json ||
              direction.targetFormat == format),
    );
    try {
      final output = await job.run(
        ConversionRequest(
          widget.source,
          direction,
          delimiter: widget.format == DocumentFormat.csv
              ? detectCsvDelimiter(widget.source)
              : ',',
        ),
        targetFormat: format,
      );
      if (mounted && _job == job) setState(() => _output = output);
    } on ConversionCancelled {
      // A new format selection or closing the dialog cancels this preview.
    } catch (error) {
      if (mounted && _job == job) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted && _job == job) setState(() => _job = null);
    }
  }

  @override
  void dispose() {
    _job?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final output = _output;
    return WorkbenchToolDialog(
      title: strings.saveAs,
      scrollable: false,
      content: SizedBox(
        width: 680,
        height: (MediaQuery.sizeOf(context).height - 180).clamp(220.0, 600.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            WorkbenchSelect<DocumentFormat>(
              label: strings.saveAsFormat,
              value: _format,
              options: [
                for (final format in DocumentFormat.values)
                  (
                    value: format,
                    label: '${format.label} (.${format.extension})',
                  ),
              ],
              onChanged: _selectFormat,
            ),
            const SizedBox(height: WorkbenchStyle.space8),
            if (_format != widget.format) ...[
              Text(strings.saveAsConversionHint, style: WorkbenchStyle.caption),
              const SizedBox(height: WorkbenchStyle.space8),
            ],
            Expanded(
              child: output != null
                  ? EJsonCodeEditor(
                      key: const ValueKey('save-as-preview'),
                      source: output.source,
                      format: output.format,
                      highlight: widget.highlight,
                      onChanged: (_) {},
                      readOnly: true,
                      useWorkspaceShortcuts: false,
                    )
                  : _error != null
                  ? SingleChildScrollView(
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          strings.formatFailed(_error!),
                          style: WorkbenchStyle.body.copyWith(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    )
                  : const Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
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
          onPressed: output == null
              ? null
              : () => Navigator.pop(context, output),
          child: Text(strings.save),
        ),
      ],
    );
  }
}
