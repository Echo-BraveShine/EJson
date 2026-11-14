import 'package:ejson_core/ejson_core.dart';
import 'package:test/test.dart';

FormatTreeNode child(FormatTreeNode node, String label) =>
    node.children.firstWhere((child) => child.label == label);
String selected(String source, FormatTreeNode node) =>
    source.substring(node.range!.start, node.range!.end);
void checkRanges(String source, FormatTreeNode node) {
  expect(node.range, isNotNull, reason: node.label);
  expect(node.range!.start, inInclusiveRange(0, source.length));
  expect(node.range!.end, inInclusiveRange(node.range!.start, source.length));
  for (final child in node.children) {
    checkRanges(source, child);
  }
}

void main() {
  test(
    'XML maps elements, attributes, repeated text and markup to exact source',
    () {
      const source =
          '<?xml version="1.0"?>\r\n<!--outside-->\r\n<n:r xmlns:n="urn:test" title="中文🙂 > =">\r\n'
          '<item id="one">same&amp;中文</item><item id=\'two\'>same&amp;中文</item>'
          '<empty/><!--keep--><![CDATA[x < y]]><?go target?></n:r>';
      final snapshot = parseOtherFormat(source, DocumentFormat.xml);
      expect(snapshot.diagnostics, isEmpty);
      final root = snapshot.structure!;
      checkRanges(source, root);
      expect(selected(source, root), startsWith('<n:r '));
      expect(selected(source, root), endsWith('</n:r>'));
      expect(selected(source, child(root, '@title')), 'title="中文🙂 > ="');
      final items = root.children
          .where((node) => node.label == 'item')
          .toList();
      expect(selected(source, items[0]), '<item id="one">same&amp;中文</item>');
      expect(selected(source, child(items[1], '@id')), "id='two'");
      expect(selected(source, child(items[1], '#text')), 'same&amp;中文');
      expect(
        child(items[1], '#text').range!.start,
        greaterThan(child(items[0], '#text').range!.start),
      );
      expect(selected(source, child(root, 'empty')), '<empty/>');
      expect(selected(source, child(root, '#comment')), '<!--keep-->');
      expect(selected(source, child(root, '#cdata')), '<![CDATA[x < y]]>');
      expect(selected(source, child(root, '#instruction')), '<?go target?>');
    },
  );

  test(
    'TOML maps dotted keys, quoted keys, inline tables, arrays and multiline strings',
    () {
      const source =
          '# 中文🙂\r\n"a.b" = "same"\r\na.b = "same"\r\n'
          'values = [1, # note\r\n { "x.y" = [true, false] }, 1979-05-27 07:32:00Z]\r\n'
          'text = """\r\ninside = value\r\n"""\r\n[server]\r\nport = 8080\r\n';
      final snapshot = parseOtherFormat(source, DocumentFormat.toml);
      expect(snapshot.diagnostics, isEmpty);
      final root = snapshot.structure!;
      checkRanges(source, root);
      expect(selected(source, child(root, 'a.b')), '"same"');
      expect(selected(source, child(child(root, 'a'), 'b')), '"same"');
      expect(
        child(root, 'a.b').range!.start,
        lessThan(child(child(root, 'a'), 'b').range!.start),
      );
      final values = child(root, 'values');
      expect(selected(source, child(values, '[0]')), '1');
      expect(
        selected(source, child(child(child(values, '[1]'), 'x.y'), '[1]')),
        'false',
      );
      expect(selected(source, child(values, '[2]')), '1979-05-27 07:32:00Z');
      expect(
        selected(source, child(root, 'text')),
        '"""\r\ninside = value\r\n"""',
      );
      expect(
        selected(source, child(root, 'server')),
        '[server]\r\nport = 8080',
      );
    },
  );

  test(
    'TOML array table ranges follow the current parent and distinguish repeated values',
    () {
      const source =
          '[[products]]\nname="same"\n[products.detail]\nid=1\n'
          '[[products.variants]]\nname="same"\n[[products.variants]]\nname="same"\n'
          '[[products]]\nname="same"\n[products.detail]\nid=2\n';
      final snapshot = parseOtherFormat(source, DocumentFormat.toml);
      expect(snapshot.diagnostics, isEmpty);
      final root = snapshot.structure!;
      checkRanges(source, root);
      final products = child(root, 'products');
      final first = child(products, '[0]');
      final second = child(products, '[1]');
      expect(selected(source, child(child(first, 'detail'), 'id')), '1');
      expect(selected(source, child(child(second, 'detail'), 'id')), '2');
      final variants = child(first, 'variants');
      expect(
        child(child(variants, '[0]'), 'name').range!.start,
        lessThan(child(child(variants, '[1]'), 'name').range!.start),
      );
      expect(selected(source, second), startsWith('[[products]]'));
    },
  );
}
