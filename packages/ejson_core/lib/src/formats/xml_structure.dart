import 'package:xml/xml_events.dart';
import 'format_structure.dart';

/// Event offsets refer to the original UTF-16 source, including entity spelling.
FormatTreeNode xmlSourceStructure(String source, StructureBudget budget) {
  final stack = <_ElementFrame>[];
  FormatTreeNode? root;
  void finish(_ElementFrame frame, int end) {
    if (!frame.retained) return;
    final node = FormatTreeNode(
      frame.name,
      'element',
      '[${frame.elements}]',
      children: frame.children,
      range: (start: frame.start, end: end),
    );
    if (stack.isEmpty) {
      root = node;
    } else {
      stack.last.children.add(node);
    }
  }

  final attributes = RegExp(r'''([^\s=<>/]+)\s*=\s*(?:"[^"]*"|'[^']*')''');
  for (final event in parseEvents(source, withLocation: true)) {
    final start = event.start!;
    final end = event.stop!;
    if (event is XmlStartElementEvent) {
      if (stack.isNotEmpty) stack.last.elements++;
      final retained = stack.isEmpty || stack.last.retained && budget.take();
      final frame = _ElementFrame(event.name, start, retained);
      if (retained) {
        final matches = attributes
            .allMatches(source.substring(start, end))
            .iterator;
        for (final attribute in event.attributes) {
          if (!budget.take()) break;
          matches.moveNext();
          final match = matches.current;
          frame.children.add(
            FormatTreeNode(
              '@${attribute.name}',
              'attribute',
              attribute.value,
              range: (start: start + match.start, end: start + match.end),
            ),
          );
        }
      }
      if (event.isSelfClosing) {
        finish(frame, end);
      } else {
        stack.add(frame);
      }
    } else if (event is XmlEndElementEvent) {
      finish(stack.removeLast(), end);
    } else if (stack.isNotEmpty && stack.last.retained) {
      final (String, String)? content = switch (event) {
        XmlTextEvent(:final value) when value.trim().isNotEmpty => (
          '#text',
          value,
        ),
        XmlCDATAEvent(:final value) => ('#cdata', value),
        XmlCommentEvent(:final value) => ('#comment', value),
        XmlProcessingEvent(:final value) => ('#instruction', value),
        _ => null,
      };
      if (content != null && budget.take()) {
        stack.last.children.add(
          FormatTreeNode(
            content.$1,
            'string',
            content.$2,
            range: (start: start, end: end),
          ),
        );
      }
    }
  }
  return root!;
}

class _ElementFrame {
  _ElementFrame(this.name, this.start, this.retained);
  final String name;
  final int start;
  final bool retained;
  final children = <FormatTreeNode>[];
  int elements = 0;
}
