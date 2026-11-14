import 'dart:convert';
import 'package:ejson_core/ejson_core.dart';
import 'package:test/test.dart';

void main() {
  test(
    'CSV import defaults to strings, preserving zeros, whitespace and quoted newlines',
    () {
      final json = csvToJson('id,text\r\n001,"x,""q""\r\n中文"\r\n2, leading ');
      expect(jsonDecode(json), [
        {'id': '001', 'text': 'x,"q"\r\n中文'},
        {'id': '2', 'text': ' leading '},
      ]);
      expect(csvToJson(''), '[]');
      expect(
        jsonDecode(
          csvToJson('"a";"b"\n"1";"2"', delimiter: ';', header: false),
        ),
        [
          {'column_1': 'a', 'column_2': 'b'},
          {'column_1': '1', 'column_2': '2'},
        ],
      );
    },
  );
  test(
    'CSV explicit column types and empty value policies preserve numeric precision',
    () {
      const columns = [
        CsvImportColumn('id', type: CsvValueType.number),
        CsvImportColumn('active', type: CsvValueType.boolean),
        CsvImportColumn('data', type: CsvValueType.json),
      ];
      const source = 'a,b,c\n123456789012345678901,true,"{""x"":1e999}"\n,,\n';
      final json = csvToJson(
        source,
        columns: columns,
        empty: CsvEmptyValue.nullValue,
      );
      expect(json, contains('123456789012345678901'));
      expect(json, contains('1e999'));
      expect((jsonDecode(json) as List).last, {
        'id': null,
        'active': null,
        'data': null,
      });
      expect(
        (jsonDecode(
                  csvToJson(
                    source,
                    columns: columns,
                    empty: CsvEmptyValue.omitField,
                  ),
                )
                as List)
            .last,
        {},
      );
    },
  );
  test('CSV duplicate headers, invalid types and row shape report errors', () {
    expect(() => csvToJson('a,a\n1,2'), throwsFormatException);
    expect(
      jsonDecode(
        csvToJson(
          'a,a\n1,2',
          columns: const [CsvImportColumn('a'), CsvImportColumn('b')],
        ),
      ),
      [
        {'a': '1', 'b': '2'},
      ],
    );
    expect(
      () => csvToJson(
        'a\nno',
        columns: const [CsvImportColumn('a', type: CsvValueType.number)],
      ),
      throwsA(isA<FormatException>().having((e) => e.offset, 'offset', 2)),
    );
    for (final source in ['a,b\n1', 'a\n"closed"x', '"unclosed']) {
      expect(() => csvToJson(source), throwsFormatException);
    }
  });
}
