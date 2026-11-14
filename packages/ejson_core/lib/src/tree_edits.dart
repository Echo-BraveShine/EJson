import 'document.dart';
import 'format.dart';
import 'syntax.dart';

/// Appends an already validated JSON value or object member.
SourcePatch appendJsonChild(String source, JsonNode container, String entry) {
  final children = container.children;
  if (children.isEmpty) {
    final start = container.range.start + 1;
    return SourcePatch((start: start, end: start), entry);
  }

  final first = children.first;
  final firstStart = first.keyRange?.start ?? first.value.range.start;
  final gap = source.substring(container.range.start + 1, firstStart);
  final separator = gap.contains('\n') || gap.contains('\r') ? gap : ' ';
  final end = children.last.value.range.end;
  return SourcePatch((start: end, end: end), ',$separator$entry');
}

/// Appends a child and formats the resulting document as a single edit.
({SourcePatch? patch, JsonDiagnostic? error}) appendFormattedJsonChild(
  String source,
  JsonNode container,
  String entry,
) {
  final lineBreak = RegExp(r'\r\n|\r|\n');
  final newline = lineBreak.firstMatch(source)?.group(0) ?? '\n';
  final addition = appendJsonChild(
    source,
    container,
    entry.replaceAll(lineBreak, newline),
  );
  final text = addition.apply(source);
  final snapshot = parseJson(text);
  if (snapshot.root == null) {
    return (patch: null, error: snapshot.diagnostics.single);
  }
  final formatted = rewriteJson(
    JsonDocument(SourceBuffer(text), snapshot: snapshot),
  );
  return (patch: SourcePatch.between(source, formatted), error: null);
}

/// Removes a child and one adjacent comma, keeping all other tokens intact.
SourcePatch removeJsonChild(JsonNode container, int index) {
  final children = container.children;
  int startOf(JsonChild child) =>
      child.keyRange?.start ?? child.value.range.start;
  final child = children[index];
  final start = index > 0
      ? children[index - 1].value.range.end
      : startOf(child);
  final end = index == 0 && children.length > 1
      ? startOf(children[1])
      : child.value.range.end;
  return SourcePatch((start: start, end: end), '');
}
