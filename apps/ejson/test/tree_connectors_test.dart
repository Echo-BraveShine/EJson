import 'package:ejson/editor/format_tree_view.dart';
import 'package:ejson/editor/hierarchy_guide_painter.dart';
import 'package:ejson/editor/tree_panel.dart';
import 'package:ejson/editor/tree_style.dart';
import 'package:ejson/main.dart';
import 'package:ejson/settings/installed_fonts.dart';
import 'package:ejson/settings/tool_preferences.dart';
import 'package:ejson/workspace/workspace.dart';
import 'package:ejson_core/ejson_core.dart';
import 'package:flutter/cupertino.dart' show CupertinoSwitch;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/conversion_test_harness.dart' show waitForConversion;

void main() {
  test('connector settings persist and failed writes can be retried', () async {
    expect(ToolPreferences.fromJson({}).treeConnectors, isTrue);
    expect(
      ToolPreferences.fromJson({'treeConnectors': 'bad'}).treeConnectors,
      isTrue,
    );
    expect(
      ToolPreferences.fromJson(
        const ToolPreferences(treeConnectors: false).toJson(),
      ).treeConnectors,
      isFalse,
    );
    var fail = true;
    final container = ProviderContainer(
      overrides: [
        saveToolPreferencesProvider.overrideWithValue((value) async {
          if (fail) throw Exception('failed');
        }),
      ],
    );
    addTearDown(container.dispose);
    final preferences = container.read(toolPreferencesProvider.notifier);
    expect(await preferences.setTreeConnectors(false), isFalse);
    expect(container.read(toolPreferencesProvider).treeConnectors, isTrue);
    fail = false;
    expect(await preferences.setTreeConnectors(false), isTrue);
    expect(container.read(toolPreferencesProvider).treeConnectors, isFalse);
  });

  test('dashes terminate at the last sibling and connect expanded parents', () {
    void last(Canvas canvas) => const HierarchyGuidePainter(
      [false],
      12,
      Colors.grey,
    ).paint(canvas, const Size(100, 34));
    void next(Canvas canvas) => const HierarchyGuidePainter(
      [true],
      12,
      Colors.grey,
    ).paint(canvas, const Size(100, 34));
    void expanded(Canvas canvas) => const HierarchyGuidePainter(
      [],
      12,
      Colors.grey,
      expanded: true,
    ).paint(canvas, const Size(100, 34));
    void collapsed(Canvas canvas) => const HierarchyGuidePainter(
      [],
      12,
      Colors.grey,
    ).paint(canvas, const Size(100, 34));
    expect(last, paintsExactlyCountTimes(#drawLine, 7));
    expect(next, paintsExactlyCountTimes(#drawLine, 10));
    expect(expanded, paintsExactlyCountTimes(#drawLine, 3));
    expect(collapsed, paintsNothing);
    expect(
      const HierarchyGuidePainter(
        [],
        12,
        Colors.grey,
        expanded: true,
      ).shouldRepaint(const HierarchyGuidePainter([], 12, Colors.grey)),
      isTrue,
    );
  });

  for (final language in ['en', 'zh']) {
    testWidgets(
      'settings toggle updates JSON and structure trees in $language',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(720, 460));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final persisted = <ToolPreferences>[];
        final container = ProviderContainer(
          overrides: [
            installedFontsProvider.overrideWith((ref) async => []),
            saveToolPreferencesProvider.overrideWithValue(
              (value) async => persisted.add(value),
            ),
            parseDocumentProvider.overrideWithValue(
              (source, revision) async => parseJson(source, revision: revision),
            ),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: EJsonApp(
              initialLanguage: language,
              initialTreeStyle: JsonTreeStyle.guides,
              initialThemeMode: language == 'en'
                  ? ThemeMode.light
                  : ThemeMode.dark,
            ),
          ),
        );
        final controller = container.read(workspaceProvider.notifier);
        controller.editSource(1, '{"nested":{"value":1},"last":2}');
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TreePanel>(find.byType(TreePanel)).showConnectors,
          isTrue,
        );
        final settings = language == 'en' ? 'Settings' : '设置';
        final label = language == 'en' ? 'Dashed tree connectors' : '树状层级虚线';
        Future<void> toggle() async {
          await tester.tap(find.byTooltip(settings));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('settings-appearance')));
          await tester.pumpAndSettle();
          final control = find.descendant(
            of: find.byKey(ValueKey('settings-row-$label')),
            matching: find.byType(CupertinoSwitch),
          );
          await tester.ensureVisible(control);
          await tester.pumpAndSettle();
          await tester.tap(control);
          await tester.pumpAndSettle();
        }

        await toggle();
        expect(persisted.last.treeConnectors, isFalse);
        for (final panel in tester.widgetList<TreePanel>(
          find.byType(TreePanel, skipOffstage: false),
        )) {
          expect(panel.showConnectors, isFalse);
        }
        await tester.tap(find.text(language == 'en' ? 'Done' : '完成'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<CustomPaint>(find.byKey(const ValueKey('tree-row:root')))
              .painter,
          isNull,
        );
        expect(
          container.read(workspaceProvider).active.text,
          '{"nested":{"value":1},"last":2}',
        );
        controller.newTabWithSource(
          'root:\n  nested:\n    value: 1',
          format: DocumentFormat.yaml,
        );
        await tester.pump(const Duration(milliseconds: 200));
        await waitForConversion(tester, find.byType(FormatTreeView));
        expect(
          tester
              .widget<FormatTreeView>(find.byType(FormatTreeView))
              .showConnectors,
          isFalse,
        );
        await toggle();
        expect(persisted.last.treeConnectors, isTrue);
        expect(
          tester
              .widget<FormatTreeView>(
                find.byType(FormatTreeView, skipOffstage: false),
              )
              .showConnectors,
          isTrue,
        );
        await tester.tap(find.text(language == 'en' ? 'Done' : '完成'));
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(FormatTreeView),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is CustomPaint &&
                  widget.painter is HierarchyGuidePainter,
            ),
          ),
          findsWidgets,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
