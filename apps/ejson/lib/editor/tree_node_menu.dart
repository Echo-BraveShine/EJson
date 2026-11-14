part of 'tree_panel.dart';

enum _NodeAction {
  focus,
  replace,
  rename,
  add,
  delete,
  copyPath,
  extract,
  copyValue,
  copyString,
  table,
  moveUp,
  moveDown,
  duplicate,
  sort,
}

extension _TreeNodeMenus on _TreePanelState {
  Widget _nodeMenu(_Row row) {
    final strings = AppLocalizations.of(context);
    final node = row.node;
    final range = node.range;
    final hasChildren = node.children.isNotEmpty;
    return PopupMenuButton<_NodeAction>(
      key: ValueKey('node-menu:${row.path}'),
      tooltip: widget.current ? strings.editNode : strings.nodeActions,
      child: const SizedBox(
        width: 28,
        height: 24,
        child: Icon(CupertinoIcons.ellipsis, size: 15),
      ),
      onSelected: (action) {
        switch (action) {
          case _NodeAction.sort:
            widget.onSortArray?.call(node);
          case _NodeAction.moveUp:
            widget.onMoveArrayItem?.call(
              _parent(row.steps)!,
              row.steps.last.index,
              -1,
            );
          case _NodeAction.moveDown:
            widget.onMoveArrayItem?.call(
              _parent(row.steps)!,
              row.steps.last.index,
              1,
            );
          case _NodeAction.duplicate:
            widget.onDuplicateArrayItem?.call(
              _parent(row.steps)!,
              row.steps.last.index,
            );
          case _NodeAction.copyValue:
            widget.onCopyValue?.call(range, false);
          case _NodeAction.copyString:
            widget.onCopyValue?.call(range, true);
          case _NodeAction.table:
            widget.onTable?.call(node);
          case _NodeAction.extract:
            widget.onExtract?.call(range);
          case _NodeAction.focus:
            _focusOn(row.steps);
          case _NodeAction.replace:
            widget.onEdit(range, false);
          case _NodeAction.rename:
            widget.onEdit(row.keyRange!, true);
          case _NodeAction.add:
            widget.onAdd?.call(node);
          case _NodeAction.delete:
            var parent = widget.snapshot.root!;
            for (final step in row.steps.take(row.steps.length - 1)) {
              parent = parent.children[step.index].value;
            }
            widget.onDelete?.call(parent, row.steps.last.index);
          case _NodeAction.copyPath:
            widget.onCopyPath?.call(
              formatJsonPath(
                row.steps.map(
                  (step) => (
                    key: step.key,
                    index: step.key == null ? step.index : null,
                  ),
                ),
              ),
            );
        }
      },
      itemBuilder: (context) {
        final parent = _parent(row.steps);
        final arrayItem = parent?.kind == JsonKind.array;
        return [
          if (hasChildren && row.depth > 0)
            WorkbenchMenuItem(
              value: _NodeAction.focus,
              icon: Icons.center_focus_strong_outlined,
              label: strings.focusSubtree,
            ),
          if (widget.current && !widget.readOnly) ...[
            if (arrayItem) ...[
              if (widget.onMoveArrayItem != null && row.steps.last.index > 0)
                WorkbenchMenuItem(
                  value: _NodeAction.moveUp,
                  icon: CupertinoIcons.arrow_up,
                  label: strings.moveArrayItemUp,
                ),
              if (widget.onMoveArrayItem != null &&
                  row.steps.last.index < parent!.children.length - 1)
                WorkbenchMenuItem(
                  value: _NodeAction.moveDown,
                  icon: CupertinoIcons.arrow_down,
                  label: strings.moveArrayItemDown,
                ),
              if (widget.onDuplicateArrayItem != null)
                WorkbenchMenuItem(
                  value: _NodeAction.duplicate,
                  icon: CupertinoIcons.plus_square_on_square,
                  label: strings.duplicateArrayItem,
                ),
            ],
            if (widget.onSortArray != null &&
                node.kind == JsonKind.array &&
                node.children.length > 1)
              WorkbenchMenuItem(
                value: _NodeAction.sort,
                icon: CupertinoIcons.sort_down,
                label: strings.sortArray,
              ),
            if (widget.onTable != null && node.kind == JsonKind.array)
              WorkbenchMenuItem(
                value: _NodeAction.table,
                icon: CupertinoIcons.table,
                label: strings.arrayTable,
              ),
            if (widget.onCopyValue != null) ...[
              WorkbenchMenuItem(
                value: _NodeAction.copyValue,
                icon: CupertinoIcons.doc_on_doc,
                label: strings.copyNodeValue,
              ),
              if (node.kind == JsonKind.string)
                WorkbenchMenuItem(
                  value: _NodeAction.copyString,
                  icon: CupertinoIcons.text_quote,
                  label: strings.copyDecodedString,
                ),
            ],
            if (widget.onExtract != null)
              WorkbenchMenuItem(
                value: _NodeAction.extract,
                icon: CupertinoIcons.doc_on_doc,
                label: strings.extractSubtree,
              ),
            if (widget.onCopyPath != null)
              WorkbenchMenuItem(
                value: _NodeAction.copyPath,
                icon: CupertinoIcons.doc_on_doc,
                label: strings.copyJsonPath,
              ),
            if (widget.onAdd != null &&
                (node.kind == JsonKind.array || node.kind == JsonKind.object))
              WorkbenchMenuItem(
                value: _NodeAction.add,
                icon: CupertinoIcons.plus,
                label: node.kind == JsonKind.object
                    ? strings.addProperty
                    : strings.addArrayItem,
              ),
            if (widget.onDelete != null && row.steps.isNotEmpty)
              WorkbenchMenuItem(
                value: _NodeAction.delete,
                icon: CupertinoIcons.trash,
                label: strings.deleteNode,
              ),
            WorkbenchMenuItem(
              value: _NodeAction.replace,
              icon: CupertinoIcons.arrow_left_right,
              label: strings.replaceValue,
            ),
            if (row.keyRange != null)
              WorkbenchMenuItem(
                value: _NodeAction.rename,
                icon: CupertinoIcons.pencil,
                label: strings.renameKey,
              ),
          ],
        ];
      },
    );
  }
}
