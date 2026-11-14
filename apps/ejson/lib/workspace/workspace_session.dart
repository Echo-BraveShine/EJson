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
  final _accessedPaths = <String, String>{};

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
      final bookmark = await bookmarkFor(path);
      if (bookmark != null) entry['bookmark'] = bookmark;
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
        if (bookmark is String) await accessFile(path, bookmark);
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

  Future<String?> bookmarkFor(String path) async {
    if (!Platform.isMacOS) return null;
    try {
      return await _files.invokeMethod<String>('createBookmark', path);
    } on PlatformException {
      return null;
    }
  }

  /// Returns true only for newly acquired access, for cleanup on failed opens.
  Future<bool> accessFile(String path, String? bookmark) async {
    if (!Platform.isMacOS ||
        bookmark == null ||
        _accessedPaths.containsKey(path) ||
        _accessedPaths.containsValue(path)) {
      return false;
    }
    final accessed = await _files.invokeMethod<bool>('accessBookmark', {
      'path': path,
      'bookmark': bookmark,
    });
    if (accessed != true) return false;
    _accessedPaths[path] = path;
    return true;
  }

  void trackAccess(String requestedPath, String canonicalPath) {
    if (requestedPath == canonicalPath) return;
    final grant = _accessedPaths.remove(requestedPath);
    if (grant != null) _accessedPaths[canonicalPath] = grant;
  }

  Future<void> releaseAccess(String path) async {
    final grantedPath = _accessedPaths.remove(path);
    if (grantedPath == null) return;
    try {
      await _files.invokeMethod<void>('releaseBookmark', grantedPath);
    } on PlatformException {
      // The native runner also releases retained access on termination.
    }
  }
}
