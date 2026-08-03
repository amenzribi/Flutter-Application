import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:barakah40_flutter/app/theme/app_radii.dart';
import 'package:barakah40_flutter/app/theme/app_typography.dart';
import 'package:barakah40_flutter/app/theme/barakah_colors.dart';

/// Material 3 themes wired to Barakah design tokens.
abstract final class AppTheme {
  static ThemeData light() => _build(BarakahColors.light, Brightness.light);

  static ThemeData dark() => _build(BarakahColors.dark, Brightness.dark);

  static ThemeData _build(BarakahColors colors, Brightness brightness) {
    final textTheme = AppTypography.textTheme(colors);
    final scheme = ColorScheme(
      brightness: brightness,
      primary: colors.olive,
      onPrimary: colors.onOlive,
      secondary: colors.gold,
      onSecondary: colors.ink,
      error: colors.danger,
      onError: colors.onOlive,
      surface: colors.surface,
      onSurface: colors.ink,
      surfaceContainerHighest: colors.surfaceMuted,
      outline: colors.line,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.bg,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      fontFamily: AppTypography.bodyFamily,
      extensions: [colors],
      appBarTheme: AppBarTheme(
        backgroundColor: colors.bg.withValues(alpha: 0),
        foregroundColor: colors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.headlineSmall,
        systemOverlayStyle: brightness == Brightness.light
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceMuted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadii.mdAll,
          borderSide: BorderSide(color: colors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.mdAll,
          borderSide: BorderSide(color: colors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.mdAll,
          borderSide: BorderSide(color: colors.olive, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadii.mdAll,
          borderSide: BorderSide(color: colors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadii.mdAll,
          borderSide: BorderSide(color: colors.danger, width: 1.5),
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(color: colors.inkSoft),
        hintStyle: textTheme.bodyMedium?.copyWith(color: colors.muted),
      ),
      dividerTheme: DividerThemeData(color: colors.line, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.ink,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: colors.bg),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
      ),
    );
  }
}
