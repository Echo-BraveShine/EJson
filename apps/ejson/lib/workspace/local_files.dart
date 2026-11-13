import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

const maxFileBytes = 16 * 1024 * 1024;

class LocalJsonFile {
  const LocalJsonFile(this.path, this.source, {this.bom = false});

  final String path;
  final String source;
  final bool bom;

  static Future<LocalJsonFile> read(String path) async {
    final file = File(await File(path).resolveSymbolicLinks());
    if (await file.length() > maxFileBytes) {
      throw LocalFileException(LocalFileError.openLimit, path);
    }
    final bytes = await file.openRead().fold<List<int>>([], (bytes, chunk) {
      if (bytes.length + chunk.length > maxFileBytes) {
        throw LocalFileException(LocalFileError.openLimit, path);
      }
      return bytes..addAll(chunk);
    });
    final hasBom =
        bytes.length >= 3 &&
        bytes[0] == 0xef &&
        bytes[1] == 0xbb &&
        bytes[2] == 0xbf;
    final text = utf8.decode(bytes);
    return LocalJsonFile(file.path, text, bom: hasBom);
  }

  /// Writes to a temporary file on the same volume and checks the original
  /// again immediately before replacing it.
  Future<LocalJsonFile> save(
    String text, {
    String? destination,
    Future<void> Function(String, Uint8List)? writeAtomically,
  }) async {
    final requested = File(destination ?? path);
    final parent = Directory(await requested.parent.resolveSymbolicLinks());
    final exists = await requested.exists();
    final target = exists
        ? File(await requested.resolveSymbolicLinks())
        : File(
            '${parent.path}${Platform.pathSeparator}${requested.uri.pathSegments.last}',
          );
    final baseline = destination == null
        ? this
        : (exists ? await read(target.path) : null);
    final bytes = utf8.encode(bom ? '\uFEFF$text' : text);
    if (bytes.length > maxFileBytes) {
      throw LocalFileException(LocalFileError.saveLimit, target.path);
    }
    Future<void> verifyBaseline() async {
      if (baseline == null) {
        if (await target.exists()) throw FileChangedException(target.path);
      } else {
        if (!await target.exists()) throw FileChangedException(target.path);
        final current = await read(target.path);
        if (current.path != baseline.path ||
            current.source != baseline.source ||
            current.bom != baseline.bom) {
          throw FileChangedException(target.path);
        }
      }
    }

    // Foundation can atomically replace a user-selected macOS file within
    // App Sandbox. The native picker does not grant sibling directory access.
    if (writeAtomically != null) {
      await verifyBaseline();
      await writeAtomically(target.path, Uint8List.fromList(bytes));
      return LocalJsonFile(target.path, text, bom: bom);
    }

    final temp = await target.parent.createTemp('.ejson-');
    try {
      final staged = File('${temp.path}${Platform.pathSeparator}document');
      await staged.writeAsBytes(bytes, flush: true);
      if (baseline != null && !Platform.isWindows && await target.exists()) {
        final mode = (await target.stat()).mode & 0x1ff;
        final result = await Process.run('chmod', [
          mode.toRadixString(8),
          staged.path,
        ]);
        if (result.exitCode != 0) {
          throw LocalFileException(LocalFileError.permissions, target.path);
        }
      }
      await verifyBaseline();
      await staged.rename(target.path);
      return LocalJsonFile(target.path, text, bom: bom);
    } finally {
      try {
        await temp.delete(recursive: true);
      } on FileSystemException {
        // Cleanup must not mask the outcome of the save.
      }
    }
  }
}

class FileChangedException implements Exception {
  FileChangedException(this.path);
  final String path;
  @override
  String toString() =>
      'The file changed on disk. Use Save As to keep your edits.\n$path';
}

enum LocalFileError { openLimit, saveLimit, permissions }

class LocalFileException implements Exception {
  const LocalFileException(this.reason, this.path);

  final LocalFileError reason;
  final String path;
}
