import 'package:ejson/main.dart';
import 'package:ejson/settings/installed_fonts.dart';
import 'package:ejson/workspace/workbench.dart';
import 'package:ejson/workspace/workspace.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:window_manager/window_manager.dart';

void main() {
  testWidgets(
    'Windows hides the approved window before engine teardown and preserves cancel',
    (tester) async {
      const window = MethodChannel('window_manager');
      final calls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(window, (
        call,
      ) async {
        calls.add(call.method);
        return null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          window,
          null,
        ),
      );
      final container = ProviderContainer(
        overrides: [installedFontsProvider.overrideWith((_) async => [])],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const EJsonApp(initialLanguage: 'en'),
        ),
      );
      await tester.pumpAndSettle();
      container
          .read(workspaceProvider.notifier)
          .editSource(1, '{"changed":true}');
      await tester.pumpAndSettle();
      final listener = tester.state(find.byType(Workbench)) as WindowListener;
      listener.onWindowClose();
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      listener.onWindowClose();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(calls, ['hide', 'destroy']);
      listener.onWindowClose();
      await tester.pumpAndSettle();
      expect(calls, ['hide', 'destroy']);
    },
    variant: TargetPlatformVariant({TargetPlatform.windows}),
  );
}
