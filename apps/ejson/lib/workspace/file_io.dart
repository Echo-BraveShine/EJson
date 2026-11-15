import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local_files.dart';

final localFileReaderProvider =
    Provider<Future<LocalJsonFile> Function(String)>(
      (ref) => LocalJsonFile.read,
    );

final workspaceAtomicWriterProvider =
    Provider<Future<void> Function(String, Uint8List)?>(
      (ref) => Platform.isMacOS
          ? (path, bytes) => const MethodChannel(
              'dev.ekko.ejson/files',
            ).invokeMethod<void>('atomicWrite', {'path': path, 'bytes': bytes})
          : null,
    );

final fileOperationQueueProvider = Provider((ref) => FileOperationQueue());

class FileOperationQueue {
  Future<void> _pending = Future.value();

  Future<T> run<T>(Future<T> Function() operation) {
    final task = _pending.then((_) => operation());
    _pending = task.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return task;
  }
}
