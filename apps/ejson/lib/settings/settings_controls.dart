part of 'settings_panel.dart';

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(WorkbenchStyle.groupRadius),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: WorkbenchStyle.space12,
          vertical: WorkbenchStyle.space4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

double _settingsRowHeight(BuildContext context) {
  final text = Theme.of(context).textTheme.bodyMedium!;
  final twoLines =
      MediaQuery.textScalerOf(context).scale(text.fontSize!) *
      (text.height ?? 1.38) *
      2;
  return (twoLines + WorkbenchStyle.space16).clamp(
    WorkbenchStyle.settingsRowHeight,
    double.infinity,
  );
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.label,
    required this.icon,
    required this.child,
    this.detail,
  });

  final String label;
  final IconData icon;
  final Widget child;
  final String? detail;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: ValueKey('settings-row-$label'),
    height: _settingsRowHeight(context),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: WorkbenchStyle.space8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: _SettingsLabel(label: label, icon: icon, detail: detail),
          ),
          const SizedBox(width: WorkbenchStyle.space12),
          Expanded(
            flex: 3,
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: child,
            ),
          ),
        ],
      ),
    ),
  );
}

class _SettingsLabel extends StatelessWidget {
  const _SettingsLabel({required this.label, required this.icon, this.detail});

  final String label;
  final IconData icon;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          icon,
          size: WorkbenchStyle.controlIconSize,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: WorkbenchStyle.space8),
        Flexible(
          child: Text.rich(
            TextSpan(
              text: label,
              children: [
                if (detail != null)
                  TextSpan(
                    text: '  $detail',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

class _SettingsSelector<T extends Object> extends StatelessWidget {
  const _SettingsSelector({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final Map<T, String> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: WorkbenchStyle.inputHeightFor(
        context,
        Theme.of(context).textTheme.bodyMedium!,
      ),
      child: CupertinoSlidingSegmentedControl<T>(
        backgroundColor: colors.surfaceContainer,
        thumbColor: colors.surfaceContainerLow,
        groupValue: selected,
        children: {
          for (final option in options.entries)
            option.key: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: WorkbenchStyle.space8,
                vertical: WorkbenchStyle.space4,
              ),
              child: Text(
                option.value,
                textAlign: TextAlign.center,
                style: WorkbenchStyle.body.copyWith(
                  color: option.key == selected
                      ? colors.onSurface
                      : colors.onSurfaceVariant,
                ),
              ),
            ),
        },
        onValueChanged: (value) {
          if (value != null) onChanged(value);
        },
      ),
    );
  }
}

class _StylePicker<T> extends StatelessWidget {
  const _StylePicker({
    required this.label,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final Map<T, String> options;
  final T selected;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PopupMenuButton<T>(
      tooltip: label,
      enabled: onChanged != null,
      constraints: const BoxConstraints(minWidth: 185, maxWidth: 260),
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final option in options.entries)
          WorkbenchMenuItem(
            value: option.key,
            checked: option.key == selected,
            label: option.value,
          ),
      ],
      child: SizedBox(
        height: WorkbenchStyle.inputHeightFor(
          context,
          Theme.of(context).textTheme.bodyMedium!,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            border: Border.all(color: colors.outlineVariant),
            borderRadius: BorderRadius.circular(WorkbenchStyle.controlRadius),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: WorkbenchStyle.space8,
              vertical: WorkbenchStyle.space4,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: Text(options[selected]!)),
                const SizedBox(width: WorkbenchStyle.space8),
                Icon(
                  CupertinoIcons.chevron_up_chevron_down,
                  color: colors.onSurfaceVariant,
                  size: WorkbenchStyle.controlIconSize,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
