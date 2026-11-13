import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';

abstract final class WorkbenchStyle {
  static const space4 = 4.0;
  static const space8 = 8.0;
  static const space12 = 12.0;
  static const space16 = 16.0;
  static const space20 = 20.0;

  static const controlRadius = 7.0;
  static const groupRadius = 11.0;
  static const dialogRadius = 15.0;
  static const rowHeight = 32.0;
  static const toolbarControlHeight = 28.0;
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

  static String codeFont(TargetPlatform platform) => switch (platform) {
    TargetPlatform.macOS => 'Menlo',
    TargetPlatform.windows => 'Consolas',
    _ => 'monospace',
  };

  static TextStyle code(TargetPlatform platform) => TextStyle(
    fontFamily: codeFont(platform),
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );
}

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
    hoverColor: colors.onSurface.withValues(alpha: .07),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: colors.onSurface,
        shape: buttonShape,
        minimumSize: const Size(56, 28),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        textStyle: WorkbenchStyle.body.copyWith(fontWeight: FontWeight.w500),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: buttonShape,
        minimumSize: const Size(68, 28),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        textStyle: WorkbenchStyle.body.copyWith(fontWeight: FontWeight.w600),
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
      filled: true,
      fillColor: colors.surface,
      contentPadding: const EdgeInsets.all(12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(WorkbenchStyle.groupRadius),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(WorkbenchStyle.groupRadius),
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
    ),
  );
}

/// Dialog layout shared by settings, document confirmation and node editors.
class WorkbenchDialog extends StatelessWidget {
  const WorkbenchDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
  });

  final String title;
  final Widget content;
  final List<Widget> actions;

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
    scrollable: true,
    actions: actions,
  );
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
        child: Padding(padding: const EdgeInsets.all(2), child: child),
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
          child: Padding(padding: const EdgeInsets.all(2), child: child),
        ),
      ),
    );
  }
}

/// Consistent compact menu rows with aligned icons and optional checkmarks.
class WorkbenchMenuItem<T> extends PopupMenuItem<T> {
  WorkbenchMenuItem({
    super.key,
    required T value,
    required IconData icon,
    required String label,
    bool checked = false,
  }) : super(
         value: value,
         height: WorkbenchStyle.rowHeight,
         padding: const EdgeInsets.symmetric(horizontal: 10),
         child: Builder(
           builder: (context) {
             final colors = Theme.of(context).colorScheme;
             return Row(
               children: [
                 Icon(
                   icon,
                   size: WorkbenchStyle.controlIconSize,
                   color: checked ? colors.primary : colors.onSurfaceVariant,
                 ),
                 const SizedBox(width: 10),
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
