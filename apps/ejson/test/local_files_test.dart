import 'dart:io';

import 'package:ejson/workspace/local_files.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory temp;

  setUp(
    () async => temp = await Directory.systemTemp.createTemp('ejson_test_'),
  );
  tearDown(() async => temp.delete(recursive: true));

  String path(String name) => '${temp.path}${Platform.pathSeparator}$name';

  test('round-trips UTF-8 BOM and saves as a different file', () async {
    final original = File(path('original.json'));
    await original.writeAsBytes([0xef, 0xbb, 0xbf, 0x7b, 0x7d]);
    final opened = await LocalJsonFile.read(original.path);
    expect(opened.source, '{}');
    expect(opened.bom, isTrue);
    final saved = await opened.save(
      '{"中":1}\r\n',
      destination: path('new file.json'),
    );
    expect((await LocalJsonFile.read(saved.path)).source, '{"中":1}\r\n');
    expect((await File(saved.path).readAsBytes()).take(3), [0xef, 0xbb, 0xbf]);
    expect((await LocalJsonFile.read(original.path)).source, '{}');
    await saved.save('[]');
    expect((await LocalJsonFile.read(saved.path)).source, '[]');
  });

  test(
    'external edits and deletions preserve the current disk state',
    () async {
      final file = File(path('conflict.json'));
      await file.writeAsString('{}');
      final opened = await LocalJsonFile.read(file.path);
      await file.writeAsString('null');
      await expectLater(
        opened.save('[]'),
        throwsA(isA<FileChangedException>()),
      );
      expect(await file.readAsString(), 'null');
      await file.delete();
      await expectLater(
        opened.save('[]'),
        throwsA(isA<FileChangedException>()),
      );
      expect(await file.exists(), isFalse);
    },
  );

  test('invalid UTF-8 is rejected', () async {
    final file = File(path('invalid.json'));
    await file.writeAsBytes([0xff]);
    await expectLater(LocalJsonFile.read(file.path), throwsFormatException);
  });
}
