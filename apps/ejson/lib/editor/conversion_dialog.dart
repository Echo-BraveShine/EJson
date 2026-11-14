import '../design/workbench_text_field.dart';
import 'package:ejson_core/ejson_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/services.dart';
import '../design/workbench_style.dart';
import '../l10n/app_localizations.dart';
import 'array_table_data.dart';
import 'code_editor.dart';
import 'json_highlight.dart';
import 'conversion_job.dart';

part 'conversion_csv_options.dart';

class ConversionResult {
  const ConversionResult(this.output, {required this.save});
  final ConversionOutput output;
  final bool save;
}

class ConversionDialog extends StatefulWidget {
  const ConversionDialog({
    super.key,
    required this.source,
    required this.format,
    required this.highlight,
  });
  final String source;
  final DocumentFormat format;
  final JsonHighlight highlight;
  @override
  State<ConversionDialog> createState() => _ConversionDialogState();
}

class _ConversionDialogState extends State<ConversionDialog> {
  final _document = TextEditingController(text: '1');
  final _scroll = ScrollController();
  late ConversionDirection _direction = widget.format == DocumentFormat.yaml
      ? ConversionDirection.yamlToJson
      : ConversionDirection.jsonToYaml;
  late final bool _csvAvailable =
      widget.format == DocumentFormat.json &&
      canConvertJsonToCsv(widget.source);
  int _indent = 2;
  bool _flatten = false,
      _header = true,
      _crlf = true,
      _bom = false,
      _busy = false,
      _columnsKnown = false;
  String _delimiter = ',';
  List<ArrayTableColumn> _order = [];
  final _included = <ArrayTableColumn>{};
  ConversionOutput? _output;
  ConversionJob? _job;
  String? _error;
  int _generation = 0;

  void _invalidate({bool resetColumns = false}) {
    _generation++;
    _job?.cancel();
    _job = null;
    setState(() {
      _busy = false;
      _output = null;
      _error = null;
      if (resetColumns) {
        _columnsKnown = false;
        _order = [];
        _included.clear();
      }
    });
  }

  @override
  void dispose() {
    _job?.cancel();
    _document.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _convert() async {
    final number = int.tryParse(_document.text);
    if (_direction == ConversionDirection.yamlToJson &&
        (number == null || number < 1)) {
      setState(
        () => _error = AppLocalizations.of(context).conversionDocumentError,
      );
      return;
    }
    final generation = ++_generation;
    final job = ConversionJob();
    _job = job;
    setState(() {
      _busy = true;
      _error = null;
      _output = null;
    });
    try {
      final result = await job.run(
        ConversionRequest(
          widget.source,
          _direction,
          indent: _indent,
          document: (number ?? 1) - 1,
          flatten: _flatten,
          delimiter: _delimiter,
          header: _header,
          crlf: _crlf,
          bom: _bom,
          columns: _columnsKnown
              ? _order.where(_included.contains).toList()
              : null,
        ),
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _output = result;
        if (!_columnsKnown && _direction == ConversionDirection.jsonToCsv) {
          _order = List.of(result.columns);
          _included.addAll(_order);
          _columnsKnown = true;
        }
      });
    } on ConversionCancelled {
      /* The input or options changed, or the user cancelled. */
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() {
          _busy = false;
          _job = null;
        });
      }
    }
  }

  Widget _check(String label, bool value, ValueChanged<bool> change) =>
      CheckboxListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text(label, style: WorkbenchStyle.body),
        value: value,
        onChanged: (next) {
          change(next ?? false);
          _invalidate();
        },
      );
  void _move(int index, int delta) {
    final next = _order.removeAt(index);
    _order.insert(index + delta, next);
    _invalidate();
  }

  Widget _runButton() {
    final strings = AppLocalizations.of(context);
    return TextButton(
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
      onPressed: _busy
          ? () => _invalidate()
          : widget.source.trim().isEmpty
          ? null
          : _convert,
      child: Text(_busy ? strings.conversionCancel : strings.conversionRun),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final output = _output;
    final csv = _direction == ConversionDirection.jsonToCsv;
    final yaml = _direction == ConversionDirection.yamlToJson;
    return WorkbenchToolDialog(
      title: strings.formatConversion,
      scrollable: false,
      content: SizedBox(
        width: 680,
        height: (MediaQuery.sizeOf(context).height - 180).clamp(
          220.0,
          double.infinity,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) => Column(
            key: const ValueKey('conversion-body'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: constraints.maxHeight * (output == null ? 1 : .5),
                ),
                child: Scrollbar(
                  controller: _scroll,
                  child: SingleChildScrollView(
                    controller: _scroll,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        WorkbenchSelect<ConversionDirection>(
                          label: strings.conversionDirection,
                          value: _direction,
                          options: [
                            if (widget.format == DocumentFormat.yaml)
                              (
                                value: ConversionDirection.yamlToJson,
                                label: 'YAML → JSON',
                              )
                            else ...[
                              (
                                value: ConversionDirection.jsonToYaml,
                                label: 'JSON → YAML',
                              ),
                              if (_csvAvailable)
                                (
                                  value: ConversionDirection.jsonToCsv,
                                  label: 'JSON → CSV',
                                ),
                            ],
                          ],
                          onChanged: (direction) {
                            _direction = direction;
                            _invalidate(resetColumns: true);
                          },
                        ),
                        const SizedBox(height: WorkbenchStyle.space12),
                        if (!csv)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: WorkbenchSelect<int>(
                                  label: strings.formatIndentation,
                                  value: _indent,
                                  options: [
                                    (value: 2, label: strings.indentTwo),
                                    (value: 4, label: strings.indentFour),
                                    (value: 8, label: strings.indentEight),
                                  ],
                                  onChanged: (value) {
                                    _indent = value;
                                    _invalidate();
                                  },
                                ),
                              ),
                              if (yaml) ...[
                                const SizedBox(width: WorkbenchStyle.space12),
                                Expanded(
                                  child: WorkbenchTextField(
                                    controller: _document,
                                    keyboardType: TextInputType.number,
                                    labelText: strings.conversionDocument,
                                    onChanged: (_) => _invalidate(),
                                  ),
                                ),
                              ],
                              const SizedBox(width: WorkbenchStyle.space8),
                              _runButton(),
                            ],
                          ),
                        if (yaml)
                          Padding(
                            padding: const EdgeInsets.only(
                              top: WorkbenchStyle.space8,
                            ),
                            child: Text(
                              strings.conversionYamlNotice,
                              style: WorkbenchStyle.caption,
                            ),
                          ),
                        if (csv) ..._csvOptions(),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: WorkbenchStyle.space8,
                            ),
                            child: Semantics(
                              liveRegion: true,
                              child: Text(
                                _error!,
                                maxLines: 5,
                                overflow: TextOverflow.ellipsis,
                                style: WorkbenchStyle.caption.copyWith(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (output != null) ...[
                const SizedBox(height: WorkbenchStyle.space8),
                Text(
                  '${output.format.label}${output.documents > 1 ? ' · ${strings.conversionDocuments(output.documents)}' : ''}',
                  style: WorkbenchStyle.body,
                ),
                const SizedBox(height: WorkbenchStyle.space8),
                Expanded(
                  child: EJsonCodeEditor(
                    key: const ValueKey('conversion-preview'),
                    source: output.source,
                    format: output.format,
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
      ),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (output != null) ...[
              Flexible(
                child: TextButton(
                  style: workbenchDialogButtonStyle(context),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: output.source));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(strings.conversionCopied)),
                      );
                    }
                  },
                  child: Text(
                    strings.conversionCopy,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: WorkbenchStyle.space8),
            ],
            Flexible(
              child: TextButton(
                style: workbenchDialogButtonStyle(context),
                onPressed: () => Navigator.pop(context),
                child: Text(
                  strings.cancel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: WorkbenchStyle.space8),
            Flexible(
              child: TextButton(
                style: workbenchDialogButtonStyle(context),
                onPressed: output == null
                    ? null
                    : () => Navigator.pop(
                        context,
                        ConversionResult(output, save: false),
                      ),
                child: Text(
                  strings.conversionOpen,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: WorkbenchStyle.space8),
            Flexible(
              child: FilledButton(
                style: workbenchDialogButtonStyle(
                  context,
                  role: DialogButtonRole.primary,
                ),
                onPressed: output == null
                    ? null
                    : () => Navigator.pop(
                        context,
                        ConversionResult(output, save: true),
                      ),
                child: Text(
                  strings.conversionExport,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
