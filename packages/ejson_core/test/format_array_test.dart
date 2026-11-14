import 'package:ejson_core/ejson_core.dart';
import 'package:test/test.dart';

JsonDocument document(String source) =>
    JsonDocument(SourceBuffer(source), snapshot: parseJson(source));

void main() {
  test(
    'format options select indentation and line endings without changing tokens',
    () {
      const source = '{"a":[1e2,"\\u4e2d"],"a":-0}\r\n';
      final formatted = rewriteJson(
        document(source),
        options: const JsonFormatOptions(
          indentation: JsonIndentation.tabs,
          lineEnding: JsonLineEnding.lf,
        ),
      );
      expect(
        formatted,
        '{\n\t"a": [\n\t\t1e2,\n\t\t"\\u4e2d"\n\t],\n\t"a": -0\n}\n',
      );
      expect(rewriteJson(document(source)), contains('\r\n  "a"'));
      expect(
        rewriteJson(
          document(source),
          minify: true,
          options: const JsonFormatOptions(
            indentation: JsonIndentation.eightSpaces,
            lineEnding: JsonLineEnding.cr,
          ),
        ),
        '{"a":[1e2,"\\u4e2d"],"a":-0}',
      );
      for (final ending in [
        JsonLineEnding.lf,
        JsonLineEnding.crlf,
        JsonLineEnding.cr,
      ]) {
        final newline = ending.resolve('');
        final text = rewriteJson(
          document('{"a":1}'),
          options: JsonFormatOptions(
            indentation: JsonIndentation.fourSpaces,
            lineEnding: ending,
          ),
        );
        expect(text, '{$newline    "a": 1$newline}');
      }
    },
  );

  test('tree additions use the selected format preferences', () {
    const source = '[1]\n';
    final result = appendFormattedJsonChild(
      source,
      parseJson(source).root!,
      '{"x":2}',
      options: const JsonFormatOptions(
        indentation: JsonIndentation.fourSpaces,
        lineEnding: JsonLineEnding.crlf,
      ),
    );
    expect(
      result.patch!.apply(source),
      '[\r\n    1,\r\n    {\r\n        "x": 2\r\n    }\r\n]\r\n',
    );
  });

  test('moves and copies retain array slots and unrelated text', () {
    const source =
        '{ "items": [\r\n  1e2, \r\n  {"a":1,"a":2},\n  "\\u4e2d"\r\n], "x":-0 }';
    final array = parseJson(source).root!.children.first.value;
    final moved = moveJsonArrayItem(source, array, 0, 2).apply(source);
    expect(
      moved,
      '{ "items": [\r\n  {"a":1,"a":2}, \r\n  "\\u4e2d",\n  1e2\r\n], "x":-0 }',
    );
    final copied = duplicateJsonArrayItem(source, array, 1).apply(source);
    expect(parseJson(copied).root!.children.first.value.children.length, 4);
    expect(copied, contains('{"a":1,"a":2},\n  {"a":1,"a":2}'));
    expect(copied, endsWith('], "x":-0 }'));
    expect(moveJsonArrayItem(source, array, 1, 1).apply(source), source);
    expect(
      duplicateJsonArrayItem(
        '[\n  1\n]',
        parseJson('[\n  1\n]').root!,
        0,
      ).apply('[\n  1\n]'),
      '[\n  1,\n  1\n]',
    );
  });

  test('array sorting is stable, exact and places missing fields last', () {
    const source =
        '[{"n":9007199254740993},{"n":2e400},{"n":9007199254740992},{},{"n":9007199254740992}]';
    final array = parseJson(source).root!;
    expect(
      sortJsonArray(source, array, key: 'n').apply(source),
      '[{"n":9007199254740992},{"n":9007199254740992},{"n":9007199254740993},{"n":2e400},{}]',
    );
    expect(
      sortJsonArray(source, array, key: 'n', ascending: false).apply(source),
      '[{"n":2e400},{"n":9007199254740993},{"n":9007199254740992},{"n":9007199254740992},{}]',
    );
    const values = '[10,2,1.0,1]';
    expect(
      sortJsonArray(values, parseJson(values).root!).apply(values),
      '[1.0,1,2,10]',
    );
    const emptyKey = '[{"":2},{"":1}]';
    expect(
      sortJsonArray(
        emptyKey,
        parseJson(emptyKey).root!,
        key: '',
      ).apply(emptyKey),
      '[{"":1},{"":2}]',
    );
    const duplicate = '[{"id":2,"id":1}]';
    expect(
      () => sortJsonArray(duplicate, parseJson(duplicate).root!, key: 'id'),
      throwsFormatException,
    );
    expect(
      sortJsonArray('[  ]', parseJson('[  ]').root!).apply('[  ]'),
      '[  ]',
    );
  });

  test('array operations reject invalid targets', () {
    final array = parseJson('[1]').root!;
    expect(() => moveJsonArrayItem('[1]', array, 0, 1), throwsRangeError);
    expect(() => duplicateJsonArrayItem('[1]', array, -1), throwsRangeError);
    expect(
      () => sortJsonArray('{}', parseJson('{}').root!),
      throwsArgumentError,
    );
  });
}
