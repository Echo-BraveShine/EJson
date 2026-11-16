import 'dart:async';
import 'dart:io';

import 'package:ejson/main.dart';
import 'package:ejson/settings/release_updates.dart';
import 'package:ejson/workspace/workbench.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pub_semver/pub_semver.dart';

void main() {
  for (final status in [...UpdateStatus.values, null]) {
    testWidgets('startup update check handles $status', (tester) async {
      final result = Completer<UpdateResult>();
      var checks = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            startupUpdateCheckProvider.overrideWithValue(() {
              checks++;
              return result.future;
            }),
          ],
          child: const EJsonApp(initialLanguage: 'en'),
        ),
      );
      await tester.pumpAndSettle();
      expect(checks, 1);
      expect(find.text('Source'), findsOneWidget);
      expect(find.text('View release'), findsNothing);

      if (status == null) {
        result.completeError(const SocketException('Offline'));
      } else {
        result.complete((
          status: status,
          latest: status == UpdateStatus.noRelease ? null : Version(2, 0, 0),
        ));
      }
      await tester.pumpAndSettle();
      final expected = status == UpdateStatus.available
          ? findsOneWidget
          : findsNothing;
      expect(find.text('Version 2.0.0 is available.'), expected);
      expect(find.text('View release'), expected);
      expect(checks, 1);
    });
  }

  test(
    'compares GitHub tags by version and ignores installed build numbers',
    () {
      final installed = Version.parse('0.9.0+47');
      expect(
        compareRelease(installed, 'v0.10.0').status,
        UpdateStatus.available,
      );
      expect(compareRelease(installed, 'v0.9.0').status, UpdateStatus.current);
      expect(compareRelease(installed, '0.8.1').status, UpdateStatus.current);
      expect(
        compareRelease(Version.parse('1.0.0-beta.1'), 'v1.0.0').status,
        UpdateStatus.available,
      );
      expect(() => compareRelease(installed, 'latest'), throwsFormatException);
    },
  );
}
