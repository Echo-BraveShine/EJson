import 'dart:ui' as ui;

import 'package:ejson_core/ejson_core.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/json.dart';
import 'package:re_highlight/languages/yaml.dart';
import 'package:re_highlight/languages/xml.dart';
import 'package:re_highlight/languages/ini.dart';
import 'package:re_highlight/re_highlight.dart';

import '../design/reading_style.dart';
import '../l10n/app_localizations.dart';
import 'json_highlight.dart';
import 'source_chunk_analyzer.dart';

part 'source_fold_markers.dart';

final _csvMode = Mode(
  name: 'CSV',
  contains: [
    Mode(scope: 'string', match: r'"(?:[^"]|"")*"'),
    Mode(scope: 'punctuation', match: r'[,;\t]'),
  ],
);

/// A tab's folded view for the exact source it was built from.
class SourceFolds {
  String? _source;
  CodeLines? _lines;
}

class EJsonCodeEditor extends StatefulWidget {
  const EJsonCodeEditor({
    super.key,
    required this.source,
    this.onChanged,
    this.onPatch,
    required this.readOnly,
    this.jump,
    this.sourceLineIndex,
    this.focusOnJump = true,
    this.highlight = JsonHighlight.atomOne,
    this.useWorkspaceShortcuts = true,
    this.format = DocumentFormat.json,
    this.preserveViewOnUpdate = false,
    this.folds,
  }) : assert((onChanged == null) != (onPatch == null));

  final String source;
  final ValueChanged<String>? onChanged;
  final void Function(SourcePatch patch, String before, String after)? onPatch;
  final bool readOnly;
  final DocumentFormat format;
  final JsonHighlight highlight;
  final bool useWorkspaceShortcuts;
  final bool focusOnJump;
  final bool preserveViewOnUpdate;
  final LineIndex? sourceLineIndex;
  final SourceFolds? folds;
  final ({SourceRange range, int sequence})? jump;

  @override
  State<EJsonCodeEditor> createState() => _EJsonCodeEditorState();
}

class _EJsonCodeEditorState extends State<EJsonCodeEditor> {
  static final _newline = RegExp(r'\r\n|\r|\n');
  late String _source;
  late String _display;
  late bool _hasCarriageReturns;
  LineIndex? _sourceLines;
  late CodeLines _lines;
  late final CodeLineEditingController _controller;
  final _focus = FocusNode();
  final _scroll = CodeScrollController();
  CodeIndicatorValueNotifier? _indicator;
  CodeChunkController? _chunks;
  final _foldGutter = GlobalKey();
  final _foldMarkers = GlobalKey<_SourceFoldMarkersState>();

  String _normalize(String text) => text.replaceAll(_newline, '\n');

  LineIndex get _sourceIndex =>
      (identical(widget.source, _source) ? widget.sourceLineIndex : null) ??
      (_sourceLines ??= LineIndex(_source));

  void _setSource(String source) {
    _source = source;
    _hasCarriageReturns = source.contains('\r');
    _sourceLines = null;
  }

  @override
  void initState() {
    super.initState();
    _setSource(widget.source);
    _display = _hasCarriageReturns ? _normalize(_source) : _source;
    final folds = widget.folds;
    final savedLines = folds?._source == _source ? folds?._lines : null;
    _controller = _FoldAwareController(
      delegate: CodeLineEditingController(
        codeLines: savedLines ?? CodeLines.fromText(_display),
        options: const CodeLineOptions(indentSize: 2),
      ),
      revealEnd: () => _unfoldAt(_controller.codeLines.lineCount - 1),
    );
    _lines = _controller.codeLines;
    _rememberFolds();
    _controller.addListener(_edited);
    _scheduleJump();
  }

  @override
  void didUpdateWidget(covariant EJsonCodeEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.folds != null &&
        widget.folds == null &&
        _lines.lineCount != _lines.length) {
      final selection = _controller.selection;
      _controller.removeListener(_edited);
      _controller.value = _controller.value.copyWith(
        codeLines: CodeLines.fromText(_display),
        selection: selection.copyWith(
          baseIndex: _controller.index2lineIndex(selection.baseIndex),
          extentIndex: _controller.index2lineIndex(selection.extentIndex),
        ),
      );
      _lines = _controller.codeLines;
      _controller.addListener(_edited);
    }
    if (widget.source != _source) {
      _setSource(widget.source);
      final display = _hasCarriageReturns ? _normalize(_source) : _source;
      if (display != _display) {
        final vertical = _scroll.verticalScroller.hasClients
            ? _scroll.verticalScroller.offset
            : null;
        final horizontal = _scroll.horizontalScroller.hasClients
            ? _scroll.horizontalScroller.offset
            : null;
        final change = SourcePatch.between(_display, display);
        final lines = LineIndex(_display);
        _controller.removeListener(_edited);
        _unfoldAt(lines.position(change.range.start).line - 1, header: true);
        _unfoldAt(lines.position(change.range.end).line - 1, header: true);
        final start = _position(change.range.start, lines);
        final end = _position(change.range.end, lines);
        final selection = _controller.selection;
        final rawBase = _controller.index2lineIndex(selection.baseIndex);
        final rawExtent = _controller.index2lineIndex(selection.extentIndex);
        _display = display;
        _controller.replaceSelection(
          change.replacement,
          _selection(start, end),
        );
        if (_controller.text != display) {
          _controller.text = display;
        }
        if (widget.preserveViewOnUpdate) {
          final lines = _controller.codeLines;
          final base = _controller
              .lineIndex2Index(rawBase.clamp(0, lines.lineCount - 1))
              .index;
          final extent = _controller
              .lineIndex2Index(rawExtent.clamp(0, lines.lineCount - 1))
              .index;
          _controller.selection = CodeLineSelection(
            baseIndex: base,
            baseOffset: selection.baseOffset.clamp(0, lines[base].length),
            extentIndex: extent,
            extentOffset: selection.extentOffset.clamp(0, lines[extent].length),
            baseAffinity: selection.baseAffinity,
            extentAffinity: selection.extentAffinity,
          );
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (vertical != null && _scroll.verticalScroller.hasClients) {
              _scroll.verticalScroller.jumpTo(
                vertical.clamp(
                  0.0,
                  _scroll.verticalScroller.position.maxScrollExtent,
                ),
              );
            }
            if (horizontal != null && _scroll.horizontalScroller.hasClients) {
              _scroll.horizontalScroller.jumpTo(
                horizontal.clamp(
                  0.0,
                  _scroll.horizontalScroller.position.maxScrollExtent,
                ),
              );
            }
          });
        }
        _lines = _controller.codeLines;
        _rememberFolds();
        _controller.addListener(_edited);
      }
    }
    if (widget.jump != oldWidget.jump) _scheduleJump();
  }

  void _scheduleJump() {
    final jump = widget.jump;
    if (jump == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.jump != jump) return;
      final lines = _sourceIndex;
      final unfoldedStart = _unfoldAt(
        lines.position(jump.range.start).line - 1,
      );
      final unfoldedEnd = _unfoldAt(lines.position(jump.range.end).line - 1);
      final start = _position(jump.range.start, lines);
      final end = _position(jump.range.end, lines);
      _controller.selection = _selection(start, end);
      if (widget.focusOnJump) _focus.requestFocus();
      void reveal() {
        if (!mounted || widget.jump != jump) return;
        _skipIntermediateLines(start);
        _scroll.makeCenterIfInvisible(start);
      }

      if (unfoldedStart || unfoldedEnd) {
        WidgetsBinding.instance.addPostFrameCallback((_) => reveal());
      } else {
        reveal();
      }
    });
  }

  void _skipIntermediateLines(CodeLinePosition target) {
    final vertical = _scroll.verticalScroller;
    final paragraphs = _indicator?.value?.paragraphs;
    if (!vertical.hasClients || paragraphs == null || paragraphs.isEmpty) {
      return;
    }
    final viewport = vertical.position;
    final first = paragraphs.first;
    final distance = (first.index - target.index) * first.preferredLineHeight;
    if (distance <= viewport.viewportDimension) return;

    // re_editor lays out every intervening paragraph on long upward scrolls.
    // This editor has wrapping off, so move to the new line and rebuild the
    // visible paragraphs there before its normal horizontal centering runs.
    final offset =
        (viewport.pixels +
                first.top -
                distance -
                viewport.viewportDimension / 2)
            .clamp(viewport.minScrollExtent, viewport.maxScrollExtent);
    vertical.jumpTo(offset);
    _controller.forceRepaint();
  }

  void _edited() {
    if (identical(_lines, _controller.codeLines)) {
      _keepCaretOutsideFold();
      return;
    }
    _lines = _controller.codeLines;
    if (widget.readOnly) return;
    final display = _controller.text;
    final change = SourcePatch.between(_display, display);
    if (change.range.start == change.range.end && change.replacement.isEmpty) {
      _rememberFolds();
      _keepCaretOutsideFold(justFolded: true);
      return;
    }
    final patch = _hasCarriageReturns ? _originalPatch(change) : change;
    final before = _source;
    _source = _hasCarriageReturns ? patch.apply(before) : display;
    _sourceLines = null;
    _display = display;
    _rememberFolds();
    widget.onPatch?.call(patch, before, _source);
    widget.onChanged?.call(_source);
  }

  void _keepCaretOutsideFold({bool justFolded = false}) {
    if (widget.folds == null) return;
    final selection = _controller.selection;
    final index = selection.extentIndex;
    if (!selection.isCollapsed || index < 0 || index >= _lines.length) return;
    final line = _lines[index];
    if (!line.chunkParent) return;
    final (label, _) = _foldLabel(line);
    if (label == '…') return;
    final opening = line.text.trimRight().length - 1;
    if (selection.extentOffset <= opening) return;
    if (justFolded) {
      // A collapse can put a caret from a hidden line at the end of the header.
      _controller.selection = CodeLineSelection.collapsed(
        index: index,
        offset: opening,
      );
    } else {
      _unfoldAt(_controller.index2lineIndex(index), header: true);
    }
  }

  void _rememberFolds() {
    final folds = widget.folds;
    if (folds == null) return;
    final folded = _lines.lineCount != _lines.length;
    folds._source = folded ? _source : null;
    folds._lines = folded ? _lines : null;
  }

  bool _unfoldAt(int rawLine, {bool header = false}) {
    if (widget.folds == null) return false;
    var unfolded = false;
    var location = _controller.lineIndex2Index(rawLine);
    while (location.index >= 0 &&
        (location.chunkIndex >= 0 ||
            (header && _controller.codeLines[location.index].chunkParent))) {
      final chunks = _chunks;
      if (chunks == null) {
        _controller.expandChunk(location.index);
      } else {
        chunks.expand(location.index);
      }
      unfolded = true;
      location = _controller.lineIndex2Index(rawLine);
    }
    return unfolded;
  }

  SourcePatch _originalPatch(SourcePatch change) {
    var (:start, :end) = change.range;
    // A CRLF adds one code unit to the source. A lone CR and an LF each
    // occupy one code unit in both the source and the editor.
    var newlineOffset = _source.indexOf('\r\n');
    while (newlineOffset >= 0 && newlineOffset < end) {
      if (newlineOffset < start) start++;
      end++;
      newlineOffset = _source.indexOf('\r\n', newlineOffset + 2);
    }
    final newline = _newline.firstMatch(_source)?.group(0) ?? '\n';
    return SourcePatch((
      start: start,
      end: end,
    ), change.replacement.replaceAll('\n', newline));
  }

  CodeLinePosition _position(int offset, LineIndex lines) {
    final point = lines.position(offset);
    return CodeLinePosition(
      index: widget.folds == null
          ? point.line - 1
          : _controller.lineIndex2Index(point.line - 1).index,
      offset: point.column - 1,
    );
  }

  CodeLineSelection _selection(CodeLinePosition start, CodeLinePosition end) =>
      CodeLineSelection(
        baseIndex: start.index,
        baseOffset: start.offset,
        extentIndex: end.index,
        extentOffset: end.offset,
      );

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    _scroll.verticalScroller.dispose();
    _scroll.horizontalScroller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final reading = ReadingStyle.of(context);
    final code = reading.text.copyWith(fontSize: reading.scaledFontSize);
    final highlight = widget.highlight.colors(theme.brightness);
    final schemeBackground = widget.highlight.editorBackground(
      theme.brightness,
    );
    final background = schemeBackground ?? colors.surface;
    final foreground = schemeBackground == null
        ? colors.onSurface
        : highlight!['root']!.color!;
    final editorDark =
        ThemeData.estimateBrightnessForColor(background) == Brightness.dark;
    final accent = schemeBackground == null
        ? colors.primary
        : editorDark
        ? const Color(0xff79b7ff)
        : const Color(0xff0066cc);
    final muted = schemeBackground == null
        ? colors.onSurfaceVariant
        : foreground.withValues(alpha: .72);
    final divider = schemeBackground == null
        ? colors.outlineVariant
        : foreground.withValues(alpha: .20);

    final language = widget.format == DocumentFormat.jsonLines
        ? 'json'
        : widget.format.name;
    final mode = switch (widget.format) {
      DocumentFormat.json || DocumentFormat.jsonLines => langJson,
      DocumentFormat.yaml => langYaml,
      DocumentFormat.csv => _csvMode,
      DocumentFormat.xml => langXml,
      DocumentFormat.toml => langIni,
    };
    final editor = CodeEditor(
      controller: _controller,
      focusNode: _focus,
      scrollController: _scroll,
      shortcutsActivatorsBuilder: widget.useWorkspaceShortcuts
          ? const _EditorShortcuts()
          : null,
      readOnly: widget.readOnly,
      wordWrap: false,
      chunkAnalyzer: widget.folds == null
          ? const NonCodeChunkAnalyzer()
          : switch (widget.format) {
              DocumentFormat.json => const SourceChunkAnalyzer(
                DocumentFormat.json,
              ),
              DocumentFormat.yaml => const SourceChunkAnalyzer(
                DocumentFormat.yaml,
              ),
              DocumentFormat.xml => const SourceChunkAnalyzer(
                DocumentFormat.xml,
              ),
              DocumentFormat.toml => const SourceChunkAnalyzer(
                DocumentFormat.toml,
              ),
              DocumentFormat.csv => const SourceChunkAnalyzer(
                DocumentFormat.csv,
              ),
              DocumentFormat.jsonLines => const SourceChunkAnalyzer(
                DocumentFormat.jsonLines,
              ),
            },
      padding: EdgeInsets.fromLTRB(13, 10, widget.folds == null ? 14 : 42, 10),
      style: CodeEditorStyle(
        backgroundColor: background,
        textColor: foreground,
        fontFamily: code.fontFamily,
        fontFamilyFallback: code.fontFamilyFallback,
        fontHeight: code.height,
        cursorColor: accent,
        selectionColor: accent.withValues(alpha: .25),
        cursorLineColor: accent.withValues(alpha: .055),
        fontSize: code.fontSize,
        codeTheme: highlight == null
            ? null
            : CodeHighlightTheme(
                languages: {language: CodeHighlightThemeMode(mode: mode)},
                theme: highlight,
              ),
      ),
      leadingDivider: VerticalDivider(width: 1, color: divider),
      indicatorBuilder: (context, controller, chunks, notifier) {
        _indicator = notifier;
        _foldMarkers.currentState?.bind(notifier);
        _chunks = chunks;
        final numbers = DefaultCodeLineNumber(
          controller: controller,
          notifier: notifier,
          textStyle: code.copyWith(color: muted),
          focusedTextStyle: code.copyWith(color: accent),
        );
        if (widget.folds == null) return numbers;
        return Row(
          key: _foldGutter,
          mainAxisSize: MainAxisSize.min,
          children: [
            numbers,
            DefaultCodeChunkIndicator(
              width: 18,
              controller: chunks,
              notifier: notifier,
              painter: _SourceFoldChevron(muted),
            ),
          ],
        );
      },
    );
    if (widget.folds == null) return editor;
    return Stack(
      fit: StackFit.expand,
      children: [
        editor,
        _SourceFoldMarkers(
          key: _foldMarkers,
          editor: this,
          textStyle: code.copyWith(color: foreground),
          background: background,
          accent: accent,
          language: language,
          mode: mode,
          highlight: highlight,
        ),
      ],
    );
  }
}

class _SourceFoldChevron implements CodeChunkIndicatorPainter {
  _SourceFoldChevron(this.color);

  final Color color;
  late final _down = _glyph(CupertinoIcons.chevron_down);
  late final _right = _glyph(CupertinoIcons.chevron_right);

  ui.Paragraph _glyph(IconData icon) {
    final family = icon.fontPackage == null
        ? icon.fontFamily
        : 'packages/${icon.fontPackage}/${icon.fontFamily}';
    return (ui.ParagraphBuilder(ui.ParagraphStyle())
          ..pushStyle(
            ui.TextStyle(color: color, fontFamily: family, fontSize: 12),
          )
          ..addText(String.fromCharCode(icon.codePoint)))
        .build()
      ..layout(const ui.ParagraphConstraints(width: 12));
  }

  void _paint(Canvas canvas, Size container, ui.Paragraph glyph) {
    canvas.drawParagraph(
      glyph,
      Offset(
        (container.width - glyph.width) / 2,
        (container.height - glyph.height) / 2,
      ),
    );
  }

  @override
  void paintCollapseIndicator(Canvas canvas, Size container) =>
      _paint(canvas, container, _down);

  @override
  void paintExpandIndicator(Canvas canvas, Size container) =>
      _paint(canvas, container, _right);
}

// Workspace shortcuts own the history for both editing surfaces.
class _EditorShortcuts extends DefaultCodeShortcutsActivatorsBuilder {
  const _EditorShortcuts();

  @override
  List<ShortcutActivator>? build(CodeShortcutType type) => switch (type) {
    CodeShortcutType.find ||
    CodeShortcutType.undo ||
    CodeShortcutType.redo ||
    CodeShortcutType.save => null,
    _ => super.build(type),
  };
}

class _FoldAwareController extends CodeLineEditingControllerDelegate {
  _FoldAwareController({required super.delegate, required this.revealEnd});

  final VoidCallback revealEnd;

  @override
  void selectAll() {
    // The native selection uses visible endpoints. If EOF is hidden, reveal
    // it before copying or replacing the entire document.
    if (codeLines.last.chunkParent) revealEnd();
    super.selectAll();
  }
}
