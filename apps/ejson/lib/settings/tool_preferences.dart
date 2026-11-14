import 'package:ejson_core/ejson_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'reading_preferences.dart';
import '../workspace/recent_file.dart';

class ToolPreferences {
  const ToolPreferences({
    this.format = const JsonFormatOptions(),
    this.queries = const [],
    this.reading = const ReadingPreferences(),
    this.recentFiles = const [],
  });

  factory ToolPreferences.fromJson(Object? value) {
    if (value is! Map) return const ToolPreferences();
    final indentation =
        JsonIndentation.values
            .where((item) => item.name == value['indentation'])
            .firstOrNull ??
        JsonIndentation.twoSpaces;
    final lineEnding =
        JsonLineEnding.values
            .where((item) => item.name == value['lineEnding'])
            .firstOrNull ??
        JsonLineEnding.preserve;
    final saved = value['queries'];
    final queries = saved is List
        ? saved
              .whereType<String>()
              .map((query) => query.trim())
              .where((query) => query.isNotEmpty)
              .toSet()
              .toList()
        : <String>[];
    final recentFiles = <RecentFile>[];
    final seenPaths = <String>{};
    final savedRecentFiles = value['recentFiles'];
    if (savedRecentFiles is List) {
      for (final entry in savedRecentFiles) {
        final file = RecentFile.fromJson(entry);
        if (file != null && seenPaths.add(file.path)) recentFiles.add(file);
        if (recentFiles.length == maxRecentFiles) break;
      }
    }
    return ToolPreferences(
      recentFiles: List.unmodifiable(recentFiles),
      format: JsonFormatOptions(
        indentation: indentation,
        lineEnding: lineEnding,
      ),
      queries: List.unmodifiable(queries),
      reading: ReadingPreferences.fromJson(value['reading']),
    );
  }

  final JsonFormatOptions format;
  final ReadingPreferences reading;
  final List<String> queries;
  final List<RecentFile> recentFiles;

  ToolPreferences copyWith({
    JsonFormatOptions? format,
    ReadingPreferences? reading,
    List<String>? queries,
    List<RecentFile>? recentFiles,
  }) => ToolPreferences(
    format: format ?? this.format,
    reading: reading ?? this.reading,
    queries: queries ?? this.queries,
    recentFiles: recentFiles ?? this.recentFiles,
  );

  Map<String, Object> toJson() => {
    'indentation': format.indentation.name,
    'lineEnding': format.lineEnding.name,
    'queries': queries,
    'reading': reading.toJson(),
    'recentFiles': [for (final file in recentFiles) file.toJson()],
  };
}

final initialToolPreferencesProvider = Provider<ToolPreferences>(
  (ref) => const ToolPreferences(),
);
final saveToolPreferencesProvider =
    Provider<Future<void> Function(ToolPreferences)>((ref) => (_) async {});
final toolPreferencesProvider =
    NotifierProvider<ToolPreferencesController, ToolPreferences>(
      ToolPreferencesController.new,
    );

class ToolPreferencesController extends Notifier<ToolPreferences> {
  Future<void> _pending = Future.value();

  @override
  ToolPreferences build() => ref.read(initialToolPreferencesProvider);

  Future<void> flush() => _pending;

  Future<bool> _update(ToolPreferences Function(ToolPreferences) change) {
    final task = _pending.then((_) async {
      if (!ref.mounted) return false;
      final next = change(state);
      if (identical(next, state)) return true;
      try {
        await ref.read(saveToolPreferencesProvider)(next);
      } on Exception {
        return false;
      }
      if (!ref.mounted) return false;
      state = next;
      return true;
    });
    _pending = task.then((_) {});
    return task;
  }

  Future<bool> setFormat(JsonFormatOptions format) =>
      _update((current) => current.copyWith(format: format));

  Future<bool> setReading(ReadingPreferences reading) =>
      _update((current) => current.copyWith(reading: reading));

  Future<bool> setQuerySaved(String expression, {required bool saved}) =>
      _update((current) {
        final query = expression.trim();
        if (query.isEmpty || current.queries.contains(query) == saved) {
          return current;
        }
        return current.copyWith(
          queries: List.unmodifiable([
            for (final existing in current.queries)
              if (existing != query) existing,
            if (saved) query,
          ]),
        );
      });

  Future<bool> recordRecentFiles(List<RecentFile> files) => _update((current) {
    if (files.isEmpty) return current;
    final recent = [...current.recentFiles];
    for (final file in files) {
      final previous = recent
          .where((entry) => entry.path == file.path)
          .firstOrNull;
      recent.removeWhere((entry) => entry.path == file.path);
      recent.insert(
        0,
        RecentFile(file.path, bookmark: file.bookmark ?? previous?.bookmark),
      );
    }
    return current.copyWith(
      recentFiles: List.unmodifiable(recent.take(maxRecentFiles)),
    );
  });

  Future<bool> removeRecentFile(String path) => _update(
    (current) => current.copyWith(
      recentFiles: List.unmodifiable(
        current.recentFiles.where((file) => file.path != path),
      ),
    ),
  );

  Future<bool> clearRecentFiles() =>
      _update((current) => current.copyWith(recentFiles: const []));
}
