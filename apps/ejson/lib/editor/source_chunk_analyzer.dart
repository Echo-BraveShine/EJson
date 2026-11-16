import 'package:ejson_core/ejson_core.dart';
import 'package:re_editor/re_editor.dart';

/// Projects parser source spans onto the editor's current visible lines.
class SourceChunkAnalyzer implements CodeChunkAnalyzer {
  const SourceChunkAnalyzer(this.format);

  final DocumentFormat format;

  @override
  List<CodeChunk> run(CodeLines codeLines) {
    final source = codeLines.asString(TextLineBreak.lf);
    final lines = LineIndex(source);
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
      for (final range in sourceFoldRanges(source, format)) {
        if (range.end <= range.start) continue;
        final start = lines.position(range.start).line - 1;
        final end = lines.position(range.end - 1).line;
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
