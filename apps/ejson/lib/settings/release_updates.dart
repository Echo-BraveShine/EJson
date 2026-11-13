import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:pub_semver/pub_semver.dart';

final latestReleasePage = Uri.https(
  'github.com',
  '/Echo-BraveShine/EJson/releases/latest',
);
final supportPage = Uri.https('buymeacoffee.com', '/1239383708p');

enum UpdateStatus { noRelease, current, available }

typedef UpdateResult = ({UpdateStatus status, Version? latest});

Future<Version> installedVersion() async {
  final info = await PackageInfo.fromPlatform();
  return Version.parse(info.version);
}

Future<UpdateResult> checkForUpdate(Version installed) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
  const timeout = Duration(seconds: 12);
  try {
    final request = await client
        .getUrl(
          Uri.https(
            'api.github.com',
            '/repos/Echo-BraveShine/EJson/releases/latest',
          ),
        )
        .timeout(timeout);
    request.headers.set(
      HttpHeaders.acceptHeader,
      'application/vnd.github+json',
    );
    request.headers.set(HttpHeaders.userAgentHeader, 'EJson');
    final response = await request.close().timeout(timeout);
    if (response.statusCode == HttpStatus.notFound) {
      return (status: UpdateStatus.noRelease, latest: null);
    }
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('GitHub returned ${response.statusCode}');
    }
    final body = await response.transform(utf8.decoder).join().timeout(timeout);
    final data = jsonDecode(body);
    if (data is! Map<String, dynamic> || data['tag_name'] is! String) {
      throw const FormatException('Missing release tag');
    }
    return compareRelease(installed, data['tag_name'] as String);
  } finally {
    client.close(force: true);
  }
}

UpdateResult compareRelease(Version installed, String tag) {
  final latest = Version.parse(tag.startsWith('v') ? tag.substring(1) : tag);
  // GitHub publishes one release per public version, independent of build numbers.
  final baseline = Version(
    installed.major,
    installed.minor,
    installed.patch,
    pre: installed.preRelease.join('.').isEmpty
        ? null
        : installed.preRelease.join('.'),
  );
  return (
    status: latest > baseline ? UpdateStatus.available : UpdateStatus.current,
    latest: latest,
  );
}
