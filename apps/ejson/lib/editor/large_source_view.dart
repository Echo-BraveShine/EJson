import 'package:ejson_core/ejson_core.dart';
import 'package:flutter/material.dart';

import '../design/workbench_text_field.dart';
import '../l10n/app_localizations.dart';
import 'code_editor.dart';
import 'json_highlight.dart';

class LargeSourceView extends StatefulWidget {
  const LargeSourceView({
    super.key,
    required this.source,
    required this.format,
    required this.jump,
    required this.focusOnJump,
  });

  final String source;
  final DocumentFormat format;
  final ({SourceRange range, int sequence})? jump;
  final bool focusOnJump;

  @override
  State<LargeSourceView> createState() => _LargeSourceViewState();
}

class _LargeSourceViewState extends State<LargeSourceView> {
  static const _pageSize = 16 * 1024;
  int _page = 0;
  ({SourceRange range, int sequence})? _jump;

  int get _pageCount {
    final length = widget.source.length;
    if (length == 0) return 1;
    final pages = (length + _pageSize - 1) ~/ _pageSize;
    return pages > 1 && _boundary(pages - 1) == length ? pages - 1 : pages;
  }

  int _boundary(int page) {
    final text = widget.source;
    final offset = page * _pageSize;
    if (offset == 0) return 0;
    if (offset >= text.length) return text.length;
    final previous = text.codeUnitAt(offset - 1);
    final next = text.codeUnitAt(offset);
    final splitsSurrogate =
        previous >= 0xd800 &&
        previous <= 0xdbff &&
        next >= 0xdc00 &&
        next <= 0xdfff;
    return splitsSurrogate || (previous == 13 && next == 10)
        ? offset + 1
        : offset;
  }

  void _showJump() {
    final jump = widget.jump;
    _jump = jump;
    if (jump == null) return;
    final offset = jump.range.start.clamp(0, widget.source.length);
    _page = (offset ~/ _pageSize).clamp(0, _pageCount - 1);
    if (offset < _boundary(_page)) _page--;
  }

  @override
  void initState() {
    super.initState();
    _showJump();
  }

  @override
  void didUpdateWidget(covariant LargeSourceView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.source != oldWidget.source) {
      _page = _page.clamp(0, _pageCount - 1);
      _showJump();
    } else if (widget.jump != oldWidget.jump) {
      _showJump();
    }
  }

  void _turnPage(int page) => setState(() {
    _page = page;
    _jump = null;
  });

  Future<void> _pickPage() async {
    final strings = AppLocalizations.of(context);
    final total = _pageCount;
    int? selected;
    final page = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) {
          void submit() {
            if (selected case final page?) Navigator.pop(context, page);
          }

          return AlertDialog(
            title: Text(strings.sourceGoToPage),
            content: WorkbenchTextField(
              autofocus: true,
              keyboardType: TextInputType.number,
              hintText: '1–$total',
              onChanged: (text) => update(() {
                final number = int.tryParse(text.trim());
                selected = number != null && number >= 1 && number <= total
                    ? number
                    : null;
              }),
              onSubmitted: (_) => submit(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(strings.cancel),
              ),
              TextButton(
                onPressed: selected == null ? null : submit,
                child: Text(strings.apply),
              ),
            ],
          );
        },
      ),
    );
    if (mounted && page != null && page <= _pageCount) _turnPage(page - 1);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final start = _boundary(_page);
    final end = _boundary(_page + 1);
    final jump = _jump;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: strings.sourcePreviousPage,
              icon: const Icon(Icons.chevron_left),
              onPressed: _page == 0 ? null : () => _turnPage(_page - 1),
            ),
            TextButton(
              onPressed: _pageCount > 1 ? _pickPage : null,
              child: Text(strings.sourcePage(_page + 1, _pageCount)),
            ),
            IconButton(
              tooltip: strings.sourceNextPage,
              icon: const Icon(Icons.chevron_right),
              onPressed: _page + 1 == _pageCount
                  ? null
                  : () => _turnPage(_page + 1),
            ),
          ],
        ),
        Expanded(
          child: EJsonCodeEditor(
            key: ValueKey(_page),
            source: widget.source.substring(start, end),
            format: widget.format,
            readOnly: true,
            highlight: JsonHighlight.monochrome,
            onChanged: (_) {},
            focusOnJump: widget.focusOnJump,
            jump: jump == null
                ? null
                : (
                    range: (
                      start: jump.range.start.clamp(start, end) - start,
                      end: jump.range.end.clamp(start, end) - start,
                    ),
                    sequence: jump.sequence,
                  ),
          ),
        ),
      ],
    );
  }
}
