import 'dart:convert';
import 'dart:math';
import 'package:ejson_core/ejson_core.dart';
import 'package:test/test.dart';

String apply(
  String left,
  String right, {
  bool Function(JsonDifference)? select,
}) {
  final a = parseJson(left).root!;
  final b = parseJson(right).root!;
  final differences = compareJsonStructure(left, a, right, b).differences;
  return applyJsonDifferences(
    left,
    a,
    right,
    b,
    differences.where(select ?? (_) => true).toList(),
  );
}

void main() {
  test('selected edits preserve other tokens, line endings and keys', () {
    const left = ' {\r\n "a":1e2, "b":"\\u0061", "c":3\r\n}\r\n';
    const right = '{"a":200,"b":"changed","c":4,"new":"yes"}';
    final result = apply(left, right, select: (d) => d.path == r'$["c"]');
    expect(result, left.replaceFirst('"c":3', '"c":4'));
    expect(apply(left, right, select: (_) => false), left);
  });
  test('multiple adjacent deletions and additions remain valid', () {
    for (final left in [
      '{"a":1,"b":2,"c":3}',
      '{\n  "a":1,\n  "b":2,\n  "c":3\n}',
    ]) {
      for (final right in [
        '{}',
        '{"new":4}',
        '{"a":1}',
        '{"b":2}',
        '{"c":3}',
      ]) {
        expect(jsonDecode(apply(left, right)), jsonDecode(right));
      }
    }
    expect(jsonDecode(apply('{ }', '{"a":1,"b":2}')), {'a': 1, 'b': 2});
  });
  test('arrays use original indices for mixed updates and removals', () {
    expect(
      apply('[0,1,2,3]', '[4,5]', select: (d) => d.path != r'$[0]'),
      '[0,5]',
    );
    expect(
      jsonDecode(apply('[1]', '[1,2,3]', select: (d) => d.path == r'$[2]')),
      [1, 3],
    );
    expect(apply('[1,2]', '[]'), '[]');
  });
  test('duplicate keys are paired by occurrence at every level', () {
    const left = '{"x":{"a":1,"a":2},"x":{"a":3},"keep":1e2}';
    const right = '{"x":{"a":10,"a":20},"x":{"a":30},"keep":1e2}';
    final result = apply(
      left,
      right,
      select: (d) => d.duplicateOccurrences.toString() == '[1, 2]',
    );
    expect(result, '{"x":{"a":1,"a":20},"x":{"a":3},"keep":1e2}');
    expect(
      apply('{"a":1,"a":2}', '{"a":3,"a":4,"a":5}'),
      '{"a":3,"a":4, "a":5}',
    );
  });
  test('root replacements and nested added or removed containers', () {
    expect(apply(' \n1\r\n', '[1e2,"\\u0061"]'), ' \n[1e2,"\\u0061"]\r\n');
    expect(jsonDecode(apply('{"a":{"b":1}}', '{"c":[1,2]}')), {
      'c': [1, 2],
    });
  });
  test('all selected differences produce structurally matching JSON', () {
    final random = Random(42);
    Object? value(int depth) {
      if (depth == 0) {
        return [null, true, random.nextInt(8), 'a/b~中文'][random.nextInt(4)];
      }
      return switch (random.nextInt(3)) {
        0 => List.generate(random.nextInt(5), (_) => value(depth - 1)),
        1 => {
          for (var i = 0; i < random.nextInt(5); i++) 'k$i': value(depth - 1),
        },
        _ => value(0),
      };
    }

    for (var i = 0; i < 100; i++) {
      final left = const JsonEncoder.withIndent('  ').convert(value(3));
      final right = jsonEncode(value(3));
      final result = apply(left, right);
      expect(parseJson(result).root, isNotNull);
      expect(
        compareJsonStructure(
          result,
          parseJson(result).root!,
          right,
          parseJson(right).root!,
        ).differences,
        isEmpty,
      );
    }
  });
}
