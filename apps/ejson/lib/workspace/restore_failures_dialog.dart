import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../design/workbench_style.dart';
import '../l10n/app_localizations.dart';
import 'recent_file.dart';

/// Lists workspace files that could not be restored using the shared dialog UI.
class RestoreFailuresDialog extends StatelessWidget {
  const RestoreFailuresDialog({super.key, required this.paths});

  final List<String> paths;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final maxListHeight = math.min(
      300.0,
      math.max(140.0, MediaQuery.sizeOf(context).height - 300),
    );
    return WorkbenchDialog(
      title: strings.restoreFailed,
      scrollable: false,
      content: SizedBox(
        width: 500,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              strings.restoreFailedDescription,
              style: WorkbenchStyle.body.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: WorkbenchStyle.space12),
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border.all(color: colors.outlineVariant),
                borderRadius: BorderRadius.circular(
                  WorkbenchStyle.controlRadius,
                ),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxListHeight),
                child: ListView.separated(
                  key: const ValueKey('restore-failures-list'),
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: paths.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: colors.outlineVariant),
                  itemBuilder: (context, index) {
                    final path = paths[index];
                    return _RestoreFailureRow(path: path, index: index);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          style: workbenchDialogButtonStyle(
            context,
            role: DialogButtonRole.primary,
          ),
          onPressed: () => Navigator.pop(context),
          child: Text(strings.done),
        ),
      ],
    );
  }
}

class _RestoreFailureRow extends StatelessWidget {
  const _RestoreFailureRow({required this.path, required this.index});

  final String path;
  final int index;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: path,
      child: Padding(
        key: ValueKey('restore-failure-row:$index'),
        padding: const EdgeInsets.symmetric(
          horizontal: WorkbenchStyle.space12,
          vertical: WorkbenchStyle.space8,
        ),
        child: Row(
          children: [
            Icon(
              CupertinoIcons.doc_text,
              size: WorkbenchStyle.controlIconSize,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(width: WorkbenchStyle.space8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    RecentFile(path).name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: WorkbenchStyle.body,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    path,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: WorkbenchStyle.caption.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: WorkbenchStyle.space8),
            Icon(
              CupertinoIcons.exclamationmark_circle,
              size: 14,
              color: colors.error,
            ),
          ],
        ),
      ),
    );
  }
}
