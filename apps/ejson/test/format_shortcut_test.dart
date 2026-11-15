import 'package:ejson/main.dart';
import 'package:ejson/settings/installed_fonts.dart';
import 'package:ejson/workspace/workspace.dart';
import 'package:ejson_core/ejson_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';

import 'support/conversion_test_harness.dart' show waitForConversion;

Future<void> formatKey(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
}

void main() {
  testWidgets('format shortcut works from the editor for all native formats', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
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
        child: const EJsonApp(initialLanguage: 'en'),
      ),
    );
    await tester.pumpAndSettle();
    final controller = container.read(workspaceProvider.notifier);
    for (final entry in {
      DocumentFormat.json: '{"a":1}',
      DocumentFormat.yaml: 'a:\n    b: 1\n',
      DocumentFormat.csv: 'id,name\n1,Alice',
      DocumentFormat.xml: '<r><id>1</id></r>',
      DocumentFormat.toml: 'a=1',
      DocumentFormat.jsonLines: '{ "a" : 1 }\n',
    }.entries) {
      controller.newTabWithSource(entry.value, format: entry.key);
      await tester.pump(const Duration(milliseconds: 200));
      await waitForConversion(
        tester,
        find.text(
          entry.key == DocumentFormat.json
              ? 'Valid JSON'
              : 'Valid ${entry.key.label}',
        ),
      );
      await tester.tap(find.byType(CodeEditor));
      await formatKey(tester);
      for (
        var i = 0;
        i < 100 && container.read(workspaceProvider).active.text == entry.value;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      expect(
        container.read(workspaceProvider).active.text,
        isNot(entry.value),
        reason: entry.key.label,
      );
      controller.undo(container.read(workspaceProvider).activeId);
      await tester.pumpAndSettle();
      expect(container.read(workspaceProvider).active.text, entry.value);
    }
    controller.newTabWithSource('{');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CodeEditor));
    await formatKey(tester);
    await tester.pumpAndSettle();
    expect(container.read(workspaceProvider).active.text, '{');
    controller.newTabWithSource('{"a":1}');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await formatKey(tester);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(container.read(workspaceProvider).active.text, '{"a":1}');
    expect(tester.takeException(), isNull);
  });
}
