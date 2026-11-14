import 'package:ejson_core/ejson_core.dart';
import 'package:test/test.dart';

void main() {
  List<String> values(String source, String query) => [
    for (final match in queryJsonPath(source, parseJson(source).root!, query))
      source.substring(match.node.range.start, match.node.range.end),
  ];

  test(
    'keys, indices and wildcards preserve duplicate members and source tokens',
    () {
      const source =
          r'{"items":[{"id":1e2,"id":101},{"id":102}],"a.b":{"中":true}}';
      expect(values(source, r'$.items[*].id'), ['1e2', '101', '102']);
      expect(values(source, r'$["items"][-1]["id"]'), ['102']);
      expect(values(source, r"$['a.b']['中']"), ['true']);
      expect(values(source, r'$.missing[*]'), isEmpty);
      expect(values(source, r'$.items[99]'), isEmpty);
      expect(values(source, r'$.items[-99]'), isEmpty);
      expect(values(source, r'$'), [source]);
      expect(values('[1,true,null]', r'$[*]'), ['1', 'true', 'null']);
      final matches = queryJsonPath(
        source,
        parseJson(source).root!,
        r'$.items[*].id',
      );
      expect(matches.map((match) => match.path), [
        r'$["items"][0]["id"]',
        r'$["items"][0]["id"]',
        r'$["items"][1]["id"]',
      ]);
      expect(matches[0].node.range, isNot(matches[1].node.range));
    },
  );

  test(
    'filters combine scalar comparisons and field existence without coercion',
    () {
      const source = r'''{"items":[
      {"id":1,"price":100,"active":true,"tag":null},
      {"id":2,"price":50,"active":false,"tag":""},
      {"id":3,"price":"100","active":true},
      {"id":4,"price":150,"active":false}
    ]}''';
      expect(
        values(source, r'$.items[?(@.price >= 100 && @.active == true)].id'),
        ['1'],
      );
      expect(values(source, r'$.items[?(@.tag)].id'), ['1', '2']);
      expect(values(source, r'$.items[?(!@.tag)].id'), ['3', '4']);
      expect(values(source, r'$.items[?(@.active)].id'), ['1', '2', '3', '4']);
      expect(values(source, r'$.items[?(@.tag == null)].id'), ['1']);
      expect(values(source, r'$.items[?(@.tag != null)].id'), ['2', '3', '4']);
      expect(
        values(
          source,
          r'$.items[?(@.id == 2 || (@.price >= 100 && !(@.active == true)))].id',
        ),
        ['2', '4'],
      );
      expect(values(source, r'$.items[?@.id < 3].id'), ['1', '2']);
      expect(values(source, r'$.items[?@.id <= 2].id'), ['1', '2']);
      expect(values(source, r'$.items[?@.id > 3].id'), ['4']);
    },
  );

  test(
    'filter operands support quoted keys, escapes, relative indices and exact numbers',
    () {
      const source = r'''[{"n":9007199254740992,"a.b":["a\nb"]},
      {"n":9007199254740993,"a.b":["a\nb"]}, {"n":2e400}]''';
      expect(values(source, r'$[?@.n > 9007199254740992].n'), [
        '9007199254740993',
        '2e400',
      ]);
      expect(values(source, r'$[?@.n == 2E400].n'), ['2e400']);
      expect(values(source, r'''$[?@['a.b'][0] == 'a\nb'].n'''), [
        '9007199254740992',
        '9007199254740993',
      ]);
      expect(
        values(
          r'''[{"name":"O'Reilly"}]''',
          r'''$[?@.name == 'O\'Reilly'].name''',
        ),
        ['"O\'Reilly"'],
      );
      expect(values(r'[{"中":1}]', r'''$[?@["\u4e2d"] == 1]'''), [r'{"中":1}']);
      expect(values(r'[{"a":1,"b":1.0},{"a":1,"b":2}]', r'$[?@.a == @.b].a'), [
        '1',
      ]);
      expect(values(r'[{"a":1,"a":2}]', r'$[?@.a == 1]'), isEmpty);
    },
  );

  test('invalid and unsupported expressions report an offset', () {
    for (final query in [
      '',
      'items',
      r'$..id',
      r'$[',
      r'$[1:3]',
      r'$[0,1]',
      r'$[?]',
      r'$[?true]',
      r'$[?@.id = 1]',
      r'$[?@.id === 1]',
      r'$[?(@.id == 1]',
      r'$[?@.* == 1]',
      r'$[?@. * == 1]',
      r'$[?@[*] == 1]',
      r'$[?@[?@.id]]',
      r'$["bad\x"]',
      r'$["bad\uZZZZ"]',
      r'$[?@.id == 01]',
      r'$[*]garbage',
      '\$[?${'(' * 140}@.id${')' * 140}]',
    ]) {
      expect(
        () => queryJsonPath('[]', parseJson('[]').root!, query),
        throwsA(
          isA<FormatException>().having(
            (error) => error.offset,
            'offset',
            isNotNull,
          ),
        ),
        reason: query,
      );
    }
  });
}
