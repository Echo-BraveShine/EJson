import 'dart:convert';
import 'package:xml/xml.dart';
import '../syntax.dart';
import 'conversion_support.dart';
import 'xml_document.dart';
import 'xml_elements.dart';

enum XmlMappingMode { typed, elements }

String jsonToXml(
  String source, {
  String rootName = 'root',
  XmlMappingMode mode = XmlMappingMode.typed,
  int indent = 2,
}) {
  final root = requireJsonRoot(source);
  if (mode == XmlMappingMode.elements) {
    return jsonElementsToXml(source, indent: indent);
  }
  if (!isSimpleXmlName(rootName)) {
    throw const FormatException(
      'Choose a root name using letters, digits, underscores, dots or hyphens, starting with a letter or underscore.',
    );
  }
  XmlElement element(
    JsonNode node,
    String name, {
    String? key,
    bool documentRoot = false,
  }) {
    final raw = source.substring(node.range.start, node.range.end);
    return XmlElement(
      XmlName.qualified(name),
      [
        if (documentRoot)
          XmlAttribute(XmlName.qualified('xmlns:ejson'), xmlTypeNamespace),
        XmlAttribute(XmlName.qualified('ejson:type'), node.kind.name),
        if (key != null)
          XmlAttribute(XmlName.qualified('ejson:key'), jsonEncode(key)),
      ],
      [
        if (node.kind == JsonKind.array)
          for (final child in node.children) element(child.value, 'ejson:item')
        else if (node.kind == JsonKind.object)
          for (final child in node.children)
            element(
              child.value,
              isSimpleXmlName(child.key!) ? child.key! : 'ejson:field',
              key: child.key,
            )
        else if (node.kind != JsonKind.nil)
          XmlText(raw),
      ],
    );
  }

  final document = XmlDocument([
    XmlDeclaration([
      XmlAttribute(XmlName.qualified('version'), '1.0'),
      XmlAttribute(XmlName.qualified('encoding'), 'UTF-8'),
    ]),
    element(root, rootName, documentRoot: true),
  ]);
  return writeXmlDocument(document, indent: indent);
}

String xmlToJson(String source, {int indent = 2}) {
  final document = parseXmlDocument(source);
  final root = document.rootElement;
  if (root.getAttribute('type', namespaceUri: xmlTypeNamespace) == null) {
    return encodeConversionJson({
      root.name.qualified: xmlElementValue(root),
    }, indent: indent);
  }
  final output = ConversionBuffer();
  void write(XmlElement node, String path, int depth) {
    if (depth > 256) {
      throw FormatException('XML nesting exceeds 256 levels at $path.');
    }
    final type = node.getAttribute('type', namespaceUri: xmlTypeNamespace);
    final children = node.childElements.toList();
    if (type == 'object' || type == 'array') {
      if (node.children.whereType<XmlText>().any(
        (text) => text.value.trim().isNotEmpty,
      )) {
        throw FormatException('Unexpected typed XML text at $path.');
      }
      output.write(type == 'object' ? '{' : '[');
      for (var i = 0; i < children.length; i++) {
        if (i > 0) output.write(',');
        final encodedKey = children[i].getAttribute(
          'key',
          namespaceUri: xmlTypeNamespace,
        );
        final key = encodedKey == null ? null : jsonDecode(encodedKey);
        if (key != null && key is! String) {
          throw FormatException('Invalid typed XML object key at $path.');
        }
        if (type == 'object') {
          if (key == null) {
            throw FormatException('Missing typed XML object key at $path.');
          }
          output.write('${jsonEncode(key)}:');
        }
        write(
          children[i],
          type == 'object' ? '$path[${jsonEncode(key)}]' : '$path[$i]',
          depth + 1,
        );
      }
      output.write(type == 'object' ? '}' : ']');
    } else {
      if (children.isNotEmpty) {
        throw FormatException('Unexpected child elements at $path.');
      }
      final raw = node.innerText;
      if (type == 'nil') {
        if (raw.trim().isNotEmpty) {
          throw FormatException('Unexpected null content at $path.');
        }
        output.write('null');
        return;
      }
      final parsed = parseJson(raw).root;
      final expected = switch (type) {
        'string' => JsonKind.string,
        'number' => JsonKind.number,
        'boolean' => JsonKind.boolean,
        _ => null,
      };
      if (expected == null || parsed?.kind != expected) {
        throw FormatException('Invalid typed XML value at $path.');
      }
      output.write(raw);
    }
  }

  write(root, r'$', 0);
  return prettyConversionJson(output.toString(), indent: indent);
}
