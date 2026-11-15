import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('both Windows installers offer all supported extensions', () {
    for (final installer in ['ejson.iss', 'ejson.wxs']) {
      final text = File('windows/installer/$installer').readAsStringSync();
      for (final extension in [
        'json',
        'jsonl',
        'ndjson',
        'yaml',
        'yml',
        'toml',
        'csv',
        'xml',
      ]) {
        expect(
          text,
          contains('.$extension\\OpenWithProgids'),
          reason: installer,
        );
      }
      expect(text, contains('%1'));
    }
  });

  test('macOS advertises system UTIs for structured documents', () {
    final text = File('macos/Runner/Info.plist').readAsStringSync();
    for (final type in [
      'public.json',
      'public.yaml',
      'public.toml',
      'public.xml',
      'public.comma-separated-values-text',
    ]) {
      expect(text, contains('<string>$type</string>'));
    }
    for (final extension in [
      'json',
      'jsonl',
      'ndjson',
      'yaml',
      'yml',
      'toml',
      'csv',
      'xml',
    ]) {
      expect(text, contains('<string>$extension</string>'));
    }
  });

  test('Linux ships MIME definitions and package installation hooks', () {
    final desktop = File('linux/dev.ekko.ejson.desktop').readAsStringSync();
    expect(desktop, contains('Exec=ejson %F'));
    for (final type in [
      'application/json',
      'application/x-ndjson',
      'application/yaml',
      'application/toml',
      'text/csv',
      'application/xml',
    ]) {
      expect(desktop, contains('$type;'));
    }
    final mime = File('linux/dev.ekko.ejson.xml').readAsStringSync();
    for (final extension in ['jsonl', 'ndjson', 'yaml', 'yml', 'toml']) {
      expect(mime, contains('pattern="*.$extension"'));
    }
    final cmake = File('linux/CMakeLists.txt').readAsStringSync();
    expect(cmake, contains('share/mime/packages'));
    for (final hook in ['postinst', 'postrm']) {
      final text = File('linux/packaging/$hook').readAsStringSync();
      expect(text, contains('update-mime-database /usr/share/mime'));
      expect(text, contains('update-desktop-database /usr/share/applications'));
    }
  });
}
