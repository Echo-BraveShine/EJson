part of 'settings_panel.dart';

class _ReleaseSettings extends StatefulWidget {
  const _ReleaseSettings();

  @override
  State<_ReleaseSettings> createState() => _ReleaseSettingsState();
}

class _ReleaseSettingsState extends State<_ReleaseSettings> {
  Version? _version;
  UpdateResult? _result;
  bool _checking = false;
  bool _checkFailed = false;
  bool _browserFailed = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final version = await installedVersion();
      if (mounted) setState(() => _version = version);
    } on Exception {
      // Package metadata may be unavailable in an unpackaged test build.
    }
  }

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _result = null;
      _checkFailed = false;
    });
    try {
      final version = _version ?? await installedVersion();
      final result = await checkForUpdate(version);
      if (mounted) setState(() => _result = result);
    } on Exception {
      if (mounted) setState(() => _checkFailed = true);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _open(Uri uri) async {
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Exception {
      // The desktop environment may have no default browser.
    }
    if (mounted) setState(() => _browserFailed = !opened);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final message = _checking
        ? strings.checkingUpdates
        : _checkFailed
        ? strings.updateFailed
        : switch (_result?.status) {
            UpdateStatus.available => strings.updateAvailable(
              '${_result!.latest}',
            ),
            UpdateStatus.current => strings.updateCurrent,
            UpdateStatus.noRelease => strings.noRelease,
            null => null,
          };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SettingsRow(
          label: strings.about,
          icon: CupertinoIcons.info_circle,
          detail: _version == null ? null : strings.versionLabel('$_version'),
          child: TextButton(
            onPressed: _checking ? null : _check,
            style: TextButton.styleFrom(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(strings.checkUpdates),
          ),
        ),
        if (message != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: WorkbenchStyle.controlIconSize + WorkbenchStyle.space8,
              bottom: WorkbenchStyle.space8,
            ),
            child: Semantics(
              liveRegion: true,
              child: Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        if (_result?.status == UpdateStatus.available)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => _open(latestReleasePage),
              child: Text(strings.downloadRelease),
            ),
          ),
        const Divider(height: 1),
        SizedBox(
          key: const ValueKey('settings-row-website'),
          height: _settingsRowHeight(context),
          child: TextButton(
            onPressed: () => _open(websitePage),
            style: TextButton.styleFrom(
              alignment: AlignmentDirectional.centerStart,
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, WorkbenchStyle.inputHeight),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.globe,
                  size: WorkbenchStyle.controlIconSize,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: WorkbenchStyle.space8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: .min,
                    children: [
                      Text(strings.website, style: WorkbenchStyle.body),
                      Text(
                        websitePage.toString(),
                        style: WorkbenchStyle.caption.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  CupertinoIcons.arrow_up_right,
                  size: WorkbenchStyle.controlIconSize,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        SizedBox(
          key: const ValueKey('settings-row-support'),
          height: _settingsRowHeight(context),
          child: TextButton(
            onPressed: () => _open(supportPage),
            style: TextButton.styleFrom(
              alignment: AlignmentDirectional.centerStart,
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, WorkbenchStyle.inputHeight),
              visualDensity: VisualDensity.standard,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: _SettingsLabel(
              label: strings.buyCoffee,
              icon: CupertinoIcons.heart,
            ),
          ),
        ),
        if (_browserFailed)
          Text(strings.browserFailed, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
