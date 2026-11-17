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
      theme.textTheme.bodyMedium!.copyWith(
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

// ============================================================
// AppColorTheme — 内置配色主题（不含 JSON 语法高亮）
// ============================================================

enum AppColorTheme {
  systemDefault,
  blue,
  amber,
  green,
  purple,
  rose,
  websiteBlue,
  slate,
  steel,
}

/// 按名称解析主题；未知名称回退到 systemDefault
AppColorTheme appColorThemeByName(String name) {
  switch (name) {
    case 'systemDefault':
      return AppColorTheme.systemDefault;
    case 'blue':
      return AppColorTheme.blue;
    case 'amber':
      return AppColorTheme.amber;
    case 'green':
      return AppColorTheme.green;
    case 'purple':
      return AppColorTheme.purple;
    case 'rose':
      return AppColorTheme.rose;
    case 'websiteBlue':
      return AppColorTheme.websiteBlue;
    case 'slate':
      return AppColorTheme.slate;
    case 'steel':
      return AppColorTheme.steel;
    default:
      return AppColorTheme.systemDefault;
  }
}

extension AppColorThemeExt on AppColorTheme {
  String get label => switch (this) {
    AppColorTheme.systemDefault => '系统默认',
    AppColorTheme.blue => '蓝色',
    AppColorTheme.amber => '琥珀',
    AppColorTheme.green => '绿色',
    AppColorTheme.purple => '紫色',
    AppColorTheme.rose => '玫瑰',
    AppColorTheme.websiteBlue => '网站蓝',
    AppColorTheme.slate => '石板灰',
    AppColorTheme.steel => '钢蓝',
  };
}

/// 主题颜色数据（亮/暗各一套）
class _ThemeColors {
  const _ThemeColors({
    required this.primaryLight,
    required this.primaryDark,
    required this.surfaceLight,
    required this.surfaceDark,
    required this.scaffoldBackgroundLight,
    required this.scaffoldBackgroundDark,
    required this.seedColor,
  });
  final Color primaryLight;
  final Color primaryDark;
  final Color surfaceLight;
  final Color surfaceDark;
  final Color scaffoldBackgroundLight;
  final Color scaffoldBackgroundDark;
  final Color seedColor;
}

const _themeColors = <AppColorTheme, _ThemeColors>{
  AppColorTheme.systemDefault: _ThemeColors(
    primaryLight: Color(0xff0066cc),
    primaryDark: Color(0xff79b7ff),
    surfaceLight: Colors.white,
    surfaceDark: Color(0xff1e1e1e),
    scaffoldBackgroundLight: Colors.white,
    scaffoldBackgroundDark: Color(0xff2b2b2d),
    seedColor: Color(0xff007aff),
  ),
  AppColorTheme.blue: _ThemeColors(
    primaryLight: Color(0xff0052a0),
    primaryDark: Color(0xff5a9bd6),
    surfaceLight: Color(0xfff7faff),
    surfaceDark: Color(0xff182333),
    scaffoldBackgroundLight: Color(0xffeef4fc),
    scaffoldBackgroundDark: Color(0xff101a29),
    seedColor: Color(0xff0066cc),
  ),
  AppColorTheme.amber: _ThemeColors(
    primaryLight: Color(0xffbb4400),
    primaryDark: Color(0xffe57300),
    surfaceLight: Color(0xfffffaf2),
    surfaceDark: Color(0xff29231c),
    scaffoldBackgroundLight: Color(0xfff7efdf),
    scaffoldBackgroundDark: Color(0xff201b16),
    seedColor: Color(0xffb7410c),
  ),
  AppColorTheme.green: _ThemeColors(
    primaryLight: Color(0xff0e6e3d),
    primaryDark: Color(0xff5fd68d),
    surfaceLight: Color(0xfff4faf6),
    surfaceDark: Color(0xff192820),
    scaffoldBackgroundLight: Color(0xffeaf3ed),
    scaffoldBackgroundDark: Color(0xff121e18),
    seedColor: Color(0xff0c7544),
  ),
  AppColorTheme.purple: _ThemeColors(
    primaryLight: Color(0xff7e3bf0),
    primaryDark: Color(0xffb88cff),
    surfaceLight: Color(0xfffaf7ff),
    surfaceDark: Color(0xff251f32),
    scaffoldBackgroundLight: Color(0xfff0eafb),
    scaffoldBackgroundDark: Color(0xff1c1727),
    seedColor: Color(0xff7e3bf0),
  ),
  AppColorTheme.rose: _ThemeColors(
    primaryLight: Color(0xffc2314a),
    primaryDark: Color(0xfff07c93),
    surfaceLight: Color(0xfffff7f9),
    surfaceDark: Color(0xff2d2028),
    scaffoldBackgroundLight: Color(0xfff9edf1),
    scaffoldBackgroundDark: Color(0xff231820),
    seedColor: Color(0xffc2314a),
  ),

  AppColorTheme.websiteBlue: _ThemeColors(
    primaryLight: Color(0xff235fd2),
    primaryDark: Color(0xff92b8ff),
    surfaceLight: Color(0xffffffff),
    surfaceDark: Color(0xff171e29),
    scaffoldBackgroundLight: Color(0xfff7f9fc),
    scaffoldBackgroundDark: Color(0xff10151e),
    seedColor: Color(0xff235fd2),
  ),
  AppColorTheme.slate: _ThemeColors(
    primaryLight: Color(0xff172538),
    primaryDark: Color(0xff5b7fa8),
    surfaceLight: Color(0xfff7f9fc),
    surfaceDark: Color(0xff171e29),
    scaffoldBackgroundLight: Color(0xfff2f5f9),
    scaffoldBackgroundDark: Color(0xff0e1219),
    seedColor: Color(0xff172538),
  ),
  AppColorTheme.steel: _ThemeColors(
    primaryLight: Color(0xff3b5a8c),
    primaryDark: Color(0xff8aa4d4),
    surfaceLight: Color(0xfff5f8fc),
    surfaceDark: Color(0xff1a2433),
    scaffoldBackgroundLight: Color(0xffecf0f5),
    scaffoldBackgroundDark: Color(0xff141c28),
    seedColor: Color(0xff3b5a8c),
  ),
};

final Map<(Brightness, AppColorTheme), ThemeData> _themeCache = {};

/// 构造并缓存主题：ColorScheme.fromSeed 是开销较大的 Material 3 色彩运算，
/// 相同 (brightness, theme) 组合只计算一次，避免每次 build 都重新生成 ThemeData。
ThemeData workbenchTheme(
  Brightness brightness, [
  AppColorTheme theme = AppColorTheme.systemDefault,
]) {
  return _themeCache.putIfAbsent((brightness, theme), () {
    final dark = brightness == Brightness.dark;
    final plain = theme == AppColorTheme.systemDefault;
    final colors = _themeColors[theme]!;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: colors.seedColor,
          brightness: brightness,
        ).copyWith(
          primary: dark ? colors.primaryDark : colors.primaryLight,
          surface: dark ? colors.surfaceDark : colors.surfaceLight,
          onSurface: dark ? const Color(0xfff2f2f4) : const Color(0xff252527),
          onSurfaceVariant: dark
              ? const Color(0xffb2b2b7)
              : const Color(0xff626267),
          outlineVariant: dark
              ? plain
                    ? const Color(0xff3b3b3e)
                    : Color.lerp(colors.surfaceDark, colors.primaryDark, .22)!
              : const Color(0xffdedee2),
          surfaceContainerLow: dark
              ? plain
                    ? const Color(0xff262628)
                    : Color.lerp(colors.surfaceDark, colors.primaryDark, .06)!
              : plain
              ? const Color(0xfff6f6f7)
              : Color.lerp(colors.surfaceLight, colors.seedColor, .035)!,
          surfaceContainer: dark
              ? plain
                    ? const Color(0xff303033)
                    : Color.lerp(colors.surfaceDark, colors.primaryDark, .12)!
              : plain
              ? const Color(0xffebebee)
              : Color.lerp(colors.surfaceLight, colors.seedColor, .075)!,
          secondaryContainer: dark
              ? plain
                    ? const Color(0xff284567)
                    : Color.lerp(colors.surfaceDark, colors.primaryDark, .22)!
              : plain
              ? const Color(0xffe0edff)
              : Color.lerp(colors.surfaceLight, colors.seedColor, .12)!,
          onSecondaryContainer: dark
              ? plain
                    ? const Color(0xffe1efff)
                    : const Color(0xfff2f5fa)
              : plain
              ? const Color(0xff164578)
              : Color.lerp(const Color(0xff152033), colors.seedColor, .35)!,
        );
    final platform = defaultTargetPlatform;
    final fontFamily = WorkbenchTypography.interfaceFamily(platform);
    final fontFamilyFallback = WorkbenchTypography.interfaceFallback(platform);
    TextStyle interfaceStyle(TextStyle style) => style.copyWith(
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
    );
    final body = interfaceStyle(WorkbenchStyle.body);
    return ThemeData(
      colorScheme: scheme,
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
      scaffoldBackgroundColor: dark
          ? colors.scaffoldBackgroundDark
          : colors.scaffoldBackgroundLight,
      typography: Typography.material2021(platform: platform),
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
      ).apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface),
      visualDensity: VisualDensity.compact,
      splashFactory: NoSplash.splashFactory,
      hoverColor: Colors.transparent,
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          overlayColor: workbenchInteractionOverlay(scheme.onSurface),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          overlayColor: workbenchInteractionOverlay(scheme.primary),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          overlayColor: workbenchInteractionOverlay(scheme.primary),
          elevation: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.pressed) ? 1.0 : 0.0,
          ),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        overlayColor: workbenchInteractionOverlay(scheme.primary),
      ),
      radioTheme: RadioThemeData(
        overlayColor: workbenchInteractionOverlay(scheme.primary),
      ),
      switchTheme: SwitchThemeData(
        overlayColor: workbenchInteractionOverlay(scheme.primary),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll(6),
        trackVisibility: const WidgetStatePropertyAll(false),
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => scheme.onSurface.withValues(
            alpha: states.contains(WidgetState.dragged) ? .45 : .25,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.onSurface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(WorkbenchStyle.controlRadius),
            ),
          ),
          minimumSize: const Size(56, 28),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          textStyle: body.copyWith(fontWeight: FontWeight.w500),
        ).copyWith(overlayColor: workbenchInteractionOverlay(scheme.onSurface)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style:
            FilledButton.styleFrom(
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(
                  Radius.circular(WorkbenchStyle.controlRadius),
                ),
              ),
              minimumSize: const Size(68, 28),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              textStyle: body.copyWith(fontWeight: FontWeight.w600),
            ).copyWith(
              overlayColor: workbenchInteractionOverlay(scheme.onPrimary),
              elevation: const WidgetStatePropertyAll(0),
            ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerLow,
        elevation: WorkbenchStyle.menuElevation,
        shadowColor: const Color(
          0xff111111,
        ).withValues(alpha: dark ? .65 : .28),
        surfaceTintColor: Colors.transparent,
        menuPadding: const EdgeInsets.all(6),
        position: PopupMenuPosition.under,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WorkbenchStyle.groupRadius),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        textStyle: body.copyWith(color: scheme.onSurface),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        barrierColor: const Color(
          0xff111111,
        ).withValues(alpha: dark ? .56 : .32),
        elevation: WorkbenchStyle.dialogElevation,
        shadowColor: const Color(0xff111111).withValues(alpha: .30),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WorkbenchStyle.dialogRadius),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        titleTextStyle: interfaceStyle(
          WorkbenchStyle.dialogTitle,
        ).copyWith(color: scheme.onSurface),
        contentTextStyle: body.copyWith(color: scheme.onSurfaceVariant),
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
        fillColor: scheme.surface,
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
        border: workbenchInputBorder(scheme.outlineVariant),
        enabledBorder: workbenchInputBorder(scheme.outlineVariant),
        focusedBorder: workbenchInputBorder(scheme.primary),
        disabledBorder: workbenchInputBorder(scheme.outlineVariant),
        errorBorder: workbenchInputBorder(scheme.error),
        focusedErrorBorder: workbenchInputBorder(scheme.error),
      ),
    );
  });
}
