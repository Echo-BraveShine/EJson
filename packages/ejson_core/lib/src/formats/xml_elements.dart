import 'dart:convert';
import 'package:xml/xml.dart';
import '../syntax.dart';
import 'conversion_support.dart';
import 'xml_document.dart';

Object xmlElementValue(XmlElement element) {
  final attributes = {
    for (final a in element.attributes) a.name.qualified: a.value,
  };
  final children = element.childElements.toList();
  if (children.isEmpty) {
    if (attributes.isEmpty) return element.innerText;
    return {'@attributes': attributes, '#text': element.innerText};
  }
  final names = <String>{};
  String? last;
  var interleaved = false;
  for (final child in children) {
    final name = child.name.qualified;
    if (names.contains(name) && last != name) interleaved = true;
    names.add(name);
    last = name;
  }
  final preserveSpace = preservesXmlSpace(element);
  final mixed = element.children.any(
    (node) =>
        node is XmlCDATA ||
        node is XmlText && (preserveSpace || node.value.trim().isNotEmpty),
  );
  final result = <String, Object>{
    if (attributes.isNotEmpty) '@attributes': attributes,
  };
  if (mixed || interleaved) {
    result['#content'] = [
      for (final node in element.children)
        if (node is XmlElement)
          {node.name.qualified: xmlElementValue(node)}
        else if (node is XmlCDATA ||
            node is XmlText && (mixed || node.value.trim().isNotEmpty))
          node.value!,
    ];
  } else {
    for (final name in names) {
      final matching = children.where((e) => e.name.qualified == name).toList();
      result[name] = matching.length == 1
          ? xmlElementValue(matching.single)
          : matching.map(xmlElementValue).toList();
    }
  }
  return result;
}

String jsonElementsToXml(String source, {int indent = 2}) {
  final root = requireJsonRoot(source, uniqueKeys: true);
  if (root.kind != JsonKind.object || root.children.length != 1) {
    throw const FormatException(
      r'Element mapping requires exactly one root property at $.',
    );
  }
  String scalar(JsonNode node, String path) {
    final raw = source.substring(node.range.start, node.range.end);
    if (node.kind == JsonKind.string) return jsonDecode(raw) as String;
    if (node.kind == JsonKind.number || node.kind == JsonKind.boolean) {
      return raw;
    }
    throw FormatException(
      'Expected text, a number or a boolean at $path.',
      source,
      node.range.start,
    );
  }

  XmlElement build(String name, JsonNode node, String path, int depth) {
    if (depth > 256) {
      throw FormatException('XML nesting exceeds 256 levels at $path.');
    }
    if (node.kind != JsonKind.object) {
      return XmlElement(XmlName.qualified(name), [], [
        XmlText(scalar(node, path)),
      ]);
    }
    final attributes = <XmlAttribute>[];
    final children = <XmlNode>[];
    void property(String key, JsonNode value, String childPath) {
      if (value.kind == JsonKind.array) {
        if (value.children.isEmpty) {
          throw FormatException(
            'An empty array has no element mapping at $childPath.',
          );
        }
        for (var i = 0; i < value.children.length; i++) {
          children.add(
            build(key, value.children[i].value, '$childPath[$i]', depth + 1),
          );
        }
      } else {
        children.add(build(key, value, childPath, depth + 1));
      }
    }

    for (final entry in node.children) {
      final key = entry.key!;
      final childPath = '$path[${jsonEncode(key)}]';
      if (key == '@attributes') {
        if (entry.value.kind != JsonKind.object) {
          throw FormatException('Attributes must be an object at $childPath.');
        }
        for (final attribute in entry.value.children) {
          if (attribute.value.kind != JsonKind.string) {
            throw FormatException(
              'Attribute values must be strings at $childPath.',
            );
          }
          attributes.add(
            XmlAttribute(
              XmlName.qualified(attribute.key!),
              scalar(attribute.value, childPath),
            ),
          );
        }
      } else if (key == '#text') {
        children.add(XmlText(scalar(entry.value, childPath)));
      } else if (key == '#content') {
        if (entry.value.kind != JsonKind.array) {
          throw FormatException(
            'Ordered XML content must be an array at $childPath.',
          );
        }
        for (final item in entry.value.children) {
          if (item.value.kind == JsonKind.string) {
            children.add(XmlText(scalar(item.value, childPath)));
          } else if (item.value.kind == JsonKind.object &&
              item.value.children.length == 1) {
            final child = item.value.children.single;
            property(
              child.key!,
              child.value,
              '$childPath[${jsonEncode(child.key)}]',
            );
          } else {
            throw FormatException(
              'Ordered XML content requires text or a single element at $childPath.',
            );
          }
        }
      } else if (key.startsWith('@') || key.startsWith('#')) {
        throw FormatException('Unknown XML mapping key at $childPath.');
      } else {
        property(key, entry.value, childPath);
      }
    }
    return XmlElement(XmlName.qualified(name), attributes, children);
  }

  final entry = root.children.single;
  if (entry.value.kind == JsonKind.array) {
    throw const FormatException(
      'An XML document requires a single root element.',
    );
  }
  return writeXmlDocument(
    XmlDocument([build(entry.key!, entry.value, r'$', 0)]),
    indent: indent,
  );
}
