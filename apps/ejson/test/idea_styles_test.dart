import 'package:ejson/editor/code_editor.dart';
import 'package:ejson/editor/json_highlight.dart';
import 'package:ejson/editor/tree_panel.dart';
import 'package:ejson/editor/tree_style.dart';
import 'package:ejson/main.dart';
import 'package:ejson/settings/installed_fonts.dart';
import 'package:ejson/workspace/workspace.dart';
import 'package:ejson_core/ejson_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';

void main() {
  test('IDEA-inspired palettes distinguish tokens with readable contrast', () {
    for (final scheme in [
      JsonHighlight.intellijLight,
      JsonHighlight.darcula,
      JsonHighlight.darculaContrast,
    ]) {
      for (final brightness in Brightness.values) {
        final colors = scheme.colors(brightness)!;
        final background = scheme.editorBackground(brightness)!;
        if (scheme == JsonHighlight.darcula ||
            scheme == JsonHighlight.darculaContrast) {
          expect(ThemeData.estimateBrightnessForColor(background), brightness);
          expect(
            scheme.colors(Brightness.light),
            isNot(scheme.colors(Brightness.dark)),
          );
        }
        expect(colors['attr']!.color, isNot(colors['string']!.color));
        expect(colors['number']!.color, isNot(colors['literal']!.color));
        for (final style in colors.values) {
          final a = style.color!.computeLuminance();
          final b = background.computeLuminance();
          final contrast = a > b
              ? (a + .05) / (b + .05)
              : (b + .05) / (a + .05);
          expect(contrast, greaterThanOrEqualTo(4.5), reason: scheme.name);
        }
      }
    }
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets(
      'new schemes and tree styles update previews and persist in $mode',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1000, 760));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final savedHighlights = <JsonHighlight>[];
        final savedTrees = <JsonTreeStyle>[];
        final container = ProviderContainer(
          overrides: [
            installedFontsProvider.overrideWith((ref) async => []),
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
              initialThemeMode: mode,
              saveHighlight: (value) async => savedHighlights.add(value),
              saveTreeStyle: (value) async => savedTrees.add(value),
            ),
          ),
        );
        const original =
            '{"nested":{"items":[true,null,12345678901234567890]}}';
        container.read(workspaceProvider.notifier).editSource(1, original);
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Settings'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('settings-appearance')));
        await tester.pumpAndSettle();
        for (final entry in {
          'IntelliJ Light': JsonHighlight.intellijLight,
          'Darcula': JsonHighlight.darcula,
          'Darcula Contrast': JsonHighlight.darculaContrast,
        }.entries) {
          final picker = find.byTooltip('JSON highlighting');
          await tester.ensureVisible(picker);
          await tester.tap(picker);
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text(entry.key).last);
          await tester.tap(find.text(entry.key).last);
          await tester.pumpAndSettle();
          final preview = find.byKey(const ValueKey('appearance-code-preview'));
          expect(
            tester.widget<EJsonCodeEditor>(preview).highlight,
            entry.value,
          );
          final editor = tester.widget<CodeEditor>(
            find.descendant(of: preview, matching: find.byType(CodeEditor)),
          );
          expect(
            editor.style!.backgroundColor,
            entry.value.editorBackground(
              mode == ThemeMode.dark ? Brightness.dark : Brightness.light,
            ),
          );
          expect(savedHighlights.last, entry.value);
        }
        for (final label
            in mode == ThemeMode.light
                ? ['Dark', 'Light']
                : ['Light', 'Dark']) {
          final option = find.text(label);
          await tester.ensureVisible(option);
          await tester.tap(option);
          await tester.pumpAndSettle();
          final expectedBrightness = label == 'Dark'
              ? Brightness.dark
              : Brightness.light;
          final preview = find.byKey(const ValueKey('appearance-code-preview'));
          final editor = tester.widget<CodeEditor>(
            find.descendant(of: preview, matching: find.byType(CodeEditor)),
          );
          expect(
            editor.style!.backgroundColor,
            JsonHighlight.darculaContrast.editorBackground(expectedBrightness),
          );
        }
        for (final entry in {
          'Structure navigator': JsonTreeStyle.structure,
          'Hierarchy guides': JsonTreeStyle.guides,
        }.entries) {
          final picker = find.byTooltip('JSON tree style');
          await tester.ensureVisible(picker);
          await tester.tap(picker);
          await tester.pumpAndSettle();
          await tester.tap(find.text(entry.key).last);
          await tester.pumpAndSettle();
          final preview = find.byKey(const ValueKey('appearance-tree-preview'));
          await tester.ensureVisible(preview);
          await tester.pumpAndSettle();
          expect(tester.widget<TreePanel>(preview).style, entry.value);
          expect(tester.widget<TreePanel>(preview).readOnly, isTrue);
          expect(
            find.descendant(
              of: preview,
              matching: find.byKey(const ValueKey('tree-type:root')),
            ),
            findsOneWidget,
          );
          final root = tester.widget<CustomPaint>(
            find.descendant(
              of: preview,
              matching: find.byKey(const ValueKey('tree-row:root')),
            ),
          );
          expect(root.painter, isNotNull);
          expect(savedTrees.last, entry.value);
        }
        final preview = find.byKey(const ValueKey('appearance-tree-preview'));
        final expand = find.descendant(
          of: preview,
          matching: find.byKey(const ValueKey('expand:root/2')),
        );
        await tester.ensureVisible(expand);
        await tester.tap(expand);
        await tester.pumpAndSettle();
        expect(
          find.descendant(of: preview, matching: find.text('[0]')),
          findsOneWidget,
        );
        final child = tester.widget<CustomPaint>(
          find.descendant(
            of: preview,
            matching: find.byKey(const ValueKey('tree-row:root/2/0')),
          ),
        );
        expect(child.painter, isNotNull);
        expect(container.read(workspaceProvider).active.text, original);
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TreePanel>(find.byType(TreePanel)).style,
          JsonTreeStyle.guides,
        );
        expect(
          tester
              .widget<EJsonCodeEditor>(find.byType(EJsonCodeEditor))
              .highlight,
          JsonHighlight.darculaContrast,
        );
        expect(container.read(workspaceProvider).active.text, original);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
