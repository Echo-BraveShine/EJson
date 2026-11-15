import 'dart:async';
import 'dart:isolate';
import 'package:ejson_core/ejson_core.dart';
import 'array_table_data.dart';

import 'conversion_models.dart';
export 'conversion_models.dart';

/// Checks whether the default CSV mapping can represent the input.
bool canConvertJsonToCsv(String source) {
  final root = parseJson(source).root;
  if (root == null ||
      (root.kind != JsonKind.array && root.kind != JsonKind.object)) {
    return false;
  }
  final rows = root.kind == JsonKind.object ? '[$source]' : source;
  final data = ArrayTableData(
    rows,
    root.kind == JsonKind.array ? root : parseJson(rows).root!,
  );
  if (data.rows.isNotEmpty && data.columns.isEmpty) return false;
  return data.columns
          .map((c) => data.columnLabel(c, quoteKeys: false))
          .toSet()
          .length ==
      data.columns.length;
}

List<ConversionDirection> availableConversions(
  String source,
  DocumentFormat format,
) {
  if (format != DocumentFormat.json) {
    return ConversionDirection.values
        .where((d) => d.sourceFormat == format)
        .toList();
  }
  final result = <ConversionDirection>[ConversionDirection.jsonToYaml];
  if (parseJson(source).root != null) {
    result.add(ConversionDirection.jsonToJsonLines);
    result.add(ConversionDirection.jsonToXml);
    try {
      jsonToToml(source);
      result.add(ConversionDirection.jsonToToml);
    } on FormatException {
      /* The data cannot be represented by TOML. */
    }
    if (canConvertJsonToCsv(source)) result.add(ConversionDirection.jsonToCsv);
  }
  return result;
}

ConversionOutput convertDocument(ConversionRequest request) {
  final result = _convertDocument(request);
  final parsed = result.format == DocumentFormat.json
      ? parseJson(result.source)
      : parseOtherFormat(result.source, result.format);
  if (parsed.diagnostics.any((d) => !d.warning)) {
    throw FormatException(parsed.diagnostics.first.message);
  }
  return result;
}

ConversionOutput _convertDocument(ConversionRequest request) {
  switch (request.direction) {
    case ConversionDirection.jsonToJsonLines:
      return ConversionOutput(
        jsonToJsonLines(request.source),
        DocumentFormat.jsonLines,
      );
    case ConversionDirection.jsonLinesToJson:
      return ConversionOutput(
        jsonLinesToJson(request.source, indent: request.indent),
        DocumentFormat.json,
      );
    case ConversionDirection.jsonToYaml:
      return ConversionOutput(
        jsonToYaml(request.source, indent: request.indent),
        DocumentFormat.yaml,
      );
    case ConversionDirection.yamlToJson:
      return ConversionOutput(
        yamlToJson(
          request.source,
          document: request.document,
          indent: request.indent,
        ),
        DocumentFormat.json,
        documents: yamlDocumentCount(request.source),
      );
    case ConversionDirection.csvToJson:
      return ConversionOutput(
        csvToJson(
          request.source,
          delimiter: request.delimiter,
          header: request.header,
          columns: request.importColumns,
          empty: request.emptyCells,
          indent: request.indent,
        ),
        DocumentFormat.json,
      );
    case ConversionDirection.jsonToToml:
      return ConversionOutput(jsonToToml(request.source), DocumentFormat.toml);
    case ConversionDirection.tomlToJson:
      return ConversionOutput(
        tomlToJson(request.source, indent: request.indent),
        DocumentFormat.json,
      );
    case ConversionDirection.jsonToXml:
      return ConversionOutput(
        jsonToXml(
          request.source,
          rootName: request.xmlRoot,
          mode: request.xmlMapping,
          indent: request.indent,
        ),
        DocumentFormat.xml,
      );
    case ConversionDirection.xmlToJson:
      return ConversionOutput(
        xmlToJson(request.source, indent: request.indent),
        DocumentFormat.json,
      );
    case ConversionDirection.jsonToCsv:
      final documentRoot = requireJsonRoot(request.source);
      final path = resolveJsonPath(documentRoot, request.csvPath);
      if (path.range == null) {
        throw const FormatException(
          'Choose an existing, unambiguous CSV source path.',
        );
      }
      final selectedSource = request.source.substring(
        path.range!.start,
        path.range!.end,
      );
      final parsed = parseJson(selectedSource);
      final input = parsed.root;
      if (input == null) {
        final diagnostic = parsed.diagnostics.first;
        throw FormatException(
          diagnostic.message,
          request.source,
          diagnostic.range.start,
        );
      }
      if (input.kind != JsonKind.array && input.kind != JsonKind.object) {
        throw const FormatException(
          'CSV conversion requires a JSON array or object.',
        );
      }
      final rows = input.kind == JsonKind.object
          ? '[$selectedSource]'
          : selectedSource;
      final source = request.flatten ? flattenObjectArray(rows) : rows;
      final root = parseJson(source).root!;
      final data = ArrayTableData(source, root);
      if (data.columns.isEmpty && data.rows.isNotEmpty) {
        throw const FormatException('The objects contain no fields to export.');
      }
      final columns = request.columns ?? data.columns;
      if (data.columns.isNotEmpty && columns.isEmpty) {
        throw const FormatException('Select at least one CSV column.');
      }
      if (request.header &&
          columns
                  .map((c) => data.columnLabel(c, quoteKeys: false))
                  .toSet()
                  .length !=
              columns.length) {
        throw const FormatException(
          'CSV headers are ambiguous. Rename the conflicting fields.',
        );
      }
      if (columns.any((c) => !data.columns.contains(c))) {
        throw const FormatException('CSV columns changed. Preview again.');
      }
      return ConversionOutput(
        data.csv(
          List.generate(data.rows.length, (i) => i),
          selectedColumns: columns,
          delimiter: request.delimiter,
          header: request.header,
          lineEnding: request.crlf ? '\r\n' : '\n',
          maxLength: maxConversionUnits,
        ),
        DocumentFormat.csv,
        columns: data.columns,
        bom: request.bom,
      );
  }
}

void _worker((SendPort, ConversionRequest, DocumentFormat?) message) {
  try {
    var output = convertDocument(message.$2);
    final target = message.$3;
    if (target != null && output.documents > 1) {
      throw const FormatException(
        'This YAML file contains multiple documents. Use Format conversion to choose a document before saving.',
      );
    }
    if (target != null && output.format != target) {
      final direction = ConversionDirection.values.firstWhere(
        (direction) =>
            direction.sourceFormat == output.format &&
            direction.targetFormat == target,
      );
      output = convertDocument(ConversionRequest(output.source, direction));
    }
    message.$1.send(output);
  } catch (error) {
    message.$1.send(error.toString());
  }
}

/// A cancellable isolate owns each conversion and releases its port on finish.
class ConversionJob {
  final _port = ReceivePort();
  final _completion = Completer<ConversionOutput>();
  Isolate? _isolate;
  bool _cancelled = false;

  Future<ConversionOutput> run(
    ConversionRequest request, {
    DocumentFormat? targetFormat,
  }) {
    _port.listen((message) {
      if (_completion.isCompleted) return;
      if (message is ConversionOutput) {
        _completion.complete(message);
      } else {
        _completion.completeError(
          StateError(message?.toString() ?? 'Conversion stopped.'),
        );
      }
    });
    unawaited(_start(request, targetFormat));
    return _completion.future.whenComplete(() {
      _port.close();
      _isolate?.kill(priority: Isolate.immediate);
    });
  }

  Future<void> _start(
    ConversionRequest request,
    DocumentFormat? targetFormat,
  ) async {
    try {
      _isolate = await Isolate.spawn(
        _worker,
        (_port.sendPort, request, targetFormat),
        onError: _port.sendPort,
        onExit: _port.sendPort,
      );
      if (_cancelled) _isolate?.kill(priority: Isolate.immediate);
    } catch (error, stack) {
      if (!_completion.isCompleted) _completion.completeError(error, stack);
    }
  }

  void cancel() {
    _cancelled = true;
    _isolate?.kill(priority: Isolate.immediate);
    if (!_completion.isCompleted) {
      _completion.completeError(ConversionCancelled());
    }
  }
}
