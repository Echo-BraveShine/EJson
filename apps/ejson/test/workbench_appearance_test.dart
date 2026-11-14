import 'package:ejson/design/workbench_style.dart';
import 'package:ejson/editor/code_editor.dart';
import 'package:ejson/editor/json_highlight.dart';
import 'package:ejson/editor/tree_panel.dart';
import 'package:ejson/editor/tree_style.dart';
import 'package:ejson/main.dart';
import 'package:ejson/settings/settings_panel.dart';
import 'package:flutter/cupertino.dart' show CupertinoSwitch;
import 'package:ejson/workspace/workspace.dart';
import 'package:ejson_core/ejson_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';

import 'support/workbench_test_harness.dart';

void main() {
  testWidgets('appearance switches theme and glass at minimum window size', (
    tester,
  ) async {
    Finder logo(String theme) =>
        find.image(AssetImage('assets/branding/logo_$theme.png'));

    tester.binding.platformDispatcher.platformBrightnessTestValue =
        Brightness.light;
    addTearDown(
      tester.binding.platformDispatcher.clearPlatformBrightnessTestValue,
    );
    await tester.binding.setSurfaceSize(const Size(720, 460));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final savedModes = <ThemeMode>[];
    await tester.pumpWidget(
      ProviderScope(
        child: EJsonApp(saveThemeMode: (mode) async => savedModes.add(mode)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(BackdropFilter), findsNWidgets(3));
    expect(logo('light'), findsOneWidget);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPanel), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('settings-about')));
    await tester.pumpAndSettle();
    final about = find.text('About EJson').last;
    final checkUpdates = find.text('Check for updates');
    await tester.ensureVisible(checkUpdates);
    await tester.pumpAndSettle();
    expect(checkUpdates.hitTestable(), findsOneWidget);
    expect(
      tester.getCenter(checkUpdates).dy,
      closeTo(tester.getCenter(about).dy, 1),
    );
    final buyCoffee = find.text('Buy me a coffee');
    await tester.ensureVisible(buyCoffee);
    await tester.pumpAndSettle();
    expect(buyCoffee.hitTestable(), findsOneWidget);
    expect(
      tester.getTopLeft(buyCoffee).dx,
      closeTo(tester.getTopLeft(about).dx, .01),
    );
    expect(
      tester.getTopLeft(buyCoffee).dy,
      greaterThan(tester.getBottomLeft(checkUpdates).dy),
    );
    final footerDivider = find
        .descendant(
          of: find.byType(SettingsPanel),
          matching: find.byType(Divider),
        )
        .last;
    expect(
      tester.getCenter(footerDivider).dy,
      greaterThan(tester.getCenter(about).dy),
    );
    expect(
      tester.getCenter(footerDivider).dy,
      lessThan(tester.getCenter(buyCoffee).dy),
    );
    await tester.tap(find.byKey(const ValueKey('settings-appearance')));
    await tester.pumpAndSettle();
    final darkOption = find.text('Dark');
    await tester.ensureVisible(darkOption);
    await tester.tap(darkOption);
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(SettingsPanel))).brightness,
      Brightness.dark,
    );
    expect(logo('dark'), findsOneWidget);
    expect(logo('light'), findsNothing);
    expect(savedModes, [ThemeMode.dark]);
    final glassSwitch = find.descendant(
      of: find.bySemanticsLabel('Glass toolbar'),
      matching: find.byType(CupertinoSwitch),
    );
    await tester.ensureVisible(glassSwitch);
    await tester.tap(glassSwitch);
    await tester.pumpAndSettle();
    expect(find.byType(BackdropFilter), findsNothing);
    final toolbarGroups = find.byType(GlassGroup);
    expect(toolbarGroups, findsNWidgets(3));
    expect([
      for (var i = 0; i < 3; i++) tester.getSize(toolbarGroups.at(i)).height,
    ], everyElement(WorkbenchStyle.toolbarControlHeight + 4));

    expect(
      tester.getSize(find.widgetWithText(FilledButton, 'Done')).height,
      WorkbenchStyle.dialogButtonHeight,
    );
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPanel), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      ProviderScope(child: EJsonApp(initialThemeMode: savedModes.single)),
    );
    await tester.pumpAndSettle();
    expect(logo('dark'), findsOneWidget);
  });

  testWidgets(
    'highlight and tree styles update independently and save their selections',
    (tester) async {
      final saved = <JsonHighlight>[];
      final savedTree = <JsonTreeStyle>[];
      final container = ProviderContainer(
        overrides: [
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
            saveHighlight: (style) async => saved.add(style),
            saveTreeStyle: (style) async => savedTree.add(style),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final editor = tester
          .widget<CodeEditor>(find.byType(CodeEditor))
          .controller!;
      editor.text = '{"name":"EJson"}';
      await settleDocumentEdits(tester);

      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('settings-appearance')));
      await tester.pumpAndSettle();
      final highlightPicker = find.byTooltip('JSON highlighting');
      await tester.ensureVisible(highlightPicker);
      await tester.tap(highlightPicker);
      await tester.pumpAndSettle();
      expect(find.text('Tokyo Night'), findsOneWidget);
      await tester.tap(find.text('GitHub'));
      await tester.pumpAndSettle();
      expect(saved, [JsonHighlight.github]);
      expect(
        tester
            .widget<EJsonCodeEditor>(find.byType(EJsonCodeEditor).first)
            .highlight,
        JsonHighlight.github,
      );
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      final tree = tester.widget<TreePanel>(find.byType(TreePanel));
      expect(tree.style, JsonTreeStyle.classic);
      tree.onEdit(tree.snapshot.root!.range, false);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<EJsonCodeEditor>(find.byType(EJsonCodeEditor).last)
            .highlight,
        JsonHighlight.github,
      );
      expect(editor.text, '{"name":"EJson"}');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('settings-appearance')));
      await tester.pumpAndSettle();
      final treePicker = find.byTooltip('JSON tree style');
      await tester.ensureVisible(treePicker);
      await tester.tap(treePicker);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Compact'));
      await tester.pumpAndSettle();
      expect(savedTree, [JsonTreeStyle.compact]);
      expect(
        tester.widget<TreePanel>(find.byType(TreePanel).first).style,
        JsonTreeStyle.compact,
      );
      expect(
        tester
            .widget<EJsonCodeEditor>(find.byType(EJsonCodeEditor).first)
            .highlight,
        JsonHighlight.github,
      );
      await tester.ensureVisible(highlightPicker);
      await tester.tap(highlightPicker);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Monochrome'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CodeEditor>(find.byType(CodeEditor).first)
            .style
            ?.codeTheme,
        isNull,
      );
    },
  );

  testWidgets(
    'language switches menus, diagnostics and dialogs without losing JSON',
    (tester) async {
      final savedLanguages = <String?>[];
      final container = ProviderContainer(
        overrides: [
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
            initialLanguage: 'en',
            saveLanguage: (language) async => savedLanguages.add(language),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final editor = tester
          .widget<CodeEditor>(find.byType(CodeEditor))
          .controller!;
      editor.text = '{"item": [true]}';
      await settleDocumentEdits(tester);
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('简体中文'));
      await tester.tap(find.text('简体中文'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AlertDialog, '设置'), findsOneWidget);
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();
      expect(savedLanguages, ['zh']);
      expect(find.text('未命名'), findsOneWidget);
      expect(find.text('源码'), findsOneWidget);
      expect(find.text('JSON 有效'), findsOneWidget);
      expect(editor.text, '{"item": [true]}');

      final tree = tester.widget<TreePanel>(find.byType(TreePanel));
      tree.onEdit(tree.snapshot.root!.children.first.value.range, false);
      await tester.pumpAndSettle();
      expect(find.text('替换 JSON 值'), findsOneWidget);
      final replacement = tester.widget<CodeEditor>(
        find.byType(CodeEditor).last,
      );
      expect(replacement.controller!.text, '[\n  true\n]');
      expect(replacement.style?.codeTheme?.languages, contains('json'));
      expect(editor.text, '{"item": [true]}');
      await tester.tap(find.text('应用'));
      await tester.pumpAndSettle();
      expect(editor.text, '{"item": [true]}');

      tree.onEdit(tree.snapshot.root!.children.first.value.range, false);
      await tester.pumpAndSettle();
      tester.widget<CodeEditor>(find.byType(CodeEditor).last).controller!.text =
          '[1';
      await tester.tap(find.text('应用'));
      await tester.pumpAndSettle();
      expect(find.text('此处需要逗号或右方括号。'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('关闭 未命名'));
      await tester.pumpAndSettle();
      expect(find.text('要保存修改吗？'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      editor.text = '{"item": truX}';
      await settleDocumentEdits(tester);
      expect(find.textContaining('此处需要 true。'), findsOneWidget);
      await tester.tap(find.byTooltip('设置'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('English'));
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(savedLanguages, ['zh', 'en']);
      expect(find.text('Source'), findsOneWidget);
      expect(editor.text, '{"item": truX}');
    },
  );
}
