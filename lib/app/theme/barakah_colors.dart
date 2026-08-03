import 'package:flutter/material.dart';

/// Brand color tokens from legacy Barakah 40 (olive / gold / ivory / charcoal).
/// Quran typography colors are not defined here — keep separate later.
@immutable
class BarakahColors extends ThemeExtension<BarakahColors> {
  const BarakahColors({
    required this.bg,
    required this.bgElevated,
    required this.surface,
    required this.surfaceMuted,
    required this.ink,
    required this.inkSoft,
    required this.muted,
    required this.olive,
    required this.oliveDeep,
    required this.oliveSoft,
    required this.gold,
    required this.goldSoft,
    required this.line,
    required this.danger,
    required this.scrim,
    required this.onOlive,
    required this.heroOverlayStart,
    required this.heroOverlayEnd,
  });

  final Color bg;
  final Color bgElevated;
  final Color surface;
  final Color surfaceMuted;
  final Color ink;
  final Color inkSoft;
  final Color muted;
  final Color olive;
  final Color oliveDeep;
  final Color oliveSoft;
  final Color gold;
  final Color goldSoft;
  final Color line;
  final Color danger;
  final Color scrim;
  final Color onOlive;
  final Color heroOverlayStart;
  final Color heroOverlayEnd;

  static const light = BarakahColors(
    bg: Color(0xFFF4F1EA),
    bgElevated: Color(0xFFECE7DB),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF7F4ED),
    ink: Color(0xFF2F2C27),
    inkSoft: Color(0xFF6C6658),
    muted: Color(0xFF9A9384),
    olive: Color(0xFF6B7A4F),
    oliveDeep: Color(0xFF54623D),
    oliveSoft: Color(0xFFE8ECDC),
    gold: Color(0xFFBF9D57),
    goldSoft: Color(0xFFEFE6CF),
    line: Color(0xFFE9E3D6),
    danger: Color(0xFFBD6A59),
    scrim: Color(0xCC0B0F0C),
    onOlive: Color(0xFFF6F2E8),
    heroOverlayStart: Color(0x99060A10),
    heroOverlayEnd: Color(0xA8060A10),
  );

  static const dark = BarakahColors(
    bg: Color(0xFF121510),
    bgElevated: Color(0xFF1A1F18),
    surface: Color(0xFF1E241C),
    surfaceMuted: Color(0xFF252B22),
    ink: Color(0xFFF1ECE0),
    inkSoft: Color(0xFFC9C2B4),
    muted: Color(0xFF9A9384),
    olive: Color(0xFF8A9A6A),
    oliveDeep: Color(0xFF6B7A4F),
    oliveSoft: Color(0xFF2A3224),
    gold: Color(0xFFD4B878),
    goldSoft: Color(0xFF3A3426),
    line: Color(0xFF32382E),
    danger: Color(0xFFCF7A68),
    scrim: Color(0xE60B0F0C),
    onOlive: Color(0xFFF6F2E8),
    heroOverlayStart: Color(0xB3060A10),
    heroOverlayEnd: Color(0xCC060A10),
  );

  @override
  BarakahColors copyWith({
    Color? bg,
    Color? bgElevated,
    Color? surface,
    Color? surfaceMuted,
    Color? ink,
    Color? inkSoft,
    Color? muted,
    Color? olive,
    Color? oliveDeep,
    Color? oliveSoft,
    Color? gold,
    Color? goldSoft,
    Color? line,
    Color? danger,
    Color? scrim,
    Color? onOlive,
    Color? heroOverlayStart,
    Color? heroOverlayEnd,
  }) {
    return BarakahColors(
      bg: bg ?? this.bg,
      bgElevated: bgElevated ?? this.bgElevated,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      ink: ink ?? this.ink,
      inkSoft: inkSoft ?? this.inkSoft,
      muted: muted ?? this.muted,
      olive: olive ?? this.olive,
      oliveDeep: oliveDeep ?? this.oliveDeep,
      oliveSoft: oliveSoft ?? this.oliveSoft,
      gold: gold ?? this.gold,
      goldSoft: goldSoft ?? this.goldSoft,
      line: line ?? this.line,
      danger: danger ?? this.danger,
      scrim: scrim ?? this.scrim,
      onOlive: onOlive ?? this.onOlive,
      heroOverlayStart: heroOverlayStart ?? this.heroOverlayStart,
      heroOverlayEnd: heroOverlayEnd ?? this.heroOverlayEnd,
    );
  }

  @override
  BarakahColors lerp(ThemeExtension<BarakahColors>? other, double t) {
    if (other is! BarakahColors) return this;
    return BarakahColors(
      bg: Color.lerp(bg, other.bg, t)!,
      bgElevated: Color.lerp(bgElevated, other.bgElevated, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkSoft: Color.lerp(inkSoft, other.inkSoft, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      olive: Color.lerp(olive, other.olive, t)!,
      oliveDeep: Color.lerp(oliveDeep, other.oliveDeep, t)!,
      oliveSoft: Color.lerp(oliveSoft, other.oliveSoft, t)!,
      gold: Color.lerp(gold, other.gold, t)!,
      goldSoft: Color.lerp(goldSoft, other.goldSoft, t)!,
      line: Color.lerp(line, other.line, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
      onOlive: Color.lerp(onOlive, other.onOlive, t)!,
      heroOverlayStart: Color.lerp(
        heroOverlayStart,
        other.heroOverlayStart,
        t,
      )!,
      heroOverlayEnd: Color.lerp(heroOverlayEnd, other.heroOverlayEnd, t)!,
    );
  }
}

extension BarakahColorsX on BuildContext {
  BarakahColors get barakahColors =>
      Theme.of(this).extension<BarakahColors>() ?? BarakahColors.light;
}
