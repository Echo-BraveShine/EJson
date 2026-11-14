import 'dart:convert';

import 'package:ejson_core/ejson_core.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

class DocumentStatistics extends StatefulWidget {
  const DocumentStatistics({
    super.key,
    required this.document,
    this.bom = false,
  });

  final JsonDocument document;
  final bool bom;

  @override
  State<DocumentStatistics> createState() => _DocumentStatisticsState();
}

class _DocumentStatisticsState extends State<DocumentStatistics> {
  late int _bytes;
  int _nodes = 0;
  int _depth = 0;
  int _arrayLength = 0;

  @override
  void initState() {
    super.initState();
    _measure();
  }

  @override
  void didUpdateWidget(covariant DocumentStatistics oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.document != oldWidget.document || widget.bom != oldWidget.bom) {
      _measure();
    }
  }

  void _measure() {
    _bytes =
        utf8.encode(widget.document.source.text).length + (widget.bom ? 3 : 0);
    _nodes = 0;
    _depth = 0;
    _arrayLength = 0;
    void visit(JsonNode node, int depth) {
      _nodes++;
      if (depth > _depth) _depth = depth;
      if (node.kind == JsonKind.array && node.children.length > _arrayLength) {
        _arrayLength = node.children.length;
      }
      for (final child in node.children) {
        visit(child.value, depth + 1);
      }
    }

    final root = widget.document.snapshot?.root;
    if (root != null) visit(root, 0);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final size = _bytes < 1024
        ? '$_bytes B'
        : _bytes < 1024 * 1024
        ? '${(_bytes / 1024).toStringAsFixed(1)} KiB'
        : '${(_bytes / (1024 * 1024)).toStringAsFixed(1)} MiB';
    final details = widget.document.isValid
        ? strings.documentStatistics(_bytes, _nodes, _depth, _arrayLength)
        : strings.documentBytes(_bytes);
    return Tooltip(
      message: details,
      child: Semantics(
        label: details,
        child: Text(
          widget.document.isValid
              ? '$size · ${strings.nodeCount(_nodes)}'
              : size,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}
