import 'dart:io';

import 'package:ejson/design/workbench_style.dart';
import 'package:ejson/editor/conversion_job.dart';
import 'package:ejson/editor/save_as_dialog.dart';
import 'package:ejson/workspace/local_files.dart';
import 'package:ejson/workspace/workspace.dart';
import 'package:ejson_core/ejson_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'file_workflow_test.dart' show start;
import 'support/conversion_test_harness.dart' show waitForConversion;

const _source = '{"id":"001","enabled":true}';

Future<void> selectSaveFormat(
  WidgetTester tester,
  DocumentFormat format,
) async {
  await tester.tap(find.byType(WorkbenchSelect<DocumentFormat>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('${format.label} (.${format.extension})').last);
  await tester.pump();
}

Finder saveButton() => find.descendant(
  of: find.byType(SaveAsDialog),
  matching: find.widgetWithText(FilledButton, 'Save'),
);

void main() {
  test('save conversion checks every pair of document formats', () async {
    for (final sourceFormat in DocumentFormat.values) {
      final source = sourceFormat == DocumentFormat.json
          ? _source
          : convertDocument(
              ConversionRequest(
                _source,
                ConversionDirection.values.firstWhere(
                  (direction) =>
                      direction.sourceFormat == DocumentFormat.json &&
                      direction.targetFormat == sourceFormat,
                ),
              ),
            ).source;
      for (final target in DocumentFormat.values) {
        if (target == sourceFormat) continue;
        final direction = ConversionDirection.values.firstWhere(
          (direction) =>
              direction.sourceFormat == sourceFormat &&
              (sourceFormat != DocumentFormat.json ||
                  direction.targetFormat == target),
        );
        final conversion = ConversionJob().run(
          ConversionRequest(source, direction),
          targetFormat: target,
        );
        if ((sourceFormat == DocumentFormat.csv ||
                sourceFormat == DocumentFormat.jsonLines) &&
            target == DocumentFormat.toml) {
          await expectLater(conversion, throwsA(isA<StateError>()));
          continue;
        }
        final output = await conversion;
        expect(output.format, target);
        expect(output.source, contains('001'));
      }
    }
  });

  test('multi-document YAML requires explicit document selection', () async {
    await expectLater(
      ConversionJob().run(
        const ConversionRequest(
          'id: 1\n---\nid: 2\n',
          ConversionDirection.yamlToJson,
        ),
        targetFormat: DocumentFormat.json,
      ),
      throwsA(isA<StateError>()),
    );
  });

  for (final format in DocumentFormat.values.where(
    (format) => format != DocumentFormat.json,
  )) {
    testWidgets('Save As previews and writes ${format.label}', (tester) async {
      final directory = Directory.systemTemp.createTempSync('ejson-save-as-');
      addTearDown(() => directory.deleteSync(recursive: true));
      final original = File('${directory.path}/source.json');
      original.writeAsStringSync('{}');
      final target = File('${directory.path}/result.${format.extension}');
      final container = await start(tester, (path) => LocalJsonFile.read(path));
      const nativeFiles = MethodChannel('dev.ekko.ejson/files');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        nativeFiles,
        (call) async {
          if (call.method == 'atomicWrite') {
            final arguments = call.arguments as Map;
            File(
              arguments['path'] as String,
            ).writeAsBytesSync(arguments['bytes'] as List<int>);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          nativeFiles,
          null,
        ),
      );
      final controller = container.read(workspaceProvider.notifier);
      controller.open(LocalJsonFile(original.path, '{}'));
      final originalId = container.read(workspaceProvider).activeId;
      controller.editSource(originalId, _source);
      await tester.pumpAndSettle();
      const selector = MethodChannel('plugins.flutter.io/file_selector');
      Map<dynamic, dynamic>? arguments;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(selector, (
        call,
      ) async {
        if (call.method == 'getSavePath') {
          arguments = call.arguments as Map;
          return target.path;
        }
        return null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          selector,
          null,
        ),
      );
      await tester.tap(find.byTooltip('Save As'));
      await tester.pumpAndSettle();
      await selectSaveFormat(tester, format);
      await waitForConversion(
        tester,
        find.byKey(const ValueKey('save-as-preview')),
      );
      await tester.pumpAndSettle();
      await tester.tap(saveButton());
      await waitForConversion(tester, find.text('result.${format.extension}'));
      await tester.pumpAndSettle();
      expect(arguments!['suggestedName'], 'source.${format.extension}');
      expect(
        ((arguments!['acceptedTypeGroups'] as List).single
            as Map)['extensions'],
        format.extensions,
      );
      final workspace = container.read(workspaceProvider);
      expect(workspace.active.format, format);
      expect(workspace.active.dirty, isFalse);
      expect(target.readAsStringSync(), workspace.active.text);
      expect(workspace.tab(originalId)!.text, _source);
      expect(workspace.tab(originalId)!.dirty, isTrue);
      expect(original.readAsStringSync(), '{}');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'first save of an untitled document selects and writes a file type on Windows',
    (tester) async {
      final directory = Directory.systemTemp.createTempSync(
        'ejson-first-save-',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final target = File('${directory.path}/untitled.xml');
      final container = await start(
        tester,
        (path) async => LocalJsonFile(path, '{}'),
      );
      container.read(workspaceProvider.notifier).editSource(1, _source);
      await tester.pumpAndSettle();

      const nativeFiles = MethodChannel('dev.ekko.ejson/files');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        nativeFiles,
        (call) async {
          if (call.method == 'atomicWrite') {
            final arguments = call.arguments as Map;
            File(
              arguments['path'] as String,
            ).writeAsBytesSync(arguments['bytes'] as List<int>);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          nativeFiles,
          null,
        ),
      );
      const selector = MethodChannel('plugins.flutter.io/file_selector');
      Map<dynamic, dynamic>? arguments;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(selector, (
        call,
      ) async {
        if (call.method == 'getSavePath') {
          arguments = call.arguments as Map;
          return target.path;
        }
        return null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          selector,
          null,
        ),
      );

      await tester.tap(find.byTooltip('Save'));
      await tester.pumpAndSettle();
      expect(find.byType(SaveAsDialog), findsOneWidget);
      expect(find.text('JSON (.json)'), findsOneWidget);
      expect(find.text('XML (.xml)'), findsNothing);

      await tester.tap(find.byType(WorkbenchSelect<DocumentFormat>));
      await tester.pumpAndSettle();
      expect(find.text('JSON (.json)'), findsWidgets);
      expect(find.text('XML (.xml)'), findsOneWidget);
      expect(find.text('CSV (.csv)'), findsOneWidget);
      expect(find.text('TOML (.toml)'), findsOneWidget);
      await tester.tap(find.text('XML (.xml)').last);
      await tester.pump();
      await waitForConversion(
        tester,
        find.byKey(const ValueKey('save-as-preview')),
      );
      await tester.tap(saveButton());
      await waitForConversion(tester, find.text('untitled.xml'));
      await tester.pumpAndSettle();

      final group =
          (arguments!['acceptedTypeGroups'] as List).single
              as Map<dynamic, dynamic>;
      expect(group['label'], 'XML');
      expect(group['extensions'], DocumentFormat.xml.extensions);
      expect(arguments!['suggestedName'], 'untitled.xml');
      expect(target.existsSync(), isTrue);
      expect(
        container.read(workspaceProvider).active.format,
        DocumentFormat.xml,
      );
      expect(
        container.read(workspaceProvider).active.file?.path,
        target.resolveSymbolicLinksSync(),
      );
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({TargetPlatform.windows}),
  );

  testWidgets('unsupported conversion disables save and can be cancelled', (
    tester,
  ) async {
    final container = await start(
      tester,
      (path) async => LocalJsonFile(path, '{}'),
    );
    await tester.binding.setSurfaceSize(const Size(720, 460));
    container.read(workspaceProvider.notifier).editSource(1, '{"value":null}');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Save As'));
    await tester.pumpAndSettle();
    await selectSaveFormat(tester, DocumentFormat.toml);
    await waitForConversion(tester, find.textContaining('Formatting failed'));
    expect(tester.widget<FilledButton>(saveButton()).onPressed, isNull);
    await selectSaveFormat(tester, DocumentFormat.json);
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(saveButton()).onPressed, isNotNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(container.read(workspaceProvider).tabs, hasLength(1));
    expect(container.read(workspaceProvider).active.file, isNull);
    expect(container.read(workspaceProvider).active.text, '{"value":null}');
    expect(tester.takeException(), isNull);
  });

  for (final failWrite in [false, true]) {
    testWidgets(
      'cancelled picker or failed write keeps the source, failWrite=$failWrite',
      (tester) async {
        final directory = Directory.systemTemp.createTempSync('ejson-save-as-');
        addTearDown(() => directory.deleteSync(recursive: true));
        final target = File('${directory.path}/missing/result.xml');
        final container = await start(
          tester,
          (path) async => LocalJsonFile(path, '{}'),
        );
        container.read(workspaceProvider.notifier).editSource(1, _source);
        await tester.pumpAndSettle();
        const selector = MethodChannel('plugins.flutter.io/file_selector');
        var pickerCalls = 0;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          selector,
          (call) async {
            if (call.method == 'getSavePath') {
              pickerCalls++;
              return failWrite ? target.path : null;
            }
            return null;
          },
        );
        addTearDown(() {
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            selector,
            null,
          );
        });
        await tester.tap(find.byTooltip('Save As'));
        await tester.pumpAndSettle();
        await selectSaveFormat(tester, DocumentFormat.xml);
        await waitForConversion(
          tester,
          find.byKey(const ValueKey('save-as-preview')),
        );
        await tester.pumpAndSettle();
        await tester.tap(saveButton());
        for (var i = 0; i < 10; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
        }
        await tester.pumpAndSettle();
        expect(pickerCalls, 1);
        expect(target.existsSync(), isFalse);
        expect(container.read(workspaceProvider).tabs, hasLength(1));
        expect(container.read(workspaceProvider).active.text, _source);
        expect(container.read(workspaceProvider).active.file, isNull);
        expect(container.read(workspaceProvider).active.dirty, isTrue);
        await tester.tap(find.byTooltip('Save As'));
        await tester.pumpAndSettle();
        expect(find.byType(SaveAsDialog), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
