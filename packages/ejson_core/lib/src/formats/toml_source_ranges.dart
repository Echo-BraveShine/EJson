import 'dart:convert';
import 'package:petitparser/petitparser.dart';
import 'package:toml/toml.dart';
import 'format_structure.dart';

/// Indexes validated TOML without searching for repeated keys or value text.
Map<String, TextRange> tomlSourceRanges(
  String source, {
  List<TextRange>? folds,
}) => _TomlSourceIndexer(source, folds).read();

class _TomlSourceIndexer {
  _TomlSourceIndexer(this.source, this.folds);
  final String source;
  final List<TextRange>? folds;
  final ranges = <String, TextRange>{};
  final latestTables = <String, int>{};
  var position = 0;

  void skipTrivia() {
    while (position < source.length) {
      final char = source[position];
      if (char == '#') {
        while (position < source.length && source[position] != '\n') {
          position++;
        }
      } else if (' \t\r\n'.contains(char)) {
        position++;
      } else {
        break;
      }
    }
  }

  T parse<T>(Parser<T> parser) {
    final result = parser.parseOn(Context(source, position));
    position = result.position;
    return result.value;
  }

  void record(List<Object> path, TextRange range) {
    for (var i = 1; i <= path.length; i++) {
      final key = jsonEncode(path.take(i).toList());
      final previous = ranges[key];
      ranges[key] = previous == null
          ? range
          : (
              start: previous.start < range.start
                  ? previous.start
                  : range.start,
              end: previous.end > range.end ? previous.end : range.end,
            );
    }
  }

  Map<String, TextRange> read() {
    var table = <Object>[];
    int? sectionStart;
    var sectionEnd = 0;
    skipTrivia();
    while (position < source.length) {
      if (source[position] == '[') {
        final start = position;
        if (sectionStart != null) {
          folds?.add((start: sectionStart, end: sectionEnd));
        }
        sectionStart = start;
        final header = parse(TomlTable.parser);
        final path = <Object>[];
        for (var i = 0; i < header.name.parts.length; i++) {
          path.add(header.name.parts[i].name);
          final key = jsonEncode(path);
          if (header is TomlArrayTable && i == header.name.parts.length - 1) {
            latestTables[key] = (latestTables[key] ?? -1) + 1;
          }
          if (latestTables[key] case final index?) path.add(index);
        }
        table = path;
        record(path, (start: start, end: position));
      } else {
        readPair(table);
      }
      sectionEnd = position;
      skipTrivia();
    }
    if (sectionStart != null) {
      folds?.add((start: sectionStart, end: sectionEnd));
    }
    ranges[jsonEncode(<Object>[])] = (start: 0, end: source.length);
    return ranges;
  }

  void readPair(List<Object> parent) {
    final start = position;
    final key = parse(TomlKey.parser);
    final path = <Object>[...parent, for (final part in key.parts) part.name];
    skipTrivia();
    position++; // The validated key/value separator.
    skipTrivia();
    readValue(path);
    // Implicit tables and enclosing tables cover their complete assignments.
    if (path.length > 1) {
      record(path.sublist(0, path.length - 1), (start: start, end: position));
    }
  }

  void readValue(List<Object> path) {
    final start = position;
    final char = source[position];
    if (char == '[') {
      position++;
      skipTrivia();
      var index = 0;
      while (source[position] != ']') {
        readValue([...path, index++]);
        skipTrivia();
        if (source[position] == ',') position++;
        skipTrivia();
      }
      position++;
    } else if (char == '{') {
      position++;
      skipTrivia();
      while (source[position] != '}') {
        readPair(path);
        skipTrivia();
        if (source[position] == ',') position++;
        skipTrivia();
      }
      position++;
    } else {
      parse(TomlValue.parser);
    }
    if (char == '[' || char == '"' || char == "'") {
      folds?.add((start: start, end: position));
    }
    record(path, (start: start, end: position));
  }
}
