import 'dart:convert';
import 'package:ejson_core/ejson_core.dart';
import 'package:test/test.dart';

void main() {
  test(
    'TOML conversion preserves nesting, scalar types and numeric spelling',
    () {
      const source =
          '{"integer":9223372036854775807,"minimum":-9223372036854775808,"float":1.20,"text":"中文\\n🙂","array":[1,true,"001",{}],"nested":{"a.b":true},"empty":{}}';
      final toml = jsonToToml(source);
      final json = tomlToJson(toml);
      expect(jsonDecode(json), jsonDecode(source));
      expect(json, contains('9223372036854775807'));
      expect(json, contains('1.20'));
      expect(tomlToJson(jsonToToml('{}')), '{}');
    },
  );
  test('TOML read retains large integers and high precision decimal lexemes', () {
    final json = tomlToJson(
      'a = 123456789012345678901\nb = 0.123456789012345678901\nc = 0xFFFF\n"1.2" = -0.0\n[1.5]\nx=2.50e+2\n',
    );
    expect(json, contains('123456789012345678901'));
    expect(json, contains('0.123456789012345678901'));
    expect(json, contains('65535'));
    expect(json, contains('2.50e+2'));
    expect(json, contains('-0.0'));
    expect((jsonDecode(json) as Map)['1']['5'], {'x': 250.0});
  });
  test(
    'TOML rejects nulls, duplicate keys, unsupported roots and numeric loss',
    () {
      for (final source in [
        '[]',
        'true',
        '{"a":null}',
        '{"a":1,"a":2}',
        '{"a":9223372036854775808}',
        '{"a":0.123456789012345678901}',
        '{"a":1e999}',
      ]) {
        expect(() => jsonToToml(source), throwsFormatException, reason: source);
      }
      expect(
        () => jsonToToml('{"a":{"b":null}}'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'path',
            contains(r'$["a"]["b"]'),
          ),
        ),
      );
      expect(() => tomlToJson('a=nan'), throwsFormatException);
      expect(() => tomlToJson('a=inf'), throwsFormatException);
      expect(
        parseOtherFormat('a=nan', DocumentFormat.toml).diagnostics,
        isEmpty,
      );
      expect(() => tomlToJson('a=1\na=2'), throwsFormatException);
    },
  );
  test(
    'dates become explicit ISO text and formatting preserves comments and strings',
    () {
      final json =
          jsonDecode(
                tomlToJson('created=1979-05-27T07:32:00Z\nday=1979-05-27\n'),
              )
              as Map;
      expect(json['created'], '1979-05-27T07:32:00Z');
      expect(json['day'], '1979-05-27');
      const source =
          '# note\na=1.230000000000000001 # keep\ntext="a=b#c"\nmultiline="""\ninside = keep\n"""\n';
      final formatted = formatOtherDocument(source, DocumentFormat.toml);
      expect(formatted, contains('a = 1.230000000000000001 # keep'));
      expect(formatted, contains('"a=b#c"'));
      expect(formatted, contains('inside = keep'));
      expect(tomlToJson(formatted), tomlToJson(source));
    },
  );
}
