import 'package:ejson/editor/array_sort_dialog.dart';
import 'package:ejson/main.dart';
import 'package:ejson/editor/json_query_dialog.dart';
import 'package:ejson/settings/tool_preferences.dart';
import 'package:ejson/workspace/workspace.dart';
import 'package:ejson_core/ejson_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ProviderContainer> mount(
  WidgetTester tester, {
  ToolPreferences initial = const ToolPreferences(),
  Future<void> Function(ToolPreferences)? save,
}) async {
  await tester.binding.setSurfaceSize(const Size(900, 620));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final container = ProviderContainer(
    overrides: [
      initialToolPreferencesProvider.overrideWithValue(initial),
      saveToolPreferencesProvider.overrideWithValue(save ?? (_) async {}),
      parseDocumentProvider.overrideWithValue(
        (source, revision) async => parseJson(source, revision: revision),
      ),
      jsonQueryProvider.overrideWithValue(
        (source, root, query) async => queryJsonPath(source, root, query),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const EJsonApp()),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> nodeMenu(WidgetTester tester, String path) async {
  await tester.tap(find.byKey(ValueKey('node-menu:$path')));
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pumpAndSettle();
}

Future<void> waitFor(WidgetTester tester, bool Function() complete) async {
  await tester.runAsync(() async {
    for (var attempt = 0; attempt < 200 && !complete(); attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await tester.pump();
    }
  });
  expect(complete(), isTrue);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'format settings persist and the format command uses them with undo',
    (tester) async {
      final saved = <ToolPreferences>[];
      final container = await mount(
        tester,
        save: (value) async {
          saved.add(value);
        },
      );
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('settings-formatting')));
      await tester.pumpAndSettle();
      final indentation = find.byTooltip('Format indentation');
      await tester.ensureVisible(indentation);
      await tester.pumpAndSettle();
      await tester.tap(indentation);
      await tester.pumpAndSettle();
      await tester.tap(find.text('4 spaces').last);
      await tester.pumpAndSettle();
      final ending = find.byTooltip('Line endings');
      await tester.ensureVisible(ending);
      await tester.pumpAndSettle();
      await tester.tap(ending);
      await tester.pumpAndSettle();
      await tester.tap(find.text('CRLF').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(saved.last.format.indentation, JsonIndentation.fourSpaces);
      expect(saved.last.format.lineEnding, JsonLineEnding.crlf);
      final controller = container.read(workspaceProvider.notifier);
      const source = '{"a":[1e2,2]}';
      controller.editSource(1, source);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Format'));
      await waitFor(
        tester,
        () => container.read(workspaceProvider).active.text.contains('\r\n'),
      );
      expect(
        container.read(workspaceProvider).active.text,
        '{\r\n    "a": [\r\n        1e2,\r\n        2\r\n    ]\r\n}',
      );
      controller.undo(1);
      await tester.pumpAndSettle();
      expect(container.read(workspaceProvider).active.text, source);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('array item menus move and duplicate items with undo', (
    tester,
  ) async {
    final container = await mount(tester);
    final controller = container.read(workspaceProvider.notifier);
    const source = '[1e2,2,3]';
    controller.editSource(1, source);
    await tester.pumpAndSettle();
    await nodeMenu(tester, 'root/1');
    await tester.tap(find.text('Move array item up'));
    await tester.pumpAndSettle();
    expect(container.read(workspaceProvider).active.text, '[2,1e2,3]');
    controller.undo(1);
    await tester.pumpAndSettle();
    await nodeMenu(tester, 'root/1');
    await tester.tap(find.text('Move array item down'));
    await tester.pumpAndSettle();
    expect(container.read(workspaceProvider).active.text, '[1e2,3,2]');
    controller.undo(1);
    await tester.pumpAndSettle();
    await nodeMenu(tester, 'root/0');
    expect(find.text('Move array item up'), findsNothing);
    await tester.tap(find.text('Duplicate array item'));
    await tester.pumpAndSettle();
    expect(container.read(workspaceProvider).active.text, '[1e2,1e2,2,3]');
    controller.undo(1);
    await tester.pumpAndSettle();
    expect(container.read(workspaceProvider).active.text, source);
    expect(tester.takeException(), isNull);
  });

  testWidgets('array sorting selects a field and direction and can be undone', (
    tester,
  ) async {
    final container = await mount(tester);
    final controller = container.read(workspaceProvider.notifier);
    const source = '[{"id":1,"price":10},{"id":2,"price":2},{}]';
    controller.editSource(1, source);
    await tester.pumpAndSettle();
    await nodeMenu(tester, 'root');
    await tester.tap(find.text('Sort array'));
    await tester.pumpAndSettle();
    expect(find.byType(ArraySortDialog), findsOneWidget);
    await tester.tap(find.byTooltip('Sort by'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('"price"').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await waitFor(
      tester,
      () => container.read(workspaceProvider).active.text != source,
    );
    expect(
      container.read(workspaceProvider).active.text,
      '[{"id":2,"price":2},{"id":1,"price":10},{}]',
    );
    controller.undo(1);
    await tester.pumpAndSettle();
    expect(container.read(workspaceProvider).active.text, source);
    await nodeMenu(tester, 'root');
    await tester.tap(find.text('Sort array'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ascending'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descending').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await waitFor(
      tester,
      () => container.read(workspaceProvider).active.text != source,
    );
    expect(
      container.read(workspaceProvider).active.text,
      '[{"id":2,"price":2},{"id":1,"price":10},{}]',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('saved queries are reusable across dialogs and can be removed', (
    tester,
  ) async {
    final saved = <ToolPreferences>[];
    final container = await mount(
      tester,
      initial: const ToolPreferences(queries: [r'$.id']),
      save: (value) async {
        saved.add(value);
      },
    );
    final controller = container.read(workspaceProvider.notifier);
    controller.editSource(1, '{"id":1,"items":[1,2]}');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('JSONPath query'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Saved queries'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(r'$.id'));
    await tester.pumpAndSettle();
    expect(find.text('1 results'), findsOneWidget);
    await tester.tap(find.byTooltip('Unsave query'));
    await tester.pumpAndSettle();
    expect(saved.last.queries, isEmpty);
    await tester.enterText(find.byType(TextField), r'$.items[*]');
    await tester.pump();
    await tester.tap(find.byTooltip('Save query'));
    await tester.pumpAndSettle();
    expect(saved.last.queries, [r'$.items[*]']);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('JSONPath query'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Saved queries'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(r'$.items[*]'));
    await tester.pumpAndSettle();
    expect(find.text('2 results'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'failed favorites can be retried without losing existing entries',
    (tester) async {
      var fail = true;
      final container = await mount(
        tester,
        save: (_) async {
          if (fail) throw Exception('failed');
        },
      );
      container.read(workspaceProvider.notifier).editSource(1, '{"id":1}');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('JSONPath query'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), r'$.id');
      await tester.pump();
      await tester.tap(find.byTooltip('Save query'));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not save preferences. Try again.'),
        findsOneWidget,
      );
      expect(container.read(toolPreferencesProvider).queries, isEmpty);
      fail = false;
      await tester.tap(find.byTooltip('Save query'));
      await tester.pumpAndSettle();
      expect(container.read(toolPreferencesProvider).queries, [r'$.id']);
      expect(find.byTooltip('Unsave query'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
