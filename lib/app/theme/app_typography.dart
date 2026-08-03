import 'package:flutter/material.dart';

import 'package:barakah40_flutter/app/theme/barakah_colors.dart';

/// UI typography — Tajawal (body) + Reem Kufi (display).
/// Do NOT use Quran fonts here; keep Amiri Quran for ayah surfaces later.
abstract final class AppTypography {
  static const String bodyFamily = 'Tajawal';
  static const String displayFamily = 'ReemKufi';

  static TextTheme textTheme(BarakahColors colors) {
    final base = TextStyle(
      fontFamily: bodyFamily,
      color: colors.ink,
      height: 1.45,
    );
    final display = TextStyle(
      fontFamily: displayFamily,
      color: colors.ink,
      height: 1.25,
    );

    return TextTheme(
      displayLarge: display.copyWith(fontSize: 40, fontWeight: FontWeight.w700),
      displayMedium: display.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w700,
      ),
      displaySmall: display.copyWith(fontSize: 28, fontWeight: FontWeight.w600),
      headlineLarge: display.copyWith(
        fontSize: 26,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: display.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w600,
      ),
      headlineSmall: display.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: base.copyWith(fontSize: 20, fontWeight: FontWeight.w700),
      titleMedium: base.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
      titleSmall: base.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
      bodyLarge: base.copyWith(fontSize: 16, fontWeight: FontWeight.w400),
      bodyMedium: base.copyWith(fontSize: 14, fontWeight: FontWeight.w400),
      bodySmall: base.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: colors.inkSoft,
      ),
      labelLarge: base.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
      labelMedium: base.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
      labelSmall: base.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: colors.muted,
      ),
    );
  }
}
