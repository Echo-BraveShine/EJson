import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';

import 'workbench_typography.dart';

part 'workbench_controls.dart';

abstract final class WorkbenchStyle {
  static const space4 = 4.0;
  static const space8 = 8.0;
  static const space12 = 12.0;
  static const space16 = 16.0;
  static const space20 = 20.0;

  static const controlRadius = 7.0;
  static const inputHeight = 40.0;
  static const inputVerticalPadding = 10.0;
  static const settingsRowHeight = 56.0;
  static const groupRadius = 11.0;
  static const dialogRadius = 15.0;
  static const rowHeight = 32.0;
  static const toolbarControlHeight = 28.0;
  static const dialogButtonHeight = 30.0;
  static const controlIconSize = 16.0;

  static const caption = TextStyle(fontSize: 11, height: 1.3, letterSpacing: 0);
  static const label = TextStyle(fontSize: 12, height: 1.3, letterSpacing: 0);
  static const body = TextStyle(fontSize: 13, height: 1.38, letterSpacing: 0);
  static const heading = TextStyle(
    fontSize: 15,
    height: 1.3,
    letterSpacing: -.15,
    fontWeight: FontWeight.w600,
  );
  static const dialogTitle = TextStyle(
    fontSize: 17,
    height: 1.25,
    letterSpacing: -.2,
    fontWeight: FontWeight.w600,
  );
  static const menuElevation = 6.0;
  static const dialogElevation = 12.0;

  static double inputHeightFor(BuildContext context, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(
        text: 'Ag',
        style: style.copyWith(height: body.height),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final height = math.max(
      inputHeight,
      painter.height + inputVerticalPadding * 2,
    );
    painter.dispose();
    return height;
  }

  static String codeFont(TargetPlatform platform) => switch (platform) {
    TargetPlatform.macOS => 'Menlo',
    TargetPlatform.windows => 'Consolas',
    _ => 'monospace',
  };

  static TextStyle code(TargetPlatform platform) => TextStyle(
    fontFamily: codeFont(platform),
    fontFamilyFallback: WorkbenchTypography.codeFallback(platform),
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );
}

enum DialogButtonRole { secondary, destructive, primary }

ButtonStyle workbenchDialogButtonStyle(
  BuildContext context, {
  DialogButtonRole role = DialogButtonRole.secondary,
}) {
  final theme = Theme.of(context);
  final colors = theme.colorScheme;
  final primary = role == DialogButtonRole.primary;
  final background = primary ? colors.primary : colors.surface;
  final foreground = switch (role) {
    DialogButtonRole.primary =>
      theme.brightness == Brightness.dark ? colors.surface : Colors.white,
    DialogButtonRole.destructive => colors.error,
    DialogButtonRole.secondary => colors.onSurface,
  };
  return ButtonStyle(
    foregroundColor: WidgetStatePropertyAll(foreground),
    backgroundColor: WidgetStatePropertyAll(background),
    overlayColor: workbenchInteractionOverlay(foreground),
    side: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.focused)) {
        return BorderSide(
          color: primary ? foreground.withValues(alpha: .7) : colors.primary,
        );
      }
      return BorderSide(
        color: primary ? Colors.transparent : colors.outlineVariant,
      );
    }),
    shape: const WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.all(
          Radius.circular(WorkbenchStyle.controlRadius),
        ),
      ),
    ),
    textStyle: WidgetStatePropertyAll(
      WorkbenchStyle.body.copyWith(
        fontWeight: primary ? FontWeight.w600 : FontWeight.w500,
      ),
    ),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(
        horizontal: WorkbenchStyle.space12,
        vertical: WorkbenchStyle.space4,
      ),
    ),
    minimumSize: const WidgetStatePropertyAll(
      Size(72, WorkbenchStyle.dialogButtonHeight),
    ),
    elevation: const WidgetStatePropertyAll(0),
    visualDensity: VisualDensity.standard,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    splashFactory: NoSplash.splashFactory,
  );
}

WidgetStateProperty<Color?> workbenchInteractionOverlay(
  Color color,
) => WidgetStateProperty.resolveWith((states) {
  if (states.contains(WidgetState.pressed)) return color.withValues(alpha: .14);
  if (states.contains(WidgetState.focused)) return color.withValues(alpha: .10);
  return Colors.transparent;
});

OutlineInputBorder workbenchInputBorder(Color color) => OutlineInputBorder(
  borderRadius: BorderRadius.circular(WorkbenchStyle.controlRadius),
  borderSide: BorderSide(color: color, width: 1),
);

ThemeData workbenchTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final colors =
      ColorScheme.fromSeed(
        seedColor: const Color(0xff007aff),
        brightness: brightness,
      ).copyWith(
        primary: dark ? const Color(0xff79b7ff) : const Color(0xff0066cc),
        surface: dark ? const Color(0xff1e1e1e) : Colors.white,
        onSurface: dark ? const Color(0xfff2f2f4) : const Color(0xff252527),
        onSurfaceVariant: dark
            ? const Color(0xffb2b2b7)
            : const Color(0xff626267),
        outlineVariant: dark
            ? const Color(0xff3b3b3e)
            : const Color(0xffdedee2),
        surfaceContainerLow: dark
            ? const Color(0xff262628)
            : const Color(0xfff6f6f7),
        surfaceContainer: dark
            ? const Color(0xff303033)
            : const Color(0xffebebee),
        secondaryContainer: dark
            ? const Color(0xff284567)
            : const Color(0xffe0edff),
        onSecondaryContainer: dark
            ? const Color(0xffe1efff)
            : const Color(0xff164578),
      );
  final buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(WorkbenchStyle.controlRadius),
  );
  return ThemeData(
    colorScheme: colors,
    fontFamily: WorkbenchTypography.interfaceFamily(defaultTargetPlatform),
    fontFamilyFallback: WorkbenchTypography.interfaceFallback(
      defaultTargetPlatform,
    ),
    scaffoldBackgroundColor: dark
        ? const Color(0xff2b2b2d)
        : const Color(0xffefeff1),
    typography: Typography.material2021(platform: defaultTargetPlatform),
    textTheme: const TextTheme(
      titleLarge: WorkbenchStyle.dialogTitle,
      titleMedium: WorkbenchStyle.heading,
      titleSmall: WorkbenchStyle.body,
      bodyLarge: WorkbenchStyle.body,
      bodyMedium: WorkbenchStyle.body,
      bodySmall: WorkbenchStyle.caption,
      labelLarge: WorkbenchStyle.body,
      labelMedium: WorkbenchStyle.label,
      labelSmall: WorkbenchStyle.caption,
    ).apply(bodyColor: colors.onSurface, displayColor: colors.onSurface),
    visualDensity: VisualDensity.compact,
    splashFactory: NoSplash.splashFactory,
    hoverColor: Colors.transparent,
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        overlayColor: workbenchInteractionOverlay(colors.onSurface),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        overlayColor: workbenchInteractionOverlay(colors.primary),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        overlayColor: workbenchInteractionOverlay(colors.primary),
        elevation: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.pressed) ? 1.0 : 0.0,
        ),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      overlayColor: workbenchInteractionOverlay(colors.primary),
    ),
    radioTheme: RadioThemeData(
      overlayColor: workbenchInteractionOverlay(colors.primary),
    ),
    switchTheme: SwitchThemeData(
      overlayColor: workbenchInteractionOverlay(colors.primary),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thickness: const WidgetStatePropertyAll(6),
      trackVisibility: const WidgetStatePropertyAll(false),
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => colors.onSurface.withValues(
          alpha: states.contains(WidgetState.dragged) ? .45 : .25,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: colors.onSurface,
        shape: buttonShape,
        minimumSize: const Size(56, 28),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        textStyle: WorkbenchStyle.body.copyWith(fontWeight: FontWeight.w500),
      ).copyWith(overlayColor: workbenchInteractionOverlay(colors.onSurface)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style:
          FilledButton.styleFrom(
            shape: buttonShape,
            minimumSize: const Size(68, 28),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            textStyle: WorkbenchStyle.body.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ).copyWith(
            overlayColor: workbenchInteractionOverlay(colors.onPrimary),
            elevation: const WidgetStatePropertyAll(0),
          ),
    ),
    dividerTheme: DividerThemeData(color: colors.outlineVariant, thickness: 1),
    popupMenuTheme: PopupMenuThemeData(
      color: colors.surfaceContainerLow,
      elevation: WorkbenchStyle.menuElevation,
      shadowColor: const Color(0xff111111).withValues(alpha: dark ? .65 : .28),
      surfaceTintColor: Colors.transparent,
      menuPadding: const EdgeInsets.all(6),
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WorkbenchStyle.groupRadius),
        side: BorderSide(color: colors.outlineVariant),
      ),
      textStyle: WorkbenchStyle.body.copyWith(color: colors.onSurface),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      barrierColor: const Color(0xff111111).withValues(alpha: dark ? .56 : .32),
      elevation: WorkbenchStyle.dialogElevation,
      shadowColor: const Color(0xff111111).withValues(alpha: .30),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WorkbenchStyle.dialogRadius),
        side: BorderSide(color: colors.outlineVariant),
      ),
      titleTextStyle: WorkbenchStyle.dialogTitle.copyWith(
        color: colors.onSurface,
      ),
      contentTextStyle: WorkbenchStyle.body.copyWith(
        color: colors.onSurfaceVariant,
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        WorkbenchStyle.space20,
        0,
        WorkbenchStyle.space20,
        WorkbenchStyle.space16,
      ),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      visualDensity: VisualDensity.standard,
      hoverColor: Colors.transparent,
      filled: true,
      fillColor: colors.surface,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: WorkbenchStyle.space8,
        vertical: WorkbenchStyle.inputVerticalPadding,
      ),
      prefixIconConstraints: const BoxConstraints(
        minWidth: WorkbenchStyle.inputHeight,
        minHeight: WorkbenchStyle.inputHeight,
      ),
      suffixIconConstraints: const BoxConstraints(
        minWidth: WorkbenchStyle.inputHeight,
        minHeight: WorkbenchStyle.inputHeight,
      ),
      border: workbenchInputBorder(colors.outlineVariant),
      enabledBorder: workbenchInputBorder(colors.outlineVariant),
      focusedBorder: workbenchInputBorder(colors.primary),
      disabledBorder: workbenchInputBorder(colors.outlineVariant),
      errorBorder: workbenchInputBorder(colors.error),
      focusedErrorBorder: workbenchInputBorder(colors.error),
    ),
  );
}
