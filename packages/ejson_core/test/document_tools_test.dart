import 'dart:convert';
import 'package:ejson_core/ejson_core.dart';
import 'package:test/test.dart';

void main() {
  test('schema errors retain source ranges and escaped pointer tokens', () {
    const source = '{"a/b":{"~name":2},"items":["bad"]}';
    const schema =
        r'{"type":"object","required":["missing"],"properties":{"a/b":{"type":"object","properties":{"~name":{"type":"string"}}},"items":{"type":"array","items":{"type":"integer"}}}}';
    final issues = validateJsonSchema(source, schema);
    expect(issues.length, greaterThanOrEqualTo(3));
    final nested = issues.firstWhere((i) => i.path == r'$["a/b"]["~name"]');
    expect(source.substring(nested.range.start, nested.range.end), '2');
    expect(issues.any((i) => i.path == r'$["items"][0]'), isTrue);
    expect(issues.any((i) => i.path == r'$'), isTrue);
  });
  test('schema supports internal refs, enums and numeric limits', () {
    const schema =
        r'{"definitions":{"item":{"type":"integer","minimum":2,"maximum":4}},"type":"array","items":{"$ref":"#/definitions/item"}}';
    expect(validateJsonSchema('[2,4]', schema), isEmpty);
    expect(validateJsonSchema('[1,5]', schema).length, 2);
    expect(validateJsonSchema('"a"', '{"enum":["b"]}'), isNotEmpty);
    expect(validateJsonSchema('null', 'true'), isEmpty);
    expect(validateJsonSchema('null', 'false'), isNotEmpty);
  });
  test('invalid schemas and ambiguous duplicate data cannot silently pass', () {
    expect(() => validateJsonSchema('{}', '{'), throwsFormatException);
    expect(
      () => validateJsonSchema('{}', r'{"$schema":"unknown-draft"}'),
      throwsFormatException,
    );
    expect(
      () => validateJsonSchema('{"a":1,"a":2}', '{}'),
      throwsFormatException,
    );
    expect(
      () => validateJsonSchema(
        '{}',
        r'{"$ref":"https://example.invalid/schema"}',
      ),
      throwsA(anything),
    );
  });
  test('redaction preserves duplicate keys, number tokens and formatting', () {
    const source =
        '{\r\n "Token":"secret", "token":22, "id":1e2,"other":"中文"\r\n}';
    final result = redactJson(
      source,
      keys: {'token'},
      paths: [],
      replacement: 'hidden"value',
    );
    expect(result.count, 2);
    expect(
      result.source,
      '{\r\n "Token":"hidden\\"value", "token":"hidden\\"value", "id":1e2,"other":"中文"\r\n}',
    );
    expect(jsonDecode(result.source)['id'], 100);
  });
  test('redaction supports wildcard paths and overlapping selections', () {
    final result = redactJson(
      '{"users":[{"email":"a","name":"x"},{"email":"b"}]}',
      keys: {'email'},
      paths: [r'$.users[*].email', r'$.users[0]'],
    );
    expect(result.count, 2);
    expect(result.source, '{"users":["***",{"email":"***"}]}');
    expect(redactJson('[1,2]', keys: {}, paths: [r'$']).source, '"***"');
  });
  test('invalid redaction rules cannot return partial output', () {
    expect(
      () => redactJson(
        '{"password":"secret"}',
        keys: {'password'},
        paths: [r'$['],
      ),
      throwsFormatException,
    );
    expect(redactJson('{"value":1}', keys: {'missing'}, paths: []).count, 0);
  });
}
