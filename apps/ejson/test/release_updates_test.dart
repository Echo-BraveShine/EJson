import 'package:ejson/settings/release_updates.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pub_semver/pub_semver.dart';

void main() {
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
