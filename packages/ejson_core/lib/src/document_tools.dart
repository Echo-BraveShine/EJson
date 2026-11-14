import 'dart:convert';
import 'package:json_schema/json_schema.dart';

import 'syntax.dart';
import 'json_path.dart';
import 'json_query.dart';

class SchemaIssue {
  const SchemaIssue(this.path, this.message, this.range);
  final String path;
  final String message;
  final SourceRange range;
}

/// Validates locally, with internal references resolved by the schema engine.
List<SchemaIssue> validateJsonSchema(String source, String schemaSource) {
  final document = parseJson(source);
  final schemaDocument = parseJson(schemaSource);
  if (document.root == null || schemaDocument.root == null) {
    throw const FormatException('Invalid JSON');
  }
  if ([
    ...document.diagnostics,
    ...schemaDocument.diagnostics,
  ].any((d) => d.code == 'duplicate_key')) {
    throw const FormatException(
      'Resolve duplicate keys before schema validation.',
    );
  }
  final schemaData = jsonDecode(schemaSource);
  if (schemaData is Map && schemaData.containsKey(r'$schema')) {
    final declared = schemaData[r'$schema'];
    if (declared is! String || SchemaVersion.fromString(declared) == null) {
      throw const FormatException('Unsupported JSON Schema version.');
    }
  }
  final schema = JsonSchema.create(schemaData as Object);
  final result = schema.validate(jsonDecode(source));
  final locations = <String, SchemaIssue?>{};
  void index(JsonNode node, String pointer, List<JsonPathSegment> segments) {
    final location = SchemaIssue(formatJsonPath(segments), '', node.range);
    locations[pointer] = locations.containsKey(pointer) ? null : location;
    for (var i = 0; i < node.children.length; i++) {
      final child = node.children[i];
      index(child.value, '$pointer/${child.key ?? i}', [
        ...segments,
        (key: child.key, index: child.key == null ? i : null),
      ]);
    }
  }

  // The engine emits literal key names in instance paths, including '/' and '~'.
  index(document.root!, '', const []);
  final issues = <SchemaIssue>[];
  ValidationError? previous;
  for (final error in result.errors) {
    if (error.schemaPath.endsWith('/required') &&
        previous != null &&
        error.message == previous.message &&
        error.schemaPath == previous.schemaPath &&
        error.instancePath.startsWith('${previous.instancePath}/')) {
      continue;
    }
    previous = error;
    var pointer = error.instancePath;
    while (!locations.containsKey(pointer) && pointer.contains('/')) {
      pointer = pointer.substring(0, pointer.lastIndexOf('/'));
    }
    // Ambiguous literal paths reveal the root.
    final location = locations[pointer] ?? locations['']!;
    issues.add(SchemaIssue(location.path, error.message, location.range));
  }
  return issues;
}

class RedactedJson {
  const RedactedJson(this.source, this.count);
  final String source;
  final int count;
}

/// Replaces selected value tokens, preserving all other text and duplicate keys.
RedactedJson redactJson(
  String source, {
  required Set<String> keys,
  required List<String> paths,
  String replacement = '***',
}) {
  final snapshot = parseJson(source);
  final root = snapshot.root;
  if (root == null) throw const FormatException('Invalid JSON');
  final names = keys.map((key) => key.toLowerCase()).toSet();
  final ranges = <SourceRange>{};
  void visit(JsonNode node) {
    for (final child in node.children) {
      if (child.key != null && names.contains(child.key!.toLowerCase())) {
        ranges.add(child.value.range);
      }
      visit(child.value);
    }
  }

  visit(root);
  for (final path in paths) {
    for (final match in queryJsonPath(source, root, path)) {
      ranges.add(match.node.range);
    }
  }
  final sorted = ranges.toList()..sort((a, b) => a.start.compareTo(b.start));
  final outer = <SourceRange>[];
  for (final range in sorted) {
    if (outer.isEmpty || range.start >= outer.last.end) outer.add(range);
  }
  var result = source;
  final encoded = jsonEncode(replacement);
  for (final range in outer.reversed) {
    result = result.replaceRange(range.start, range.end, encoded);
  }
  return RedactedJson(result, outer.length);
}
