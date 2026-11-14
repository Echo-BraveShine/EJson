import 'dart:async';
import 'dart:isolate';
import 'package:ejson_core/ejson_core.dart';
import 'array_table_data.dart';

enum ConversionDirection { jsonToYaml, yamlToJson, jsonToCsv }

class ConversionRequest {
  const ConversionRequest(
    this.source,
    this.direction, {
    this.indent = 2,
    this.document = 0,
    this.flatten = false,
    this.delimiter = ',',
    this.header = true,
    this.crlf = true,
    this.bom = false,
    this.columns,
  });
  final String source;
  final ConversionDirection direction;
  final int indent;
  final int document;
  final bool flatten;
  final String delimiter;
  final bool header;
  final bool crlf;
  final bool bom;
  final List<ArrayTableColumn>? columns;
}

class ConversionOutput {
  const ConversionOutput(
    this.source,
    this.format, {
    this.columns = const [],
    this.documents = 1,
    this.bom = false,
  });
  final String source;
  final DocumentFormat format;
  final List<ArrayTableColumn> columns;
  final int documents;
  final bool bom;
}

class ConversionCancelled implements Exception {}

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

ConversionOutput convertDocument(ConversionRequest request) {
  switch (request.direction) {
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
    case ConversionDirection.jsonToCsv:
      final parsed = parseJson(request.source);
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
          ? '[${request.source}]'
          : request.source;
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

void _worker((SendPort, ConversionRequest) message) {
  try {
    message.$1.send(convertDocument(message.$2));
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

  Future<ConversionOutput> run(ConversionRequest request) {
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
    unawaited(_start(request));
    return _completion.future.whenComplete(() {
      _port.close();
      _isolate?.kill(priority: Isolate.immediate);
    });
  }

  Future<void> _start(ConversionRequest request) async {
    try {
      _isolate = await Isolate.spawn(
        _worker,
        (_port.sendPort, request),
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
