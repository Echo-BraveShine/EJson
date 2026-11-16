import 'package:ejson/editor/source_chunk_analyzer.dart';
import 'package:ejson/main.dart';
import 'package:ejson/workspace/workspace.dart';
import 'package:ejson_core/ejson_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';

void main() {
  final fixtures = <DocumentFormat, ({String source, List<(int, int)> spans})>{
    DocumentFormat.yaml: (
      source: 'root:\n  list:\n    - alpha\n    - beta\nother: true',
      spans: [(0, 5), (1, 4)],
    ),
    DocumentFormat.xml: (
      source: '<root>\n  <item>\n    value\n  </item>\n  <other/>\n</root>',
      spans: [(0, 6), (1, 4)],
    ),
    DocumentFormat.toml: (
      source: '[first]\nitems = [\n  1,\n  2\n]\nlabel = "a"\n[second]\nx = 3',
      spans: [(0, 6), (1, 5), (6, 8)],
    ),
    DocumentFormat.csv: (
      source: 'id,note\n1,"line one\nline two"\n2,plain',
      spans: [(1, 3)],
    ),
    DocumentFormat.jsonLines: (
      source: '{"id":1}\n{"id":2}\n\n{"id":3}\n{"id":4}',
      spans: [(0, 2), (3, 5)],
    ),
  };

  for (final entry in fixtures.entries) {
    test(
      '${entry.key.label} maps parser spans and retains collapsed blocks',
      () {
        final fixture = entry.value;
        final controller = CodeLineEditingController.fromText(fixture.source);
        addTearDown(controller.dispose);
        final analyzer = SourceChunkAnalyzer(entry.key);
        final chunks = analyzer.run(controller.codeLines);
        expect(chunks.map((chunk) => (chunk.index, chunk.end)), fixture.spans);
        final first = chunks.first;
        controller.collapseChunk(first.index, first.end);
        final collapsed = analyzer.run(controller.codeLines);
        expect(collapsed.first.index, first.index);
        expect(collapsed.first.canCollapse, isFalse);
        expect(controller.text, fixture.source);
      },
    );
  }

  testWidgets(
    'CSV folding at EOF preserves selection and full source',
    (tester) async {
      const source = 'id,note\r\n1,"line one\r\nline two"';
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const EJsonApp(),
        ),
      );
      container
          .read(workspaceProvider.notifier)
          .newTabWithSource(source, format: DocumentFormat.csv);
      await tester.pump(const Duration(milliseconds: 200));
      final gutter = find.byType(DefaultCodeChunkIndicator);
      CodeChunkController chunks() =>
          tester.widget<DefaultCodeChunkIndicator>(gutter).controller;
      for (var i = 0; i < 100 && !chunks().canCollapse(1); i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      expect(chunks().canCollapse(1), isTrue);
      chunks().collapse(1);
      await tester.pump();
      final editor = tester.widget<CodeEditor>(find.byType(CodeEditor));
      final controller = editor.controller!;
      expect(controller.lineIndex2Index(2).chunkIndex, isNonNegative);
      expect(container.read(workspaceProvider).active.text, source);

      editor.focusNode!.requestFocus();
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(controller.selectedText, source.replaceAll('\r\n', '\n'));
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({TargetPlatform.linux}),
  );
}
