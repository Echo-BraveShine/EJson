import 'dart:async';
import 'dart:isolate';

import 'package:ejson_core/ejson_core.dart';
import 'package:flutter/material.dart';

import '../design/workbench_style.dart';
import '../design/workbench_text_field.dart';
import '../l10n/app_localizations.dart';
import '../l10n/workspace_messages.dart';

enum JsonLinesFilter { all, valid, invalid }

Future<String> _prepareExport(
  List<JsonLineRecord> records,
  DocumentFormat format,
) => Isolate.run(() {
  final lines = records.map((record) => record.source).join('\n');
  return format == DocumentFormat.json ? jsonLinesToJson(lines) : '$lines\n';
});

class JsonLinesView extends StatefulWidget {
  const JsonLinesView({
    super.key,
    required this.data,
    required this.onReveal,
    required this.onExport,
  });
  final JsonLinesData data;
  final ValueChanged<SourceRange> onReveal;
  final Future<String?> Function(String, DocumentFormat) onExport;

  @override
  State<JsonLinesView> createState() => _JsonLinesViewState();
}

class _JsonLinesViewState extends State<JsonLinesView> {
  final _search = TextEditingController();
  Timer? _debounce;
  JsonLinesFilter _filter = JsonLinesFilter.all;
  late List<JsonLineRecord> _matches = widget.data.records;
  bool _exporting = false;

  void _applyFilter() {
    final query = _search.text.toLowerCase();
    setState(() {
      _matches = widget.data.records
          .where(
            (record) =>
                (query.isEmpty ||
                    record.source.toLowerCase().contains(query)) &&
                switch (_filter) {
                  JsonLinesFilter.all => true,
                  JsonLinesFilter.valid => record.isValid,
                  JsonLinesFilter.invalid => !record.isValid,
                },
          )
          .toList();
    });
  }

  @override
  void didUpdateWidget(covariant JsonLinesView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) _applyFilter();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _export(DocumentFormat format) async {
    final strings = AppLocalizations.of(context);
    final records = List.of(_matches);
    setState(() => _exporting = true);
    try {
      final source = await _prepareExport(records, format);
      if (!mounted) return;
      final message = await widget.onExport(source, format);
      if (mounted && message != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(strings.exportFailed)));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final invalid = widget.data.records
        .where((record) => !record.isValid)
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(WorkbenchStyle.space8),
          child: Column(
            children: [
              WorkbenchTextField(
                key: const ValueKey('json-lines-search'),
                controller: _search,
                labelText: strings.jsonLinesSearch,
                onChanged: (_) {
                  _debounce?.cancel();
                  _debounce = Timer(
                    const Duration(milliseconds: 150),
                    _applyFilter,
                  );
                },
              ),
              const SizedBox(height: WorkbenchStyle.space8),
              WorkbenchSelect<JsonLinesFilter>(
                label: strings.jsonLinesFilter,
                value: _filter,
                options: [
                  (value: JsonLinesFilter.all, label: strings.jsonLinesAll),
                  (value: JsonLinesFilter.valid, label: strings.jsonLinesValid),
                  (
                    value: JsonLinesFilter.invalid,
                    label: strings.jsonLinesInvalid,
                  ),
                ],
                onChanged: (filter) {
                  _filter = filter;
                  _applyFilter();
                },
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      strings.jsonLinesCount(
                        _matches.length,
                        widget.data.records.length,
                        invalid,
                      ),
                      style: WorkbenchStyle.caption,
                    ),
                  ),
                  PopupMenuButton<DocumentFormat>(
                    tooltip: strings.jsonLinesExport,
                    enabled: !_exporting && _matches.isNotEmpty,
                    icon: const Icon(Icons.file_download_outlined, size: 18),
                    onSelected: _export,
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: DocumentFormat.jsonLines,
                        child: Text('JSON Lines (.jsonl)'),
                      ),
                      PopupMenuItem(
                        value: DocumentFormat.json,
                        enabled: _matches.every((record) => record.isValid),
                        child: const Text('JSON (.json)'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _matches.isEmpty
              ? Center(child: Text(strings.jsonLinesNoMatches))
              : ListView.builder(
                  itemCount: _matches.length,
                  itemBuilder: (context, index) {
                    final record = _matches[index];
                    return ListTile(
                      key: ValueKey('json-line-${record.lineNumber}'),
                      dense: true,
                      leading: Text(
                        '${record.lineNumber}',
                        style: WorkbenchStyle.caption,
                      ),
                      title: Text(
                        record.source.isEmpty
                            ? strings.jsonLinesBlank
                            : record.source,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: WorkbenchStyle.body,
                      ),
                      subtitle: record.diagnostics.isEmpty
                          ? null
                          : Text(
                              strings.diagnosticMessage(
                                record.diagnostics.first,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: WorkbenchStyle.caption,
                            ),
                      trailing: Icon(
                        record.isValid
                            ? Icons.check_circle_outline
                            : Icons.error_outline,
                        size: 16,
                        color: record.isValid
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.error,
                      ),
                      onTap: () => widget.onReveal(record.range),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
