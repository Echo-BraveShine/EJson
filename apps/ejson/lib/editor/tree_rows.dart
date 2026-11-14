part of 'tree_panel.dart';

extension _TreeRows on _TreePanelState {
  Widget _treeRow(
    _Row row,
    int index,
    JsonTreeStyle style,
    TextStyle code,
    double indent,
    ColorScheme colors,
  ) {
    final strings = AppLocalizations.of(context);
    final node = row.node;
    final range = node.range;
    final hasChildren = node.children.isNotEmpty;
    final expanded = _expanded.contains(row.path);
    final preview = switch (node.kind) {
      JsonKind.object => '{${node.children.length}}',
      JsonKind.array => '[${node.children.length}]',
      _ => widget.source.substring(
        range.start,
        (range.start + 120).clamp(0, range.end),
      ),
    };
    final selected = widget.current && _selected == row.path;
    return Material(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WorkbenchStyle.controlRadius),
        side: style == JsonTreeStyle.outline && (hasChildren || selected)
            ? BorderSide(color: colors.outlineVariant)
            : BorderSide.none,
      ),
      color: selected
          ? colors.secondaryContainer
          : style == JsonTreeStyle.striped && index.isOdd
          ? colors.surfaceContainer
          : Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(WorkbenchStyle.controlRadius),
        onTap: widget.current
            ? () {
                _updateView(() => _selected = row.path);
                widget.onReveal(range);
              }
            : null,
        onDoubleTap: widget.current && !widget.readOnly
            ? () => widget.onEdit(range, false)
            : null,
        child: CustomPaint(
          key: ValueKey('tree-row:${row.path}'),
          painter: style == JsonTreeStyle.guides
              ? HierarchyGuidePainter(
                  row.continuation,
                  indent,
                  colors.outlineVariant,
                )
              : null,
          child: Padding(
            padding: EdgeInsets.only(left: 2.0 + indent * row.depth, right: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: hasChildren
                      ? IconButton(
                          key: ValueKey('expand:${row.path}'),
                          padding: EdgeInsets.zero,
                          iconSize: 12,
                          tooltip: expanded ? strings.collapse : strings.expand,
                          onPressed: () => _updateView(() {
                            if (!_expanded.remove(row.path)) {
                              _expanded.add(row.path);
                            }
                          }),
                          icon: Icon(
                            expanded
                                ? CupertinoIcons.chevron_down
                                : CupertinoIcons.chevron_right,
                          ),
                        )
                      : null,
                ),
                if (style.typeIcons) ...[
                  Icon(
                    switch (node.kind) {
                      JsonKind.object => CupertinoIcons.cube_box,
                      JsonKind.array => CupertinoIcons.list_bullet,
                      JsonKind.string => CupertinoIcons.textformat,
                      JsonKind.number => CupertinoIcons.number,
                      JsonKind.boolean => CupertinoIcons.checkmark_square,
                      JsonKind.nil => CupertinoIcons.nosign,
                    },
                    key: ValueKey('tree-type:${row.path}'),
                    semanticLabel: node.kind == JsonKind.nil
                        ? 'null'
                        : node.kind.name,
                    size: WorkbenchStyle.controlIconSize,
                    color: style.valueColor(node.kind, colors),
                  ),
                  const SizedBox(width: WorkbenchStyle.space8),
                ],
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          row.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: code.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: code.copyWith(
                            color: style.valueColor(node.kind, colors),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.current && !widget.readOnly ||
                    hasChildren && row.depth > 0)
                  _nodeMenu(row),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
