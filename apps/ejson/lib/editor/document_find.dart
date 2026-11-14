import 'dart:convert';

import 'package:ejson_core/ejson_core.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../design/workbench_style.dart';
import '../l10n/app_localizations.dart';

enum _Scope { source, keys, scalarValues }

class DocumentFind extends StatefulWidget {
  const DocumentFind({
    super.key,
    required this.document,
    required this.enabled,
    required this.focusNode,
    required this.onMatch,
    required this.onClose,
  });

  final JsonDocument document;
  final bool enabled;
  final FocusNode focusNode;
  final ValueChanged<SourceRange> onMatch;
  final VoidCallback onClose;

  @override
  State<DocumentFind> createState() => _DocumentFindState();
}

class _DocumentFindState extends State<DocumentFind> {
  static const _matchLimit = 10000;
  final _query = TextEditingController();
  _Scope _scope = _Scope.source;
  List<SourceRange> _matches = const [];
  int _index = -1;
  bool _limited = false;

  @override
  void didUpdateWidget(covariant DocumentFind oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.document != oldWidget.document ||
        widget.enabled != oldWidget.enabled) {
      _updateMatches();
    }
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _updateMatches() {
    final query = _query.text;
    final source = widget.document.source.text;
    final root = widget.document.snapshot?.root;
    _index = -1;
    _matches = [];
    _limited = false;
    if (query.isEmpty || !widget.enabled) return;
    final pattern = RegExp(RegExp.escape(query), caseSensitive: false);
    if (_scope == _Scope.source) {
      _matches = [
        for (final match in pattern.allMatches(source).take(_matchLimit + 1))
          (start: match.start, end: match.end),
      ];
      _limitMatches();
      return;
    }
    if (root == null) return;

    void visit(JsonNode node) {
      if (_scope == _Scope.scalarValues &&
          node.kind != JsonKind.object &&
          node.kind != JsonKind.array) {
        final raw = source.substring(node.range.start, node.range.end);
        final value = node.kind == JsonKind.string
            ? jsonDecode(raw) as String
            : raw;
        if (pattern.hasMatch(value)) _matches.add(node.range);
      }
      for (final child in node.children) {
        if (_matches.length > _matchLimit) return;
        if (_scope == _Scope.keys &&
            child.key != null &&
            pattern.hasMatch(child.key!)) {
          _matches.add(child.keyRange!);
        }
        visit(child.value);
      }
    }

    visit(root);
    _limitMatches();
  }

  void _limitMatches() {
    if (_matches.length > _matchLimit) {
      _matches.length = _matchLimit;
      _limited = true;
    }
  }

  void _move(int direction) {
    if (_matches.isEmpty) return;
    setState(() {
      _index = _index == -1 && direction < 0
          ? _matches.length - 1
          : (_index + direction) % _matches.length;
    });
    widget.onMatch(_matches[_index]);
  }

  void _search() {
    setState(_updateMatches);
    _move(1);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final labels = {
      _Scope.source: strings.searchSource,
      _Scope.keys: strings.searchKeys,
      _Scope.scalarValues: strings.searchValues,
    };
    final status = !widget.enabled
        ? strings.largeFile
        : _scope != _Scope.source && !widget.document.isValid
        ? strings.findNeedsValidJson
        : _query.text.isEmpty
        ? ''
        : _matches.isEmpty
        ? strings.noMatches
        : '${_index < 0 ? '–' : _index + 1} / ${_matches.length}${_limited ? '+' : ''}';
    final colors = theme.colorScheme;
    const radius = BorderRadius.all(
      Radius.circular(WorkbenchStyle.controlRadius),
    );
    final border = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: colors.outlineVariant),
    );
    return Material(
      color: colors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: WorkbenchStyle.space12,
          vertical: WorkbenchStyle.space8,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Flexible(
              flex: 3,
              child: SizedBox(
                width: 280,
                child: TextField(
                  autofocus: true,
                  focusNode: widget.focusNode,
                  controller: _query,
                  style: theme.textTheme.bodyMedium,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: strings.findInDocument,
                    prefixIcon: Icon(
                      CupertinoIcons.search,
                      size: WorkbenchStyle.controlIconSize,
                      color: colors.onSurfaceVariant,
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 32),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: WorkbenchStyle.space8,
                      horizontal: WorkbenchStyle.space8,
                    ),
                    border: border,
                    enabledBorder: border,
                    focusedBorder: border.copyWith(
                      borderSide: BorderSide(color: colors.primary),
                    ),
                  ),
                  onChanged: (_) => _search(),
                  onEditingComplete: () => _move(1),
                ),
              ),
            ),
            const SizedBox(width: WorkbenchStyle.space8),
            PopupMenuButton<_Scope>(
              initialValue: _scope,
              onSelected: (scope) {
                _scope = scope;
                _search();
              },
              itemBuilder: (context) => [
                for (final entry in labels.entries)
                  WorkbenchMenuItem(
                    value: entry.key,
                    icon: CupertinoIcons.search,
                    label: entry.value,
                    checked: entry.key == _scope,
                  ),
              ],
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: radius,
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: WorkbenchStyle.space8,
                    vertical: WorkbenchStyle.space8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(labels[_scope]!, style: theme.textTheme.labelMedium),
                      const SizedBox(width: WorkbenchStyle.space8),
                      Icon(
                        CupertinoIcons.chevron_down,
                        size: 12,
                        color: colors.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (status.isNotEmpty) ...[
              const SizedBox(width: WorkbenchStyle.space8),
              Flexible(
                child: Tooltip(
                  message: status,
                  child: Text(
                    status,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(width: WorkbenchStyle.space8),
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: radius,
                border: Border.all(color: colors.outlineVariant),
              ),
              child: Row(
                children: [
                  _button(
                    strings.previousMatch,
                    CupertinoIcons.chevron_up,
                    _matches.isEmpty ? null : () => _move(-1),
                  ),
                  SizedBox(
                    height: WorkbenchStyle.space16,
                    child: VerticalDivider(
                      width: 1,
                      color: colors.outlineVariant,
                    ),
                  ),
                  _button(
                    strings.nextMatch,
                    CupertinoIcons.chevron_down,
                    _matches.isEmpty ? null : () => _move(1),
                  ),
                ],
              ),
            ),
            const SizedBox(width: WorkbenchStyle.space4),
            _button(strings.closeFind, CupertinoIcons.xmark, widget.onClose),
          ],
        ),
      ),
    );
  }

  Widget _button(String label, IconData icon, VoidCallback? onPressed) =>
      IconButton(
        tooltip: label,
        onPressed: onPressed,
        icon: Icon(icon, size: 14),
        style: IconButton.styleFrom(
          minimumSize: const Size(30, WorkbenchStyle.toolbarControlHeight),
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(WorkbenchStyle.controlRadius),
          ),
        ),
      );
}
