import 'package:ejson_core/ejson_core.dart';
import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/json.dart';

import '../design/workbench_style.dart';
import 'json_highlight.dart';

class EJsonCodeEditor extends StatefulWidget {
  const EJsonCodeEditor({
    super.key,
    required this.source,
    required this.onChanged,
    required this.readOnly,
    this.jump,
    this.focusOnJump = true,
    this.highlight = JsonHighlight.atomOne,
    this.useWorkspaceShortcuts = true,
  });

  final String source;
  final ValueChanged<String> onChanged;
  final bool readOnly;
  final JsonHighlight highlight;
  final bool useWorkspaceShortcuts;
  final bool focusOnJump;
  final ({SourceRange range, int sequence})? jump;

  @override
  State<EJsonCodeEditor> createState() => _EJsonCodeEditorState();
}

class _EJsonCodeEditorState extends State<EJsonCodeEditor> {
  static final _newline = RegExp(r'\r\n|\r|\n');
  late String _source;
  late String _display;
  late CodeLines _lines;
  late final CodeLineEditingController _controller;
  final _focus = FocusNode();
  final _scroll = CodeScrollController();

  String _normalize(String text) => text.replaceAll(_newline, '\n');

  @override
  void initState() {
    super.initState();
    _source = widget.source;
    _display = _normalize(_source);
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
      _source = widget.source;
      final display = _normalize(_source);
      if (display != _display) {
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
      final lines = LineIndex(_source);
      final start = _position(jump.range.start, lines);
      final end = _position(jump.range.end, lines);
      _controller.selection = _selection(start, end);
      if (widget.focusOnJump) _focus.requestFocus();
      _scroll.makeCenterIfInvisible(start);
    });
  }

  void _edited() {
    if (identical(_lines, _controller.codeLines)) return;
    _lines = _controller.codeLines;
    final display = _controller.text;
    if (display == _display || widget.readOnly) return;
    final change = SourcePatch.between(_display, display);
    final shown = LineIndex(_display);
    final original = LineIndex(_source);
    int originalOffset(int offset) {
      final position = shown.position(offset);
      return original.starts[position.line - 1] + position.column - 1;
    }

    final newline = _newline.firstMatch(_source)?.group(0) ?? '\n';
    final patch = SourcePatch((
      start: originalOffset(change.range.start),
      end: originalOffset(change.range.end),
    ), change.replacement.replaceAll('\n', newline));
    _source = patch.apply(_source);
    _display = display;
    widget.onChanged(_source);
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
    final code = WorkbenchStyle.code(theme.platform);
    final highlight = widget.highlight.colors(theme.brightness);
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
        backgroundColor: colors.surface,
        textColor: colors.onSurface,
        fontFamily: code.fontFamily,
        cursorColor: colors.primary,
        selectionColor: colors.primary.withValues(alpha: .25),
        cursorLineColor: colors.primary.withValues(alpha: .055),
        fontSize: code.fontSize,
        codeTheme: highlight == null
            ? null
            : CodeHighlightTheme(
                languages: {'json': CodeHighlightThemeMode(mode: langJson)},
                theme: highlight,
              ),
      ),
      leadingDivider: VerticalDivider(width: 1, color: colors.outlineVariant),
      indicatorBuilder: (context, controller, _, notifier) =>
          DefaultCodeLineNumber(
            controller: controller,
            notifier: notifier,
            textStyle: code.copyWith(color: colors.onSurfaceVariant),
            focusedTextStyle: code.copyWith(color: colors.primary),
          ),
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
