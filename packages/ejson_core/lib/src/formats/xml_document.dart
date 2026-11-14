import 'package:xml/xml.dart';
import 'package:xml/xml_events.dart';
import 'conversion_support.dart';

const xmlTypeNamespace = 'urn:ejson:types:1';

XmlDocument parseXmlDocument(String source) {
  if (source.length > maxConversionUnits) {
    throw const FormatException('XML exceeds the supported text size limit.');
  }
  var depth = 0;
  var count = 0;
  for (final event in parseEvents(
    source,
    validateDocument: true,
    validateNamespace: true,
    validateNesting: true,
    withLocation: true,
  )) {
    if (event is XmlDoctypeEvent &&
        (event.externalId != null ||
            RegExp(
              r'<!ENTITY\b',
              caseSensitive: false,
            ).hasMatch(event.internalSubset ?? ''))) {
      throw FormatException(
        'XML document types and external entities are disabled.',
        source,
        event.start,
      );
    }
    if (++count > 200000) {
      throw FormatException(
        'XML exceeds the supported node count.',
        source,
        event.start,
      );
    }
    if (event is XmlStartElementEvent &&
        !event.isSelfClosing &&
        ++depth > 256) {
      throw FormatException(
        'XML nesting exceeds 256 levels.',
        source,
        event.start,
      );
    }
    if (event is XmlEndElementEvent) depth--;
  }
  return XmlDocument.parse(source);
}

String writeXmlDocument(
  XmlDocument document, {
  int indent = 2,
  bool compact = false,
  String lineEnding = '\n',
}) {
  final output = ConversionBuffer();
  if (compact) {
    for (final element in document.descendantElements.toList()) {
      final preserve = preservesXmlSpace(element);
      final mixed = element.children.any(
        (node) =>
            node is XmlCDATA || node is XmlText && node.value.trim().isNotEmpty,
      );
      if (!preserve && !mixed && element.childElements.isNotEmpty) {
        element.children.removeWhere(
          (node) => node is XmlText && node.value.trim().isEmpty,
        );
      }
    }
    document.accept(XmlWriter(output));
  } else {
    document.accept(
      XmlPrettyWriter(
        output,
        indent: ' ' * indent,
        newLine: lineEnding,
        preserveWhitespace: (node) =>
            node is XmlElement &&
            (preservesXmlSpace(node) ||
                node.children.any(
                  (child) =>
                      child is XmlCDATA ||
                      child is XmlText && child.value.trim().isNotEmpty,
                ) ||
                node.children.isNotEmpty &&
                    node.children.every((child) => child is XmlText)),
      ),
    );
  }
  final text = output.toString();
  parseXmlDocument(text);
  return text;
}

bool isSimpleXmlName(String name) =>
    RegExp(r'^[A-Za-z_][A-Za-z0-9_.-]*$').hasMatch(name) &&
    !name.toLowerCase().startsWith('xml');

/// The nearest xml:space declaration controls inherited whitespace behavior.
bool preservesXmlSpace(XmlElement element) =>
    [element, ...element.ancestors.whereType<XmlElement>()]
        .expand((node) => node.attributes)
        .where((attribute) => attribute.name.qualified == 'xml:space')
        .map((attribute) => attribute.value)
        .firstOrNull ==
    'preserve';
