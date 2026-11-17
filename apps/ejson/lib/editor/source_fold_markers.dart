part of 'code_editor.dart';

class _SourceFoldMarkers extends StatefulWidget {
  const _SourceFoldMarkers({
    super.key,
    required this.editor,
    required this.textStyle,
    required this.background,
    required this.accent,
    required this.language,
    required this.mode,
    required this.highlight,
  });

  final _EJsonCodeEditorState editor;
  final TextStyle textStyle;
  final Color background;
  final Color accent;
  final String language;
  final Mode mode;
  final Map<String, TextStyle>? highlight;

  @override
  State<_SourceFoldMarkers> createState() => _SourceFoldMarkersState();
}

class _SourceFoldMarkersState extends State<_SourceFoldMarkers> {
  CodeIndicatorValueNotifier? _notifier;
  bool _refreshScheduled = false;

  @override
  void initState() {
    super.initState();
    final notifier = widget.editor._indicator;
    if (notifier != null) bind(notifier);
  }

  void bind(CodeIndicatorValueNotifier notifier) {
    if (identical(_notifier, notifier)) return;
    _notifier?.removeListener(_refresh);
    _notifier = notifier;
    notifier.addListener(_refresh);
    _refresh();
  }

  void _refresh() {
    if (_refreshScheduled) return;
    _refreshScheduled = true;
    // The editor publishes paragraph positions during layout.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshScheduled = false;
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    _notifier?.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editor = widget.editor;
    final paragraphs = _notifier?.value?.paragraphs;
    final gutter = editor._foldGutter.currentContext?.findRenderObject();
    if (paragraphs == null || gutter is! RenderBox || !gutter.hasSize) {
      return const SizedBox.expand();
    }

    // The indicator and source field are siblings with a 1 px divider.
    final sourceLeft = gutter.size.width + 1;
    final lines = editor._controller.codeLines;
    final fill = Color.alphaBlend(
      widget.accent.withValues(alpha: .13),
      widget.background,
    );

    // Use the same strut and scaling as the source editor's paragraphs.
    final strut = StrutStyle(
      fontSize: widget.textStyle.fontSize,
      fontFamily: widget.textStyle.fontFamily,
      height: widget.textStyle.height,
      forceStrutHeight: true,
    );
    Widget markerText(String text) => Text(
      text,
      style: widget.textStyle.copyWith(inherit: false),
      strutStyle: strut,
      textScaler: TextScaler.noScaling,
      textDirection: TextDirection.ltr,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final markers = <Widget>[];
        for (final paragraph in paragraphs) {
          if (!paragraph.chunkParent || paragraph.index >= lines.length) {
            continue;
          }
          final line = lines[paragraph.index];
          if (!line.chunkParent) continue;
          final (label, suffix) = _foldLabel(line);
          final labelStart = label == '…'
              ? paragraph.length
              : line.text.trimRight().length - 1;
          final offset = paragraph.getOffset(
            TextPosition(offset: labelStart.clamp(0, paragraph.length)),
          );
          if (offset == null) continue;
          final x = sourceLeft + paragraph.offset.dx + offset.dx;
          final y = paragraph.top + offset.dy;
          if (x < sourceLeft ||
              x + 12 > constraints.maxWidth ||
              y < 0 ||
              y + paragraph.preferredLineHeight > constraints.maxHeight) {
            continue;
          }
          markers.add(
            Positioned(
              key: ObjectKey(line),
              left: x,
              top: y,
              height: paragraph.preferredLineHeight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Tooltip(
                    richMessage: WidgetSpan(
                      child: _FoldSourcePreview(
                        line: line,
                        style: widget.textStyle,
                        language: widget.language,
                        mode: widget.mode,
                        highlight: widget.highlight,
                      ),
                    ),
                    waitDuration: const Duration(milliseconds: 350),
                    preferBelow: true,
                    excludeFromSemantics: true,
                    decoration: BoxDecoration(
                      color: widget.background,
                      border: Border.all(color: fill),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: kElevationToShadow[4],
                    ),
                    padding: const EdgeInsets.all(10),
                    child: Semantics(
                      label: AppLocalizations.of(context).expand,
                      button: true,
                      child: CodeEditorTapRegion(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => editor._chunks?.expand(paragraph.index),
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // The editor paints the original opener below
                                // this overlay. Mask it before adding the inset.
                                Positioned.fill(
                                  child: ColoredBox(color: widget.background),
                                ),
                                Positioned.fill(
                                  top: 2,
                                  bottom: 2,
                                  left: 2,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: fill,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 5,
                                    right: 3,
                                  ),
                                  child: Transform.translate(
                                    offset: const Offset(0, -1),
                                    child: markerText(label),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (suffix.isNotEmpty) markerText(suffix),
                ],
              ),
            ),
          );
        }
        return Stack(fit: StackFit.expand, children: markers);
      },
    );
  }
}

(String, String) _foldLabel(CodeLine line) {
  final header = line.text.trimRight();
  final closer = sourceFoldCloser(header);
  if (closer == null) return ('…', '');
  var last = line.chunks.last;
  while (last.chunkParent) {
    last = last.chunks.last;
  }
  final tail = last.text.trim();
  return tail == closer || tail == '$closer,'
      ? ('${header[header.length - 1]}…$closer', tail.substring(1))
      : ('…', '');
}

class _FoldSourcePreview extends StatelessWidget {
  const _FoldSourcePreview({
    required this.line,
    required this.style,
    required this.language,
    required this.mode,
    required this.highlight,
  });

  final CodeLine line;
  final TextStyle style;
  final String language;
  final Mode mode;
  final Map<String, TextStyle>? highlight;

  @override
  Widget build(BuildContext context) {
    const maxLines = 12;
    const maxColumns = 160;
    final lines = _sourceLines(line).take(maxLines).map((text) {
      final characters = text.characters.take(maxColumns + 1);
      return characters.length <= maxColumns
          ? text
          : '${characters.take(maxColumns)}…';
    });
    final source = lines.join('\n');
    final remaining = line.lineCount - maxLines;
    final theme = highlight;
    TextSpan span = TextSpan(text: source, style: style);
    if (theme != null) {
      final engine = Highlight()..registerLanguage(language, mode);
      final renderer = TextSpanRenderer(style, theme);
      engine.highlight(code: source, language: language).render(renderer);
      span = renderer.span ?? span;
    }
    final l10n = AppLocalizations.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(span),
          if (remaining > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                l10n.foldPreviewMoreLines(remaining),
                style: style.copyWith(fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }

  Iterable<String> _sourceLines(CodeLine line) sync* {
    yield line.text;
    for (final child in line.chunks) {
      yield* _sourceLines(child);
    }
  }
}
