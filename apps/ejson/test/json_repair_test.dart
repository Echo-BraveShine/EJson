import 'package:ejson/editor/json_repair_dialog.dart';
import 'package:ejson/main.dart';
import 'package:ejson/settings/installed_fonts.dart';
import 'package:ejson/workspace/workspace.dart';
import 'package:ejson_core/ejson_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/conversion_test_harness.dart' show waitForConversion;

Future<ProviderContainer> mountRepair(
  WidgetTester tester,
  String source, {
  String language = 'en',
  ThemeMode theme = ThemeMode.light,
}) async {
  await tester.binding.setSurfaceSize(const Size(720, 460));
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
      child: EJsonApp(initialLanguage: language, initialThemeMode: theme),
    ),
  );
  container.read(workspaceProvider.notifier).editSource(1, source);
  await tester.pumpAndSettle();
  await tester.tap(
    find.byTooltip(language == 'en' ? 'Document tools' : '文档工具'),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(language == 'en' ? 'Repair JSON' : '修复 JSON'));
  await tester.pump();
  return container;
}

Finder applyRepair(String label) => find.descendant(
  of: find.byType(JsonRepairDialog),
  matching: find.widgetWithText(FilledButton, label),
);

void main() {
  for (final language in ['en', 'zh']) {
    testWidgets('repair preview applies once and supports undo in $language', (
      tester,
    ) async {
      const source = "{id:123456789012345678901,name:'中文',}";
      final container = await mountRepair(
        tester,
        source,
        language: language,
        theme: language == 'en' ? ThemeMode.light : ThemeMode.dark,
      );
      await waitForConversion(
        tester,
        find.byKey(const ValueKey('json-repair-preview')),
      );
      await tester.pumpAndSettle();
      expect(container.read(workspaceProvider).active.text, source);
      expect(tester.takeException(), isNull);
      await tester.tap(applyRepair(language == 'en' ? 'Apply' : '应用'));
      await tester.pumpAndSettle();
      final repaired = container.read(workspaceProvider).active.text;
      expect(parseJson(repaired).root, isNotNull);
      expect(repaired, contains('123456789012345678901'));
      final controller = container.read(workspaceProvider.notifier);
      controller.undo(1);
      await tester.pumpAndSettle();
      expect(container.read(workspaceProvider).active.text, source);
      controller.redo(1);
      await tester.pumpAndSettle();
      expect(container.read(workspaceProvider).active.text, repaired);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('missing values show a repair error and preserve the source', (
    tester,
  ) async {
    final container = await mountRepair(tester, '{a:}');
    await waitForConversion(
      tester,
      find.textContaining('The content could not be repaired.'),
    );
    expect(tester.widget<FilledButton>(applyRepair('Apply')).onPressed, isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(container.read(workspaceProvider).active.text, '{a:}');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a changed document rejects an outdated repair preview', (
    tester,
  ) async {
    final container = await mountRepair(tester, '{a:1,}');
    await waitForConversion(
      tester,
      find.byKey(const ValueKey('json-repair-preview')),
    );
    container
        .read(workspaceProvider.notifier)
        .editSource(1, '{"updated":true}');
    await tester.pump();
    await tester.tap(applyRepair('Apply'));
    await tester.pumpAndSettle();
    expect(container.read(workspaceProvider).active.text, '{"updated":true}');
    expect(tester.takeException(), isNull);
  });

  testWidgets('valid JSON needs no repairs', (tester) async {
    final container = await mountRepair(tester, '{"a":1}');
    await waitForConversion(
      tester,
      find.text('This document is already valid JSON.'),
    );
    expect(tester.widget<FilledButton>(applyRepair('Apply')).onPressed, isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(container.read(workspaceProvider).active.text, '{"a":1}');
  });
}
