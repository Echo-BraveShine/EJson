import 'package:ejson_core/ejson_core.dart';
import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/json.dart';
import 'package:re_highlight/languages/yaml.dart';
import 'package:re_highlight/languages/xml.dart';
import 'package:re_highlight/languages/ini.dart';
import 'package:re_highlight/re_highlight.dart';

import '../design/reading_style.dart';
import 'json_highlight.dart';

final _csvMode = Mode(
  name: 'CSV',
  contains: [
    Mode(scope: 'string', match: r'"(?:[^"]|"")*"'),
    Mode(scope: 'punctuation', match: r'[,;\t]'),
  ],
);

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
    _controller = CodeLineEditingController.fromText(
      _display,
      const CodeLineOptions(indentSize: 2),
    );
    _lines = _controller.codeLines;
    _controller.addListener(_edited);
    _scheduleJump();
  }

  @override
  void didUpdateWidget(covariant EJsonCodeEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.source != _source) {
      _setSource(widget.source);
      final display = _hasCarriageReturns ? _normalize(_source) : _source;
      if (display != _display) {
        final selection = _controller.selection;
        final vertical = _scroll.verticalScroller.hasClients
            ? _scroll.verticalScroller.offset
            : null;
        final horizontal = _scroll.horizontalScroller.hasClients
            ? _scroll.horizontalScroller.offset
            : null;
        final change = SourcePatch.between(_display, display);
        final lines = LineIndex(_display);
        final start = _position(change.range.start, lines);
        final end = _position(change.range.end, lines);
        _display = display;
        _controller.removeListener(_edited);
        _controller.replaceSelection(
          change.replacement,
          _selection(start, end),
        );
        if (_controller.text != display) {
          _controller.text = display;
        }
        if (widget.preserveViewOnUpdate) {
          final lines = _controller.codeLines;
          final base = selection.baseIndex.clamp(0, lines.length - 1);
          final extent = selection.extentIndex.clamp(0, lines.length - 1);
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
      final start = _position(jump.range.start, lines);
      final end = _position(jump.range.end, lines);
      _controller.selection = _selection(start, end);
      if (widget.focusOnJump) _focus.requestFocus();
      _skipIntermediateLines(start);
      _scroll.makeCenterIfInvisible(start);
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
    if (identical(_lines, _controller.codeLines)) return;
    _lines = _controller.codeLines;
    if (widget.readOnly) return;
    final display = _controller.text;
    final change = SourcePatch.between(_display, display);
    if (change.range.start == change.range.end && change.replacement.isEmpty) {
      return;
    }
    final patch = _hasCarriageReturns ? _originalPatch(change) : change;
    final before = _source;
    _source = _hasCarriageReturns ? patch.apply(before) : display;
    _sourceLines = null;
    _display = display;
    widget.onPatch?.call(patch, before, _source);
    widget.onChanged?.call(_source);
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
    return CodeLinePosition(index: point.line - 1, offset: point.column - 1);
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

    return CodeEditor(
      controller: _controller,
      focusNode: _focus,
      scrollController: _scroll,
      shortcutsActivatorsBuilder: widget.useWorkspaceShortcuts
          ? const _EditorShortcuts()
          : null,
      readOnly: widget.readOnly,
      wordWrap: false,
      padding: const EdgeInsets.fromLTRB(13, 10, 14, 10),
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
                languages: {
                  (widget.format == DocumentFormat.jsonLines
                      ? 'json'
                      : widget.format.name): CodeHighlightThemeMode(
                    mode: switch (widget.format) {
                      DocumentFormat.json ||
                      DocumentFormat.jsonLines => langJson,
                      DocumentFormat.yaml => langYaml,
                      DocumentFormat.csv => _csvMode,
                      DocumentFormat.xml => langXml,
                      DocumentFormat.toml => langIni,
                    },
                  ),
                },
                theme: highlight,
              ),
      ),
      leadingDivider: VerticalDivider(width: 1, color: divider),
      indicatorBuilder: (context, controller, _, notifier) {
        _indicator = notifier;
        return DefaultCodeLineNumber(
          controller: controller,
          notifier: notifier,
          textStyle: code.copyWith(color: muted),
          focusedTextStyle: code.copyWith(color: accent),
        );
      },
    );
  }
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
