part of 'workbench.dart';

extension _WorkbenchSync on _WorkbenchState {
  Future<bool> _confirmDiskChange(String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => WorkbenchDialog(
          title: strings.diskSyncConflict,
          content: SizedBox(width: 420, child: Text(message)),
          actions: [
            TextButton(
              style: workbenchDialogButtonStyle(context),
              onPressed: () => Navigator.pop(context, false),
              child: Text(strings.cancel),
            ),
            FilledButton(
              style: workbenchDialogButtonStyle(
                context,
                role: DialogButtonRole.primary,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text(strings.done),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _compareDisk(WorkspaceTab tab, LocalJsonFile disk) =>
      showDialog<void>(
        context: context,
        builder: (context) => WorkbenchToolDialog(
          title: strings.diskSyncCompare,
          scrollable: false,
          content: SizedBox(
            width: 900,
            height: (MediaQuery.sizeOf(context).height - 180).clamp(
              220.0,
              650.0,
            ),
            child: Row(
              children: [
                for (final entry in [
                  (label: strings.diskSyncLocal, source: tab.text),
                  (label: strings.diskSyncDisk, source: disk.source),
                ])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(entry.label, style: WorkbenchStyle.heading),
                          const SizedBox(height: WorkbenchStyle.space8),
                          Expanded(
                            child: EJsonCodeEditor(
                              source: entry.source,
                              onChanged: (_) {},
                              readOnly: true,
                              format: tab.format,
                              highlight: widget.highlight,
                              useWorkspaceShortcuts: false,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              style: workbenchDialogButtonStyle(context),
              onPressed: () => Navigator.pop(context),
              child: Text(strings.done),
            ),
          ],
        ),
      );

  Widget _diskSyncBanner(WorkspaceTab tab, DiskSyncState sync) {
    if (sync.status != DiskSyncStatus.conflict &&
        sync.status != DiskSyncStatus.unavailable &&
        sync.status != DiskSyncStatus.failed) {
      return const SizedBox.shrink();
    }
    final disk = sync.external;
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              sync.status == DiskSyncStatus.conflict
                  ? strings.diskSyncConflictDescription
                  : strings.diskSyncError(
                      sync.error == null
                          ? tab.name
                          : strings.fileError(sync.error!),
                    ),
              style: WorkbenchStyle.body.copyWith(
                color: colors.onErrorContainer,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            Wrap(
              spacing: WorkbenchStyle.space8,
              children: [
                if (disk != null)
                  TextButton(
                    onPressed: () => _compareDisk(tab, disk),
                    child: Text(strings.diskSyncCompare),
                  ),
                if (sync.status == DiskSyncStatus.conflict)
                  TextButton(
                    onPressed: () async {
                      if (await _confirmDiskChange(
                            strings.diskSyncReloadConfirm,
                          ) &&
                          mounted) {
                        await ref
                            .read(diskSyncProvider.notifier)
                            .check(tab.id, reload: true);
                      }
                    },
                    child: Text(strings.diskSyncReload),
                  ),
                if (disk != null)
                  TextButton(
                    onPressed: () async {
                      if (await _confirmDiskChange(
                            strings.diskSyncOverwriteConfirm,
                          ) &&
                          mounted) {
                        await ref
                            .read(diskSyncProvider.notifier)
                            .overwrite(tab.id, disk);
                      }
                    },
                    child: Text(strings.diskSyncOverwrite),
                  ),
                TextButton(
                  onPressed: () => _save(tab.id, saveAs: true),
                  child: Text(strings.saveAs),
                ),
                TextButton(
                  onPressed: () => ref
                      .read(diskSyncProvider.notifier)
                      .check(tab.id, write: true),
                  child: Text(strings.diskSyncRetry),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
