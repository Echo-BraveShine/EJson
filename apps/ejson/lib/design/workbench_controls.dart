part of 'workbench_style.dart';

/// Dialog layout shared by settings, document confirmation and node editors.
class WorkbenchDialog extends StatelessWidget {
  const WorkbenchDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
    this.scrollable = true,
  });

  final String title;
  final Widget content;
  final List<Widget> actions;
  final bool scrollable;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(title),
    titlePadding: const EdgeInsets.fromLTRB(
      WorkbenchStyle.space20,
      WorkbenchStyle.space20,
      WorkbenchStyle.space20,
      0,
    ),
    content: content,
    contentPadding: const EdgeInsets.fromLTRB(
      WorkbenchStyle.space20,
      WorkbenchStyle.space12,
      WorkbenchStyle.space20,
      WorkbenchStyle.space16,
    ),
    scrollable: scrollable,
    actions: actions,
  );
}

/// A labeled selector using the same menu rows as the workbench toolbar.
class WorkbenchSelect<T> extends StatelessWidget {
  const WorkbenchSelect({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<({T value, String label})> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: WorkbenchStyle.label),
        const SizedBox(height: WorkbenchStyle.space4),
        PopupMenuButton<T>(
          tooltip: label,
          initialValue: value,
          onSelected: onChanged,
          itemBuilder: (_) => [
            for (final option in options)
              WorkbenchMenuItem(
                value: option.value,
                label: option.label,
                checked: option.value == value,
              ),
          ],
          child: Container(
            constraints: const BoxConstraints(
              minHeight: WorkbenchStyle.inputHeight,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: WorkbenchStyle.space8,
              vertical: WorkbenchStyle.space4,
            ),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(WorkbenchStyle.controlRadius),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    options.firstWhere((option) => option.value == value).label,
                    style: WorkbenchStyle.body,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
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
      ],
    );
  }
}

/// A compact macOS-style checkbox with a square, lightly rounded indicator.
class WorkbenchCheckbox extends StatelessWidget {
  const WorkbenchCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.controlKey,
    this.tristate = false,
    this.semanticLabel,
  });

  final bool? value;
  final ValueChanged<bool?>? onChanged;
  final Key? controlKey;
  final bool tristate;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final enabled = onChanged != null;
    final borderColor = enabled
        ? colors.onSurface.withValues(alpha: .28)
        : colors.outlineVariant;
    return SizedBox(
      width: 24,
      height: 24,
      child: Theme(
        data: Theme.of(context).copyWith(
          checkboxTheme: CheckboxThemeData(
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(3.5)),
            ),
            side: WidgetStateBorderSide.resolveWith(
              (states) => BorderSide(
                color: states.contains(WidgetState.selected)
                    ? colors.primary
                    : borderColor,
              ),
            ),
            fillColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? colors.primary
                  : Colors.transparent,
            ),
            checkColor: WidgetStatePropertyAll(colors.onPrimary),
            overlayColor: WidgetStatePropertyAll(
              colors.primary.withValues(alpha: .10),
            ),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
          ),
        ),
        child: Checkbox(
          key: controlKey,
          value: value,
          tristate: tristate,
          semanticLabel: semanticLabel,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// Compact form controls and fixed dialog chrome for document tools.
class WorkbenchToolDialog extends StatelessWidget {
  const WorkbenchToolDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
    this.scrollable = true,
  });

  final String title;
  final Widget content;
  final List<Widget> actions;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Theme(
      data: theme.copyWith(
        checkboxTheme: theme.checkboxTheme.copyWith(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
          side: BorderSide(color: colors.outlineVariant),
          visualDensity: VisualDensity.compact,
        ),
        textButtonTheme: TextButtonThemeData(
          style: workbenchDialogButtonStyle(context),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: workbenchDialogButtonStyle(
            context,
            role: DialogButtonRole.primary,
          ),
        ),
      ),
      child: WorkbenchDialog(
        title: title,
        scrollable: false,
        content: scrollable
            ? ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: (MediaQuery.sizeOf(context).height - 180).clamp(
                    220.0,
                    560.0,
                  ),
                ),
                child: SingleChildScrollView(child: content),
              )
            : content,
        actions: actions,
      ),
    );
  }
}

/// A translucent control surface over the workbench's own background.
class GlassGroup extends StatelessWidget {
  const GlassGroup({super.key, required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  static final _blur = ImageFilter.blur(sigmaX: 18, sigmaY: 18);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final colors = theme.colorScheme;
    const radius = BorderRadius.all(
      Radius.circular(WorkbenchStyle.groupRadius),
    );
    final glass = enabled && !MediaQuery.highContrastOf(context);
    if (!glass) {
      return Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: SizedBox(
            height: WorkbenchStyle.toolbarControlHeight,
            child: child,
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: _blur,
        child: Material(
          color: colors.surface.withValues(alpha: dark ? .40 : .58),
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(
              color: colors.outlineVariant.withValues(alpha: .80),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: SizedBox(
              height: WorkbenchStyle.toolbarControlHeight,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Consistent compact menu rows with aligned icons and optional checkmarks.
class WorkbenchMenuItem<T> extends PopupMenuItem<T> {
  WorkbenchMenuItem({
    super.key,
    required T super.value,
    IconData? icon,
    required String label,
    bool checked = false,
    super.enabled,
  }) : super(
         height: WorkbenchStyle.rowHeight,
         padding: const EdgeInsets.symmetric(horizontal: 10),
         child: Builder(
           builder: (context) {
             final colors = Theme.of(context).colorScheme;
             return Row(
               children: [
                 if (icon != null) ...[
                   Icon(
                     icon,
                     size: WorkbenchStyle.controlIconSize,
                     color: checked ? colors.primary : colors.onSurfaceVariant,
                   ),
                   const SizedBox(width: 10),
                 ],
                 Expanded(
                   child: Text(
                     label,
                     style: checked
                         ? TextStyle(
                             color: colors.primary,
                             fontWeight: FontWeight.w600,
                           )
                         : null,
                   ),
                 ),
                 const SizedBox(width: 10),
                 SizedBox(
                   width: 14,
                   child: checked
                       ? Icon(
                           CupertinoIcons.checkmark,
                           size: 14,
                           color: colors.primary,
                         )
                       : null,
                 ),
               ],
             );
           },
         ),
       );
}
