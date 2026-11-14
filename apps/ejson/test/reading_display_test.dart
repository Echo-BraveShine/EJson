import 'dart:convert';

import 'package:ejson/editor/array_table.dart';
import 'package:ejson/editor/json_query_dialog.dart';
import 'package:ejson/editor/tree_panel.dart';
import 'package:ejson/main.dart';
import 'package:ejson/settings/font_picker.dart';
import 'package:ejson/settings/installed_fonts.dart';
import 'package:ejson/settings/reading_preferences.dart';
import 'package:ejson/settings/tool_preferences.dart';
import 'package:ejson/workspace/workspace.dart';
import 'package:ejson_core/ejson_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';

const fonts = [
  InstalledFont(family: 'Courier New', name: 'Courier New', monospace: true),
  InstalledFont(family: 'Arial', name: 'Arial', monospace: false),
];

Future<ProviderContainer> mount(
  WidgetTester tester, {
  ToolPreferences initial = const ToolPreferences(),
  Future<void> Function(ToolPreferences)? save,
  Future<List<InstalledFont>> Function()? loadFonts,
  ThemeMode mode = ThemeMode.light,
  Size size = const Size(900, 620),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final container = ProviderContainer(
    overrides: [
      initialToolPreferencesProvider.overrideWithValue(initial),
      saveToolPreferencesProvider.overrideWithValue(save ?? (_) async {}),
      installedFontsProvider.overrideWith(
        (_) => loadFonts?.call() ?? Future.value(fonts),
      ),
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
    UncontrolledProviderScope(
      container: container,
      child: EJsonApp(initialThemeMode: mode),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> chooseSize(WidgetTester tester, int size) async {
  final picker = find.byTooltip('Font size');
  await tester.ensureVisible(picker);
  await tester.pumpAndSettle();
  await tester.tap(picker);
  await tester.pumpAndSettle();
  final value = find.descendant(
    of: find.byWidgetPredicate((widget) => widget is PopupMenuItem<int>),
    matching: find.text('$size'),
  );
  await tester.ensureVisible(value);
  await tester.pumpAndSettle();
  await tester.tap(value);
  await tester.pumpAndSettle();
}

void desktopTestWidgets(
  String description,
  Future<void> Function(WidgetTester) body,
) {
  testWidgets(
    description,
    body,
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'installed fonts are validated, localized, deduplicated and ordered',
    () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const channel = MethodChannel('dev.ekko.ejson/fonts');
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'list');
        return [
          {'family': 'Arial', 'name': 'Arial', 'monospace': false},
          {'family': 'Test Mono', 'name': '等宽测试', 'monospace': true},
          {'family': 'arial', 'name': 'Arial', 'monospace': false},
          {'family': ''},
          {'family': 42},
          'invalid',
        ];
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final catalog = await container.read(installedFontsProvider.future);
      expect(catalog.length, 2);
      expect(catalog.first.monospace, isTrue);
      expect(catalog.first.name, '等宽测试');
      expect(findInstalledFont(catalog, 'ARIAL')!.name, 'Arial');
    },
  );

  test(
    'reading preferences round-trip with other settings and tolerate older data',
    () async {
      final saved = <ToolPreferences>[];
      final container = ProviderContainer(
        overrides: [
          saveToolPreferencesProvider.overrideWithValue((value) async {
            saved.add(value);
          }),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(toolPreferencesProvider.notifier);
      await Future.wait([
        controller.setReading(
          const ReadingPreferences(
            fontFamily: 'Arial',
            fontSize: 32,
            lineSpacing: ReadingLineSpacing.spacious,
          ),
        ),
        controller.setFormat(
          const JsonFormatOptions(indentation: JsonIndentation.tabs),
        ),
        controller.setQuerySaved(r'$.items[*]', saved: true),
      ]);
      final restored = ToolPreferences.fromJson(
        jsonDecode(jsonEncode(saved.last.toJson())),
      );
      expect(restored.reading.fontFamily, 'Arial');
      expect(restored.reading.fontSize, 32);
      expect(restored.reading.lineSpacing, ReadingLineSpacing.spacious);
      expect(restored.format.indentation, JsonIndentation.tabs);
      expect(restored.queries, [r'$.items[*]']);
      expect(ToolPreferences.fromJson({}).reading.fontSize, 13);
      expect(ReadingPreferences.fromJson({'fontSize': 200}).fontSize, 32);
      expect(ReadingPreferences.fromJson({'fontSize': -10}).fontSize, 10);
      expect(
        ReadingPreferences.fromJson({
          'fontSize': 'bad',
          'fontFamily': ' ',
          'lineSpacing': 'bad',
        }).fontFamily,
        isNull,
      );
      await controller.setReading(const ReadingPreferences());
      expect(
        container.read(toolPreferencesProvider).format.indentation,
        JsonIndentation.tabs,
      );
      expect(container.read(toolPreferencesProvider).queries, [r'$.items[*]']);
    },
  );

  desktopTestWidgets(
    'font picker searches installed fonts and settings update every editor',
    (tester) async {
      final saved = <ToolPreferences>[];
      final container = await mount(
        tester,
        initial: const ToolPreferences(queries: [r'$.id']),
        save: (value) async {
          saved.add(value);
        },
      );
      final controller = container.read(workspaceProvider.notifier);
      const source = '{"message":"中🙂", "items":[1,2]}';
      controller.editSource(1, source);
      await tester.pumpAndSettle();
      final editor = tester
          .widget<CodeEditor>(find.byType(CodeEditor))
          .controller!;
      final tree = tester.widget<TreePanel>(find.byType(TreePanel));
      tree.onReveal(tree.snapshot.root!.children.first.value.range);
      await tester.pumpAndSettle();
      final selected = editor.selectedText;
      final revision = container
          .read(workspaceProvider)
          .active
          .document
          .revision;
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('settings-reading')));
      await tester.pumpAndSettle();
      final fontButton = find.text('Default monospace font');
      await tester.ensureVisible(fontButton);
      await tester.pumpAndSettle();
      await tester.tap(fontButton);
      await tester.pumpAndSettle();
      expect(find.byType(FontPicker), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'aRiAl');
      await tester.pumpAndSettle();
      expect(find.text('Courier New'), findsNothing);
      await tester.tap(find.text('Arial'));
      await tester.pumpAndSettle();
      expect(saved.last.reading.fontFamily, 'Arial');
      await chooseSize(tester, 32);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is IconButton &&
                    widget.tooltip == 'Increase font size',
              ),
            )
            .onPressed,
        isNull,
      );
      final spacing = find.byTooltip('Line spacing');
      await tester.ensureVisible(spacing);
      await tester.pumpAndSettle();
      await tester.tap(spacing);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Spacious').last);
      await tester.pumpAndSettle();
      final preview = find.descendant(
        of: find.byKey(const ValueKey('reading-preview')),
        matching: find.byType(CodeEditor),
      );
      expect(tester.widget<CodeEditor>(preview).style!.fontFamily, 'Arial');
      expect(tester.widget<CodeEditor>(preview).style!.fontSize, 32);
      expect(tester.widget<CodeEditor>(preview).style!.fontHeight, 1.8);
      expect(editor.selectedText, selected);
      expect(editor.text, source);
      expect(
        container.read(workspaceProvider).active.document.revision,
        revision,
      );
      await chooseSize(tester, 10);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is IconButton &&
                    widget.tooltip == 'Decrease font size',
              ),
            )
            .onPressed,
        isNull,
      );
      final reset = find.text('Reset to defaults');
      await tester.ensureVisible(reset);
      await tester.pumpAndSettle();
      await tester.tap(reset);
      await tester.pumpAndSettle();
      expect(saved.last.reading.fontSize, 13);
      expect(saved.last.reading.fontFamily, isNull);
      expect(saved.last.queries, [r'$.id']);
      expect(tester.widget<CodeEditor>(preview).style!.fontSize, 13);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(
        identical(
          tester.widget<CodeEditor>(find.byType(CodeEditor)).controller,
          editor,
        ),
        isTrue,
      );
      controller.undo(1);
      await tester.pumpAndSettle();
      expect(container.read(workspaceProvider).active.text, '');
      expect(tester.takeException(), isNull);
    },
  );

  desktopTestWidgets(
    'unavailable fonts use a default while retaining the saved choice',
    (tester) async {
      final container = await mount(
        tester,
        initial: const ToolPreferences(
          reading: ReadingPreferences(fontFamily: 'Missing Font', fontSize: 20),
        ),
      );
      expect(
        tester.widget<CodeEditor>(find.byType(CodeEditor)).style!.fontFamily,
        isNot('Missing Font'),
      );
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('settings-reading')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('The font “Missing Font” is unavailable.'),
        findsOneWidget,
      );
      expect(
        container.read(toolPreferencesProvider).reading.fontFamily,
        'Missing Font',
      );
      expect(tester.takeException(), isNull);
    },
  );

  desktopTestWidgets(
    'failed reading saves retain the previous value and allow retry',
    (tester) async {
      var fail = true;
      final container = await mount(
        tester,
        save: (_) async {
          if (fail) throw Exception('failed');
        },
      );
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('settings-reading')));
      await tester.pumpAndSettle();
      final increase = find.byTooltip('Increase font size');
      await tester.ensureVisible(increase);
      await tester.pumpAndSettle();
      await tester.tap(increase);
      await tester.pumpAndSettle();
      expect(container.read(toolPreferencesProvider).reading.fontSize, 13);
      expect(
        find.text('Could not save preferences. Try again.'),
        findsOneWidget,
      );
      fail = false;
      await tester.tap(increase);
      await tester.pumpAndSettle();
      expect(container.read(toolPreferencesProvider).reading.fontSize, 14);
      expect(tester.takeException(), isNull);
    },
  );

  desktopTestWidgets('font catalog failures can be retried in the picker', (
    tester,
  ) async {
    var calls = 0;
    final container = await mount(
      tester,
      loadFonts: () async {
        if (++calls == 1) throw PlatformException(code: 'font_list_failed');
        return fonts;
      },
    );
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-reading')));
    await tester.pumpAndSettle();
    final fontButton = find.text('Default monospace font');
    await tester.ensureVisible(fontButton);
    await tester.pumpAndSettle();
    await tester.tap(fontButton);
    await tester.pumpAndSettle();
    final error = find.descendant(
      of: find.byType(FontPicker),
      matching: find.text('Could not load fonts. Retry.'),
    );
    expect(error, findsOneWidget);
    await tester.tap(find.byTooltip('Refresh fonts'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Arial'));
    await tester.pumpAndSettle();
    expect(container.read(toolPreferencesProvider).reading.fontFamily, 'Arial');
    expect(calls, 2);
    expect(tester.takeException(), isNull);
  });

  desktopTestWidgets(
    'system text scaling is applied once and query layouts remain usable',
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final container = await mount(
        tester,
        size: const Size(720, 460),
        initial: const ToolPreferences(
          reading: ReadingPreferences(
            fontSize: 32,
            lineSpacing: ReadingLineSpacing.spacious,
          ),
        ),
      );
      container.read(workspaceProvider.notifier).editSource(1, '{"id":1}');
      await tester.pumpAndSettle();
      expect(
        tester.widget<CodeEditor>(find.byType(CodeEditor)).style!.fontSize,
        48,
      );
      await tester.tap(find.byTooltip('JSONPath query'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), r'$.id');
      await tester.pump();
      await tester.tap(find.text('Run query'));
      await tester.pumpAndSettle();
      expect(find.text('1 results'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    desktopTestWidgets(
      'large fonts keep tree, table, query and source locations usable in $mode',
      (tester) async {
        final container = await mount(
          tester,
          mode: mode,
          size: const Size(720, 460),
          initial: const ToolPreferences(
            reading: ReadingPreferences(
              fontFamily: 'Arial',
              fontSize: 32,
              lineSpacing: ReadingLineSpacing.spacious,
            ),
          ),
        );
        final controller = container.read(workspaceProvider.notifier);
        const source =
            '{"items":[{"name":"中🙂","id":1},{"name":"English","id":2}]}';
        controller.editSource(1, source);
        await tester.pumpAndSettle();
        final tree = tester.widget<TreePanel>(find.byType(TreePanel));
        final array = tree.snapshot.root!.children.first.value;
        final range = array.children.first.value.children.first.value.range;
        tree.onReveal(range);
        await tester.pumpAndSettle();
        final editor = tester.widget<CodeEditor>(find.byType(CodeEditor));
        expect(editor.style!.fontSize, 32);
        expect(editor.controller!.selectedText, '"中🙂"');
        final list = find.descendant(
          of: find.byType(TreePanel),
          matching: find.byType(ListView),
        );
        expect(tester.widget<ListView>(list).itemExtent, greaterThan(60));
        tree.onTable!(array);
        await tester.pumpAndSettle();
        final tableList = find.descendant(
          of: find.byType(ArrayTable),
          matching: find.byType(ListView),
        );
        expect(tester.widget<ListView>(tableList).itemExtent, greaterThan(60));
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('JSONPath query'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(find.byType(TextField)).style!.fontSize,
          32,
        );
        await tester.enterText(find.byType(TextField), r'$.items[*].name');
        await tester.pump();
        await tester.tap(find.text('Run query'));
        await tester.pumpAndSettle();
        expect(find.text('2 results'), findsOneWidget);
        final path = find.descendant(
          of: find.byType(ListTile),
          matching: find.text(r'$["items"][0]["name"]'),
        );
        await tester.tap(path);
        await tester.pumpAndSettle();
        expect(editor.controller!.selectedText, '"中🙂"');
        expect(tester.takeException(), isNull);
      },
    );
  }
}
