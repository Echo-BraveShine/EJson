import 'dart:async';
import 'package:ejson/main.dart';
import 'package:ejson/settings/installed_fonts.dart';
import 'package:ejson/settings/tool_preferences.dart';
import 'package:ejson/workspace/external_file_opens.dart';
import 'package:ejson/workspace/local_files.dart';
import 'package:ejson/workspace/recent_file.dart';
import 'package:ejson/workspace/workbench.dart';
import 'package:ejson/workspace/workspace.dart';
import 'package:ejson_core/ejson_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.ekko.ejson/open-files');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  Future<void> send(List<Object?> files) async {
    final reply = Completer<void>();
    ServicesBinding.instance.channelBuffers.push(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(MethodCall('open', files)),
      (_) => reply.complete(),
    );
    await reply.future;
  }

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'buffers arguments and native startup requests before subscription',
    () async {
      final requests = ExternalFileOpens([
        '-psn_1',
        '',
        '/path with spaces/中文.json',
        'file:///tmp/a%20b.json',
      ]);
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => [
          {'path': '/startup.json', 'bookmark': 'grant'},
          null,
          {'path': 4},
        ],
      );
      await requests.connectMacOS();
      final batches = <List<RecentFile>>[];
      final subscription = requests.requests.listen(batches.add);
      await send([
        {'path': '/running.json'},
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(batches.expand((b) => b).map((f) => f.path), [
        '/path with spaces/中文.json',
        '/tmp/a b.json',
        '/startup.json',
        '/running.json',
      ]);
      expect(batches[1].single.bookmark, 'grant');
      await subscription.cancel();
      await requests.dispose();
    },
  );

  testWidgets(
    'external opens wait for dialogs, preserve dirty tabs and record recents',
    (tester) async {
      final requests = ExternalFileOpens(['/first.json']);
      messenger.setMockMethodCallHandler(channel, (_) async => []);
      await requests.connectMacOS();
      final reads = <String>[];
      final container = ProviderContainer(
        overrides: [
          externalFileOpensProvider.overrideWithValue(requests),
          installedFontsProvider.overrideWith((ref) async => []),
          parseDocumentProvider.overrideWithValue(
            (source, revision) async => parseJson(source, revision: revision),
          ),
          localFileReaderProvider.overrideWithValue((path) async {
            reads.add(path);
            return LocalJsonFile(path, '{}');
          }),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const EJsonApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        container.read(workspaceProvider).active.file?.path,
        '/first.json',
      );
      final first = container.read(workspaceProvider).activeId;
      container
          .read(workspaceProvider.notifier)
          .editSource(first, '{"dirty":true}');
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      await send([
        {'path': '/second.json'},
        {'path': '/first.json'},
      ]);
      await tester.pump(const Duration(milliseconds: 250));
      expect(reads, ['/first.json']);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      expect(reads, ['/first.json', '/second.json']);
      expect(container.read(workspaceProvider).active.id, first);
      expect(container.read(workspaceProvider).active.text, '{"dirty":true}');
      expect(
        container.read(toolPreferencesProvider).recentFiles.map((f) => f.path),
        ['/first.json', '/second.json'],
      );
      await tester.pumpWidget(const SizedBox());
      container.dispose();
      await tester.runAsync(requests.dispose);
      expect(tester.takeException(), isNull);
    },
  );
}
