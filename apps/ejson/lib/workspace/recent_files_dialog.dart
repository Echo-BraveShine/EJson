import '../design/workbench_text_field.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/workbench_style.dart';
import '../l10n/app_localizations.dart';
import '../settings/tool_preferences.dart';

class RecentFilesDialog extends ConsumerStatefulWidget {
  const RecentFilesDialog({super.key});

  @override
  ConsumerState<RecentFilesDialog> createState() => _RecentFilesDialogState();
}

class _RecentFilesDialogState extends ConsumerState<RecentFilesDialog> {
  final _search = TextEditingController();
  bool _saving = false;
  bool _failed = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _change(Future<bool> Function() save) async {
    setState(() {
      _saving = true;
      _failed = false;
    });
    final saved = await save();
    if (!mounted) return;
    setState(() {
      _saving = false;
      _failed = !saved;
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final all = ref.watch(toolPreferencesProvider).recentFiles;
    final query = _search.text.toLowerCase();
    final files = all
        .where((file) => file.path.toLowerCase().contains(query))
        .toList();
    final controller = ref.read(toolPreferencesProvider.notifier);
    return WorkbenchDialog(
      title: strings.recentFiles,
      scrollable: false,
      content: SizedBox(
        width: 560,
        height: (MediaQuery.sizeOf(context).height * .55).clamp(180.0, 460.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            WorkbenchTextField(
              autofocus: true,
              controller: _search,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) {
                if (!_saving && files.isNotEmpty) {
                  Navigator.pop(context, files.first);
                }
              },
              hintText: strings.searchRecentFiles,
              prefixIcon: const Icon(
                CupertinoIcons.search,
                size: WorkbenchStyle.controlIconSize,
              ),
            ),
            const SizedBox(height: WorkbenchStyle.space8),
            if (_failed)
              Padding(
                padding: const EdgeInsets.only(bottom: WorkbenchStyle.space8),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    strings.toolPreferenceFailed,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ),
            Expanded(
              child: files.isEmpty
                  ? Center(
                      child: Text(
                        all.isEmpty ? strings.noRecentFiles : strings.noMatches,
                      ),
                    )
                  : ListView.builder(
                      itemCount: files.length,
                      itemBuilder: (context, index) {
                        final file = files[index];
                        return Tooltip(
                          message: file.path,
                          child: ListTile(
                            dense: true,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                WorkbenchStyle.controlRadius,
                              ),
                            ),
                            enabled: !_saving,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: WorkbenchStyle.space4,
                            ),
                            leading: const Icon(
                              CupertinoIcons.doc_text,
                              size: WorkbenchStyle.controlIconSize,
                            ),
                            title: Text(
                              file.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              file.path,
                              style: WorkbenchStyle.caption.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: IconButton(
                              tooltip: strings.removeRecentFile,
                              onPressed: _saving
                                  ? null
                                  : () => _change(
                                      () => controller.removeRecentFile(
                                        file.path,
                                      ),
                                    ),
                              icon: const Icon(CupertinoIcons.xmark, size: 14),
                            ),
                            onTap: _saving
                                ? null
                                : () => Navigator.pop(context, file),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          style: workbenchDialogButtonStyle(context),
          onPressed: _saving || all.isEmpty
              ? null
              : () => _change(controller.clearRecentFiles),
          child: Text(strings.clearRecentFiles),
        ),
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
