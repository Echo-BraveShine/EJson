import 'package:ejson/editor/code_editor.dart';
import 'package:ejson/editor/tree_panel.dart';
import 'package:ejson/main.dart';
import 'package:ejson/settings/installed_fonts.dart';
import 'package:ejson/settings/tool_preferences.dart';
import 'package:ejson/settings/reading_preferences.dart';
import 'package:ejson/workspace/compare_documents.dart';
import 'package:ejson/workspace/workspace.dart';
import 'package:ejson_core/ejson_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const before = '{"items":[{"x":1}],"remove":true,"keep":1e2}';
const after = '{"items":[{"x":2}],"add":3,"keep":1e2}';
Future<ProviderContainer> mount(
  WidgetTester tester, {
  ThemeMode mode = ThemeMode.light,
  String language = 'en',
}) async {
  await tester.binding.setSurfaceSize(const Size(720, 460));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final container = ProviderContainer(
    overrides: [
      installedFontsProvider.overrideWith((ref) async => []),
      parseDocumentProvider.overrideWithValue(
        (source, revision) async => parseJson(source, revision: revision),
      ),
      jsonComparisonProvider.overrideWithValue(
        (a, b) async => compareJsonStructure(
          a.source.text,
          a.snapshot!.root!,
          b.source.text,
          b.snapshot!.root!,
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: EJsonApp(initialThemeMode: mode, initialLanguage: language),
    ),
  );
  final controller = container.read(workspaceProvider.notifier);
  controller.editSource(1, before);
  controller.newTabWithSource(after);
  controller.activate(1);
  await tester.pumpAndSettle();
  await tester.tap(
    find.byTooltip(language == 'zh' ? '对比 JSON 文档' : 'Compare JSON documents'),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> select(WidgetTester tester, int index) async {
  final box = find.byKey(ValueKey('comparison-select-$index'));
  await tester.scrollUntilVisible(
    box,
    40,
    scrollable: find
        .descendant(
          of: find.byType(CompareDocuments),
          matching: find.byType(Scrollable),
        )
        .last,
  );
  await tester.pumpAndSettle();
  await tester.tap(box);
  await tester.pumpAndSettle();
}

Future<void> preview(WidgetTester tester) async {
  await tester.tap(find.text('Preview changes to left'));
  for (var i = 0; i < 100; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
    if (find.text('Preview applying differences').evaluate().isNotEmpty) {
      await tester.pumpAndSettle();
      return;
    }
  }
  expect(find.text('Preview applying differences'), findsOneWidget);
}

void main() {
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets(
      'selected changes preview, apply atomically and undo in $mode',
      (tester) async {
        final container = await mount(tester, mode: mode);
        await select(tester, 0);
        await select(tester, 2);
        await preview(tester);
        const expected =
            '{"items":[{"x":2}],"remove":true,"keep":1e2, "add":3}';
        final result = tester.widget<EJsonCodeEditor>(
          find.byKey(const ValueKey('comparison-apply-preview')),
        );
        expect(result.source, expected);
        expect(container.read(workspaceProvider).tab(1)!.text, before);
        await tester.tap(find.text('Apply changes'));
        await tester.pumpAndSettle();
        expect(find.byType(CompareDocuments), findsNothing);
        expect(container.read(workspaceProvider).activeId, 1);
        expect(container.read(workspaceProvider).tab(1)!.text, expected);
        expect(container.read(workspaceProvider).tab(2)!.text, after);
        await tester.tap(find.byTooltip('Undo'));
        await tester.pumpAndSettle();
        expect(container.read(workspaceProvider).tab(1)!.text, before);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'cancelling preview keeps both documents and selected differences',
    (tester) async {
      final container = await mount(tester);
      await select(tester, 0);
      await preview(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(container.read(workspaceProvider).tab(1)!.text, before);
      expect(container.read(workspaceProvider).tab(2)!.text, after);
      expect(
        tester
            .widget<Checkbox>(find.byKey(const ValueKey('comparison-select-0')))
            .value,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'source and tree views locate both sides and keep tree previews read-only',
    (tester) async {
      await mount(tester);
      await tester.tap(find.text(r'$["items"][0]["x"]'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('JSON tree'));
      await tester.pumpAndSettle();
      final trees = tester
          .widgetList<TreePanel>(
            find.descendant(
              of: find.byType(CompareDocuments),
              matching: find.byType(TreePanel),
            ),
          )
          .toList();
      expect(trees.length, 2);
      for (final tree in trees) {
        expect(tree.readOnly, isTrue);
        expect(tree.reveal, isNotNull);
        expect(
          tree.source.substring(
            tree.reveal!.range.start,
            tree.reveal!.range.end,
          ),
          anyOf('1', '2'),
        );
      }
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('external edits disable applying until a new comparison', (
    tester,
  ) async {
    final container = await mount(tester);
    await select(tester, 0);
    await preview(tester);
    container
        .read(workspaceProvider.notifier)
        .editSource(2, '{"items":[{"x":9}]}');
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Apply changes'),
          )
          .onPressed,
      isNull,
    );
    expect(container.read(workspaceProvider).tab(1)!.text, before);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Documents changed. Compare again.'), findsOneWidget);
    await tester.tap(find.text('Compare again'));
    await tester.pumpAndSettle();
    expect(find.text('Documents changed. Compare again.'), findsNothing);
    expect(
      tester
          .widget<Checkbox>(find.byKey(const ValueKey('comparison-select-0')))
          .value,
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'select all and swapped single application follow the displayed direction',
    (tester) async {
      final container = await mount(tester);
      await tester.tap(
        find.byTooltip('Select or clear all displayed differences'),
      );
      await tester.pumpAndSettle();
      expect(find.text('3 selected'), findsOneWidget);
      await preview(tester);
      await tester.tap(find.text('Apply changes'));
      await tester.pumpAndSettle();
      final merged = container.read(workspaceProvider).tab(1)!.text;
      expect(
        compareJsonStructure(
          merged,
          parseJson(merged).root!,
          after,
          parseJson(after).root!,
        ).differences,
        isEmpty,
      );
      container.read(workspaceProvider.notifier).undo(1);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Compare JSON documents'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Swap comparison sides'));
      await tester.pumpAndSettle();
      await select(tester, 0);
      await preview(tester);
      await tester.tap(find.text('Apply changes'));
      await tester.pumpAndSettle();
      expect(container.read(workspaceProvider).activeId, 2);
      expect(
        container.read(workspaceProvider).tab(2)!.text,
        '{"items":[{"x":1}],"add":3,"keep":1e2}',
      );
      expect(container.read(workspaceProvider).tab(1)!.text, before);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('comparison handles large reading fonts at minimum window size', (
    tester,
  ) async {
    final container = await mount(tester);
    await container
        .read(toolPreferencesProvider.notifier)
        .setReading(const ReadingPreferences(fontSize: 32));
    await tester.pumpAndSettle();
    await select(tester, 0);
    await tester.tap(find.byTooltip('JSON tree'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await preview(tester);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('Chinese comparison fits the minimum window', (tester) async {
    await mount(tester, language: 'zh');
    await select(tester, 0);
    expect(find.text('已选 1 项'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
