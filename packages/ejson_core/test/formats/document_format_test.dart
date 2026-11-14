import 'dart:convert';
import 'package:ejson_core/ejson_core.dart';
import 'package:test/test.dart';

void main() {
  test('all extensions identify their native document formats', () {
    for (final format in DocumentFormat.values) {
      expect(DocumentFormat.fromPath('/tmp/中文.${format.extension}'), format);
    }
    expect(DocumentFormat.fromPath('config.YML'), DocumentFormat.yaml);
  });

  test('YAML formatting retains comments, aliases and multiline values', () {
    for (final source in [
      '# heading\nroot:\n    a: 1 # keep\n    b:\n        - name: first\n          value: true\n        - name: second\n          value: false\n',
      'root:\n    text: |\n        first\n          indented\n        last\n    after: yes\n',
      'base: &base\n    name: test\ncopy: *base\n',
      'text: "first\n    second"\nnext: true\n',
      '---\na:\n    b: 1\n---\nx: [1, 2]\n',
    ]) {
      final formatted = formatOtherDocument(
        source,
        DocumentFormat.yaml,
        indent: 2,
      );
      final count = yamlDocumentCount(source);
      for (var i = 0; i < count; i++) {
        expect(
          jsonDecode(yamlToJson(formatted, document: i)),
          jsonDecode(yamlToJson(source, document: i)),
          reason: source,
        );
      }
      if (source.contains('# keep')) expect(formatted, contains('# keep'));
      if (source.contains('&base')) expect(formatted, contains('&base'));
    }
  });

  test(
    'structure snapshots expose source ranges and errors for native formats',
    () {
      final yaml = parseOtherFormat('root:\n  value: 1', DocumentFormat.yaml);
      expect(
        yaml.structure!.children.single.children.single.children.single.range,
        isNotNull,
      );
      final csv = parseOtherFormat('id;name\n001;中文', DocumentFormat.csv);
      expect(csv.table!.delimiter, ';');
      expect(csv.table!.records.last.cells.first.text, '001');
      for (final entry in {
        DocumentFormat.xml: '<r><a/></r>',
        DocumentFormat.toml: '[a]\nb = 1',
      }.entries) {
        final snapshot = parseOtherFormat(entry.value, entry.key);
        expect(snapshot.diagnostics, isEmpty);
        expect(snapshot.structure, isNotNull);
      }
      expect(
        parseOtherFormat('a=1\na=2', DocumentFormat.toml).diagnostics,
        isNotEmpty,
      );
    },
  );
}
