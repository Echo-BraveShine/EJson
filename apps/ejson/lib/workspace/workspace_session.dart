import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'local_files.dart';
import 'workspace.dart';

class RestoredWorkspace {
  const RestoredWorkspace({
    this.files = const [],
    this.activePath,
    this.failedPaths = const [],
  });

  final List<LocalJsonFile> files;
  final String? activePath;
  final List<String> failedPaths;
}

/// Stores file references and tab selection. Document contents stay on disk.
class WorkspaceSession {
  WorkspaceSession(this._preferences);

  static const _enabledKey = 'restoreWorkspaceOnStartup';
  static const _sessionKey = 'lastWorkspace';
  static const _files = MethodChannel('dev.ekko.ejson/files');

  final SharedPreferencesAsync _preferences;
  final _accessedPaths = <String>{};

  Future<bool> isEnabled() async =>
      await _preferences.getBool(_enabledKey) ?? true;

  Future<void> setEnabled(bool enabled) =>
      _preferences.setBool(_enabledKey, enabled);

  Future<void> remember(Workspace workspace, {required bool enabled}) async {
    if (!enabled) {
      await _preferences.remove(_sessionKey);
      return;
    }

    final entries = <Map<String, String>>[];
    for (final tab in workspace.tabs) {
      final path = tab.file?.path;
      if (path == null) continue;
      final entry = {'path': path};
      if (Platform.isMacOS) {
        try {
          final bookmark = await _files.invokeMethod<String>(
            'createBookmark',
            path,
          );
          if (bookmark != null) entry['bookmark'] = bookmark;
        } on PlatformException {
          // The path remains usable for files the app can already access.
        }
      }
      entries.add(entry);
    }

    await _preferences.setString(
      _sessionKey,
      jsonEncode({'files': entries, 'activePath': workspace.active.file?.path}),
    );
  }

  Future<RestoredWorkspace> restore() async {
    final raw = await _preferences.getString(_sessionKey);
    if (raw == null) return const RestoredWorkspace();

    final Object? data;
    try {
      data = jsonDecode(raw);
    } on FormatException {
      return const RestoredWorkspace();
    }
    if (data is! Map<String, dynamic> || data['files'] is! List) {
      return const RestoredWorkspace();
    }

    final files = <LocalJsonFile>[];
    final failedPaths = <String>[];
    final seen = <String>{};
    final savedActivePath = data['activePath'];
    String? activePath;
    for (final entry in data['files'] as List) {
      if (entry is! Map<String, dynamic> || entry['path'] is! String) continue;
      final path = entry['path'] as String;
      if (path.isEmpty || !seen.add(path)) continue;

      try {
        final bookmark = entry['bookmark'];
        if (Platform.isMacOS && bookmark is String) {
          final opened = await _files.invokeMethod<bool>('accessBookmark', {
            'path': path,
            'bookmark': bookmark,
          });
          if (opened == true) _accessedPaths.add(path);
        }
        final file = await LocalJsonFile.read(path);
        if (file.path != path) {
          // The saved tab refers to the original location.
          await releaseAccess(path);
          failedPaths.add(path);
          continue;
        }
        files.add(file);
        if (path == savedActivePath) activePath = file.path;
      } on Exception {
        await releaseAccess(path);
        failedPaths.add(path);
      }
    }

    return RestoredWorkspace(
      files: files,
      activePath: activePath,
      failedPaths: failedPaths,
    );
  }

  Future<void> releaseAccess(String path) async {
    if (!_accessedPaths.remove(path)) return;
    try {
      await _files.invokeMethod<void>('releaseBookmark', path);
    } on PlatformException {
      // The native runner also releases retained access on termination.
    }
  }
}
