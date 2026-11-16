import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

enum RevealFileResult { opened, openedOriginalFolder, folderMissing, failed }

final revealFileProvider = Provider<Future<RevealFileResult> Function(String)>(
  (ref) => revealFileInFolder,
);

Future<RevealFileResult> revealFileInFolder(
  String path, {
  Future<bool> Function(String) selectFile = _selectFile,
  Future<bool> Function(Uri) openFolder = _openFolder,
}) async {
  final file = File(path);
  final parent = file.parent;
  final exists = await file.exists();
  if (exists && await _tryOpen(() => selectFile(path))) {
    return RevealFileResult.opened;
  }
  if (!await parent.exists()) return RevealFileResult.folderMissing;
  if (!await _tryOpen(() => openFolder(parent.uri))) {
    return RevealFileResult.failed;
  }
  return exists
      ? RevealFileResult.opened
      : RevealFileResult.openedOriginalFolder;
}

Future<bool> _tryOpen(Future<bool> Function() open) async {
  try {
    return await open();
  } on Exception {
    return false;
  }
}

Future<bool> _openFolder(Uri folder) =>
    launchUrl(folder, mode: LaunchMode.externalApplication);

Future<bool> _selectFile(String path) async {
  if (Platform.isMacOS || Platform.isWindows) {
    return await const MethodChannel(
          'dev.ekko.ejson/files',
        ).invokeMethod<bool>('revealFile', path) ??
        false;
  }
  if (!Platform.isLinux) return false;
  final result = await Process.run('gdbus', [
    'call',
    '--session',
    '--timeout',
    '3',
    '--dest',
    'org.freedesktop.FileManager1',
    '--object-path',
    '/org/freedesktop/FileManager1',
    '--method',
    'org.freedesktop.FileManager1.ShowItems',
    jsonEncode([Uri.file(path).toString()]),
    '',
  ]);
  return result.exitCode == 0;
}
