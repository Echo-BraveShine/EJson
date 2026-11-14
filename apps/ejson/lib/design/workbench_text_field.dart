import 'package:flutter/material.dart';

import 'workbench_style.dart';

/// Shared form input geometry. Labels and feedback sit outside the input border.
class WorkbenchTextField extends StatelessWidget {
  const WorkbenchTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.autofocus = false,
    this.style,
    this.onChanged,
    this.onSubmitted,
    this.onEditingComplete,
    this.keyboardType,
    this.minLines,
    this.maxLines = 1,
    this.expands = false,
    this.labelText,
    this.hintText,
    this.errorText,
    this.errorMaxLines,
    this.prefixIcon,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool autofocus;
  final TextStyle? style;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onEditingComplete;
  final TextInputType? keyboardType;
  final int? minLines;
  final int? maxLines;
  final bool expands;
  final String? labelText;
  final String? hintText;
  final String? errorText;
  final int? errorMaxLines;
  final Widget? prefixIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolved = theme.textTheme.bodyMedium!.merge(style);
    final textStyle = maxLines == 1
        ? resolved.copyWith(height: WorkbenchStyle.body.height)
        : resolved;
    final height = WorkbenchStyle.inputHeightFor(context, textStyle);
    final field = Semantics(
      label: labelText,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: autofocus,
        style: textStyle,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        onEditingComplete: onEditingComplete,
        keyboardType: keyboardType,
        minLines: minLines,
        maxLines: maxLines,
        expands: expands,
        textAlignVertical: expands || maxLines != 1
            ? TextAlignVertical.top
            : TextAlignVertical.center,
        decoration: InputDecoration(
          isDense: maxLines == 1 ? false : null,
          constraints: maxLines == 1
              ? BoxConstraints.tightFor(height: height)
              : null,
          hintText: hintText,
          prefixIcon: prefixIcon,
          // Feedback is laid out below the fixed-height input surface.
          enabledBorder: errorText == null
              ? null
              : workbenchInputBorder(theme.colorScheme.error),
          focusedBorder: errorText == null
              ? null
              : workbenchInputBorder(theme.colorScheme.error),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: expands ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (labelText != null) ...[
          Text(
            labelText!,
            style: WorkbenchStyle.label.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: WorkbenchStyle.space4),
        ],
        if (expands)
          Expanded(child: field)
        else if (maxLines == 1)
          SizedBox(height: height, child: field)
        else
          field,
        if (errorText != null) ...[
          const SizedBox(height: WorkbenchStyle.space4),
          Semantics(
            liveRegion: true,
            child: Text(
              errorText!,
              maxLines: errorMaxLines,
              overflow: errorMaxLines == null ? null : TextOverflow.ellipsis,
              style: WorkbenchStyle.caption.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
