import 'dart:isolate';

import 'package:ejson_core/ejson_core.dart';

enum JsonLinesFilter { all, valid, invalid }

typedef JsonLinesSelection = ({List<JsonLineRecord> records, bool allValid});

Future<bool> _matchesLongRecord(String source, String query) =>
    Isolate.run(() => source.toLowerCase().contains(query));

/// Yields between batches so large datasets can be searched without copying
/// the entire record graph to another isolate.
Future<JsonLinesSelection?> filterJsonLines(
  JsonLinesData data,
  String text,
  JsonLinesFilter filter, {
  required bool Function() cancelled,
}) async {
  final query = text.toLowerCase();
  if (query.isEmpty && filter == JsonLinesFilter.all) {
    return (records: data.records, allValid: data.invalidCount == 0);
  }
  const unitBudget = 128 * 1024;
  final matches = <JsonLineRecord>[];
  var allValid = true;
  var units = 0;
  var count = 0;
  for (final record in data.records) {
    final valid = record.isValid;
    if (filter == JsonLinesFilter.all ||
        valid == (filter == JsonLinesFilter.valid)) {
      final source = record.source;
      var matched = query.isEmpty;
      if (!matched && source.length > unitBudget) {
        matched = await _matchesLongRecord(source, query);
        if (cancelled()) return null;
      } else if (!matched) {
        matched = source.toLowerCase().contains(query);
      }
      if (matched) {
        matches.add(record);
        allValid = allValid && valid;
      }
      units += source.length;
    }
    if (++count >= 1024 || units >= unitBudget) {
      await Future<void>(() {});
      if (cancelled()) return null;
      units = 0;
      count = 0;
    }
  }
  return cancelled() ? null : (records: matches, allValid: allValid);
}
