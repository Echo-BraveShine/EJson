import 'dart:convert';

import 'package:ejson_core/ejson_core.dart';
import 'package:test/test.dart';

void main() {
  test('valid documents remain byte-for-byte identical', () {
    for (final source in [
      ' { "x" : 1e+12, "x": 9007199254740993 }\r\n',
      '[]',
      'true',
      '"text"',
      '{"escape":"\\u0061"}',
    ]) {
      final result = repairJson(source);
      expect(result.source, source);
      expect(result.repairs, isEmpty);
    }
  });

  test('repairs quotes, comments, bare keys and trailing commas', () {
    final result = repairJson("{name:'中文', // note\nlist:[1,2,], /* end */}");
    expect(jsonDecode(result.source), {
      'name': '中文',
      'list': [1, 2],
    });
    expect(result.repairs[JsonRepairKind.comments], 2);
    expect(result.repairs[JsonRepairKind.singleQuotes], 1);
    expect(result.repairs[JsonRepairKind.unquotedKeys], 2);
    expect(result.repairs[JsonRepairKind.trailingCommas], 2);
  });

  test('repairs missing punctuation and EOF closing delimiters', () {
    final result = repairJson('{"a" 1 "b":[true false');
    expect(jsonDecode(result.source), {
      'a': 1,
      'b': [true, false],
    });
    expect(result.repairs[JsonRepairKind.missingColons], 1);
    expect(result.repairs[JsonRepairKind.missingCommas], 2);
    expect(result.repairs[JsonRepairKind.closingContainers], 2);
    expect(jsonDecode(repairJson('{').source), {});
    expect(jsonDecode(repairJson('[1,').source), [1]);
    expect(jsonDecode(repairJson('{"a":"text').source), {'a': 'text'});
  });

  test('preserves duplicate keys, large numbers and number spelling', () {
    final result = repairJson('{x:123456789012345678901,x:1.2300e+40,}');
    final parsed = parseJson(result.source);
    expect(parsed.root!.children, hasLength(2));
    expect(result.source, contains('123456789012345678901'));
    expect(result.source, contains('1.2300e+40'));
    expect(parsed.diagnostics.single.code, 'duplicate_key');
  });

  test('handles quotes, escapes and comments inside strings', () {
    final result = repairJson(
      r'''{url:'https://example.com/a/*b*/',quote:'it\'s "ok"',path:"C:\\tmp",unicode:'\u4e2d',}''',
    );
    expect(jsonDecode(result.source), {
      'url': 'https://example.com/a/*b*/',
      'quote': 'it\'s "ok"',
      'path': r'C:\tmp',
      'unicode': '中',
    });
    expect(result.repairs.containsKey(JsonRepairKind.comments), isFalse);
  });

  test('escapes literal controls and supports common pasted literals', () {
    final result = repairJson(
      '\uFEFF{a:"line\nnext\ttext",b:True,c:False,d:None}',
    );
    expect(jsonDecode(result.source), {
      'a': 'line\nnext\ttext',
      'b': true,
      'c': false,
      'd': null,
    });
    expect(result.repairs[JsonRepairKind.byteOrderMark], 1);
    expect(result.repairs[JsonRepairKind.controlCharacters], 2);
    expect(result.repairs[JsonRepairKind.literals], 3);
  });

  test('rejects missing values, ambiguous tokens and unsupported escapes', () {
    for (final source in [
      '',
      '{a:}',
      '[1,,2]',
      '{a:undefined}',
      '{a:NaN}',
      '[1 2}',
      '{} {}',
      '{a:0123}',
      '{a:hello}',
      '/* unfinished',
      r'''{a:'\q'}''',
      r'''{a:'\u00'}''',
      '"trailing\\',
    ]) {
      expect(() => repairJson(source), throwsFormatException, reason: source);
    }
  });

  test('respects formatting options and preserves CRLF input style', () {
    final result = repairJson(
      '{\r\na:1,\r\n}',
      options: const JsonFormatOptions(indentation: JsonIndentation.tabs),
    );
    expect(result.source, '{\r\n\t"a": 1\r\n}');
  });

  test('enforces source size and nesting limits', () {
    expect(
      () => repairJson(' ' * (2 * 1024 * 1024 + 1)),
      throwsFormatException,
    );
    expect(() => repairJson('${'[' * 258}0'), throwsFormatException);
  });
}
