import '../design/workbench_text_field.dart';
import 'dart:convert';

import 'package:ejson_core/ejson_core.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../design/workbench_style.dart';
import '../l10n/app_localizations.dart';
import '../l10n/workspace_messages.dart';
import 'regex_replacement.dart';

enum _Scope { source, keys, scalarValues }

class DocumentFind extends StatefulWidget {
  const DocumentFind({
    super.key,
    required this.document,
    required this.enabled,
    required this.focusNode,
    required this.onMatch,
    required this.onClose,
    this.onNoMatch,
    this.onReplace,
    this.structured = true,
  });

  final JsonDocument document;
  final bool structured;
  final bool enabled;
  final FocusNode focusNode;
  final ValueChanged<SourceRange> onMatch;
  final VoidCallback onClose;
  final VoidCallback? onNoMatch;
  final ValueChanged<String>? onReplace;

  @override
  State<DocumentFind> createState() => _DocumentFindState();
}

class _DocumentFindState extends State<DocumentFind> {
  static const _matchLimit = 10000;
  final _query = TextEditingController();
  final _replacement = TextEditingController();
  bool _showReplace = false;
  bool _caseSensitive = false;
  bool _regex = false;
  bool _ignoreWhitespace = false;
  bool _invalidPattern = false;
  RegExp? _pattern;
  _Scope _scope = _Scope.source;
  List<SourceRange> _matches = const [];
  final _sourceMatches = <SourceRange, RegExpMatch>{};
  int _index = -1;
  bool _limited = false;

  @override
  void didUpdateWidget(covariant DocumentFind oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 只有在文档或 enabled 真正变化时才重新匹配
    if (widget.document != oldWidget.document ||
        widget.enabled != oldWidget.enabled) {
      // 保存旧的选中索引，用于匹配后恢复
      final oldIndex = _index;
      _updateMatches();
      // 如果旧索引在新匹配列表中有效，则尝试恢复
      if (oldIndex >= 0 && _matches.length > oldIndex) {
        _index = oldIndex;
      } else if (_matches.isNotEmpty) {
        // 否则回退到第一个匹配
        _index = 0;
      } else {
        _index = -1;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_index >= 0 && _index < _matches.length) {
          widget.onMatch(_matches[_index]);
        } else {
          widget.onNoMatch?.call();
        }
      });
    }
  }

  @override
  void dispose() {
    _query.dispose();
    _replacement.dispose();
    super.dispose();
  }

  void _updateMatches() {
    final query = _query.text;
    final source = widget.document.source.text;
    final root = widget.document.isValid
        ? widget.document.snapshot?.root
        : null;
    _index = -1;
    _matches = [];
    _sourceMatches.clear();
    _limited = false;
    _invalidPattern = false;
    _pattern = null;
    if (query.isEmpty || !widget.enabled) return;
    late RegExp pattern;
    try {
      pattern = RegExp(
        _regex ? query : RegExp.escape(query),
        caseSensitive: _caseSensitive,
      );
      _pattern = pattern;
    } on FormatException {
      _invalidPattern = true;
      return;
    }
    if (_scope == _Scope.source) {
      final searchSource = _ignoreWhitespace
          ? _stripWhitespace(source)
          : source;
      final searchQuery = _ignoreWhitespace ? _stripWhitespace(query) : query;
      if (_ignoreWhitespace && searchQuery.isEmpty) {
        _matches = [];
        _limited = false;
        return;
      }
      late RegExp pattern;
      try {
        pattern = RegExp(
          _regex ? searchQuery : RegExp.escape(searchQuery),
          caseSensitive: _caseSensitive,
        );
      } on FormatException {
        _invalidPattern = true;
        return;
      }
      _pattern = pattern;
      if (_ignoreWhitespace) {
        final mapping = _buildIndexMapping(source);
        for (final match
            in pattern.allMatches(searchSource).take(_matchLimit + 1)) {
          final start = match.start < mapping.length
              ? mapping[match.start]
              : source.length;
          final end = match.start == match.end
              ? start
              : mapping[match.end - 1] + 1;
          final range = (start: start, end: end);
          _matches.add(range);
          _sourceMatches[range] = match;
        }
      } else {
        for (final match
            in pattern.allMatches(searchSource).take(_matchLimit + 1)) {
          final range = (start: match.start, end: match.end);
          _matches.add(range);
          _sourceMatches[range] = match;
        }
      }
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

  /// Removes all whitespace characters from [text].
  String _stripWhitespace(String text) {
    return text.replaceAll(RegExp(r'\s+'), '');
  }

  /// Checks if a character is whitespace (same regex as _stripWhitespace).
  static bool _isWhitespace(String c) => RegExp(r'\s').hasMatch(c);

  /// Builds a mapping from normalized (whitespace-stripped) index to original
  /// index. [mapping][i] is the index in the original string for the i-th
  /// non-whitespace character. Used to translate match positions back to the
  /// original document when ignoring whitespace.
  List<int> _buildIndexMapping(String text) {
    final mapping = <int>[];
    for (var i = 0; i < text.length; i++) {
      if (!_isWhitespace(text[i])) {
        mapping.add(i);
      }
    }
    return mapping;
  }

  void _replace(bool all) {
    if (_matches.isEmpty || _pattern == null || widget.onReplace == null) {
      return;
    }
    // A capped result set cannot represent a complete replace-all operation.
    if (all && _limited) return;
    final source = widget.document.source.text;
    final ranges = all ? _matches : [_matches[_index < 0 ? 0 : _index]];
    var result = source;
    for (final range in ranges.reversed) {
      final raw = source.substring(range.start, range.end);
      String replacement;
      if (_scope == _Scope.source) {
        replacement = _regex
            ? expandRegexReplacement(_replacement.text, _sourceMatches[range]!)
            : _replacement.text;
      } else {
        final isString = raw.startsWith('"');
        final value = isString ? jsonDecode(raw) as String : raw;
        final replaced = value.replaceAllMapped(
          _pattern!,
          (match) => _regex
              ? expandRegexReplacement(_replacement.text, match)
              : _replacement.text,
        );
        replacement = isString ? jsonEncode(replaced) : replaced;
        if (!isString) {
          final parsed = parseJson(replacement);
          if (parsed.root == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  AppLocalizations.of(
                    context,
                  ).diagnosticMessage(parsed.diagnostics.first),
                ),
              ),
            );
            return;
          }
        }
      }
      result = result.replaceRange(range.start, range.end, replacement);
    }
    widget.onReplace!(result);
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
    if (_matches.isEmpty) widget.onNoMatch?.call();
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
        : _invalidPattern
        ? strings.invalidRegex
        : _query.text.isEmpty
        ? ''
        : _matches.isEmpty
        ? strings.noMatches
        : '${_index < 0 ? '–' : _index + 1}/${_matches.length}${_limited ? '+' : ''}';
    final colors = theme.colorScheme;
    final controlHeight = WorkbenchStyle.inputHeightFor(
      context,
      theme.textTheme.bodyMedium!,
    );
    final statusStyle = theme.textTheme.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
    );
    final actionStyle = workbenchDialogButtonStyle(context).copyWith(
      fixedSize: WidgetStatePropertyAll(Size.fromHeight(controlHeight)),
    );
    const radius = BorderRadius.all(
      Radius.circular(WorkbenchStyle.controlRadius),
    );
    return Material(
      color: colors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: WorkbenchStyle.space12,
          vertical: WorkbenchStyle.space8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: WorkbenchTextField(
                    autofocus: true,
                    focusNode: widget.focusNode,
                    controller: _query,
                    style: theme.textTheme.bodyMedium,
                    hintText: strings.findInDocument,
                    prefixIcon: Icon(
                      CupertinoIcons.search,
                      size: WorkbenchStyle.controlIconSize,
                      color: colors.onSurfaceVariant,
                    ),
                    suffixIcon: status.isEmpty
                        ? null
                        : Tooltip(
                            key: const ValueKey('find-status'),
                            message: status,
                            child: Padding(
                              padding: EdgeInsets.only(right: 8),
                              child: Text(
                                status,
                                maxLines: 1,
                                style: statusStyle,
                              ),
                            ),
                          ),
                    suffixIconConstraints: const BoxConstraints(
                      minWidth: 0,
                      minHeight: 0,
                    ),
                    onChanged: (_) => _search(),
                    onEditingComplete: () => _move(1),
                  ),
                ),
                const SizedBox(width: WorkbenchStyle.space8),
                if (widget.onReplace != null) ...[
                  Tooltip(
                    message: _showReplace
                        ? strings.hideReplace
                        : strings.showReplace,
                    child: Semantics(
                      expanded: _showReplace,
                      child: TextButton.icon(
                        style: workbenchDialogButtonStyle(context).copyWith(
                          minimumSize: WidgetStatePropertyAll(
                            Size(0, controlHeight),
                          ),
                          padding: const WidgetStatePropertyAll(
                            EdgeInsets.symmetric(
                              horizontal: WorkbenchStyle.space8,
                            ),
                          ),
                          backgroundColor: WidgetStatePropertyAll(
                            _showReplace
                                ? colors.secondaryContainer
                                : colors.surface,
                          ),
                          foregroundColor: WidgetStatePropertyAll(
                            _showReplace
                                ? colors.onSecondaryContainer
                                : colors.onSurface,
                          ),
                          side: WidgetStatePropertyAll(
                            BorderSide(
                              color: _showReplace
                                  ? colors.primary
                                  : colors.outlineVariant,
                            ),
                          ),
                        ),
                        onPressed: () {
                          setState(() => _showReplace = !_showReplace);
                          widget.focusNode.requestFocus();
                        },
                        icon: const Icon(
                          CupertinoIcons.arrow_2_squarepath,
                          size: 14,
                        ),
                        label: Text(strings.replace),
                      ),
                    ),
                  ),
                  const SizedBox(width: WorkbenchStyle.space8),
                ],
                _toggle(strings.matchCase, 'Aa', _caseSensitive, (value) {
                  _caseSensitive = value;
                  _search();
                }),
                const SizedBox(width: WorkbenchStyle.space4),
                _toggle(strings.useRegex, '.*', _regex, (value) {
                  _regex = value;
                  _search();
                }),
                const SizedBox(width: WorkbenchStyle.space8),
                _toggle(strings.ignoreWhitespace, '∅', _ignoreWhitespace, (
                  value,
                ) {
                  _ignoreWhitespace = value;
                  _search();
                }),
                const SizedBox(width: WorkbenchStyle.space8),
                PopupMenuButton<_Scope>(
                  initialValue: _scope,
                  onSelected: (scope) {
                    _scope = scope;
                    _search();
                  },
                  itemBuilder: (context) => [
                    for (final entry in labels.entries.where(
                      (entry) =>
                          widget.structured || entry.key == _Scope.source,
                    ))
                      WorkbenchMenuItem(
                        value: entry.key,
                        label: entry.value,
                        checked: entry.key == _scope,
                      ),
                  ],
                  child: SizedBox(
                    height: controlHeight,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: radius,
                        border: Border.all(color: colors.outlineVariant),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: WorkbenchStyle.space8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              labels[_scope]!,
                              style: theme.textTheme.labelMedium,
                            ),
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
                ),
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
                _button(
                  strings.closeFind,
                  CupertinoIcons.xmark,
                  widget.onClose,
                ),
              ],
            ),
            if (widget.onReplace != null && _showReplace) ...[
              const SizedBox(height: WorkbenchStyle.space8),
              Row(
                children: [
                  Expanded(
                    child: WorkbenchTextField(
                      controller: _replacement,
                      style: theme.textTheme.bodyMedium,
                      hintText: strings.replaceText,
                      onSubmitted: (_) => _replace(false),
                    ),
                  ),
                  const SizedBox(width: WorkbenchStyle.space8),
                  TextButton(
                    style: actionStyle,
                    onPressed: _matches.isEmpty ? null : () => _replace(false),
                    child: Text(strings.replaceCurrent),
                  ),
                  const SizedBox(width: WorkbenchStyle.space8),
                  TextButton(
                    style: actionStyle,
                    onPressed: _matches.isEmpty || _limited
                        ? null
                        : () => _replace(true),
                    child: Text(strings.replaceAll),
                  ),
                ],
              ),
              if (_regex)
                Padding(
                  padding: const EdgeInsets.only(top: WorkbenchStyle.space4),
                  child: Text(
                    strings.captureReplacementHelp,
                    style: WorkbenchStyle.caption.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _toggle(
    String label,
    String symbol,
    bool selected,
    ValueChanged<bool> onChanged,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final height = WorkbenchStyle.inputHeightFor(
      context,
      theme.textTheme.bodyMedium!,
    );
    return Tooltip(
      message: label,
      child: TextButton(
        style: workbenchDialogButtonStyle(context).copyWith(
          minimumSize: WidgetStatePropertyAll(Size(30, height)),
          fixedSize: WidgetStatePropertyAll(Size.fromHeight(height)),
          backgroundColor: WidgetStatePropertyAll(
            selected ? colors.secondaryContainer : colors.surface,
          ),
          foregroundColor: WidgetStatePropertyAll(
            selected ? colors.onSecondaryContainer : colors.onSurfaceVariant,
          ),
          side: WidgetStatePropertyAll(
            BorderSide(
              color: selected ? colors.primary : colors.outlineVariant,
            ),
          ),
        ),
        onPressed: () => onChanged(!selected),
        child: Semantics(label: label, toggled: selected, child: Text(symbol)),
      ),
    );
  }

  Widget _button(String label, IconData icon, VoidCallback? onPressed) {
    final height = WorkbenchStyle.inputHeightFor(
      context,
      Theme.of(context).textTheme.bodyMedium!,
    );
    return IconButton(
      tooltip: label,
      onPressed: onPressed,
      icon: Icon(icon, size: 14),
      style: IconButton.styleFrom(
        minimumSize: Size(30, height),
        fixedSize: Size(30, height),
        visualDensity: VisualDensity.standard,
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WorkbenchStyle.controlRadius),
        ),
      ),
    );
  }
}
