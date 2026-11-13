import 'syntax.dart';

class SourceBuffer {
  const SourceBuffer(this.text);
  final String text;

  String slice(SourceRange range) => text.substring(range.start, range.end);
}

class SourcePatch {
  const SourcePatch(this.range, this.replacement);

  /// Generates a single edit and retains common text on either side.
  factory SourcePatch.between(String before, String after) {
    final sharedLength = before.length < after.length
        ? before.length
        : after.length;
    var start = 0;
    while (start < sharedLength &&
        before.codeUnitAt(start) == after.codeUnitAt(start)) {
      start++;
    }
    var beforeEnd = before.length;
    var afterEnd = after.length;
    while (beforeEnd > start &&
        afterEnd > start &&
        before.codeUnitAt(beforeEnd - 1) == after.codeUnitAt(afterEnd - 1)) {
      beforeEnd--;
      afterEnd--;
    }
    return SourcePatch((
      start: start,
      end: beforeEnd,
    ), after.substring(start, afterEnd));
  }

  final SourceRange range;
  final String replacement;

  String apply(String source) =>
      source.replaceRange(range.start, range.end, replacement);

  SourcePatch inverse(String source) => SourcePatch((
    start: range.start,
    end: range.start + replacement.length,
  ), source.substring(range.start, range.end));
}

class JsonDocument {
  const JsonDocument(
    this.source, {
    this.revision = 0,
    this.snapshot,
    this.lastValid,
    this.lastValidSource,
  });

  final SourceBuffer source;
  final int revision;
  final ParseSnapshot? snapshot;
  final ParseSnapshot? lastValid;
  final SourceBuffer? lastValidSource;

  bool get isValid => snapshot?.root != null;

  JsonDocument? apply(SourcePatch patch, {required int expectedRevision}) {
    if (expectedRevision != revision) return null;
    return JsonDocument(
      SourceBuffer(patch.apply(source.text)),
      revision: revision + 1,
      lastValid: lastValid,
      lastValidSource: lastValidSource,
    );
  }

  JsonDocument accept(ParseSnapshot result) {
    if (result.revision != revision) return this;
    return JsonDocument(
      source,
      revision: revision,
      snapshot: result,
      lastValid: result.root == null ? lastValid : result,
      lastValidSource: result.root == null ? lastValidSource : source,
    );
  }
}

class EditHistory {
  final _undo = <({SourcePatch forward, SourcePatch backward})>[];
  final _redo = <({SourcePatch forward, SourcePatch backward})>[];

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  void record(SourcePatch patch, String before) {
    _redo.clear();
    _undo.add((forward: patch, backward: patch.inverse(before)));
    // Cap history by retained UTF-16 units as well as by edit count.
    var retained = 0;
    var keepFrom = _undo.length;
    while (keepFrom > 0 && _undo.length - keepFrom < 200) {
      final entry = _undo[keepFrom - 1];
      retained +=
          entry.forward.replacement.length + entry.backward.replacement.length;
      if (retained > 8 * 1024 * 1024) break;
      keepFrom--;
    }
    _undo.removeRange(0, keepFrom);
  }

  SourcePatch? undo() {
    if (!canUndo) return null;
    final edit = _undo.removeLast();
    _redo.add(edit);
    return edit.backward;
  }

  SourcePatch? redo() {
    if (!canRedo) return null;
    final edit = _redo.removeLast();
    _undo.add(edit);
    return edit.forward;
  }
}
