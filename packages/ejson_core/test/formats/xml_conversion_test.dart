import 'dart:convert';
import 'package:ejson_core/ejson_core.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

void main() {
  test('typed XML round trips every JSON root and exact numeric tokens', () {
    for (final source in [
      'null',
      'true',
      '123456789012345678901',
      '1e999',
      '"line\\r\\n&<>🙂"',
      '[]',
      '{}',
      '[1,null,false,{"中文":0.1234567890123456789}]',
      '{"a":1,"a":2,"a:b":"x","\\u0000":"\\u0000"}',
    ]) {
      final xml = jsonToXml(source, rootName: 'data');
      expect(parseOtherFormat(xml, DocumentFormat.xml).diagnostics, isEmpty);
      final json = xmlToJson(xml);
      expect(jsonDecode(json), jsonDecode(source), reason: source);
      if (source.contains('1e999')) expect(json, contains('1e999'));
      if (source.contains('0.1234567890123456789')) {
        expect(json, contains('0.1234567890123456789'));
      }
    }
  });
  test(
    'element mapping preserves attributes, namespaces, repeated nodes and mixed order',
    () {
      for (final source in [
        '<book id="001"><name>中文</name><tag>a</tag><tag>b</tag><empty/></book>',
        '<p xmlns="urn:root" xmlns:n="urn:note">before<n:b>bold</n:b> after<n:b>two</n:b>end</p>',
        '<r><a>1</a><b>2</b><a>3</a></r>',
        '<中文 属性="值">文本</中文>',
        '<r xml:space="preserve"><p> <b/> </p></r>',
      ]) {
        final json = xmlToJson(source);
        final xml = jsonToXml(json, mode: XmlMappingMode.elements);
        expect(jsonDecode(xmlToJson(xml)), jsonDecode(json));
        expect(
          XmlDocument.parse(xml).descendants
              .whereType<XmlText>()
              .where((node) => node.value.trim().isNotEmpty)
              .map((node) => node.value)
              .join(),
          XmlDocument.parse(source).descendants
              .whereType<XmlText>()
              .where((node) => node.value.trim().isNotEmpty)
              .map((node) => node.value)
              .join(),
        );
      }
    },
  );
  test(
    'XML invalid names, malformed typed data and external entities report errors',
    () {
      expect(() => jsonToXml('{}', rootName: '1 bad'), throwsFormatException);
      expect(
        () => jsonToXml('{"a":null}', mode: XmlMappingMode.elements),
        throwsFormatException,
      );
      expect(
        () => jsonToXml('{"a":[],"b":1}', mode: XmlMappingMode.elements),
        throwsFormatException,
      );
      for (final source in [
        '<a><b></a>',
        '<p:r/>',
        '<!DOCTYPE a SYSTEM "file:///etc/passwd"><a/>',
        '<!DOCTYPE a [<!ENTITY x "test">]><a>&x;</a>',
        '<r xmlns:ejson="urn:ejson:types:1" ejson:type="number">oops</r>',
      ]) {
        expect(() => xmlToJson(source), throwsFormatException, reason: source);
      }
    },
  );
  test('XML formatting retains comments, CDATA, mixed text and xml:space', () {
    const source =
        '<root><!--keep--><p>a<b>bold</b> after</p><c><![CDATA[x < y]]></c><s xml:space="preserve"> <b/> </s></root>';
    final formatted = formatOtherDocument(
      source,
      DocumentFormat.xml,
      indent: 4,
    );
    expect(
      formatOtherDocument(
        '<r><a/></r>',
        DocumentFormat.xml,
        lineEnding: '\r\n',
      ),
      contains('\r\n  <a'),
    );
    expect(formatted, contains('<!--keep-->'));
    expect(formatted, contains('<![CDATA[x < y]]>'));
    expect(formatted, contains('<p>a<b>bold</b> after</p>'));
    final compact = formatOtherDocument(
      formatted,
      DocumentFormat.xml,
      minify: true,
    );
    expect(jsonDecode(xmlToJson(compact)), jsonDecode(xmlToJson(source)));
    expect(compact, isNot(contains('\n    <')));
  });
}
