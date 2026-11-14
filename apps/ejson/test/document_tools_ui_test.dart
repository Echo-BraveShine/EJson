import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:ejson/workspace/workbench.dart';
import 'package:ejson/editor/schema_dialog.dart';
import 'package:ejson/editor/redaction_dialog.dart';
import 'package:ejson/editor/code_editor.dart';
import 'package:ejson/editor/tree_panel.dart';
import 'package:ejson/l10n/app_localizations.dart';
import 'package:ejson/main.dart';
import 'package:ejson/settings/installed_fonts.dart';
import 'package:ejson/workspace/workspace.dart';
import 'package:ejson_core/ejson_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ProviderContainer> mount(
  WidgetTester tester,
  ThemeMode mode, {
  void Function(String, Uint8List)? onSave,
}) async {
  await tester.binding.setSurfaceSize(const Size(720, 460));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final container = ProviderContainer(
    overrides: [
      workspaceAtomicWriterProvider.overrideWithValue((path, bytes) async {
        onSave?.call(path, bytes);
      }),
      parseDocumentProvider.overrideWithValue(
        (source, revision) async => parseJson(source, revision: revision),
      ),
      installedFontsProvider.overrideWith((ref) async => []),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: EJsonApp(initialThemeMode: mode),
    ),
  );
  container
      .read(workspaceProvider.notifier)
      .editSource(1, '{"email":"secret@example.com","age":"bad","id":1e2}');
  await tester.pumpAndSettle();
  return container;
}

Future<void> waitFor(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 100; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
    if (finder.evaluate().isNotEmpty) return;
  }
  expect(finder, findsWidgets);
}

void main() {
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets(
      'schema issues reveal source and drafts survive reopening in $mode',
      (tester) async {
        final container = await mount(tester, mode);
        await tester.tap(find.byTooltip('Document tools'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('JSON Schema validation'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextField),
          '{"type":"object","properties":{"age":{"type":"integer"}}}',
        );
        await tester.pump();
        await tester.tap(find.text('Validate'));
        await waitFor(tester, find.text(r'$["age"]'));
        await tester.tap(find.text(r'$["age"]'));
        await tester.pumpAndSettle();
        expect(find.byType(SchemaDialog), findsNothing);
        final editor = tester.widget<EJsonCodeEditor>(
          find.byType(EJsonCodeEditor),
        );
        expect(
          container
              .read(workspaceProvider)
              .active
              .text
              .substring(editor.jump!.range.start, editor.jump!.range.end),
          '"bad"',
        );
        await tester.tap(find.byTooltip('Document tools'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('JSON Schema validation'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          contains('integer'),
        );
        await tester.enterText(find.byType(TextField), 'true');
        await tester.pump();
        await tester.tap(find.text('Validate'));
        await waitFor(tester, find.text('Matches schema'));
        await tester.enterText(find.byType(TextField), '{');
        await tester.pump();
        expect(find.text('Matches schema'), findsNothing);
        await tester.pump();
        await tester.tap(find.text('Validate'));
        await waitFor(tester, find.textContaining('Validation failed'));
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets('redaction previews and opens an editable copy in $mode', (
      tester,
    ) async {
      final container = await mount(tester, mode);
      final original = container.read(workspaceProvider).active.text;
      await tester.tap(find.byTooltip('Document tools'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Redact data'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Preview'));
      await tester.pumpAndSettle();
      expect(
        tester.getBottomLeft(find.byType(TextField).last).dy,
        closeTo(
          tester.getBottomLeft(find.widgetWithText(TextButton, 'Preview')).dy,
          0.01,
        ),
      );
      await tester.tap(find.text('Preview'));
      await waitFor(tester, find.text('1 values replaced'));
      await tester.ensureVisible(find.text('Open redacted copy'));
      await tester.tap(find.text('Open redacted copy'));
      await tester.pumpAndSettle();
      expect(find.byType(RedactionDialog), findsNothing);
      expect(container.read(workspaceProvider).tabs.first.text, original);
      expect(
        container.read(workspaceProvider).active.text,
        '{"email":"***","age":"bad","id":1e2}',
      );
      expect(container.read(workspaceProvider).active.dirty, isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('save redacted copy uses Save As and keeps the source document', (
    tester,
  ) async {
    final directory = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('ejson-redaction-'),
    ))!;
    addTearDown(() => directory.deleteSync(recursive: true));
    final target = '${directory.path}/ejson-redacted-copy-test.json';
    Uint8List? saved;
    final container = await mount(
      tester,
      ThemeMode.light,
      onSave: (path, bytes) {
        saved = bytes;
        File(path).writeAsBytesSync(bytes);
      },
    );
    const selector = MethodChannel('plugins.flutter.io/file_selector');
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      selector,
      (call) async => call.method == 'getSavePath' ? target : null,
    );
    addTearDown(() => messenger.setMockMethodCallHandler(selector, null));
    final original = container.read(workspaceProvider).active.text;
    await tester.tap(find.byTooltip('Document tools'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Redact data'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Preview'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Preview'));
    await waitFor(tester, find.text('1 values replaced'));
    await tester.tap(find.text('Save redacted copy'));
    await waitFor(tester, find.text('ejson-redacted-copy-test.json'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(saved, isNotNull);
    expect(utf8.decode(saved!), '{"email":"***","age":"bad","id":1e2}');
    final persisted = await tester.runAsync(() => File(target).readAsString());
    expect(persisted, '{"email":"***","age":"bad","id":1e2}');
    expect(
      container.read(workspaceProvider).active.file!.path,
      File(target).resolveSymbolicLinksSync(),
    );
    expect(container.read(workspaceProvider).active.dirty, isFalse);
    expect(container.read(workspaceProvider).tabs.first.text, original);
    expect(tester.takeException(), isNull);
  });

  testWidgets('breadcrumbs copy selected paths and navigate to ancestors', (
    tester,
  ) async {
    const source = '{"a/b":[{"nested":1}]}';
    SourceRange? revealed;
    String? copied;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TreePanel(
            snapshot: parseJson(source),
            source: source,
            current: true,
            onReveal: (range) => revealed = range,
            onEdit: (_, _) {},
            onCopyPath: (path) => copied = path,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('expand:root/0')));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('expand:root/0/0')));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.tap(find.text('nested'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Copy JSONPath'));
    expect(copied, r'$["a/b"][0]["nested"]');
    await tester.ensureVisible(find.byKey(const ValueKey('breadcrumb-1')));
    await tester.tap(find.byKey(const ValueKey('breadcrumb-1')));
    await tester.pumpAndSettle();
    expect(source.substring(revealed!.start, revealed!.end), '[{"nested":1}]');
    await tester.ensureVisible(find.byKey(const ValueKey('breadcrumb-0')));
    await tester.tap(find.byKey(const ValueKey('breadcrumb-0')));
    await tester.pumpAndSettle();
    expect(revealed, (start: 0, end: source.length));
    expect(tester.takeException(), isNull);
  });
}
