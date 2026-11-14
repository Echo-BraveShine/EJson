import 'package:desktop_drop/desktop_drop.dart';
import 'package:ejson/main.dart';
import 'package:ejson/settings/installed_fonts.dart';
import 'package:ejson/workspace/local_files.dart';
import 'package:ejson/workspace/workbench.dart';
import 'package:ejson/workspace/workspace.dart';
import 'package:ejson_core/ejson_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/conversion_test_harness.dart';

void main() {
  test('saved native files are inferred when opening or restoring', () async {
    final container = ProviderContainer(
      overrides: [
        initialWorkspaceProvider.overrideWithValue((
          files: const [
            LocalJsonFile('/tmp/a.yaml', 'name: test'),
            LocalJsonFile('/tmp/a.csv', '"a"\n"1"'),
            LocalJsonFile('/tmp/a.xml', '<a/>'),
            LocalJsonFile('/tmp/a.toml', 'a=1'),
          ],
          activePath: '/tmp/a.yaml',
        )),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(workspaceProvider).tabs.map((t) => t.format), [
      DocumentFormat.yaml,
      DocumentFormat.csv,
      DocumentFormat.xml,
      DocumentFormat.toml,
    ]);
  });

  testWidgets('promised YAML file drops retain format and BOM in a new draft', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        installedFontsProvider.overrideWith((ref) async => []),
        localFileReaderProvider.overrideWithValue(
          (path) async => LocalJsonFile(path, 'name: test', bom: true),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const EJsonApp()),
    );
    await tester.pumpAndSettle();
    tester.widget<DropTarget>(find.byType(DropTarget)).onDragDone!(
      DropDoneDetails(
        files: [DropItemFile('/tmp/promised.yaml', fromPromise: true)],
        localPosition: Offset.zero,
        globalPosition: Offset.zero,
      ),
    );
    await tester.pumpAndSettle();
    await waitForConversion(tester, find.text('Valid YAML'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    final tab = container.read(workspaceProvider).active;
    expect(tab.format, DocumentFormat.yaml);
    expect(tab.bom, isTrue);
    expect(tab.file, isNull);
    expect(tab.text, 'name: test');
    expect(tester.takeException(), isNull);
  });
}
