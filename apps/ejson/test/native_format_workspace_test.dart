import 'package:ejson/main.dart';
import 'package:ejson/editor/code_editor.dart';
import 'package:ejson/editor/format_tree_view.dart';
import 'package:ejson/settings/installed_fonts.dart';
import 'package:ejson/workspace/workspace.dart';
import 'package:ejson_core/ejson_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';

import 'support/conversion_test_harness.dart';

void main() {
  testWidgets(
    'new-document menu creates every native format and formatting supports undo',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = ProviderContainer(
        overrides: [installedFontsProvider.overrideWith((ref) async => [])],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const EJsonApp(initialLanguage: 'en'),
        ),
      );
      await tester.pumpAndSettle();
      final controller = container.read(workspaceProvider.notifier);
      for (final entry in {
        DocumentFormat.yaml: 'root:\n    value: 1 # keep\n',
        DocumentFormat.xml: '<r><value>1</value></r>',
        DocumentFormat.toml: 'value=1 # keep\n',
        DocumentFormat.csv: 'id,value\n001,true',
      }.entries) {
        expect(
          find.byTooltip('New document format'),
          findsOneWidget,
          reason: entry.key.label,
        );
        await tester.tap(find.byTooltip('New document format'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(entry.key.label).last);
        await tester.pumpAndSettle();
        final tab = container.read(workspaceProvider).active;
        expect(tab.format, entry.key);
        controller.editSource(tab.id, entry.value);
        await tester.pump(const Duration(milliseconds: 250));
        await waitForConversion(tester, find.text('Valid ${entry.key.label}'));
        expect(container.read(workspaceProvider).active.canFormat, isTrue);
        await tester.runAsync(() => controller.rewrite(tab.id, minify: false));
        await tester.pumpAndSettle();
        expect(
          container.read(workspaceProvider).active.text,
          isNot(entry.value),
        );
        controller.undo(tab.id);
        await tester.pumpAndSettle();
        expect(container.read(workspaceProvider).active.text, entry.value);
        expect(tester.takeException(), isNull);
        controller.close(tab.id);
        await tester.pumpAndSettle();
      }
    },
  );

  for (final entry in {
    DocumentFormat.toml: (
      source: '[server]\nport = 8080\nname = "中文" # keep\n',
      path: 'root/0',
      selected: '[server]\nport = 8080\nname = "中文"',
    ),
    DocumentFormat.xml: (
      source:
          '<catalog lang="zh">\r\n  <item id="001">中文 &amp; text</item>\r\n</catalog>',
      path: 'root/1',
      selected: '<item id="001">中文 &amp; text</item>',
    ),
  }.entries) {
    testWidgets('${entry.key.label} tree selection reveals folded source', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1120, 740));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = ProviderContainer(
        overrides: [installedFontsProvider.overrideWith((ref) async => [])],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const EJsonApp(initialLanguage: 'en'),
        ),
      );
      await tester.pumpAndSettle();
      container
          .read(workspaceProvider.notifier)
          .newTabWithSource(entry.value.source, format: entry.key);
      await tester.pump(const Duration(milliseconds: 250));
      await waitForConversion(tester, find.text('Valid ${entry.key.label}'));
      expect(find.byType(FormatTreeView), findsOneWidget);

      final gutter = find.byType(DefaultCodeChunkIndicator);
      CodeChunkController chunks() =>
          tester.widget<DefaultCodeChunkIndicator>(gutter).controller;
      for (var i = 0; i < 100 && !chunks().canCollapse(0); i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      expect(chunks().canCollapse(0), isTrue);
      chunks().collapse(0);
      await tester.pump();

      await tester.tap(find.byKey(ValueKey('format-row:${entry.value.path}')));
      await tester.pumpAndSettle();

      final editor = tester.widget<CodeEditor>(find.byType(CodeEditor));
      expect(editor.controller!.selectedText, entry.value.selected);
      expect(
        tester.widget<EJsonCodeEditor>(find.byType(EJsonCodeEditor)).jump,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
