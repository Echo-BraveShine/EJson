import 'dart:convert';

import 'package:ejson_core/ejson_core.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../design/workbench_style.dart';
import '../l10n/app_localizations.dart';

typedef ArraySortOptions = ({String? key, bool ascending});
typedef _SortField = ({String? key});

class ArraySortDialog extends StatefulWidget {
  const ArraySortDialog({super.key, required this.array});

  final JsonNode array;

  @override
  State<ArraySortDialog> createState() => _ArraySortDialogState();
}

class _ArraySortDialogState extends State<ArraySortDialog> {
  late final _keys = {
    for (final item in widget.array.children)
      if (item.value.kind == JsonKind.object)
        for (final field in item.value.children) field.key!,
  }.toList();
  late String? _key = _keys.firstOrNull;
  bool _ascending = true;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return WorkbenchDialog(
      title: strings.sortArray,
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(strings.sortField),
                const SizedBox(width: WorkbenchStyle.space12),
                Expanded(
                  child: PopupMenuButton<_SortField>(
                    tooltip: strings.sortField,
                    onSelected: (field) => setState(() => _key = field.key),
                    itemBuilder: (_) => [
                      WorkbenchMenuItem(
                        value: (key: null),
                        icon: CupertinoIcons.list_bullet,
                        label: strings.sortValue,
                        checked: _key == null,
                      ),
                      for (final key in _keys)
                        WorkbenchMenuItem(
                          value: (key: key),
                          icon: CupertinoIcons.tag,
                          label: jsonEncode(key),
                          checked: key == _key,
                        ),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.all(WorkbenchStyle.space8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _key == null
                                  ? strings.sortValue
                                  : jsonEncode(_key),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(CupertinoIcons.chevron_down, size: 12),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: WorkbenchStyle.space8),
            PopupMenuButton<bool>(
              tooltip: _ascending
                  ? strings.sortAscending
                  : strings.sortDescending,
              onSelected: (value) => setState(() => _ascending = value),
              itemBuilder: (_) => [
                WorkbenchMenuItem(
                  value: true,
                  icon: CupertinoIcons.arrow_up,
                  label: strings.sortAscending,
                  checked: _ascending,
                ),
                WorkbenchMenuItem(
                  value: false,
                  icon: CupertinoIcons.arrow_down,
                  label: strings.sortDescending,
                  checked: !_ascending,
                ),
              ],
              child: Padding(
                padding: const EdgeInsets.all(WorkbenchStyle.space8),
                child: Row(
                  children: [
                    Icon(
                      _ascending
                          ? CupertinoIcons.arrow_up
                          : CupertinoIcons.arrow_down,
                      size: WorkbenchStyle.controlIconSize,
                    ),
                    const SizedBox(width: WorkbenchStyle.space8),
                    Expanded(
                      child: Text(
                        _ascending
                            ? strings.sortAscending
                            : strings.sortDescending,
                      ),
                    ),
                    const Icon(CupertinoIcons.chevron_down, size: 12),
                  ],
                ),
              ),
            ),
            const SizedBox(height: WorkbenchStyle.space12),
            Text(
              strings.sortArrayHelp,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          style: workbenchDialogButtonStyle(context),
          onPressed: () => Navigator.pop(context),
          child: Text(strings.cancel),
        ),
        FilledButton(
          style: workbenchDialogButtonStyle(
            context,
            role: DialogButtonRole.primary,
          ),
          onPressed: () =>
              Navigator.pop(context, (key: _key, ascending: _ascending)),
          child: Text(strings.apply),
        ),
      ],
    );
  }
}
