import 'dart:convert';

import 'package:ejson_core/ejson_core.dart';
import 'package:test/test.dart';

void main() {
  test('jsonl and ndjson extensions map to the same native format', () {
    expect(DocumentFormat.fromPath('logs.JSONL'), DocumentFormat.jsonLines);
    expect(DocumentFormat.fromPath('logs.NDJSON'), DocumentFormat.jsonLines);
    expect(DocumentFormat.jsonLines.extensions, ['jsonl', 'ndjson']);
  });

  test('validates each physical line and reports global source offsets', () {
    const source = '{"id":1}\r\ninvalid\r\n\r\nnull\r\n';
    final snapshot = parseOtherFormat(
      source,
      DocumentFormat.jsonLines,
      revision: 8,
    );
    final rows = snapshot.jsonLines!.records;
    expect(snapshot.revision, 8);
    expect(rows.map((row) => row.lineNumber), [1, 2, 3, 4]);
    expect(rows.map((row) => row.isValid), [true, false, false, true]);
    expect(rows[1].range.start, source.indexOf('invalid'));
    expect(
      snapshot.lines.position(rows[1].diagnostics.first.range.start).line,
      2,
    );
    expect(
      snapshot.lines.position(rows[2].diagnostics.first.range.start).line,
      3,
    );
    expect(rows[3].source, 'null');
  });

  test(
    'accepts empty streams and all JSON value types with optional final LF',
    () {
      expect(readJsonLines('').records, isEmpty);
      final data = readJsonLines('{}\n[]\n"text"\n1e2\ntrue\nfalse\nnull');
      expect(data.records, hasLength(7));
      expect(data.records.every((row) => row.isValid), isTrue);
      expect(readJsonLines('null\n').records, hasLength(1));
      expect(readJsonLines('\n').records.single.isValid, isFalse);
    },
  );

  test(
    'JSON Lines converts to an array while retaining numbers and duplicate keys',
    () {
      const source = '{"id":123456789012345678901,"id":1.2300e+40}\nnull\n';
      final result = jsonLinesToJson(source);
      expect(result, contains('123456789012345678901'));
      expect(result, contains('1.2300e+40'));
      final parsed = parseJson(result);
      expect(parsed.root!.children, hasLength(2));
      expect(parsed.root!.children.first.value.children, hasLength(2));
      expect(jsonLinesToJson(''), '[]');
      expect(jsonDecode(jsonLinesToJson('{"id":1}')), [
        {'id': 1},
      ]);
    },
  );

  test(
    'JSON arrays export one element per line and scalar roots become one record',
    () {
      final lines = jsonToJsonLines('[{"id":1},[2,3],null,"a\\nb"]');
      expect(lines, '{"id":1}\n[2,3]\nnull\n"a\\nb"\n');
      expect(jsonToJsonLines('[]'), '');
      expect(jsonToJsonLines('true'), 'true\n');
      expect(jsonToJsonLines('{"id":1}'), '{"id":1}\n');
    },
  );

  test('formatting always preserves the one-value-per-line structure', () {
    const source = '{ "id" : 1 }\r\n [ 2, 3 ]\r\n';
    final result = formatOtherDocument(
      source,
      DocumentFormat.jsonLines,
      lineEnding: '\r\n',
    );
    expect(result, '{"id":1}\r\n[2,3]\r\n');
    expect(readJsonLines(result).records, hasLength(2));
    expect(
      formatOtherDocument(result, DocumentFormat.jsonLines, minify: true),
      '{"id":1}\n[2,3]\n',
    );
  });

  test('invalid rows block strict conversion and formatting', () {
    for (final source in [
      '{}\n\n[]',
      '{} []',
      '{\n"id":1\n}',
      'null\nbad',
      'null\n ',
    ]) {
      expect(
        () => jsonLinesToJson(source),
        throwsFormatException,
        reason: source,
      );
      expect(
        () => formatJsonLines(source),
        throwsFormatException,
        reason: source,
      );
    }
    expect(readJsonLines('{"a":1,"a":2}').records.single.isValid, isTrue);
  });
}
