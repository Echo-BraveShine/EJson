// Run on macOS with flutter run -d macos --profile -t tool/performance.dart.
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show FrameTiming;

import 'package:ejson/editor/json_highlight.dart';
import 'package:ejson/editor/json_lines_view.dart';
import 'package:ejson/main.dart';
import 'package:ejson/settings/installed_fonts.dart';
import 'package:ejson/workspace/local_files.dart';
import 'package:ejson/workspace/workspace.dart';
import 'package:ejson/workspace/workspace_recovery.dart';
import 'package:ejson_core/ejson_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:re_editor/re_editor.dart';

const _record = '{"id":1,"name":"Alpha","ok":true}';

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer(
    overrides: [installedFontsProvider.overrideWith((ref) async => [])],
  );
  final directory = await Directory.systemTemp.createTemp('ejson-performance-');
  var status = 0;
  try {
    runApp(
      UncontrolledProviderScope(
        container: container,
        child: const EJsonApp(
          initialLanguage: 'en',
          initialHighlight: JsonHighlight.monochrome,
        ),
      ),
    );
    await binding.waitUntilFirstFrameRasterized.timeout(
      const Duration(seconds: 30),
    );
    if (const bool.fromEnvironment('EJSON_REVEAL_BENCHMARK')) {
      await _benchmarkTreeReveal(container);
    } else {
      await _benchmarkWorkspace(container, directory);
    }
  } on Object catch (error, stack) {
    stderr.writeln('$error\n$stack');
    status = 1;
  } finally {
    container.dispose();
    await directory.delete(recursive: true);
  }
  exit(status);
}

Future<void> _benchmarkWorkspace(
  ProviderContainer container,
  Directory directory,
) async {
  final binding = WidgetsBinding.instance;
  final workspace = container.read(workspaceProvider.notifier);
  final emptyTab = container.read(workspaceProvider).activeId;
  final source = '[\n${List.filled(57000, _record).join(',\n')}\n]';
  workspace.newTabWithSource(source);
  await _until(() => container.read(workspaceProvider).active.document.isValid);
  final editor = _find<CodeEditor>()!.controller!;
  const targetLine = 28000;
  const selection = CodeLineSelection(
    baseIndex: targetLine,
    baseOffset: 6,
    extentIndex: targetLine,
    extentOffset: 7,
  );
  final input = <int>[];
  await _measure('single-character edit (1.995 MB JSON)', () async {
    for (var i = 0; i < 24; i++) {
      final timer = Stopwatch()..start();
      editor.replaceSelection(i.isEven ? '2' : '1', selection);
      input.add(timer.elapsedMicroseconds);
      await binding.endOfFrame;
    }
  });
  _report('synchronous editor callback', input);
  await _until(() => container.read(workspaceProvider).active.document.isValid);
  if (container.read(workspaceProvider).active.text != source) {
    throw StateError('Edit fixture did not return to its original contents.');
  }

  var treeIndex = 0;
  await _measure('select visible tree rows (10,000 rows)', () async {
    for (var i = 0; i < 24; i++) {
      // The first children have the same shape and stay in the viewport.
      _tapTreeRow(treeIndex);
      treeIndex = 1 - treeIndex;
      await binding.endOfFrame;
    }
  });

  final recovery = WorkspaceRecovery(directory);
  final baseline = '[\n${List.filled(25000, _record).join(',\n')}\n]';
  final changed = baseline.replaceFirst('Alpha', 'Gamma');
  final snapshot = Workspace([
    for (var id = 1; id <= 4; id++)
      WorkspaceTab(
        id,
        JsonDocument(SourceBuffer(changed)),
        file: LocalJsonFile('${directory.path}/tab-$id.json', baseline),
      ),
  ], 4);
  await recovery.save(snapshot);
  final save = <int>[];
  await _measure('draft save (four 0.875 MB modified files)', () async {
    for (var i = 0; i < 6; i++) {
      final timer = Stopwatch()..start();
      await recovery.save(snapshot);
      save.add(timer.elapsedMicroseconds);
      await Future<void>.delayed(const Duration(milliseconds: 35));
    }
  });
  _report('draft save completion', save);
  await recovery.close();

  final logs = StringBuffer();
  for (var i = 0; i < 125000; i++) {
    logs.write('{"name":"Alpha","id":1}\n{"name":"Bravo","id":2}\n');
  }
  workspace.newTabWithSource(logs.toString(), format: DocumentFormat.jsonLines);
  await _until(() => _find<JsonLinesView>() != null);
  final search = _find<TextField>(
    from: _elementWithKey(const ValueKey('json-lines-search')),
  )!;
  final filter = <int>[];
  await _measure('JSON Lines search (250,000 records, 6 MB)', () async {
    for (var i = 0; i < 8; i++) {
      final query = i.isEven ? 'alpha' : 'missing';
      final expected = i.isEven ? '125000 / 250000' : '0 / 250000';
      final timer = Stopwatch()..start();
      search.controller!.text = query;
      search.onChanged!(query);
      await _until(
        () =>
            _find<Text>(
              where: (text) => text.data?.startsWith(expected) ?? false,
            ) !=
            null,
      );
      filter.add(timer.elapsedMicroseconds);
    }
  });
  _report('filter completion including 150 ms debounce', filter);

  workspace.activate(emptyTab);
  await binding.endOfFrame;
  // Include the first mount, then leave and re-enter the large document.
  final large = '["${'x' * 3000000}"]';
  await _measure('mount read-only preview (3 MB single-line JSON)', () async {
    workspace.newTabWithSource(large);
    final largeTab = container.read(workspaceProvider).activeId;
    await binding.endOfFrame;
    for (var i = 0; i < 6; i++) {
      workspace.activate(emptyTab);
      await binding.endOfFrame;
      workspace.activate(largeTab);
      await binding.endOfFrame;
    }
  });
}

Future<void> _benchmarkTreeReveal(ProviderContainer container) async {
  final binding = WidgetsBinding.instance;
  final workspace = container.read(workspaceProvider.notifier);
  final padding = List.filled(18000, _record).join(',\r\n');
  workspace.newTabWithSource(
    '{\r\n"first": 101,\r\n"nearby": 202,\r\n"padding": [\r\n$padding'
    '\r\n],\r\n"last": 404\r\n}',
  );
  await _until(
    () => _elementWithKey(const ValueKey('tree-row:root/3')) != null,
  );
  final editor = _find<CodeEditor>()!;
  final controller = editor.controller!;
  final positions = <int>[1, 2, 3, 18005];
  final expected = ['101', '202', '', '404'];
  final scroller = editor.scrollController!.verticalScroller;

  Future<void> reveal(int index) async {
    _tapTreeRow(index);
    await binding.endOfFrame;
    await binding.endOfFrame;
    if (controller.selectedText != expected[index] ||
        controller.selection.baseIndex != positions[index] ||
        (scroller.offset > 1000) != (index == 3)) {
      throw StateError(
        'Source selection or scroll position is wrong for row $index.',
      );
    }
  }

  await _measure('first source selection', () => reveal(0));
  await _measure('repeat source selection within viewport', () async {
    for (var i = 0; i < 16; i++) {
      await reveal(i.isEven ? 1 : 0);
    }
  });
  await _measure('tree selection jumps roughly 18,000 source lines', () async {
    for (var i = 0; i < 8; i++) {
      await reveal(3);
      await reveal(0);
    }
  });
}

void _tapTreeRow(int index) {
  final row = _elementWithKey(ValueKey('tree-row:root/$index'))!;
  InkWell? ink;
  row.visitAncestorElements((element) {
    if (element.widget case final InkWell item) ink = item;
    return ink == null;
  });
  ink!.onTap!();
}

Future<void> _measure(String label, Future<void> Function() scenario) async {
  final binding = WidgetsBinding.instance;
  await Future<void>.delayed(const Duration(milliseconds: 250));
  final frames = <FrameTiming>[];
  void collect(List<FrameTiming> batch) => frames.addAll(batch);
  binding.addTimingsCallback(collect);
  final turns = <int>[];
  final clock = Stopwatch()..start();
  var previous = clock.elapsedMicroseconds;
  final probe = Timer.periodic(const Duration(milliseconds: 4), (_) {
    final now = clock.elapsedMicroseconds;
    turns.add(now - previous);
    previous = now;
  });
  try {
    await scenario().timeout(const Duration(minutes: 1));
  } finally {
    // Let an overdue timer fire after any synchronous work in the final step.
    await Future<void>.delayed(const Duration(milliseconds: 10));
    probe.cancel();
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    binding.removeTimingsCallback(collect);
  }
  stdout.writeln(label);
  _report(
    'UI frame build',
    frames.map((frame) => frame.buildDuration.inMicroseconds),
  );
  _report('raster', frames.map((frame) => frame.rasterDuration.inMicroseconds));
  _report('4 ms UI timer interval', turns);
}

void _report(String label, Iterable<int> samples) {
  final sorted = samples.toList()..sort();
  if (sorted.isEmpty) return;
  String percentile(double value) =>
      (sorted[math.max(0, (sorted.length * value).ceil() - 1)] / 1000)
          .toStringAsFixed(2);
  stdout.writeln(
    '  $label ms (n=${sorted.length}) p50=${percentile(.50)} '
    'p95=${percentile(.95)} max=${percentile(1)}',
  );
}

Future<void> _until(bool Function() condition) async {
  final timer = Stopwatch()..start();
  while (!condition()) {
    if (timer.elapsed > const Duration(seconds: 20)) {
      throw TimeoutException('Performance fixture did not become ready.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 8));
  }
}

Element? _elementWithKey(Key key) =>
    _walk(WidgetsBinding.instance.rootElement, (widget) => widget.key == key);

T? _find<T extends Widget>({Element? from, bool Function(T)? where}) =>
    _walk(
          from ?? WidgetsBinding.instance.rootElement,
          (widget) => widget is T && (where == null || where(widget)),
        )?.widget
        as T?;

Element? _walk(Element? from, bool Function(Widget) matches) {
  if (from == null) return null;
  if (matches(from.widget)) return from;
  Element? found;
  from.visitChildren((child) => found ??= _walk(child, matches));
  return found;
}
