import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'recent_file.dart';

final externalFileOpensProvider = Provider<ExternalFileOpens?>((ref) => null);

/// Buffers operating-system open requests until the workbench can handle them.
class ExternalFileOpens {
  ExternalFileOpens(List<String> arguments) {
    final files = <RecentFile>[];
    for (final argument in arguments) {
      if (argument.isEmpty || argument.startsWith('-')) continue;
      final uri = Uri.tryParse(argument);
      final path = uri?.scheme == 'file'
          ? uri!.toFilePath(windows: Platform.isWindows)
          : argument;
      files.add(RecentFile(path));
    }
    if (files.isNotEmpty) _requests.add(files);
  }

  static const _channel = MethodChannel('dev.ekko.ejson/open-files');
  final _requests = StreamController<List<RecentFile>>();
  Stream<List<RecentFile>> get requests => _requests.stream;

  void _receive(Object? value) {
    if (value is! List) return;
    final files = value
        .map(RecentFile.fromJson)
        .whereType<RecentFile>()
        .toList();
    if (files.isNotEmpty) _requests.add(files);
  }

  Future<void> connectMacOS() async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'open') _receive(call.arguments);
    });
    _receive(await _channel.invokeMethod<Object?>('ready'));
  }

  Future<void> dispose() async {
    _channel.setMethodCallHandler(null);
    await _requests.close();
  }
}
