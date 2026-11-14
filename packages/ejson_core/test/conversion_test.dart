import 'dart:convert';
import 'package:ejson_core/ejson_core.dart';
import 'package:test/test.dart';

void main() {
  test('JSON to YAML retains strings, empty containers and number tokens', () {
    const source =
        r'{"id":123456789012345678901234567890,"decimal":1.234567890123456789,"exponent":1e999,"strings":["001","true","2026-11-14","中文\n\"quoted\""],"empty":{},"list":[],"nil":null}';
    final yaml = jsonToYaml(source);
    final result = yamlToJson(yaml);
    expect(result, contains('123456789012345678901234567890'));
    expect(result, contains('1.234567890123456789'));
    expect(result, contains('1e999'));
    expect(result, contains('"001"'));
    expect(result, contains('"true"'));
    final a = parseJson(source).root!;
    final b = parseJson(result).root!;
    expect(compareJsonStructure(source, a, result, b).differences, isEmpty);
    expect(yaml, contains('"id":'));
  });
  test('all scalar roots and nested arrays round-trip', () {
    for (final source in [
      'null',
      'true',
      '42',
      '"001"',
      '[]',
      '{}',
      '[[1,2],{"x":false}]',
    ]) {
      final output = yamlToJson(jsonToYaml(source, indent: 4), indent: 4);
      expect(jsonDecode(output), jsonDecode(source));
    }
  });
  test('YAML handles exact numeric spellings, tags and aliases', () {
    const source =
        'number: &n 1.234567890123456789\ncopy: *n\nlarge: 999999999999999999999999999999\nquoted: !!float "1.234567890123456789"\nhex: 0xABC\noctal: 0o17\nleading: 001\nplus: +.5\ntrailing: 2.\n';
    final result = yamlToJson(source);
    expect(RegExp('1.234567890123456789').allMatches(result).length, 3);
    expect(result, contains('999999999999999999999999999999'));
    expect(jsonDecode(result)['hex'], 2748);
    expect(jsonDecode(result)['octal'], 15);
    expect(jsonDecode(result)['leading'], 1);
    expect(jsonDecode(result)['plus'], .5);
  });
  test('YAML merge keys expand with explicit keys taking precedence', () {
    final result = yamlToJson(
      'base: &a {x: 1, y: 2}\nsecond: &b {y: 3, z: 4}\nmerged:\n  <<: [*a, *b]\n  x: 9\nliteral: {"<<": 1}\nexplicit: {!!str <<: 1}\n',
    );
    expect(jsonDecode(result)['merged'], {'x': 9, 'y': 2, 'z': 4});
    expect(jsonDecode(result)['literal'], {'<<': 1});
    expect(jsonDecode(result)['explicit'], {'<<': 1});
  });
  test('YAML document selection and source validation', () {
    const source = '---\nx: 1\n---\nx: 2\n';
    expect(yamlDocumentCount(source), 2);
    expect(jsonDecode(yamlToJson(source, document: 1)), {'x': 2});
    expect(() => yamlToJson(source, document: 2), throwsFormatException);
    expect(parseOtherFormat(source, DocumentFormat.yaml).diagnostics, isEmpty);
    expect(
      parseOtherFormat('x: [', DocumentFormat.yaml).diagnostics,
      isNotEmpty,
    );
  });
  test('conversion errors report lossy or unsupported data', () {
    expect(() => jsonToYaml('{"a":1,"a":2}'), throwsFormatException);
    final parsed = parseJson('{"a":1}');
    expect(
      () => rewriteJson(
        JsonDocument(SourceBuffer('{"a":1}'), snapshot: parsed),
        maxLength: 3,
      ),
      throwsFormatException,
    );
    expect(() => yamlToJson('x: 1\nx: 2'), throwsA(anything));
    expect(() => yamlToJson('? [a,b]\n: value'), throwsFormatException);
    expect(() => yamlToJson('x: .inf'), throwsFormatException);
    expect(() => yamlToJson('x: .nan'), throwsFormatException);
    expect(() => yamlToJson('x: !custom value'), throwsA(anything));
    expect(() => yamlToJson('&a [*a]'), throwsA(anything));
  });
  test('flattened columns remain unambiguous and retain raw tokens', () {
    final result = flattenObjectArray(
      r'[{"a.b":1e2,"a":{"b":2},"empty":[],"rows":[{"id":"001"}]}]',
    );
    expect(result, contains('1e2'));
    final fields = (jsonDecode(result) as List).first as Map;
    expect(fields[r'$["a.b"]'], 100);
    expect(fields[r'$["a"]["b"]'], 2);
    expect(fields[r'$["rows"][0]["id"]'], '001');
    expect(fields[r'$["empty"]'], isEmpty);
  });
  test('CSV validation handles quoted multiline data and row counts', () {
    for (final source in [
      '"a","b"\r\n"x\ny","a""b"',
      '"a";"b"\n"1";"2"',
      '"a"\t"b"\n"1"\t"2"',
      '',
    ]) {
      expect(parseOtherFormat(source, DocumentFormat.csv).diagnostics, isEmpty);
    }
    for (final source in ['"unclosed', 'a,b\n1', '"a"x,b', 'a"b,c']) {
      expect(
        parseOtherFormat(source, DocumentFormat.csv).diagnostics,
        isNotEmpty,
      );
    }
  });
  test('format detection retains JSON as the legacy fallback', () {
    expect(DocumentFormat.fromPath('/tmp/a.YML'), DocumentFormat.yaml);
    expect(DocumentFormat.fromPath('/tmp/a.csv'), DocumentFormat.csv);
    expect(DocumentFormat.fromPath('/tmp/a.txt'), DocumentFormat.json);
  });
}
