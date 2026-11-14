import 'dart:convert';
import 'dart:math';

import 'package:ejson_core/ejson_core.dart';
import 'package:test/test.dart';

JsonDocument document(String source) =>
    JsonDocument(SourceBuffer(source)).accept(parseJson(source));

void main() {
  test(
    'JSONPath resolves copied paths and reports malformed or duplicate keys',
    () {
      const source = r'{"items":[{"a/b":42}],"dup":1,"dup":2}';
      final root = parseJson(source).root!;
      final match = resolveJsonPath(root, r'$.items[0]["a/b"]');
      expect(match.status, JsonPathStatus.found);
      expect(source.substring(match.range!.start, match.range!.end), '42');
      expect(resolveJsonPath(root, r'$.dup').status, JsonPathStatus.ambiguous);
      expect(
        resolveJsonPath(root, r'$.items[5]').status,
        JsonPathStatus.missing,
      );
      expect(
        resolveJsonPath(root, r'$.missing[*]').status,
        JsonPathStatus.invalid,
      );
    },
  );

  test(
    'structure comparison ignores key order and keeps duplicate occurrences',
    () {
      const a = r'{"b":[1,2],"s":"a","dup":1,"dup":2,"gone":true}';
      const b = r'{"s":"\u0061","dup":1,"dup":3,"b":[2,1],"new":null}';
      JsonComparison compare({int limit = 1000}) => compareJsonStructure(
        a,
        parseJson(a).root!,
        b,
        parseJson(b).root!,
        limit: limit,
      );
      final result = compare();
      expect(result.differences.map((diff) => diff.path), [
        r'$["b"][0]',
        r'$["b"][1]',
        r'$["dup"]',
        r'$["gone"]',
        r'$["new"]',
      ]);
      expect(result.differences[2].duplicateOccurrences, [2]);
      expect(result.differences[3].right, isNull);
      expect(result.differences[4].left, isNull);
      expect(compare(limit: 2).truncated, isTrue);
    },
  );

  test(
    'tree patches preserve unrelated tokens and remove the correct comma',
    () {
      const source = '{ "dup": 1e+2, "dup": "\\u0061", "list": [1, 2, 3] }';
      final root = parseJson(source).root!;
      final list = root.children.last.value;
      expect(
        appendJsonChild(source, list, '4').apply(source),
        source.replaceFirst('[1, 2, 3]', '[1, 2, 3, 4]'),
      );
      for (final (index, expected) in [
        (0, '[2, 3]'),
        (1, '[1, 3]'),
        (2, '[1, 2]'),
      ]) {
        expect(
          removeJsonChild(list, index).apply(source),
          source.replaceFirst('[1, 2, 3]', expected),
        );
      }
      const empty = '{"list": []}';
      expect(
        appendJsonChild(
          empty,
          parseJson(empty).root!.children.single.value,
          'null',
        ).apply(empty),
        '{"list": [null]}',
      );
      expect(removeJsonChild(parseJson('[0]').root!, 0).apply('[0]'), '[]');
    },
  );

  test('formatting tree additions preserves raw tokens and line endings', () {
    const source = '{"dup":1e+2,"dup":"\\u0061","list":[]}\r\n';
    final list = parseJson(source).root!.children.last.value;
    final result = appendFormattedJsonChild(source, list, '{\n"k":2\n}');
    expect(result.error, isNull);
    final patch = result.patch!;
    final updated = patch.apply(source);
    expect(
      updated,
      [
        '{',
        '  "dup": 1e+2,',
        r'  "dup": "\u0061",',
        '  "list": [',
        '    {',
        '      "k": 2',
        '    }',
        '  ]',
        '}',
        '',
      ].join('\r\n'),
    );
    expect(patch.inverse(source).apply(updated), source);

    final tooDeep = appendFormattedJsonChild(
      source,
      list,
      '${'[' * 256}0${']' * 256}',
    );
    expect(tooDeep.patch, isNull);
    expect(tooDeep.error?.code, 'depth_limit');
  });

  test('accepts all JSON root types and strict whitespace', () {
    for (final source in [
      ' {} ',
      '[]',
      ' "\\u4e2d" ',
      'false',
      'true',
      'null',
      '-12.30e+09',
      '\r\n\t[1,2]',
    ]) {
      expect(parseJson(source).root, isNotNull, reason: source);
    }
  });

  test('rejects invalid grammar and reports an in-bounds range', () {
    for (final source in [
      '',
      '[,1]',
      '[1,]',
      '{"x":1,}',
      '{"x" 1}',
      '{x:1}',
      '[01]',
      '-01',
      '.3',
      '1.',
      '1e+',
      '+1',
      'NaN',
      'true false',
      '// comment',
      '"unclosed',
      '"\\q"',
      '"\\u00x0"',
      '"abc\t"',
      '[nul]',
      '\u00a0null',
    ]) {
      final parsed = parseJson(source);
      expect(parsed.root, isNull, reason: source);
      final range = parsed.diagnostics.single.range;
      expect(range.start, inInclusiveRange(0, source.length), reason: source);
      expect(
        range.end,
        inInclusiveRange(range.start, source.length),
        reason: source,
      );
    }
  });

  test('duplicate keys retain raw ranges, including escaped aliases', () {
    final source = r'{"a":1,"\u0061":999999999999999999999,"🙂":"中"}';
    final parsed = parseJson(source);
    final children = parsed.root!.children;
    expect(children.map((child) => child.key), ['a', 'a', '🙂']);
    expect(parsed.diagnostics.single.code, 'duplicate_key');
    expect(SourceBuffer(source).slice(children[1].keyRange!), r'"\u0061"');
    expect(SourceBuffer(source).slice(children[2].value.range), '"中"');
  });

  test('diagnostics use UTF-16 offsets and handle CRLF and lone CR', () {
    const source = '{\r\n  "🙂": false,\r  "中": ?\n}';
    final result = parseJson(source);
    final offset = result.diagnostics.single.range.start;
    expect(offset, source.indexOf('?'));
    expect(result.lines.position(offset), (line: 3, column: 8));
  });

  test('formatter preserves tokens, CRLF and final newline', () {
    final doc = document(
      ' { "x" : 1e+03, "\\u0078" : [ 99999999999999999999 , { } ] }\r\n',
    );
    final pretty = rewriteJson(doc);
    expect(
      pretty,
      '{\r\n  "x": 1e+03,\r\n  "\\u0078": [\r\n    99999999999999999999,\r\n    {}\r\n  ]\r\n}\r\n',
    );
    expect(rewriteJson(document(pretty)), pretty);
    expect(
      rewriteJson(doc, minify: true),
      r'{"x":1e+03,"\u0078":[99999999999999999999,{}]}',
    );
  });

  test('source patch, stale revision, last valid snapshot and undo/redo', () {
    const source = '{ "x" : 20,  "x" : 22 }';
    final doc = document(source);
    final target = doc.snapshot!.root!.children.first.value.range;
    final patch = SourcePatch(target, '3');
    final history = EditHistory()..record(patch, source);
    expect(doc.apply(patch, expectedRevision: 99), isNull);
    final changed = doc.apply(patch, expectedRevision: 0)!;
    expect(changed.source.text, '{ "x" : 3,  "x" : 22 }');
    expect(changed.accept(doc.snapshot!), same(changed));
    expect(changed.lastValidSource!.text, source);
    expect(history.undo()!.apply(changed.source.text), source);
    expect(history.redo()!.apply(source), changed.source.text);
  });

  test('deep nesting returns a diagnostic rather than overflowing', () {
    final result = parseJson('${'[' * 300}0${']' * 300}');
    expect(result.diagnostics.single.code, 'depth_limit');
  });

  test(
    'random JSON round-trips through Dart decoding and EJson formatting',
    () {
      final random = Random(31);
      Object? value(int depth) {
        if (depth == 0) {
          return [
            null,
            true,
            false,
            '中文🙂\n"\\',
            random.nextInt(1000),
            random.nextDouble(),
          ][random.nextInt(6)];
        }
        return random.nextBool()
            ? List.generate(random.nextInt(5), (_) => value(depth - 1))
            : {
                for (var i = random.nextInt(5); i > 0; i--)
                  'key$i': value(depth - 1),
              };
      }

      for (var i = 0; i < 200; i++) {
        final original = value(random.nextInt(5));
        final doc = document(jsonEncode(original));
        expect(jsonDecode(rewriteJson(doc)), original);
        expect(jsonDecode(rewriteJson(doc, minify: true)), original);
      }
    },
  );
}
