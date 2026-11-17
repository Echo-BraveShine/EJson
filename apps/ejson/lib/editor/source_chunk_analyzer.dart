import 'package:ejson_core/ejson_core.dart';
import 'package:re_editor/re_editor.dart';

/// Projects parser source spans onto the editor's current visible lines.
class SourceChunkAnalyzer implements CodeChunkAnalyzer {
  const SourceChunkAnalyzer(this.format);

  final DocumentFormat format;

  @override
  List<CodeChunk> run(CodeLines codeLines) {
    final visibleStarts = <int>[];
    var rawLine = 0;
    for (final segment in codeLines.segments) {
      for (final line in segment.codeLines) {
        visibleStarts.add(rawLine);
        rawLine += line.lineCount;
      }
    }

    int boundary(int line) {
      var low = 0;
      var high = visibleStarts.length;
      while (low < high) {
        final middle = (low + high) ~/ 2;
        if (visibleStarts[middle] < line) {
          low = middle + 1;
        } else {
          high = middle;
        }
      }
      return low;
    }

    final ends = <int, int>{};
    try {
      for (final (start, end) in _lineRanges(codeLines, rawLine)) {
        if (end - start < 2) continue;
        final index = boundary(start);
        if (index == visibleStarts.length || visibleStarts[index] != start) {
          continue;
        }
        final visibleEnd = boundary(end);
        if ((ends[index] ?? index) < visibleEnd) ends[index] = visibleEnd;
      }
    } on Exception {
      // A malformed document has no trustworthy fold boundaries.
      return const [];
    }

    final enclosing = <int>[];
    return [
      for (final index in ends.keys.toList()..sort())
        if (_fits(index, ends[index]!, enclosing))
          CodeChunk(index, ends[index]!),
    ];
  }

  Iterable<(int, int)> _lineRanges(
    CodeLines codeLines,
    int rawLineCount,
  ) sync* {
    if (format == DocumentFormat.json) {
      final raw = codeLines.length == rawLineCount
          ? codeLines
          : CodeLines.fromText(codeLines.asString(TextLineBreak.lf));
      for (final chunk in const DefaultCodeChunkAnalyzer().run(raw)) {
        final start = raw[chunk.index].text.trimRight();
        final end = raw[chunk.end].text.trim();
        final closer = sourceFoldCloser(start);
        // The native analyzer leaves the closing line visible. Bring it into
        // the fold when it contains only the delimiter and an optional comma.
        final includeCloser =
            closer != null && (end == closer || end == '$closer,');
        yield (chunk.index, chunk.end + (includeCloser ? 1 : 0));
      }
      return;
    }
    final source = codeLines.asString(TextLineBreak.lf);
    final lines = LineIndex(source);
    for (final range in sourceFoldRanges(source, format)) {
      if (range.end <= range.start) continue;
      yield (
        lines.position(range.start).line - 1,
        lines.position(range.end - 1).line,
      );
    }
  }

  // Different structures can start or end on the same source line.
  bool _fits(int start, int end, List<int> enclosing) {
    while (enclosing.isNotEmpty && enclosing.last <= start) {
      enclosing.removeLast();
    }
    if (enclosing.isNotEmpty && end > enclosing.last) return false;
    enclosing.add(end);
    return true;
  }
}

String? sourceFoldCloser(String header) => header.isEmpty
    ? null
    : switch (header[header.length - 1]) {
        '{' => '}',
        '[' => ']',
        '(' => ')',
        _ => null,
      };
